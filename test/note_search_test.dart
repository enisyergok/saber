import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saber/components/home/favorite_note_button.dart';
import 'package:saber/data/defter_strings.dart';
import 'package:saber/data/editor/editor_core_info.dart';
import 'package:saber/data/editor/page.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/flavor_config.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/search/note_search.dart';
import 'package:saber/data/tools/stroke_properties.dart';
import 'package:saber/pages/favorites.dart';
import 'package:saber/pages/search.dart';

import 'utils/test_mock_channel_handlers.dart';

NoteSearchEntry _entry(String path, String text, [int modified = 1]) =>
    NoteSearchEntry(path: path, modifiedMs: modified, text: text);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupMockPathProvider();
  FlavorConfig.setup();
  StrokeOptionsExtension.setDefaults();

  group('NoteSearchIndex.fold:', () {
    test('makes Turkish letters comparable', () {
      expect(NoteSearchIndex.fold('İSTANBUL ışık ŞĞÜÖÇ'), 'istanbul isik sguoc');
      expect(NoteSearchIndex.fold('Toplantı'), NoteSearchIndex.fold('TOPLANTI'));
      expect(NoteSearchIndex.fold('çalışma'), NoteSearchIndex.fold('calisma'));
    });

    test('keeps the length of ordinary text', () {
      const text = 'Proje notları: İlk toplantı!';
      expect(NoteSearchIndex.fold(text).length, text.length);
    });
  });

  group('NoteSearchIndex.search:', () {
    late NoteSearchIndex index;
    setUp(() {
      index = NoteSearchIndex()
        ..put(_entry('/Projeler/Plan', 'Bütçe toplantısı yarın saat 10'))
        ..put(_entry('/Toplantı notları', 'Gündem: bütçe ve takvim'))
        ..put(_entry('/Alışveriş', 'süt, ekmek, peynir'));
    });

    test('finds notes by content, ignoring Turkish letters and case', () {
      final results = index.search('BUTCE');
      expect(results.map((r) => r.path), ['/Projeler/Plan', '/Toplantı notları']);
    });

    test('ranks name matches first', () {
      final results = index.search('toplanti');
      expect(results.first.path, '/Toplantı notları');
      expect(results.first.nameMatches, isTrue);
      expect(results.last.path, '/Projeler/Plan');
      expect(results.last.nameMatches, isFalse);
    });

    test('every word has to match', () {
      expect(index.search('butce takvim').map((r) => r.path), [
        '/Toplantı notları',
      ]);
      expect(index.search('butce ekmek'), isEmpty);
    });

    test('words may match the name or the content', () {
      expect(index.search('plan yarin').map((r) => r.path), ['/Projeler/Plan']);
    });

    test('gives a snippet around the match', () {
      final result = index.search('yarın').single;
      expect(result.snippet, contains('yarın'));
    });

    test('an empty query finds nothing', () {
      expect(index.search('   '), isEmpty);
    });
  });

  group('NoteSearchIndex on disk:', () {
    late final String rootDir;
    late final File storage;
    setUpAll(() async {
      await FileManager.init(shouldWatchRootDirectory: false);
      rootDir = FileManager.documentsDirectory;
      storage = File('${Directory(rootDir).parent.path}/search_test_index.json');
    });

    Future<void> writeNote(String path, String text) async {
      final note = EditorCoreInfo(filePath: path);
      if (note.pages.isEmpty) note.pages.add(EditorPage());
      note.pages.first.quill.controller.document.insert(0, text);
      await FileManager.writeFile(
        '$path.sbn2',
        note.saveToBinary(currentPageIndex: 0).$1,
        awaitWrite: true,
      );
      note.dispose();
    }

    test('indexes typed text, notices edits and deletions', () async {
      await writeNote('/search_a', 'kahve molası');
      await writeNote('/search_b', 'çay saati');

      final index = NoteSearchIndex(storageFile: storage);
      await index.refresh();
      expect(index.search('kahve').map((r) => r.path), ['/search_a']);
      expect(index.search('cay').map((r) => r.path), ['/search_b']);

      // edit a note (a later modified time makes it be read again)
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      await writeNote('/search_a', 'limonata');
      await index.refresh();
      expect(index.search('kahve'), isEmpty);
      expect(index.search('limonata').map((r) => r.path), ['/search_a']);

      // delete a note
      await FileManager.deleteFile('/search_b.sbn2');
      await index.refresh();
      expect(index.search('cay'), isEmpty);
    });

    test('is saved and loaded again', () async {
      final first = NoteSearchIndex(storageFile: storage)
        ..put(_entry('/Saved', 'kalıcı metin'));
      await first.save();

      final second = NoteSearchIndex(storageFile: storage);
      await second.load();
      expect(second.search('kalici').map((r) => r.path), ['/Saved']);
    });

    test('a damaged index file is ignored', () async {
      await storage.writeAsString('{ not json');
      final index = NoteSearchIndex(storageFile: storage);
      await index.load();
      expect(index.length, 0);
    });
  });

  group('SearchPage:', () {
    testWidgets('shows results and opens the tapped one', (tester) async {
      final index = NoteSearchIndex()
        ..put(_entry('/Projeler/Plan', 'bütçe toplantısı'))
        ..put(_entry('/Alışveriş', 'süt ekmek'));
      String? opened;

      await tester.runAsync(() async {
        await FileManager.init(shouldWatchRootDirectory: false);
        await tester.pumpWidget(
          MaterialApp(
            home: SearchPage(index: index, onOpen: (_, path) => opened = path),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'butce');
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Plan'), findsOneWidget);
      expect(find.text('Alışveriş'), findsNothing);

      await tester.tap(find.text('Plan'));
      expect(opened, '/Projeler/Plan');

      await tester.enterText(find.byType(TextField), 'yokboyle');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(find.text(DefterStrings.searchNoResults), findsOneWidget);
    });
  });

  group('Favorites:', () {
    setUp(() => stows.favoriteFiles.value.clear());

    test('toggle adds, then removes', () {
      FavoriteNoteButton.toggle(['/a', '/b']);
      expect(stows.favoriteFiles.value, ['/a.sbn2', '/b.sbn2']);
      FavoriteNoteButton.toggle(['/a', '/b']);
      expect(stows.favoriteFiles.value, isEmpty);
    });

    test('toggle adds the missing ones when only some are favourites', () {
      FavoriteNoteButton.toggle(['/a']);
      FavoriteNoteButton.toggle(['/a', '/b']);
      expect(stows.favoriteFiles.value, ['/a.sbn2', '/b.sbn2']);
    });

    test('withoutExtension', () {
      expect(FavoritesPage.withoutExtension('/x/y.sbn2'), '/x/y');
      expect(FavoritesPage.withoutExtension('/x/y.sbn'), '/x/y');
    });

    testWidgets('page lists favourites and opens one', (tester) async {
      stows.favoriteFiles.value.addAll(['/Projeler/Plan.sbn2', '/Not.sbn2']);
      String? opened;
      await tester.pumpWidget(
        MaterialApp(home: FavoritesPage(onOpen: (_, path) => opened = path)),
      );
      expect(find.text('Plan'), findsOneWidget);
      expect(find.text('Not'), findsOneWidget);

      await tester.tap(find.text('Plan'));
      expect(opened, '/Projeler/Plan');

      await tester.tap(find.byTooltip(DefterStrings.removeFromFavorites).first);
      await tester.pump();
      expect(find.text('Plan'), findsNothing);
    });

    testWidgets('page says so when there are none', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: FavoritesPage()));
      expect(find.text(DefterStrings.noFavorites), findsOneWidget);
    });
  });
}
