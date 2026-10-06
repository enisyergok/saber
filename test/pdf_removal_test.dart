import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_screenshot/golden_screenshot.dart';
import 'package:saber/components/canvas/_asset_cache.dart';
import 'package:saber/components/canvas/image/editor_image.dart';
import 'package:saber/components/canvas/save_indicator.dart';
import 'package:saber/components/toolbar/pdf_remove_dialog.dart';
import 'package:saber/data/defter_strings.dart';
import 'package:saber/data/editor/editor_core_info.dart';
import 'package:saber/data/editor/editor_history.dart';
import 'package:saber/data/editor/note_assets.dart';
import 'package:saber/data/editor/page.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/flavor_config.dart';
import 'package:saber/data/pdf/pdf_removal.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/versions/note_versions.dart';
import 'package:saber/i18n/strings.g.dart';
import 'package:saber/pages/editor/editor.dart';

import 'utils/test_editor.dart';
import 'utils/test_mock_channel_handlers.dart';
import 'utils/test_pdfium.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupMockPathProvider();
  FlavorConfig.setup();

  late Directory temp;
  final cache = AssetCache();
  var counter = 0;
  setUp(() => temp = Directory.systemTemp.createTempSync('pdf_removal_test'));
  tearDown(() {
    try {
      temp.deleteSync(recursive: true);
    } on FileSystemException {
      // Still in use by something that is being closed.
    }
  });

  Uint8List content(int seed, [int length = 4000]) => Uint8List.fromList(
    List.generate(length, (i) => (i * 31 + seed * 7 + (i >> 5)) & 0xff),
  );

  PdfEditorImage pdfPage(File file, int page) => PdfEditorImage(
    id: counter++,
    assetCache: cache,
    pdfBytes: null,
    pdfFile: file,
    pdfPage: page,
    pageIndex: 0,
    pageSize: const Size(1000, 1400),
    naturalSize: const Size(595, 842),
    onMoveImage: null,
    onDeleteImage: null,
    onMiscChange: null,
  );

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

  /// A note like this (the letter is the PDF, * means written on):
  ///
  ///     0: own page with a photo
  ///     1: A1    2: A2*    3: A3
  ///     4: own page with a photo
  ///     5: B1*   6: B2
  ///     7: the empty last page
  ({
    EditorCoreInfo note,
    List<EditorPage> pages,
    List<PdfEditorImage> a,
    List<PdfEditorImage> b,
  })
  build() {
    final fileA = File('${temp.path}/A.pdf'), fileB = File('${temp.path}/B.pdf');
    final a = [for (var i = 0; i < 3; i++) pdfPage(File(fileA.path), i)];
    final b = [for (var i = 0; i < 2; i++) pdfPage(File(fileB.path), i)];
    final note = EditorCoreInfo(filePath: '/Karışık');
    addTearDown(note.dispose);
    final pages = [
      EditorPage(images: [picture(MemoryImage(content(1)))]),
      EditorPage(backgroundImage: a[0]),
      EditorPage(
        backgroundImage: a[1],
        images: [picture(MemoryImage(content(2)))],
      ),
      EditorPage(backgroundImage: a[2]),
      EditorPage(images: [picture(MemoryImage(content(3)))]),
      EditorPage(
        backgroundImage: b[0],
        images: [picture(MemoryImage(content(4)))],
      ),
      EditorPage(backgroundImage: b[1]),
      EditorPage(),
    ];
    note.pages.addAll(pages);
    for (var i = 0; i < pages.length; i++) {
      pages[i].updatePageIndex(i);
    }
    return (note: note, pages: pages, a: a, b: b);
  }

  group('Which pages a choice means:', () {
    test('the open page, its PDF, or every PDF', () {
      final (:note, pages: _, a: _, b: _) = build();
      List<int> of(PdfRemovalScope scope, int at) =>
          PdfRemover.pagesIn(note, scope, at);

      expect(of(.page, 2), [2]);
      expect(of(.document, 2), [1, 2, 3]);
      expect(of(.document, 6), [5, 6]);
      expect(of(.all, 2), [1, 2, 3, 5, 6]);
      // From a page that is no PDF page there is no "this page" or "this
      // PDF", only all of them.
      expect(of(.page, 0), isEmpty);
      expect(of(.document, 4), isEmpty);
      expect(of(.all, 0), [1, 2, 3, 5, 6]);
      expect(of(.all, 99), [1, 2, 3, 5, 6]);
      expect(of(.page, 99), isEmpty);

      expect(PdfRemover.writtenOn(note, [1, 2, 3]), 1);
      expect(PdfRemover.writtenOn(note, [1, 3, 6]), 0);
    });
  });

  group('Taking a PDF out:', () {
    test('written pages stay with their writing, the others go; undo and '
        'redo are exact', () {
      final (:note, :pages, :a, :b) = build();
      final written = pages[2].images.single;

      final removal = PdfRemover.remove(note, PdfRemover.pagesIn(note, .document, 2))!;
      expect(removal.removed.map((e) => e.index), [1, 3]);
      expect(removal.stripped.single.page, same(pages[2]));
      // The note: own page, the written page without its PDF, the rest.
      expect(note.pages, [pages[0], pages[2], pages[4], pages[5], pages[6], pages[7]]);
      expect(pages[2].backgroundImage, isNull);
      expect(pages[2].images.single, same(written));
      expect(pages[2].size, const Size(1000, 1400), reason: 'writing stays put');
      // The other PDF was not touched.
      expect(pages[5].backgroundImage, same(b[0]));
      expect(pages[6].backgroundImage, same(b[1]));
      // What is on the pages knows where it is now.
      expect(written.pageIndex, 1);
      expect(b[1].pageIndex, 4);
      expect(removal.images.toSet(), {a[0], a[1], a[2]});

      PdfRemover.undo(note, removal);
      expect(note.pages, pages);
      expect([for (final page in pages) page.backgroundImage], [
        null, a[0], a[1], a[2], null, b[0], b[1], null,
      ]);
      expect(written.pageIndex, 2);
      expect(a[2].pageIndex, 3);
      // Undoing twice changes nothing more.
      PdfRemover.undo(note, removal);
      expect(note.pages, pages);

      PdfRemover.redo(note, removal);
      expect(note.pages, [pages[0], pages[2], pages[4], pages[5], pages[6], pages[7]]);
      expect(pages[2].backgroundImage, isNull);
      PdfRemover.undo(note, removal);
      expect(note.pages, pages);
      expect(pages[2].backgroundImage, same(a[1]));
    });

    test('every PDF at once, and one page at a time', () {
      final (:note, :pages, a: _, b: _) = build();

      final all = PdfRemover.remove(note, PdfRemover.pagesIn(note, .all, 0))!;
      expect(all.removed.map((e) => e.index), [1, 3, 6]);
      expect(all.stripped.map((e) => e.page), [pages[2], pages[5]]);
      expect(note.pages, [pages[0], pages[2], pages[4], pages[5], pages[7]]);
      expect(note.pages.every((page) => page.backgroundImage == null), isTrue);
      PdfRemover.undo(note, all);
      expect(note.pages, pages);

      // One page that was not written on: it goes.
      final one = PdfRemover.remove(note, PdfRemover.pagesIn(note, .page, 3))!;
      expect(one.removed.single.index, 3);
      expect(one.stripped, isEmpty);
      expect(note.pages.length, pages.length - 1);
      PdfRemover.undo(note, one);

      // One page that was: only the PDF behind it goes.
      final kept = PdfRemover.remove(note, PdfRemover.pagesIn(note, .page, 5))!;
      expect(kept.removed, isEmpty);
      expect(note.pages, pages);
      expect(pages[5].backgroundImage, isNull);
      PdfRemover.undo(note, kept);

      // Nothing to do where there is no PDF.
      expect(PdfRemover.remove(note, [0, 4, 7, 99, -1]), isNull);
      expect(note.pages, pages);
    });

    test('the history knows what undo could still bring back', () {
      final (:note, pages: _, :a, b: _) = build();
      final history = EditorHistory();
      expect(history.imagesKept, isEmpty);

      final removal = PdfRemover.remove(note, PdfRemover.pagesIn(note, .document, 1))!;
      history.recordChange(
        EditorHistoryItem(
          type: .removePdf,
          pageIndex: 1,
          strokes: const [],
          images: const [],
          pdfRemoval: removal,
        ),
      );
      expect(history.imagesKept.toSet().containsAll(a), isTrue);

      // Still after it was undone: redo could take them out again and a
      // later undo bring them back.
      final item = history.undo();
      PdfRemover.undo(note, item.pdfRemoval!);
      expect(history.imagesKept.toSet().containsAll(a), isTrue);
    });
  });

  group('On disk:', () {
    test('a PDF that was removed keeps its file while undo can bring it '
        'back, and comes back whole', () async {
      await FileManager.init(
        documentsDirectory: '${temp.path}/docs',
        shouldWatchRootDirectory: false,
      );
      Directory('${temp.path}/docs').createSync();
      const note = '/Silinen';
      File asset(int i) => File('${temp.path}/docs$note.sbn2.$i');
      asset(0).writeAsBytesSync(content(70, 100000)); // the PDF
      asset(1).writeAsBytesSync(content(71)); // a photo
      final pdf = [for (var i = 0; i < 3; i++) pdfPage(asset(0), i)];
      final photo = picture(FileImage(asset(1)));

      OrderedAssetCache collect(
        List<EditorImage> inNote, [
        List<EditorImage> kept = const [],
      ]) {
        final assets = OrderedAssetCache();
        for (final image in inNote) {
          image.toJson(assets);
        }
        // As a save does for what the history holds.
        for (final image in kept) {
          assets.add(image.assetFile!, owner: image);
        }
        return assets;
      }

      // The PDF is removed and the note saved: the photo becomes the first
      // asset, the PDF stays on disk behind it.
      var assets = collect([photo], pdf);
      expect(assets.length, 2);
      var result = await NoteAssets.write('$note.sbn2', assets);
      expect(result.ok, isTrue);
      await FileManager.removeUnusedAssets('$note.sbn2', numAssets: 2);
      expect(asset(0).readAsBytesSync(), content(71));
      expect(asset(1).readAsBytesSync(), content(70, 100000));
      expect(photo.assetFile!.path, asset(0).path);
      for (final page in pdf) {
        expect(page.pdfFile!.path, asset(1).path);
      }

      // Saved again with the PDF still removed: nothing moves.
      result = await NoteAssets.write('$note.sbn2', collect([photo], pdf));
      expect((result.kept, result.copied, result.written), (2, 0, 0));

      // Undo: the PDF is in the note again, in front of the photo.
      assets = collect([...pdf, photo], pdf);
      expect(assets.length, 2, reason: 'in the note and in the history: once');
      result = await NoteAssets.write('$note.sbn2', assets);
      expect(result.ok, isTrue);
      await FileManager.removeUnusedAssets('$note.sbn2', numAssets: 2);
      expect(asset(0).readAsBytesSync(), content(70, 100000));
      expect(asset(1).readAsBytesSync(), content(71));
      expect(asset(2).existsSync(), isFalse);

      // Removed again and the note closed: the history is gone, and so is
      // the file.
      result = await NoteAssets.write('$note.sbn2', collect([photo]));
      expect(result.ok, isTrue);
      await FileManager.removeUnusedAssets('$note.sbn2', numAssets: 1);
      expect(asset(0).readAsBytesSync(), content(71));
      expect(asset(1).existsSync(), isFalse);
    });

    test('a picture read from a file and the same file as such are one '
        'asset', () {
      final file = File('${temp.path}/x.png');
      final assets = OrderedAssetCache();
      expect(assets.add(FileImage(file), owner: 'in the note'), 0);
      expect(assets.add(File(file.path), owner: 'in the history'), 0);
      expect(assets.length, 1);
      expect(assets.ownersOf(0), ['in the note', 'in the history']);
    });
  });

  group('The dialog:', () {
    Future<PdfRemovalScope?> ask(
      WidgetTester tester,
      EditorCoreInfo note,
      int at,
      Future<void> Function() act,
    ) async {
      PdfRemovalScope? chosen;
      var closed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  chosen = await showDialog<PdfRemovalScope>(
                    context: context,
                    builder: (_) =>
                        PdfRemoveDialog(coreInfo: note, currentPageIndex: at),
                  );
                  closed = true;
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await act();
      await tester.pumpAndSettle();
      expect(closed, isTrue);
      return chosen;
    }

    testWidgets('offers the page, the PDF and all, with what each means', (
      tester,
    ) async {
      final (:note, pages: _, a: _, b: _) = build();
      final chosen = await ask(tester, note, 2, () async {
        expect(find.text(DefterStrings.pdfRemoveAbout), findsOneWidget);
        expect(find.byKey(const Key('pdfRemove-page')), findsOneWidget);
        expect(find.byKey(const Key('pdfRemove-document')), findsOneWidget);
        expect(find.byKey(const Key('pdfRemove-all')), findsOneWidget);
        // The open page was written on.
        expect(
          find.text(DefterStrings.pdfRemoveCounts(pages: 1, written: 1)),
          findsOneWidget,
        );
        expect(
          find.text(DefterStrings.pdfRemoveCounts(pages: 3, written: 1)),
          findsOneWidget,
        );
        expect(
          find.text(DefterStrings.pdfRemoveCounts(pages: 5, written: 2)),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('pdfRemove-document')));
      });
      expect(chosen, PdfRemovalScope.document);
    });

    testWidgets('offers only what there is, and can be left', (tester) async {
      final (:note, pages: _, a: _, b: _) = build();
      // From a page of the note's own: only all PDFs.
      var chosen = await ask(tester, note, 0, () async {
        expect(find.byKey(const Key('pdfRemove-page')), findsNothing);
        expect(find.byKey(const Key('pdfRemove-document')), findsNothing);
        expect(find.byKey(const Key('pdfRemove-all')), findsOneWidget);
        await tester.tap(find.byKey(const Key('pdfRemoveCancel')));
      });
      expect(chosen, isNull);

      // A note with one PDF of one page: one choice.
      final single = EditorCoreInfo(filePath: '/Tek');
      addTearDown(single.dispose);
      single.pages
        ..add(
          EditorPage(backgroundImage: pdfPage(File('${temp.path}/C.pdf'), 0)),
        )
        ..add(EditorPage());
      chosen = await ask(tester, single, 0, () async {
        expect(find.byKey(const Key('pdfRemove-page')), findsOneWidget);
        expect(find.byKey(const Key('pdfRemove-document')), findsNothing);
        expect(find.byKey(const Key('pdfRemove-all')), findsNothing);
        expect(
          find.text(DefterStrings.pdfRemoveCounts(pages: 1, written: 0)),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('pdfRemove-page')));
      });
      expect(chosen, PdfRemovalScope.page);
    });

    test('says in words what happened', () {
      for (final (removed, kept) in [(3, 0), (0, 2), (4, 1), (1, 0), (0, 1)]) {
        expect(
          DefterStrings.pdfRemoved(removed: removed, kept: kept),
          isNotEmpty,
        );
      }
      expect(
        DefterStrings.pdfRemoveCounts(pages: 5, written: 2),
        isNot(DefterStrings.pdfRemoveCounts(pages: 5, written: 0)),
      );
    });
  });

  group('With PDFium:', () {
    final hasPdfium = setUpPdfium();

    testGoldens('Editor: a PDF is removed, what was written stays, undo '
        'brings the PDF back and the file goes when the note is closed', (
      tester,
    ) async {
      if (!hasPdfium) {
        markTestSkipped('PDFium was not found on this computer');
        return;
      }
      setupMockPrinting();
      // Leaving the editor ends full screen, through the window's channel.
      setupMockWindowManager();
      stows.editorGnLayout.value = false;
      EditorImage.shouldLoadOutImmediately = true;
      addTearDown(() => EditorImage.shouldLoadOutImmediately = false);

      Directory('${temp.path}/docs').createSync();
      NoteVersions.rootOverride = Directory('${temp.path}/versions');
      addTearDown(() => NoteVersions.rootOverride = null);
      await tester.runAsync(
        () => FileManager.init(
          documentsDirectory: '${temp.path}/docs',
          shouldWatchRootDirectory: false,
        ),
      );
      final pdf = (await tester.runAsync(
        () => writeSamplePdf(Directory('${temp.path}'), copies: 2),
      ))!;
      final pdfBytes = pdf.readAsBytesSync();
      const pdfPages = 6;

      const path = '/Kaldırılacak';
      await tester.pumpWidget(
        TranslationProvider(
          child: ScreenshotApp(
            device: GoldenScreenshotDevices.androidPhone.device,
            home: Editor(path: path),
          ),
        ),
      );
      final editor = tester.state<EditorState>(find.byType(Editor));
      addTearDown(editor.cancelAutosaveAndMarkSaved);
      Future<void> wait([int ms = 100]) => tester.runAsync(
        () => Future<void>.delayed(Duration(milliseconds: ms)),
      );
      await wait(500);
      await tester.pump();

      expect(
        await tester.runAsync(
          () => editor
              .importPdfFromFilePath(pdf.path)
              .timeout(const Duration(seconds: 60)),
        ),
        isTrue,
      );
      await tester.pump();
      // Something is written on the first PDF page.
      editor.drawTestStroke();
      await tester.pump();

      Future<void> save() async {
        await tester.runAsync(
          () => editor.saveToFile().timeout(const Duration(seconds: 60)),
        );
        await wait();
        await tester.pump();
        expect(editor.savingState.value, SavingState.saved);
      }

      Future<EditorCoreInfo> onDisk() async {
        final note = (await tester.runAsync(
          () => EditorCoreInfo.loadFromFilePath(path),
        ))!;
        addTearDown(note.dispose);
        return note;
      }

      File asset(int i) => File('${temp.path}/docs$path.sbn2.$i');

      await save();
      expect(asset(0).readAsBytesSync(), pdfBytes);
      final pagesBefore = editor.coreInfo.pages.toList();
      expect(pagesBefore.length, pdfPages + 1);

      // The PDF is removed.
      final removal = editor.removePdf(.all);
      await tester.pump();
      expect(removal, isNotNull);
      expect(removal!.removed.length, pdfPages - 1);
      expect(removal.stripped.length, 1);
      var pages = editor.coreInfo.pages;
      expect(pages.length, 2, reason: 'the written page and an empty one');
      expect(pages.first, same(pagesBefore.first));
      expect(pages.first.backgroundImage, isNull);
      expect(pages.first.strokes.length, 1);
      expect(pages.last.isEmpty, isTrue);
      expect(editor.history.canUndo, isTrue);

      // Saved: the note on disk has no PDF, but the file is still there
      // because undo could need it.
      await save();
      var disk = await onDisk();
      expect(disk.pages.length, 2);
      expect(disk.pages.first.backgroundImage, isNull);
      expect(disk.pages.first.strokes.length, 1);
      expect(asset(0).readAsBytesSync(), pdfBytes);

      // Undo: every page is back where it was, with its PDF.
      editor.undo();
      await tester.pump();
      pages = editor.coreInfo.pages;
      expect(pages.length, pdfPages + 1);
      for (var i = 0; i < pdfPages; i++) {
        expect(pages[i], same(pagesBefore[i]));
        expect(pages[i].backgroundImage, isA<PdfEditorImage>());
      }
      expect(pages.first.strokes.length, 1);
      await save();
      disk = await onDisk();
      expect(disk.pages.length, pdfPages + 1);
      for (var i = 0; i < pdfPages; i++) {
        final background = disk.pages[i].backgroundImage! as PdfEditorImage;
        expect(background.pdfFile!.path, asset(0).path);
        expect(background.pdfPage, i);
      }
      expect(asset(0).readAsBytesSync(), pdfBytes);
      expect(asset(1).existsSync(), isFalse);

      // Redo, save, and close the note: now the PDF's file goes too.
      editor.redo();
      await tester.pump();
      expect(editor.coreInfo.pages.length, 2);
      await save();
      expect(asset(0).existsSync(), isTrue);

      await tester.pumpWidget(const SizedBox());
      for (var i = 0; i < 40 && asset(0).existsSync(); i++) {
        await wait(50);
        await tester.pump();
      }
      expect(asset(0).existsSync(), isFalse, reason: 'the space is given back');
      disk = await onDisk();
      expect(disk.pages.length, 2);
      expect(disk.pages.first.strokes.length, 1);
      expect(disk.pages.first.backgroundImage, isNull);
    });
  });
}
