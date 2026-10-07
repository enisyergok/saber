import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:bson/bson.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_screenshot/golden_screenshot.dart';
import 'package:saber/components/canvas/_asset_cache.dart';
import 'package:saber/components/canvas/_stroke.dart';
import 'package:saber/components/canvas/image/editor_image.dart';
import 'package:saber/data/covers/cover_designs.dart';
import 'package:saber/data/editor/editor_core_info.dart';
import 'package:saber/data/editor/note_cover.dart';
import 'package:saber/data/editor/page.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/flavor_config.dart';
import 'package:saber/data/notebooks/notebook_spec.dart';
import 'package:saber/data/notebooks/paper_templates.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/tools/pen.dart';
import 'package:saber/data/versions/note_versions.dart';
import 'package:saber/i18n/strings.g.dart';
import 'package:saber/pages/editor/editor.dart';

import 'utils/test_editor.dart';
import 'utils/test_mock_channel_handlers.dart';

const _pageSize = Size(1000, 1400);

/// The pixel size of an encoded [picture].
Future<Size> _sizeOf(Uint8List picture) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(picture);
  final descriptor = await ui.ImageDescriptor.encoded(buffer);
  final size = Size(descriptor.width.toDouble(), descriptor.height.toDouble());
  descriptor.dispose();
  buffer.dispose();
  return size;
}

