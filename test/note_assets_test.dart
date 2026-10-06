import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saber/components/canvas/_asset_cache.dart';
import 'package:saber/components/canvas/image/editor_image.dart';
import 'package:saber/data/editor/editor_core_info.dart';
import 'package:saber/data/editor/note_assets.dart';
import 'package:saber/data/editor/page.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/flavor_config.dart';

import 'utils/test_mock_channel_handlers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupMockPathProvider();
  FlavorConfig.setup();

  late Directory temp;
  late String docs;
  final cache = AssetCache();
  var counter = 0;

  setUp(() async {
    temp = Directory.systemTemp.createTempSync('note_assets_test');
    docs = '${temp.path}/docs';
    Directory(docs).createSync();
    await FileManager.init(
      documentsDirectory: docs,
      shouldWatchRootDirectory: false,
    );
  });
  tearDown(() => temp.deleteSync(recursive: true));

  /// Bytes that are different for every [seed].
  Uint8List content(int seed, [int length = 4000]) => Uint8List.fromList(
    List.generate(length, (i) => (i * 31 + seed * 7 + (i >> 5)) & 0xff),
  );

  File asset(String note, int i) => File('$docs$note.sbn2.$i');

  PngEditorImage picture(ImageProvider provider) => PngEditorImage(
    id: counter++,
    assetCache: cache,
    extension: '.png',
    imageProvider: provider,
    pageIndex: 0,
    pageSize: const Size(1000, 1400),
    onMoveImage: null,
    onDeleteImage: null,
    onMiscChange: null,
    naturalSize: const Size(100, 100),
    srcRect: const Rect.fromLTWH(0, 0, 100, 100),
    dstRect: const Rect.fromLTWH(0, 0, 100, 100),
  );

  PdfEditorImage pdfPage(File file, int page) => PdfEditorImage(
    id: counter++,
    assetCache: cache,
    pdfBytes: null,
    pdfFile: file,
    pdfPage: page,
    pageIndex: page,
    pageSize: const Size(1000, 1400),
    naturalSize: const Size(595, 842),
    onMoveImage: null,
    onDeleteImage: null,
    onMiscChange: null,
  );

  /// The assets as a save would collect them from [images].
  OrderedAssetCache collect(List<EditorImage> images) {
    final assets = OrderedAssetCache();
    for (final image in images) {
      image.toJson(assets);
    }
    return assets;
  }

  group('Saving the assets of a note:', () {
    test('a PDF of many pages is copied once and then left alone', () async {
      const note = '/Fizik';
      final picked = File('${temp.path}/picked/Fizik.pdf')
        ..createSync(recursive: true)
        ..writeAsBytesSync(content(1, 300000));
      // Every page has a File object of its own, as when a note is read.
      final pages = [
        for (var i = 0; i < 40; i++) pdfPage(File(picked.path), i),
      ];

      var assets = collect(pages);
      expect(assets.length, 1, reason: 'forty pages, one PDF');
      var result = await NoteAssets.write('$note.sbn2', assets);
      expect(result.ok, isTrue);
      expect((result.kept, result.copied, result.written), (0, 1, 0));
      expect(asset(note, 0).readAsBytesSync(), content(1, 300000));
      expect(asset(note, 1).existsSync(), isFalse);
      expect(File('${asset(note, 0).path}.new').existsSync(), isFalse);
      // From now on the pages read the copy that belongs to the note…
      for (final page in pages) {
        expect(page.pdfFile!.path, asset(note, 0).path);
      }
      // …so the picked file may go away,
      picked.deleteSync();

      // and saving again does not write the PDF again.
      final before = asset(note, 0).statSync();
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      assets = collect(pages);
      expect(assets.length, 1);
      result = await NoteAssets.write('$note.sbn2', assets);
      expect(result.ok, isTrue);
      expect((result.kept, result.copied, result.written), (1, 0, 0));
      expect(asset(note, 0).statSync().modified, before.modified);
      expect(asset(note, 0).readAsBytesSync(), content(1, 300000));
    });

    test('taking the first of three pictures away keeps the other two, '
        'however often the note is saved', () async {
      const note = '/Resimli';
      for (var i = 0; i < 3; i++) {
        asset(note, i).writeAsBytesSync(content(10 + i));
      }
      // As read from disk: each picture is shown from its file.
      final a = picture(FileImage(asset(note, 0)));
      final b = picture(FileImage(asset(note, 1)));
      final c = picture(FileImage(asset(note, 2)));

      var result = await NoteAssets.write('$note.sbn2', collect([a, b, c]));
      expect((result.kept, result.copied, result.written), (3, 0, 0));

      // The first picture is deleted: the others move up a number.
      result = await NoteAssets.write('$note.sbn2', collect([b, c]));
      expect(result.ok, isTrue);
      expect((result.kept, result.copied, result.written), (0, 2, 0));
      await FileManager.removeUnusedAssets('$note.sbn2', numAssets: 2);
      expect(asset(note, 0).readAsBytesSync(), content(11));
      expect(asset(note, 1).readAsBytesSync(), content(12));
      expect(asset(note, 2).existsSync(), isFalse);
      expect(b.assetFile!.path, asset(note, 0).path);
      expect(c.assetFile!.path, asset(note, 1).path);

      // Saved again and again: nothing is mixed up (each picture is read
      // from where it is now, not from where it was when the note opened).
      for (var i = 0; i < 3; i++) {
        result = await NoteAssets.write('$note.sbn2', collect([b, c]));
        expect(result.ok, isTrue);
        expect((result.kept, result.copied, result.written), (2, 0, 0));
        await FileManager.removeUnusedAssets('$note.sbn2', numAssets: 2);
      }
      expect(asset(note, 0).readAsBytesSync(), content(11));
      expect(asset(note, 1).readAsBytesSync(), content(12));

      // The two change places (the page they are on was moved up).
      result = await NoteAssets.write('$note.sbn2', collect([c, b]));
      expect(result.ok, isTrue);
      expect(result.copied, 2);
      expect(asset(note, 0).readAsBytesSync(), content(12));
      expect(asset(note, 1).readAsBytesSync(), content(11));
      expect(c.assetFile!.path, asset(note, 0).path);
      expect(b.assetFile!.path, asset(note, 1).path);
      result = await NoteAssets.write('$note.sbn2', collect([c, b]));
      expect((result.kept, result.copied, result.written), (2, 0, 0));
      expect(asset(note, 0).readAsBytesSync(), content(12));
      expect(asset(note, 1).readAsBytesSync(), content(11));
    });

    test('a picture that was just added is written from memory', () async {
      const note = '/Yeni';
      asset(note, 0).writeAsBytesSync(content(20));
      final old = picture(FileImage(asset(note, 0)));
      final added = picture(MemoryImage(content(21)));

      // The new picture comes first on the page.
      var result = await NoteAssets.write('$note.sbn2', collect([added, old]));
      expect(result.ok, isTrue);
      expect((result.kept, result.copied, result.written), (0, 1, 1));
      expect(asset(note, 0).readAsBytesSync(), content(21));
      expect(asset(note, 1).readAsBytesSync(), content(20));
      expect(old.assetFile!.path, asset(note, 1).path);
      expect(added.assetFile, isNull, reason: 'it stays in memory');

      result = await NoteAssets.write('$note.sbn2', collect([added, old]));
      expect((result.kept, result.copied, result.written), (1, 0, 1));
      expect(asset(note, 0).readAsBytesSync(), content(21));
      expect(asset(note, 1).readAsBytesSync(), content(20));
    });

    test('a picture whose file is gone does not stop the others', () async {
      const note = '/Eksik';
      final gone = picture(FileImage(File('${temp.path}/gone.png')));
      final added = picture(MemoryImage(content(31)));

      final result = await NoteAssets.write(
        '$note.sbn2',
        collect([gone, added]),
      );
      expect(result.ok, isFalse);
      expect(result.errors.length, 1);
      expect(result.written, 1);
      expect(asset(note, 0).existsSync(), isFalse);
      expect(asset(note, 1).readAsBytesSync(), content(31));
      expect(File('${asset(note, 0).path}.new').existsSync(), isFalse);
    });

    test('the copy being put in place is never shown as a note or synced', () {
      for (final path in ['/a.sbn2.0.new', '/dir/b.sbn2.12.new']) {
        expect(
          FileManager.transientFileRegex.hasMatch(path),
          isTrue,
          reason: path,
        );
      }
      expect(FileManager.transientFileRegex.hasMatch('/news.sbn2'), isFalse);
    });
  });

  group('Notes of earlier versions:', () {
    test('the copies of a PDF, one a page, become one file again', () async {
      const note = '/Eski PDF';
      // As an earlier version left it: a picture, then a PDF of four
      // pages saved four times, then another PDF of the same size twice.
      asset(note, 0).writeAsBytesSync(content(50));
      for (var i = 1; i <= 4; i++) {
        asset(note, i).writeAsBytesSync(content(51, 200000));
      }
      for (var i = 5; i <= 6; i++) {
        asset(note, i).writeAsBytesSync(content(52, 200000));
      }
      final photo = picture(FileImage(asset(note, 0)));
      final first = [
        for (var i = 0; i < 4; i++) pdfPage(asset(note, i + 1), i),
      ];
      final second = [
        for (var i = 0; i < 2; i++) pdfPage(asset(note, i + 5), i),
      ];
      final coreInfo = EditorCoreInfo(filePath: note);
      addTearDown(coreInfo.dispose);
      coreInfo.pages.add(EditorPage(images: [photo]));
      for (final page in [...first, ...second]) {
        coreInfo.pages.add(EditorPage(backgroundImage: page));
      }
      List<EditorImage> all() => [photo, ...first, ...second];

      expect(collect(all()).length, 7);
      expect(await NoteAssets.shareIdenticalPdfs(coreInfo), 4);
      for (final page in first) {
        expect(page.pdfFile!.path, asset(note, 1).path);
      }
      for (final page in second) {
        expect(page.pdfFile!.path, asset(note, 5).path, reason: 'another PDF');
      }
      // Nothing on disk was touched by looking.
      for (var i = 0; i <= 6; i++) {
        expect(asset(note, i).existsSync(), isTrue);
      }

      // The next save keeps one file for each PDF and removes the rest.
      final assets = collect(all());
      expect(assets.length, 3);
      final result = await NoteAssets.write('$note.sbn2', assets);
      expect(result.ok, isTrue);
      expect((result.kept, result.copied, result.written), (2, 1, 0));
      await FileManager.removeUnusedAssets('$note.sbn2', numAssets: 3);
      expect(asset(note, 0).readAsBytesSync(), content(50));
      expect(asset(note, 1).readAsBytesSync(), content(51, 200000));
      expect(asset(note, 2).readAsBytesSync(), content(52, 200000));
      expect(asset(note, 3).existsSync(), isFalse);
      expect(asset(note, 6).existsSync(), isFalse);
      for (final page in second) {
        expect(page.pdfFile!.path, asset(note, 2).path);
      }

      // Looking again finds nothing to do.
      expect(await NoteAssets.shareIdenticalPdfs(coreInfo), 0);
      expect(collect(all()).length, 3);
    });

    test('PDFs that only have the same size are left apart', () async {
      const note = '/Benzer';
      asset(note, 0).writeAsBytesSync(content(60, 50000));
      asset(note, 1).writeAsBytesSync(content(61, 50000));
      final a = pdfPage(asset(note, 0), 0), b = pdfPage(asset(note, 1), 0);
      final coreInfo = EditorCoreInfo(filePath: note);
      addTearDown(coreInfo.dispose);
      coreInfo.pages
        ..add(EditorPage(backgroundImage: a))
        ..add(EditorPage(backgroundImage: b));

      expect(await NoteAssets.shareIdenticalPdfs(coreInfo), 0);
      expect(a.pdfFile!.path, asset(note, 0).path);
      expect(b.pdfFile!.path, asset(note, 1).path);
    });
  });

  group('When the files of a note move:', () {
    test('its pictures are read from where they are now', () async {
      const from = '/Eski ad', to = '/Klasör/Yeni ad';
      asset(from, 0).writeAsBytesSync(content(40));
      asset(from, 1).writeAsBytesSync(content(41));
      final pdf = pdfPage(asset(from, 0), 0);
      final photo = picture(FileImage(asset(from, 1)));
      final added = picture(MemoryImage(content(42)));
      final elsewhere = picture(FileImage(File('${temp.path}/other.png')));

      final coreInfo = EditorCoreInfo(filePath: from);
      addTearDown(coreInfo.dispose);
      coreInfo.pages
        ..add(EditorPage(backgroundImage: pdf, images: [photo]))
        ..add(EditorPage(images: [added, elsewhere]));

      File(
        '$docs$from.sbn2',
      ).writeAsBytesSync(const [1, 2, 3]);
      final moved = await FileManager.moveFile('$from.sbn2', '$to.sbn2');
      expect(moved, '$to.sbn2');
      NoteAssets.moved(coreInfo, '$from.sbn2', moved);

      expect(pdf.pdfFile!.path, asset(to, 0).path);
      expect(photo.assetFile!.path, asset(to, 1).path);
      expect(added.assetFile, isNull);
      expect(elsewhere.assetFile!.path, '${temp.path}/other.png');

      // A save after the move finds everything in place.
      final result = await NoteAssets.write(
        '$to.sbn2',
        collect([pdf, photo]),
      );
      expect(result.ok, isTrue);
      expect((result.kept, result.copied, result.written), (2, 0, 0));
      expect(asset(to, 0).readAsBytesSync(), content(40));
      expect(asset(to, 1).readAsBytesSync(), content(41));
    });
  });
}
