import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_screenshot/golden_screenshot.dart';
import 'package:saber/components/canvas/_asset_cache.dart';
import 'package:saber/components/canvas/image/editor_image.dart';
import 'package:saber/components/canvas/image/pdf_document_cache.dart';
import 'package:saber/components/canvas/save_indicator.dart';
import 'package:saber/data/editor/editor_core_info.dart';
import 'package:saber/data/editor/page.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/flavor_config.dart';
import 'package:saber/data/pdf/pdf_import.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/versions/note_versions.dart';
import 'package:saber/i18n/strings.g.dart';
import 'package:saber/pages/editor/editor.dart';

import 'utils/test_editor.dart';
import 'utils/test_mock_channel_handlers.dart';
import 'utils/test_pdfium.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temp;
  setUp(() => temp = Directory.systemTemp.createTempSync('pdf_import_test'));
  tearDown(() {
    try {
      temp.deleteSync(recursive: true);
    } on FileSystemException {
      // Still in use by something that is being closed.
    }
  });

  group('Before a PDF is opened:', () {
    test('the mark of a PDF is looked for at the start of the file', () {
      expect(PdfImport.looksLikePdf('%PDF-1.7\n'.codeUnits), isTrue);
      // Some PDFs have a few bytes in front of the mark.
      expect(PdfImport.looksLikePdf([0xef, 0xbb, 0xbf, ...'%PDF-1.4'.codeUnits]),
          isTrue);
      expect(PdfImport.looksLikePdf('PK\x03\x04 not a pdf'.codeUnits), isFalse);
      expect(PdfImport.looksLikePdf('%PDF'.codeUnits), isFalse);
      expect(PdfImport.looksLikePdf(const []), isFalse);
      // Further in than a reader would look.
      expect(
        PdfImport.looksLikePdf([
          ...List.filled(PdfImport.headLength, 0x20),
          ...'%PDF-1.7'.codeUnits,
        ]),
        isFalse,
      );
    });

    test('a file that is plainly not a PDF is refused with the reason',
        () async {
      Future<PdfImportFailure?> failureOf(String path) async {
        try {
          await PdfImport.check(path);
          return null;
        } on PdfImportException catch (e) {
          return e.failure;
        }
      }

      expect(await failureOf('${temp.path}/yok.pdf'), PdfImportFailure.missing);

      final empty = File('${temp.path}/bos.pdf')..writeAsBytesSync(const []);
      expect(await failureOf(empty.path), PdfImportFailure.empty);

      final picture = File('${temp.path}/resim.pdf')
        ..writeAsBytesSync([0x89, 0x50, 0x4e, 0x47, ...List.filled(64, 1)]);
      expect(await failureOf(picture.path), PdfImportFailure.notPdf);

      final pdf = File('${temp.path}/gercek.pdf')
        ..writeAsBytesSync(await samplePdfBytes());
      expect(await failureOf(pdf.path), isNull);
    });

    test('names are made safe for a file of the app', () {
      expect(PdfImport.safeName('Ders notları.pdf'), 'Ders notları.pdf');
      expect(PdfImport.safeName('../../etc/passwd'), 'passwd');
      expect(PdfImport.safeName(r'C:\Belgeler\a:b?.pdf'), 'a_b_.pdf');
      expect(PdfImport.safeName(''), 'document.pdf');
      expect(PdfImport.safeName('..'), 'document.pdf');
      final long = PdfImport.safeName('${'a' * 300}.pdf');
      expect(long.length, 120);
      expect(long.endsWith('.pdf'), isTrue);
    });

    test('a note made from a PDF gets a name a note can have', () {
      expect(PdfImport.noteNameFor('Fizik 101.pdf'), 'Fizik 101');
      expect(PdfImport.noteNameFor('ÖDEV.PDF'), 'ÖDEV');
      expect(PdfImport.noteNameFor('/cache/file_picker/17/Ders.pdf'), 'Ders');
      expect(PdfImport.noteNameFor('a:b?c*d|e<f>g"h.pdf'), 'a b c d e f g h');
      expect(PdfImport.noteNameFor('Bölüm 3....pdf'), 'Bölüm 3');
      expect(PdfImport.noteNameFor('.pdf'), 'PDF');
      expect(PdfImport.noteNameFor('...'), 'PDF');
      expect(PdfImport.noteNameFor('adsız'), 'adsız');
      final long = PdfImport.noteNameFor('${'ığüşöç ' * 60}.pdf');
      expect(long.runes.length, lessThanOrEqualTo(PdfImport.maxNoteNameLength));
      expect(long, isNot(endsWith(' ')));
      // With the endings a note's files get, the name still fits in what a
      // file system allows.
      expect('$long.sbn2.123.new'.codeUnits.length * 2, lessThan(510));
    });

    test('a picked file that came without a path is written to a file',
        () async {
      final bytes = await samplePdfBytes();
      final real = File('${temp.path}/var.pdf')..writeAsBytesSync(bytes);

      // The picker gave a copy: it is used as it is, nothing is read.
      expect(
        await PdfImport.localPath(
          path: real.path,
          name: 'var.pdf',
          readBytes: () async => throw StateError('must not be read'),
        ),
        real.path,
      );

      // Only the content came.
      final folder = Directory('${temp.path}/tmp')..createSync();
      final written = await PdfImport.localPath(
        path: null,
        name: 'Ödev: 3/4.pdf',
        readBytes: () async => bytes,
        folder: folder,
      );
      expect(written.startsWith(folder.path), isTrue);
      expect(File(written).readAsBytesSync(), bytes);
      expect(written.endsWith('4.pdf'), isTrue);

      // A path to a file that is not there is not trusted.
      final again = await PdfImport.localPath(
        path: '${temp.path}/gitti.pdf',
        name: 'gitti.pdf',
        readBytes: () async => bytes,
        folder: folder,
      );
      expect(again, isNot('${temp.path}/gitti.pdf'));
      expect(File(again).readAsBytesSync(), bytes);

      // Nothing to read at all: the reason is given, nothing is thrown raw.
      await expectLater(
        PdfImport.localPath(
          path: null,
          name: 'x.pdf',
          readBytes: () async => throw const FileSystemException('no access'),
          folder: folder,
        ),
        throwsA(
          isA<PdfImportException>().having(
            (e) => e.failure,
            'failure',
            PdfImportFailure.missing,
          ),
        ),
      );
    });
  });

  group('Assets of a note:', () {
    test('two File objects for one path are not equal to Dart', () {
      // This is why paths are compared: the pages of a PDF each hold a File
      // of their own, and each used to be saved as a PDF of its own.
      expect(File('${temp.path}/a.pdf') == File('${temp.path}/a.pdf'), isFalse);
    });

    test('the pages of one PDF file are one asset', () {
      final assets = OrderedAssetCache();
      final first = assets.add(File('${temp.path}/a.pdf'), owner: 'page 1');
      final second = assets.add(File('${temp.path}/a.pdf'), owner: 'page 2');
      final other = assets.add(File('${temp.path}/b.pdf'), owner: 'page 3');
      expect(first, 0);
      expect(second, 0, reason: 'another File object for the same path');
      expect(other, 1);
      expect(assets.length, 2);
      expect(assets.ownersOf(0), ['page 1', 'page 2']);
      expect(assets.ownersOf(1), ['page 3']);
      expect(assets.fileAt(0)!.path, '${temp.path}/a.pdf');

      final bytes = assets.add(Uint8List.fromList([1, 2, 3]));
      expect(assets.add(Uint8List.fromList([1, 2, 3])), bytes);
      expect(assets.fileAt(bytes), isNull);
      expect(assets.ownersOf(bytes), isEmpty);
    });
  });

  group('With PDFium:', () {
    final hasPdfium = setUpPdfium();

    test('every page has its own size once the PDF is opened', () async {
      if (!hasPdfium) {
        markTestSkipped('PDFium was not found on this computer');
        return;
      }
      final pdf = await writeSamplePdf(temp);
      final cache = PdfDocumentCache();
      addTearDown(cache.dispose);

      final document = await PdfImport.open(cache, pdf.path);
      expect(document.pages.length, samplePdfSizes.length);
      for (var i = 0; i < samplePdfSizes.length; i++) {
        final page = document.pages[i];
        expect(page.isLoaded, isTrue, reason: 'page ${i + 1} was read');
        expect(page.width, closeTo(samplePdfSizes[i].width, 0.5));
        expect(page.height, closeTo(samplePdfSizes[i].height, 0.5));
      }

      // The same document is handed out again, also under another name.
      expect(await cache.load(pdf.path), same(document));
      cache.alias(pdf.path, '${temp.path}/note.sbn2.0');
      expect(await cache.load('${temp.path}/note.sbn2.0'), same(document));
    });

    test('a file that only looks like a PDF is refused, and can be retried',
        () async {
      if (!hasPdfium) {
        markTestSkipped('PDFium was not found on this computer');
        return;
      }
      final broken = File('${temp.path}/bozuk.pdf')
        ..writeAsStringSync('%PDF-1.7\nthis is not really a pdf\n%%EOF\n');
      final cache = PdfDocumentCache();
      addTearDown(cache.dispose);

      for (var attempt = 0; attempt < 2; attempt++) {
        await expectLater(
          PdfImport.open(cache, broken.path),
          throwsA(
            isA<PdfImportException>().having(
              (e) => e.failure,
              'failure',
              PdfImportFailure.unreadable,
            ),
          ),
        );
      }

      // The file is replaced by a real PDF: it opens (the failure was not
      // remembered).
      broken.writeAsBytesSync(await samplePdfBytes());
      final document = await PdfImport.open(cache, broken.path);
      expect(document.pages.length, samplePdfSizes.length);
    });

    testGoldens('Editor: a PDF is imported, saved once and found again', (
      tester,
    ) async {
      if (!hasPdfium) {
        markTestSkipped('PDFium was not found on this computer');
        return;
      }
      setupMockPathProvider();
      setupMockPrinting();
      FlavorConfig.setup();
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
      // Six pages: the three sizes twice.
      final pdf = (await tester.runAsync(
        () => writeSamplePdf(Directory('${temp.path}'), copies: 2),
      ))!;
      final pdfBytes = pdf.readAsBytesSync();
      const pdfPages = 6;

      const path = '/PDF dersi';
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
      expect(editor.coreInfo.pages.length, 1);

      // Something that is not a PDF: the reason is shown, nothing changes.
      final notPdf = File('${temp.path}/foto.pdf')
        ..writeAsBytesSync([0x89, 0x50, 0x4e, 0x47, ...List.filled(64, 1)]);
      final refused = await tester.runAsync(
        () => editor.importPdfFromFilePath(notPdf.path),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(refused, isFalse);
      expect(find.byKey(const Key('pdfImportError')), findsOneWidget);
      expect(editor.coreInfo.pages.length, 1);
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('pdfImportError')),
          matching: find.byType(TextButton),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('pdfImportError')), findsNothing);

      // The PDF itself.
      final imported = await tester.runAsync(
        () => editor
            .importPdfFromFilePath(pdf.path)
            .timeout(const Duration(seconds: 60)),
      );
      expect(imported, isTrue);
      await tester.pump();

      final pages = editor.coreInfo.pages;
      expect(pages.length, pdfPages + 1, reason: 'the PDF and an empty page');
      expect(pages.last.isEmpty, isTrue);
      for (var i = 0; i < pdfPages; i++) {
        final background = pages[i].backgroundImage;
        expect(background, isA<PdfEditorImage>());
        final size = samplePdfSizes[i % samplePdfSizes.length];
        expect(pages[i].size.width, EditorPage.defaultWidth);
        expect(
          pages[i].size.height,
          closeTo(EditorPage.defaultWidth * size.height / size.width, 1),
          reason: 'page ${i + 1} keeps its own shape',
        );
        expect((background! as PdfEditorImage).pdfPage, i);
      }

      Future<void> save() async {
        await tester.runAsync(
          () => editor.saveToFile().timeout(const Duration(seconds: 60)),
        );
        await wait();
        await tester.pump();
      }

      File asset(int i) => File('${temp.path}/docs$path.sbn2.$i');

      // The first save puts the PDF next to the note: once, whole.
      await save();
      expect(editor.savingState.value, SavingState.saved);
      expect(File('${temp.path}/docs$path.sbn2').existsSync(), isTrue);
      expect(asset(0).readAsBytesSync(), pdfBytes);
      expect(asset(1).existsSync(), isFalse, reason: 'one copy, not one a page');
      expect(File('${asset(0).path}.new').existsSync(), isFalse);
      for (var i = 0; i < pdfPages; i++) {
        final background = pages[i].backgroundImage! as PdfEditorImage;
        expect(background.pdfFile!.path, asset(0).path);
      }

      // Writing on a page saves the note again, but not the PDF.
      final firstWrite = asset(0).lastModifiedSync();
      await wait(1100);
      editor.drawTestStroke();
      await tester.pump();
      await save();
      expect(editor.savingState.value, SavingState.saved);
      expect(asset(0).lastModifiedSync(), firstWrite);
      expect(asset(1).existsSync(), isFalse);

      // The note opens again from disk as it was left.
      final reopened = (await tester.runAsync(
        () => EditorCoreInfo.loadFromFilePath(path),
      ))!;
      addTearDown(reopened.dispose);
      expect(reopened.pages.length, pdfPages + 1);
      expect(reopened.pages.first.strokes.length, 1);
      for (var i = 0; i < pdfPages; i++) {
        final background = reopened.pages[i].backgroundImage;
        expect(background, isA<PdfEditorImage>());
        final pdfImage = background! as PdfEditorImage;
        expect(pdfImage.pdfFile!.path, asset(0).path);
        expect(pdfImage.pdfPage, i);
      }

      // A second PDF is added to the same note: it becomes the second asset
      // and the first is still not touched.
      final second = (await tester.runAsync(
        () => writeSamplePdf(Directory('${temp.path}'), name: 'Ek.pdf'),
      ))!;
      expect(
        await tester.runAsync(
          () => editor
              .importPdfFromFilePath(second.path)
              .timeout(const Duration(seconds: 60)),
        ),
        isTrue,
      );
      await tester.pump();
      expect(editor.coreInfo.pages.length, pdfPages + 3 + 1);
      await save();
      expect(editor.savingState.value, SavingState.saved);
      expect(asset(0).lastModifiedSync(), firstWrite);
      expect(asset(0).readAsBytesSync(), pdfBytes);
      expect(asset(1).readAsBytesSync(), second.readAsBytesSync());
      expect(asset(2).existsSync(), isFalse);
    });
  });
}