bool _isJpeg(Uint8List bytes) => bytes[0] == 0xFF && bytes[1] == 0xD8;
bool _isPng(Uint8List bytes) =>
    bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupMockPathProvider();
  FlavorConfig.setup();

  final cache = AssetCache();
  var ids = 0;

  PngEditorImage picture(
    Uint8List bytes, {
    bool invertible = false,
    Size pageSize = _pageSize,
  }) => PngEditorImage(
    id: ids++,
    assetCache: cache,
    extension: '.png',
    imageProvider: MemoryImage(bytes),
    pageIndex: 0,
    pageSize: pageSize,
    invertible: invertible,
    onMoveImage: null,
    onDeleteImage: null,
    onMiscChange: null,
  );

  /// A notebook as earlier versions made it: its cover as the first page,
  /// then a page with a line on it, then the empty page at the end.
  EditorCoreInfo oldNotebook(
    Uint8List coverPng, {
    bool invertible = false,
    bool withSecondPage = true,
  }) {
    final info = EditorCoreInfo(filePath: '/Eski defter');
    info.pages.add(
      EditorPage(
        size: _pageSize,
        backgroundImage: picture(coverPng, invertible: invertible),
      ),
    );
    if (withSecondPage) {
      final written = EditorPage(size: _pageSize);
      written.insertStroke(
        Stroke(
            color: Colors.black,
            pressureEnabled: false,
            options: Pen.fountainPenOptions,
            pageIndex: 1,
            page: written,
            toolId: .fountainPen,
          )
          ..addPoint(const Offset(100, 100))
          ..addPoint(const Offset(300, 120)),
      );
      info.pages
        ..add(written)
        ..add(EditorPage(size: _pageSize));
    }
    return info;
  }

  group('NoteCover:', () {
    test('a cover is kept with the note, and is not one of its pages', () {
      final info = EditorCoreInfo(filePath: '/Fizik')
        ..pages.add(EditorPage(size: _pageSize))
        ..cover = NoteCover(designId: 'c-navy', title: 'Fizik');

      final (bson, _) = info.saveToBinary(currentPageIndex: 0);
      final json = BsonCodec.deserialize(BsonBinary.from(bson));
      expect((json['z'] as List).length, 1, reason: 'one page, as before');
      expect(json['cv'], {'d': 'c-navy', 't': 'Fizik'});

      final read = EditorCoreInfo.fromJson(
        json,
        filePath: '/Fizik',
        onlyFirstPage: false,
      );
      expect(read.pages.length, 1);
      expect(read.pages.first.backgroundImage, isNull);
      expect(read.cover!.designId, 'c-navy');
      expect(read.cover!.title, 'Fizik');
      expect(read.cover!.design, CoverDesigns.byId('c-navy'));
      expect(read.cover!.isUsable, isTrue);
    });

    test('a cover that is a picture is kept as the picture', () {
      final bytes = Uint8List.fromList(List.generate(300, (i) => i & 0xff));
      final info = EditorCoreInfo(filePath: '/Eski')
        ..pages.add(EditorPage(size: _pageSize))
        ..cover = NoteCover(picture: bytes);

      final (bson, _) = info.saveToBinary(currentPageIndex: 0);
      final read = EditorCoreInfo.fromJson(
        BsonCodec.deserialize(BsonBinary.from(bson)),
        filePath: '/Eski',
        onlyFirstPage: false,
      );
      expect(read.cover!.picture, bytes);
      expect(read.cover!.designId, isNull);
      expect(read.cover!.title, isEmpty);
      expect(read.cover!.isUsable, isTrue);
    });

    test('a note without a cover has none, and says nothing about one', () {
      final info = EditorCoreInfo(filePath: '/Düz')
        ..pages.add(EditorPage(size: _pageSize));
      final (json, _) = info.toJson();
      expect(json.containsKey('cv'), isFalse);
      expect(NoteCover.fromJson(null), isNull);
      expect(NoteCover.fromJson(const <String, dynamic>{}), isNull);
      expect(NoteCover.fromJson('nonsense'), isNull);
    });

    test('a design this version does not know is kept, but not shown', () {
      final cover = NoteCover.fromJson(const {'d': 'from-the-future', 't': 'X'});
      expect(cover, isNotNull);
      expect(cover!.isUsable, isFalse);
      // ... and is written back as it was
      expect(cover.toJson(), {'d': 'from-the-future', 't': 'X'});
    });

    test('two states of a cover can be told apart', () {
      final a = NoteCover(designId: 'c-navy', title: 'Fizik');
      expect(a.signature, NoteCover(designId: 'c-navy', title: 'Fizik').signature);
      expect(
        a.signature,
        isNot(NoteCover(designId: 'c-navy', title: 'Kimya').signature),
      );
      expect(
        a.signature,
        isNot(NoteCover(designId: 'c-brown', title: 'Fizik').signature),
      );
    });

    testWidgets('a design is drawn to fill a card exactly', (tester) async {
      final cover = NoteCover(designId: 'c-navy', title: 'Fizik');
      final png = (await tester.runAsync(cover.render))!;
      expect(_isPng(png), isTrue);
      final size = (await tester.runAsync(() => _sizeOf(png)))!;
      expect(size.width, NoteCover.width);
      expect(size.width / size.height, closeTo(NoteCover.aspectRatio, 0.002));
    });
  });

  group('A notebook whose cover is still its first page:', () {
    /// The cover as earlier versions drew it: at the size of the page.
    Future<Uint8List> oldCover(WidgetTester tester) async =>
        (await tester.runAsync(
          () => CoverDesigns.byId(
            'c-navy',
          )!.renderPng(_pageSize, title: 'Eski defter'),
        ))!;

    testWidgets('the cover goes onto the card and out of the pages', (
      tester,
    ) async {
      final coverPng = await oldCover(tester);
      final info = oldNotebook(coverPng)..initialPageIndex = 1;
      addTearDown(info.dispose);
      final written = info.pages[1];
      expect(NoteCover.mayHaveCoverPage(info), isTrue);

      final adopted = await tester.runAsync(
        () => NoteCover.adoptCoverPage(info),
      );
      expect(adopted, isTrue);

      // The pages: what was written, and the empty page after it
      expect(info.pages.length, 2);
      expect(info.pages.first, same(written));
      expect(info.pages.first.backgroundImage, isNull);
      expect(info.pages.first.strokes.single.pageIndex, 0);
      expect(info.initialPageIndex, 0, reason: 'opens on the same page');

      // The cover: a small picture of what the page looked like
      final cover = info.cover!;
      expect(cover.designId, isNull);
      expect(cover.isUsable, isTrue);
      expect(_isJpeg(cover.picture!), isTrue);
      final size = (await tester.runAsync(() => _sizeOf(cover.picture!)))!;
      expect(size.width, NoteCover.width);
      expect(size.height, closeTo(NoteCover.width * 1400 / 1000, 1));
      expect(cover.picture!.length, lessThan(coverPng.length));

      // Done once: there is no cover page any more
      expect(NoteCover.mayHaveCoverPage(info), isFalse);
      expect(
        await tester.runAsync(() => NoteCover.adoptCoverPage(info)),
        isFalse,
      );
      expect(info.pages.length, 2);
    });

    testWidgets('a first page that is not a cover beyond doubt stays a page', (
      tester,
    ) async {
      final coverPng = await oldCover(tester);
      Future<void> expectLeftAlone(EditorCoreInfo info, String why) async {
        addTearDown(info.dispose);
        final pages = info.pages.toList();
        final adopted = await tester.runAsync(
          () => NoteCover.adoptCoverPage(info),
        );
        expect(adopted, isFalse, reason: why);
        expect(info.pages, pages, reason: why);
        expect(info.cover, isNull, reason: why);
      }

      // A photograph made the background of the first page: not as many
      // pixels as the page is wide and high.
      final photo = await tester.runAsync(
        () => CoverDesigns.byId(
          'c-navy',
        )!.renderPng(const Size(800, 600)),
      );
      await expectLeftAlone(oldNotebook(photo!), 'a picture of another size');

      // A picture that is inverted with the page, as added pictures are
      await expectLeftAlone(
        oldNotebook(coverPng, invertible: true),
        'an invertible picture',
      );

      // Something was written on the page
      final writtenOn = oldNotebook(coverPng);
      writtenOn.pages.first.insertStroke(
        Stroke(
            color: Colors.black,
            pressureEnabled: false,
            options: Pen.fountainPenOptions,
            pageIndex: 0,
            page: writtenOn.pages.first,
            toolId: .fountainPen,
          )
          ..addPoint(const Offset(10, 10))
          ..addPoint(const Offset(60, 20)),
      );
      await expectLeftAlone(writtenOn, 'a page that was written on');

      // The only page of the note
      await expectLeftAlone(
        oldNotebook(coverPng, withSecondPage: false),
        'the only page',
      );

      // A note that cannot be changed
      await expectLeftAlone(
        oldNotebook(coverPng)..readOnlyReason = .versionTooNew,
        'a read-only note',
      );
    });

    testWidgets('a notebook that has a cover keeps its pages', (tester) async {
      final coverPng = await oldCover(tester);
      final info = oldNotebook(coverPng)
        ..cover = NoteCover(designId: 'c-brown', title: 'Yeni');
      addTearDown(info.dispose);
      expect(
        await tester.runAsync(() => NoteCover.adoptCoverPage(info)),
        isFalse,
      );
      expect(info.pages.length, 3);
      expect(info.cover!.designId, 'c-brown');
    });
  });

  group('In the editor:', () {
    late Directory temp;

    setUp(() {
      temp = Directory.systemTemp.createTempSync('note_cover_test');
      Directory('${temp.path}/docs').createSync();
      NoteVersions.rootOverride = Directory('${temp.path}/versions');
    });
    tearDown(() {
      NoteVersions.rootOverride = null;
      temp.deleteSync(recursive: true);
    });

    Future<EditorState> openEditor(WidgetTester tester, String path) async {
      await tester.pumpWidget(
        TranslationProvider(
          child: ScreenshotApp(
            device: GoldenScreenshotDevices.androidPhone.device,
            home: Editor(key: UniqueKey(), path: path),
          ),
        ),
      );
      final editor = tester.state<EditorState>(find.byType(Editor));
      addTearDown(editor.cancelAutosaveAndMarkSaved);
      // Until the note has been read (and its cover page taken out)
      for (var i = 0; i < 150 && editor.coreInfo.filePath != path; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();
      }
      expect(editor.coreInfo.filePath, path);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pump();
      return editor;
    }

    Future<void> save(WidgetTester tester, EditorState editor) async {
      await tester.runAsync(
        () => editor.saveToFile().timeout(const Duration(seconds: 60)),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
      expect(editor.savingState.value, SavingState.saved);
    }

    Future<EditorCoreInfo> onDisk(WidgetTester tester, String path) async {
      final note = (await tester.runAsync(
        () => EditorCoreInfo.loadFromFilePath(path),
      ))!;
      addTearDown(note.dispose);
      return note;
    }

    Future<void> setUpEditor(WidgetTester tester) async {
      setupMockPrinting();
      setupMockWindowManager();
      stows.editorGnLayout.value = false;
      stows.autosaveDelay.value = -1;
      EditorImage.shouldLoadOutImmediately = true;
      addTearDown(() {
        EditorImage.shouldLoadOutImmediately = false;
        stows.autosaveDelay.value = stows.autosaveDelay.defaultValue;
      });
      await tester.runAsync(
        () => FileManager.init(
          documentsDirectory: '${temp.path}/docs',
          shouldWatchRootDirectory: false,
        ),
      );
    }

    testGoldens('a new notebook has its cover on the card, not as a page', (
      tester,
    ) async {
      await setUpEditor(tester);
      const path = '/Fizik';
      final preview = File('${temp.path}/docs$path.sbn2.p');
      final editor = await openEditor(tester, path);

      await editor.applyNotebookSpec(
        NotebookSpec(
          template: PaperTemplates.byId('lined-narrow'),
          cover: CoverDesigns.byId('c-navy'),
          name: 'Fizik',
        ),
      );
      await tester.pump();

      // Inside there is only paper
      final info = editor.coreInfo;
      for (final page in info.pages) {
        expect(page.backgroundImage, isNull);
        expect(page.isEmpty, isTrue);
      }
      expect(info.cover!.designId, 'c-navy');
      expect(info.cover!.title, 'Fizik');

      // The card shows the cover
      editor.drawTestStroke();
      await tester.pump();
      await save(tester, editor);
      final coverPicture = preview.readAsBytesSync();
      expect(
        coverPicture,
        await tester.runAsync(
          NoteCover(designId: 'c-navy', title: 'Fizik').render,
        ),
      );

      // ... and goes on showing it whatever is written inside
      editor.drawTestStroke();
      await tester.pump();
      await save(tester, editor);
      expect(preview.readAsBytesSync(), coverPicture);

      // The cover is in the note that was saved, and no page is a cover
      final saved = await onDisk(tester, path);
      expect(saved.cover!.designId, 'c-navy');
      expect(saved.cover!.title, 'Fizik');
      expect(saved.pages.first.backgroundImage, isNull);
      expect(saved.pages.first.strokes, isNotEmpty);

      // Another cover: the card follows
      editor.setCover(CoverDesigns.byId('c-brown'));
      await tester.pump();
      await save(tester, editor);
      expect(preview.readAsBytesSync(), isNot(coverPicture));
      expect((await onDisk(tester, path)).cover!.designId, 'c-brown');

      // No cover: the card shows the first page again
      editor.setCover(null);
      await tester.pump();
      await save(tester, editor);
      expect(editor.coreInfo.cover, isNull);
      expect((await onDisk(tester, path)).cover, isNull);
      final firstPage = preview.readAsBytesSync();
      final size = (await tester.runAsync(() => _sizeOf(firstPage)))!;
      expect(
        size.width / size.height,
        isNot(closeTo(NoteCover.aspectRatio, 0.002)),
        reason: 'the picture of a page, not of a cover',
      );

      // Let the messages about the cover go before the test ends
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 1));
    });

    testGoldens('an old notebook loses its cover page when it is opened, '
        'keeps its cover on the card and everything else where it was', (
      tester,
    ) async {
      await setUpEditor(tester);
      const path = '/Eski defter';
      final preview = File('${temp.path}/docs$path.sbn2.p');
      final coverPng = (await tester.runAsync(
        () => CoverDesigns.byId(
          'c-navy',
        )!.renderPng(_pageSize, title: 'Eski defter'),
      ))!;
      // A picture on the page after the cover: it must still be there.
      final photoPng = (await tester.runAsync(
        () => CoverDesigns.byId(
          'c-brown',
        )!.renderPng(const Size(320, 200)),
      ))!;

      // The notebook as an earlier version left it
      var editor = await openEditor(tester, path);
      final old = editor.coreInfo;
      old.pages.first.insertStroke(
        Stroke(
            color: Colors.black,
            pressureEnabled: false,
            options: Pen.fountainPenOptions,
            pageIndex: 0,
            page: old.pages.first,
            toolId: .fountainPen,
          )
          ..addPoint(const Offset(100, 100))
          ..addPoint(const Offset(300, 120)),
      );
      old.pages.first.images.add(
        PngEditorImage(
          id: old.nextImageId++,
          assetCache: old.assetCache,
          extension: '.png',
          imageProvider: MemoryImage(photoPng),
          pageIndex: 0,
          pageSize: _pageSize,
          onMoveImage: null,
          onDeleteImage: null,
          onMiscChange: null,
          naturalSize: const Size(320, 200),
          srcRect: const Rect.fromLTWH(0, 0, 320, 200),
          dstRect: const Rect.fromLTWH(50, 300, 320, 200),
        ),
      );
      old.pages.insert(
        0,
        EditorPage(
          size: _pageSize,
          backgroundImage: PngEditorImage(
            id: old.nextImageId++,
            assetCache: old.assetCache,
            extension: '.png',
            imageProvider: MemoryImage(coverPng),
            pageIndex: 0,
            pageSize: _pageSize,
            invertible: false,
            onMoveImage: null,
            onDeleteImage: null,
            onMiscChange: null,
          ),
        ),
      );
      for (var i = 0; i < old.pages.length; i++) {
        old.pages[i].updatePageIndex(i);
      }
      editor.createPage(1);
      editor.history.markUnsaved();
      editor.autosaveAfterDelay();
      await tester.pump();
      await save(tester, editor);

      final before = await onDisk(tester, path);
      expect(before.cover, isNull);
      expect(before.pages.first.backgroundImage, isA<PngEditorImage>());
      final pagesBefore = before.pages.length;
      File asset(int i) => File('${temp.path}/docs$path.sbn2.$i');
      expect(asset(0).readAsBytesSync(), coverPng);
      expect(asset(1).readAsBytesSync(), photoPng);

      // It is opened by this version
      editor = await openEditor(tester, path);
      final info = editor.coreInfo;
      expect(info.cover, isNotNull);
      expect(_isJpeg(info.cover!.picture!), isTrue);
      expect(info.pages.length, pagesBefore - 1);
      expect(info.pages.first.backgroundImage, isNull);
      expect(info.pages.first.strokes, hasLength(1));
      expect(info.pages.first.strokes.single.pageIndex, 0);
      expect(info.pages.first.images, hasLength(1));
      expect(info.pages.first.images.single.pageIndex, 0);

      await save(tester, editor);

      // On disk: the cover is the note's, the picture is still its file
      final after = await onDisk(tester, path);
      expect(after.cover!.picture, info.cover!.picture);
      expect(after.pages.length, pagesBefore - 1);
      expect(after.pages.first.backgroundImage, isNull);
      expect(after.pages.first.strokes, hasLength(1));
      expect(after.pages.first.images, hasLength(1));
      expect(asset(0).readAsBytesSync(), photoPng);
      expect(asset(1).existsSync(), isFalse, reason: 'the cover page is gone');

      // The card shows the cover
      expect(preview.readAsBytesSync(), info.cover!.picture);

      // Opened once more, nothing more is taken away
      editor = await openEditor(tester, path);
      expect(editor.coreInfo.pages.length, pagesBefore - 1);
      expect(editor.coreInfo.cover!.picture, info.cover!.picture);
    });
  });
}
