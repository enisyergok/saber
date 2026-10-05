import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:saber/data/ai/note_assistant.dart';
import 'package:saber/data/search/handwriting_text.dart';
import 'package:saber/data/search/note_search.dart';

void main() {
  group('bandChunks:', () {
    Rect at(double y) => Rect.fromLTWH(0, y, 100, 20);

    test('nothing gives no groups', () {
      expect(bandChunks<Rect>([], (r) => r), isEmpty);
    });

    test('lines close together stay in one group', () {
      final chunks = bandChunks<Rect>([at(0), at(100), at(300)], (r) => r);
      expect(chunks, hasLength(1));
      expect(chunks.single, hasLength(3));
    });

    test('a long page is cut into bands, top to bottom', () {
      final items = [for (var y = 0.0; y < 2000; y += 50) at(y)];
      final chunks = bandChunks<Rect>(items.reversed.toList(), (r) => r);
      expect(chunks.length, greaterThan(2));
      expect(chunks.expand((c) => c), hasLength(items.length));
      final tops = [for (final c in chunks) c.map((r) => r.top).reduce(
        (a, b) => a < b ? a : b,
      )];
      expect(tops, [...tops]..sort());
      for (final chunk in chunks) {
        final top = chunk.map((r) => r.top).reduce((a, b) => a < b ? a : b);
        final bottom = chunk.map((r) => r.bottom).reduce((a, b) => a > b ? a : b);
        expect(bottom - top, lessThan(700));
      }
    });
  });

  group('HandwritingTexts:', () {
    late Directory dir;
    setUp(() {
      dir = Directory.systemTemp.createTempSync('hw_text');
      HandwritingTexts.fileOverride = File('${dir.path}/texts.json');
      HandwritingTexts.resetForTesting();
    });
    tearDown(() {
      HandwritingTexts.fileOverride = null;
      HandwritingTexts.resetForTesting();
      dir.deleteSync(recursive: true);
    });

    const text = NoteHandwriting(recognizedMs: 5, pages: ['merhaba dünya', '']);

    test('is kept between runs, by note path without extension', () async {
      await HandwritingTexts.put('/Plan.sbn2', text);
      HandwritingTexts.resetForTesting();
      await HandwritingTexts.load();
      expect(HandwritingTexts.of('/Plan')?.pages, ['merhaba dünya', '']);
      expect(HandwritingTexts.of('/Plan.sbn2')?.recognizedMs, 5);
      expect(HandwritingTexts.of('/Plan')!.hasText, isTrue);
    });

    test('follows a renamed note and goes with a deleted one', () async {
      await HandwritingTexts.put('/A', text);
      await HandwritingTexts.move('/A.sbn2', '/Klasör/B.sbn2');
      expect(HandwritingTexts.of('/A'), isNull);
      expect(HandwritingTexts.of('/Klasör/B')?.pages.first, 'merhaba dünya');
      await HandwritingTexts.remove('/Klasör/B');
      expect(HandwritingTexts.of('/Klasör/B'), isNull);
      HandwritingTexts.resetForTesting();
      await HandwritingTexts.load();
      expect(HandwritingTexts.all, isEmpty);
    });

    test('a damaged file is ignored, not fatal', () async {
      File('${dir.path}/texts.json').writeAsStringSync('{not json');
      await HandwritingTexts.load();
      expect(HandwritingTexts.all, isEmpty);
      await HandwritingTexts.put('/A', text);
      expect(HandwritingTexts.of('/A'), isNotNull);
    });

    test('no temporary file is left behind', () async {
      await HandwritingTexts.put('/A', text);
      expect(File('${dir.path}/texts.json.tmp').existsSync(), isFalse);
    });
  });

  group('outdated text:', () {
    const text = NoteHandwriting(recognizedMs: 100, pages: ['x']);
    test('a note saved after reading is outdated', () {
      expect(HandwritingIndexer.isOutdated(text, 101), isTrue);
      expect(HandwritingIndexer.isOutdated(text, 100), isFalse);
      expect(HandwritingIndexer.isOutdated(text, 50), isFalse);
    });
  });

  group('search with handwriting:', () {
    late NoteSearchIndex index;
    setUp(() {
      index = NoteSearchIndex()
        ..put(
          const NoteSearchEntry(path: '/Defter', modifiedMs: 1, text: 'yazılı'),
        )
        ..put(
          const NoteSearchEntry(path: '/Toplantı', modifiedMs: 1, text: ''),
        );
      index.setHandwriting('/Toplantı', [
        'ilk sayfa boş',
        'Bütçe toplantısı yarın saat 10',
      ]);
    });

    test('finds a note by its handwriting and says which page', () {
      final results = index.search('butce');
      expect(results.map((r) => r.path), ['/Toplantı']);
      expect(results.single.page, 2);
      expect(results.single.snippet, contains('Bütçe'));
    });

    test('typed text matches without a page', () {
      final result = index.search('yazili').single;
      expect(result.path, '/Defter');
      expect(result.page, isNull);
    });

    test('every word may match in a different place', () {
      expect(index.search('ilk butce').map((r) => r.path), ['/Toplantı']);
    });

    test('forgetting the handwriting removes it from search', () {
      index.setHandwriting('/Toplantı', const []);
      expect(index.search('butce'), isEmpty);
    });

    test('the assistant also reads handwriting', () {
      final excerpts = NoteAssistant.retrieve(index, 'Bütçe ne zaman?');
      expect(excerpts.map((e) => e.path), ['/Toplantı']);
      expect(excerpts.single.text, contains('yarın'));
    });
  });
}
