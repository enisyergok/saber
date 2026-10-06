import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_screenshot/golden_screenshot.dart';
import 'package:saber/components/canvas/image/editor_image.dart';
import 'package:saber/components/canvas/image/pdf_document_cache.dart';
import 'package:saber/components/canvas/save_indicator.dart';
import 'package:saber/components/toolbar/pdf_picker_dialog.dart';
import 'package:saber/data/defter_strings.dart';
import 'package:saber/data/editor/editor_core_info.dart';
import 'package:saber/data/editor/page.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/flavor_config.dart';
import 'package:saber/data/pdf/pdf_import.dart';
import 'package:saber/data/pdf/pdf_pick.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/versions/note_versions.dart';
import 'package:saber/i18n/strings.g.dart';
import 'package:saber/pages/editor/editor.dart';

import 'utils/test_mock_channel_handlers.dart';
import 'utils/test_pdfium.dart';

/// The blue of the block on the first sample page (PdfColors.blue).
const _blue = (r: 0x21, g: 0x96, b: 0xf3);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupMockPathProvider();
  FlavorConfig.setup();

  late Directory temp;
  setUp(() => temp = Directory.systemTemp.createTempSync('pdf_pick_test'));
  tearDown(() {
    try {
      temp.deleteSync(recursive: true);
    } on FileSystemException {
      // Still in use by something that is being closed.
    }
  });

  group('A marked part of a page:', () {
    test('a rectangle between two corners, whatever their order', () {
      final region = PdfRegion.rectangle(
        const Offset(0.8, 0.6),
        const Offset(0.2, 0.1),
      );
      expect(region.isRectangle, isTrue);
      expect(region.bounds, const Rect.fromLTRB(0.2, 0.1, 0.8, 0.6));
      expect(region.contains(const Offset(0.5, 0.3)), isTrue);
      expect(region.contains(const Offset(0.2, 0.1)), isTrue);
      expect(region.contains(const Offset(0.8, 0.6)), isTrue);
      expect(region.contains(const Offset(0.19, 0.3)), isFalse);
      expect(region.contains(const Offset(0.5, 0.61)), isFalse);
    });

    test('what is drawn outside the page is brought back onto it', () {
      final region = PdfRegion.rectangle(
        const Offset(-0.3, 0.5),
        const Offset(1.4, 1.2),
      );
      expect(region.bounds, const Rect.fromLTRB(0, 0.5, 1, 1));
      final lasso = PdfRegion.lasso(const [
        Offset(-1, -1),
        Offset(2, -1),
        Offset(0.5, 3),
      ]);
      expect(lasso.bounds, const Rect.fromLTRB(0, 0, 1, 1));
    });

    test('the inside of a freely drawn line', () {
      // A triangle with its point at the bottom.
      final region = PdfRegion.lasso(const [
        Offset(0.2, 0.2),
        Offset(0.8, 0.2),
        Offset(0.5, 0.8),
      ]);
      expect(region.isRectangle, isFalse);
      expect(region.bounds, const Rect.fromLTRB(0.2, 0.2, 0.8, 0.8));
      expect(region.contains(const Offset(0.5, 0.3)), isTrue);
      expect(region.contains(const Offset(0.5, 0.7)), isTrue);
      // Inside the rectangle around it, but outside the line.
      expect(region.contains(const Offset(0.25, 0.7)), isFalse);
      expect(region.contains(const Offset(0.75, 0.7)), isFalse);
      expect(region.contains(const Offset(0.1, 0.1)), isFalse);

      // A shape with a dent: the dent is outside.
      final dented = PdfRegion.lasso(const [
        Offset(0.1, 0.1),
        Offset(0.9, 0.1),
        Offset(0.9, 0.9),
        Offset(0.5, 0.4),
        Offset(0.1, 0.9),
      ]);
      expect(dented.contains(const Offset(0.5, 0.2)), isTrue);
      expect(dented.contains(const Offset(0.5, 0.7)), isFalse);
      expect(dented.contains(const Offset(0.8, 0.6)), isTrue);
    });

    test('a tap or a slip of the pen marks nothing', () {
      const shown = Size(800, 1000);
      expect(
        PdfRegion.rectangle(
          const Offset(0.5, 0.5),
          const Offset(0.505, 0.505),
        ).isLargeEnough(shown),
        isFalse,
      );
      expect(
        PdfRegion.rectangle(
          const Offset(0.5, 0.5),
          const Offset(0.6, 0.502),
        ).isLargeEnough(shown),
        isFalse,
        reason: 'a line has no inside',
      );
      expect(
        PdfRegion.rectangle(
          const Offset(0.5, 0.5),
          const Offset(0.6, 0.6),
        ).isLargeEnough(shown),
        isTrue,
      );
      expect(
        PdfRegion.lasso(const [
          Offset(0.1, 0.1),
          Offset(0.9, 0.9),
        ]).isLargeEnough(shown),
        isFalse,
        reason: 'two points close nothing in',
      );
    });

    test('as a path on a page of any size', () {
      final rectangle = PdfRegion.rectangle(
        const Offset(0.25, 0.5),
        const Offset(0.75, 1),
      ).pathIn(const Size(400, 200));
      expect(rectangle.getBounds(), const Rect.fromLTRB(100, 100, 300, 200));

      final lasso = PdfRegion.lasso(const [
        Offset(0.2, 0.2),
        Offset(0.8, 0.2),
        Offset(0.5, 0.8),
      ]).pathIn(const Size(100, 100));
      expect(lasso.contains(const Offset(50, 30)), isTrue);
      expect(lasso.contains(const Offset(25, 70)), isFalse);
    });
  });

  group('The text of a marked part:', () {
    // Two lines: "Ohm kanunu" over "V = I R", each letter 0.05 wide.
    const fullText = 'Ohm kanunu\nV = I R';
    List<Rect?> rects() {
      final out = <Rect?>[];
      var x = 0.1, y = 0.1;
      for (var i = 0; i < fullText.length; i++) {
        final char = fullText[i];
        if (char == '\n') {
          out.add(null);
          x = 0.1;
          y = 0.2;
          continue;
        }
        out.add(char == ' ' ? Rect.zero : Rect.fromLTWH(x, y, 0.05, 0.05));
        x += 0.05;
      }
      return out;
    }

    String pick(Rect part) => PdfTextPicker.textIn(
      fullText: fullText,
      charRects: rects(),
      contains: part.contains,
    );

    test('whole lines keep their words and their line breaks', () {
      expect(pick(const Rect.fromLTRB(0, 0, 1, 1)), fullText);
      expect(pick(const Rect.fromLTRB(0, 0.05, 1, 0.17)), 'Ohm kanunu');
      expect(pick(const Rect.fromLTRB(0, 0.18, 1, 0.3)), 'V = I R');
    });

    test('a part of a line gives the letters whose middle is inside', () {
      // The first three letters of the first line.
      expect(pick(const Rect.fromLTRB(0.09, 0.05, 0.26, 0.17)), 'Ohm');
      // The second word of the first line.
      expect(pick(const Rect.fromLTRB(0.29, 0.05, 0.62, 0.17)), 'kanunu');
      // A column through both lines: what is taken from each stays on its
      // own line.
      expect(pick(const Rect.fromLTRB(0.09, 0.05, 0.16, 0.3)), 'O\nV');
    });

    test('letters that are left out between two taken ones part them', () {
      final chosen = {0, 2}; // O and m of "Ohm"
      var index = -1;
      final text = PdfTextPicker.textIn(
        fullText: 'Ohm',
        charRects: [
          for (var i = 0; i < 3; i++) Rect.fromLTWH(i * 0.1, 0, 0.1, 0.1),
        ],
        contains: (_) => chosen.contains(++index),
      );
      expect(text, 'O m');
    });

    test('nothing marked, or a page without text, gives nothing', () {
      expect(pick(const Rect.fromLTRB(0.5, 0.5, 0.9, 0.9)), '');
      expect(
        PdfTextPicker.textIn(
          fullText: '',
          charRects: const [],
          contains: (_) => true,
        ),
        '',
      );
      // Fewer places than letters (never expected): what has no place is
      // left out instead of failing.
      expect(
        PdfTextPicker.textIn(
          fullText: 'abc',
          charRects: [const Rect.fromLTWH(0, 0, 1, 1)],
          contains: (_) => true,
        ),
        'a',
      );
    });
  });

  group('How large a piece becomes:', () {
    test('three pixels a point, less for a very large piece', () {
      var size = PdfClip.pixelsFor(200, 100);
      expect((size.width, size.height, size.scale), (600, 300, 3.0));

      // A whole A0 sheet would be far too large: its long side is capped.
      size = PdfClip.pixelsFor(2384, 3370);
      expect(size.height, PdfClip.maxSide);
      expect(size.width, closeTo(2384 * PdfClip.maxSide / 3370, 1));
      expect(size.scale, lessThan(1));

      size = PdfClip.pixelsFor(0.01, 0.01);
      expect((size.width, size.height), (1, 1));
    });

    test('on the note it is as wide as it was on its own page', () {
      const page = Size(1000, 1400);
      // A third of the PDF page's width, twice as wide as high.
      var rect = PdfClip.placeOn(
        pageSize: page,
        fractionOfPage: const Size(1 / 3, 0.1),
        pixelSize: const Size(600, 300),
        top: 500,
      );
      expect(rect.width, closeTo(1000 / 3, 0.01));
      expect(rect.height, closeTo(1000 / 6, 0.01));
      expect(rect.center.dx, closeTo(500, 0.01), reason: 'in the middle');
      expect(rect.top, 500);

      // A whole page fits inside the margins and keeps its shape.
      rect = PdfClip.placeOn(
        pageSize: page,
        fractionOfPage: const Size(1, 1),
        pixelSize: const Size(1000, 2000),
        top: -50,
      );
      expect(rect.height, lessThanOrEqualTo(1400 * 0.92 + 0.01));
      expect(rect.width / rect.height, closeTo(0.5, 0.001));
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.bottom, lessThanOrEqualTo(1400));

      // Asked for below the page: it is put where it still fits.
      rect = PdfClip.placeOn(
        pageSize: page,
        fractionOfPage: const Size(0.5, 0.2),
        pixelSize: const Size(500, 250),
        top: 5000,
      );
      expect(rect.bottom, lessThanOrEqualTo(1400));
      expect(rect.width, 500);
    });
  });

  group('With PDFium:', () {
    final hasPdfium = setUpPdfium();

    /// The pixels of a PNG, as red, green, blue, alpha.
    Future<({ByteData rgba, int width, int height})> decode(
      Uint8List png,
    ) async {
      final codec = await ui.instantiateImageCodec(png);
      final frame = await codec.getNextFrame();
      final data = await frame.image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      final result = (
        rgba: data!,
        width: frame.image.width,
        height: frame.image.height,
      );
      frame.image.dispose();
      codec.dispose();
      return result;
    }

    testWidgets('a marked part is drawn sharp, and only that part', (
      tester,
    ) async {
      if (!hasPdfium) {
        markTestSkipped('PDFium was not found on this computer');
        return;
      }
      await tester.runAsync(() async {
        final pdf = await writeSamplePdf(temp);
        final cache = PdfDocumentCache();
        final document = await PdfImport.open(cache, pdf.path);
        final page = document.pages.first;

        // Inside the blue block of the first page (36 to 196 points from
        // the left, 124 to 184 from the top, on a page of 595 by 842).
        final inBlue = PdfRegion.rectangle(
          const Offset(60 / 595.28, 135 / 841.89),
          const Offset(170 / 595.28, 175 / 841.89),
        );
        final piece = await PdfPickReader.image(page, inBlue);
        expect(piece.pixelSize.width, closeTo(110 * 3, 2));
        expect(piece.pixelSize.height, closeTo(40 * 3, 2));
        expect(piece.fractionOfPage.width, closeTo(110 / 595.28, 0.001));
        var pixels = await decode(piece.png);
        expect(pixels.width, piece.pixelSize.width);
        expect(pixels.height, piece.pixelSize.height);
        for (final (x, y) in [
          (0, 0),
          (pixels.width - 1, 0),
          (0, pixels.height - 1),
          (pixels.width - 1, pixels.height - 1),
          (pixels.width ~/ 2, pixels.height ~/ 2),
        ]) {
          final at = (y * pixels.width + x) * 4;
          expect(pixels.rgba.getUint8(at), closeTo(_blue.r, 2), reason: '$x,$y');
          expect(pixels.rgba.getUint8(at + 1), closeTo(_blue.g, 2));
          expect(pixels.rgba.getUint8(at + 2), closeTo(_blue.b, 2));
          expect(pixels.rgba.getUint8(at + 3), 255, reason: 'not see-through');
        }

        // The same place marked freely, as a triangle: its corners are
        // outside the line and see-through, its middle is the block.
        final triangle = PdfRegion.lasso(const [
          Offset(60 / 595.28, 135 / 841.89),
          Offset(170 / 595.28, 135 / 841.89),
          Offset(115 / 595.28, 175 / 841.89),
        ]);
        final clipped = await PdfPickReader.image(page, triangle);
        pixels = await decode(clipped.png);
        int alphaAt(int x, int y) =>
            pixels.rgba.getUint8((y * pixels.width + x) * 4 + 3);
        expect(alphaAt(2, pixels.height - 3), 0, reason: 'bottom left');
        expect(alphaAt(pixels.width - 3, pixels.height - 3), 0);
        final middle = ((pixels.height ~/ 3) * pixels.width + pixels.width ~/ 2) * 4;
        expect(pixels.rgba.getUint8(middle + 3), 255);
        expect(pixels.rgba.getUint8(middle + 2), closeTo(_blue.b, 2));

        // The white of the page is white, not see-through.
        final margin = await PdfPickReader.image(
          page,
          PdfRegion.rectangle(const Offset(0, 0), const Offset(0.04, 0.03)),
        );
        pixels = await decode(margin.png);
        expect(pixels.rgba.getUint32(0), 0xffffffff);

        cache.dispose();
      });
    });

    testWidgets('the text of a marked part is the text that is there', (
      tester,
    ) async {
      if (!hasPdfium) {
        markTestSkipped('PDFium was not found on this computer');
        return;
      }
      await tester.runAsync(() async {
        final pdf = await writeSamplePdf(temp);
        final cache = PdfDocumentCache();
        final document = await PdfImport.open(cache, pdf.path);
        final page = document.pages.first;

        // The title is in the top tenth, "Page 1" right under it.
        final title = await PdfPickReader.text(
          page,
          PdfRegion.rectangle(const Offset(0, 0), const Offset(1, 80 / 841.89)),
        );
        expect(title.trim(), 'Defter PDF');

        final both = await PdfPickReader.text(
          page,
          PdfRegion.rectangle(const Offset(0, 0), const Offset(1, 115 / 841.89)),
        );
        expect(both.trim(), 'Defter PDF\nPage 1');

        // Half of the title's width: only the letters that are in it.
        final part = await PdfPickReader.text(
          page,
          PdfRegion.rectangle(
            const Offset(0, 0),
            const Offset(120 / 595.28, 80 / 841.89),
          ),
        );
        expect(part, isNotEmpty);
        expect('Defter PDF'.startsWith(part.trim()), isTrue, reason: part);
        expect(part.trim().length, lessThan('Defter PDF'.length));

        // The blue block has no text in it.
        final none = await PdfPickReader.text(
          page,
          PdfRegion.rectangle(
            const Offset(60 / 595.28, 135 / 841.89),
            const Offset(170 / 595.28, 175 / 841.89),
          ),
        );
        expect(none, '');

        // Another page has its own text.
        final second = await PdfPickReader.text(
          document.pages[1],
          PdfRegion.rectangle(const Offset(0, 0), const Offset(1, 0.3)),
        );
        expect(second, contains('Page 2'));

        cache.dispose();
      });
    });

    testWidgets('the window: leafing, ticking pages, marking a part', (
      tester,
    ) async {
      if (!hasPdfium) {
        markTestSkipped('PDFium was not found on this computer');
        return;
      }
      tester.view.physicalSize = const Size(1400, 1300);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final cache = PdfDocumentCache();
      addTearDown(cache.dispose);
      final document = (await tester.runAsync(() async {
        final pdf = await writeSamplePdf(temp, copies: 2);
        return PdfImport.open(cache, pdf.path);
      }))!;

      final shownPages = <int>[];
      final picks = <PdfPick?>[];
      Future<void> open({int initialPage = 0}) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    picks.add(
                      await showDialog<PdfPick>(
                        context: context,
                        builder: (_) => PdfPickerDialog(
                          document: document,
                          name: 'Ders notlari.pdf',
                          initialPage: initialPage,
                          onPageChanged: shownPages.add,
                        ),
                      ),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
      }

      /// Lets what runs off the main thread (drawing, reading text) finish.
      Future<void> settle([int rounds = 6]) async {
        for (var i = 0; i < rounds; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 80)),
          );
          await tester.pump();
        }
        await tester.pump(const Duration(milliseconds: 400));
      }

      String pageNumber() => tester
          .widget<Text>(find.byKey(const Key('pdfPickPageNumber')))
          .data!;
      PdfPickerDialogState state() =>
          tester.state<PdfPickerDialogState>(find.byType(PdfPickerDialog));

      // -- leafing through the pages
      await open();
      await settle();
      expect(find.text('Ders notlari.pdf'), findsOneWidget);
      expect(pageNumber(), '1 / 6');
      expect(find.text(DefterStrings.pdfPickHint), findsOneWidget);
      await tester.tap(find.byKey(const Key('pdfPickNext')));
      await tester.pump();
      expect(pageNumber(), '2 / 6');
      await tester.tap(find.byKey(const Key('pdfPickThumb-4')));
      await tester.pump();
      expect(pageNumber(), '5 / 6');
      await tester.tap(find.byKey(const Key('pdfPickPrevious')));
      await tester.pump();
      expect(pageNumber(), '4 / 6');
      expect(shownPages, [1, 4, 3]);

      // -- ticking pages: nothing can be taken before one is ticked
      FilledButton chosenButton() => tester.widget<FilledButton>(
        find.byKey(const Key('pdfPickChosenPages')),
      );
      expect(chosenButton().onPressed, isNull);
      await tester.tap(find.byKey(const Key('pdfPickPage-2')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('pdfPickPage-0')));
      await tester.pump();
      // The page that is open, with the chip under it.
      await tester.tap(find.byKey(const Key('pdfPickThisPage')));
      await tester.pump();
      expect(find.text(DefterStrings.pdfPickChosenPages(3)), findsOneWidget);
      // Ticked twice is not ticked.
      await tester.tap(find.byKey(const Key('pdfPickPage-0')));
      await tester.pump();
      expect(find.text(DefterStrings.pdfPickChosenPages(2)), findsOneWidget);
      await tester.tap(find.byKey(const Key('pdfPickChosenPages')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(picks.single, isA<PdfPickPages>());
      expect((picks.single! as PdfPickPages).pages, [2, 3]);

      // -- all pages at once
      picks.clear();
      await open(initialPage: 3);
      await settle(2);
      expect(pageNumber(), '4 / 6', reason: 'opens where it was left');
      await tester.tap(find.byKey(const Key('pdfPickAllPages')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect((picks.single! as PdfPickPages).pages, [0, 1, 2, 3, 4, 5]);

      // -- marking a part of the first page with the pen
      picks.clear();
      await open();
      await settle();
      final area = tester.getRect(find.byKey(const Key('pdfPickPageArea')));
      expect(area.width / area.height, closeTo(595.28 / 841.89, 0.01));
      Offset at(double x, double y) =>
          area.topLeft + Offset(area.width * x, area.height * y);

      // A tap marks nothing.
      await tester.tapAt(at(0.5, 0.5));
      await tester.pump();
      expect(state().region, isNull);

      // A rectangle around the title.
      var pen = await tester.startGesture(
        at(0.02, 0.01),
        kind: PointerDeviceKind.stylus,
      );
      await pen.moveTo(at(0.5, 0.05));
      await pen.moveTo(at(0.98, 80 / 841.89));
      await pen.up();
      await tester.pump();
      expect(state().region, isNotNull);
      expect(state().region!.isRectangle, isTrue);
      expect(state().region!.bounds.left, closeTo(0.02, 0.005));
      expect(state().region!.bounds.bottom, closeTo(80 / 841.89, 0.005));
      // What can be done with it replaces what can be done with pages.
      expect(find.byKey(const Key('pdfPickAsImage')), findsOneWidget);
      expect(find.byKey(const Key('pdfPickChosenPages')), findsNothing);
      await settle();
      expect(state().regionText!.trim(), 'Defter PDF');
      expect(
        find.text(DefterStrings.pdfPickTextFound('Defter PDF')),
        findsOneWidget,
      );

      // Marking again replaces the mark; a part without text says so.
      pen = await tester.startGesture(
        at(60 / 595.28, 135 / 841.89),
        kind: PointerDeviceKind.stylus,
      );
      await pen.moveTo(at(170 / 595.28, 175 / 841.89));
      await pen.up();
      await tester.pump();
      await settle();
      expect(state().regionText, '');
      expect(find.text(DefterStrings.pdfPickNoText), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('pdfPickAsText')))
            .onPressed,
        isNull,
      );

      // Going to another page takes the mark away.
      await tester.tap(find.byKey(const Key('pdfPickNext')));
      await tester.pump();
      expect(state().region, isNull);
      await tester.tap(find.byKey(const Key('pdfPickPrevious')));
      await tester.pump();
      await settle(2);

      // The title again, taken as text.
      state().setRegion(
        PdfRegion.rectangle(const Offset(0, 0), const Offset(1, 80 / 841.89)),
      );
      await tester.pump();
      await settle();
      await tester.tap(find.byKey(const Key('pdfPickAsText')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect((picks.single! as PdfPickText).text.trim(), 'Defter PDF');

      // -- a freely drawn mark, taken as a picture
      picks.clear();
      await open();
      await settle();
      await tester.tap(find.text(DefterStrings.pdfPickLasso));
      await tester.pump();
      pen = await tester.startGesture(
        at(60 / 595.28, 135 / 841.89),
        kind: PointerDeviceKind.stylus,
      );
      await pen.moveTo(at(170 / 595.28, 135 / 841.89));
      await pen.moveTo(at(115 / 595.28, 175 / 841.89));
      await pen.up();
      await tester.pump();
      expect(state().region!.isRectangle, isFalse);
      expect(state().region!.outline!.length, 3);
      await tester.tap(find.byKey(const Key('pdfPickAsImage')));
      await tester.pump();
      for (var i = 0; i < 40 && picks.isEmpty; i++) {
        await settle(1);
      }
      final piece = picks.single! as PdfPickImage;
      expect(piece.png.sublist(1, 4), 'PNG'.codeUnits);
      expect(piece.pixelSize.width, closeTo(110 * 3, 3));
      expect(piece.fractionOfPage.height, closeTo(40 / 841.89, 0.003));

      // -- closed without taking anything
      picks.clear();
      await open();
      await settle(2);
      await tester.tap(find.byKey(const Key('pdfPickClose')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(picks.single, isNull);
    });

    testGoldens('Editor: pages, a piece and text taken from a PDF land in '
        'the note', (tester) async {
      if (!hasPdfium) {
        markTestSkipped('PDFium was not found on this computer');
        return;
      }
      setupMockPrinting();
      stows.editorGnLayout.value = false;
      // Saved when the test says so, not by a timer in between.
      stows.autosaveDelay.value = -1;
      addTearDown(() => stows.autosaveDelay.value = 10000);
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

      const path = '/Seçerek';
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
      expect(editor.lastPdfWindowName, isNull);

      Future<bool> apply(PdfPick pick) async {
        final done = await tester.runAsync(
          () => editor
              .applyPdfPick(pdf.path, pick)
              .timeout(const Duration(seconds: 60)),
        );
        await tester.pump();
        return done!;
      }

      // -- a piece of a page, as a picture on the open page
      final piece = (await tester.runAsync(() async {
        final document = await PdfImport.open(
          editor.coreInfo.assetCache.pdfDocumentCache,
          pdf.path,
        );
        return PdfPickReader.image(
          document.pages.first,
          PdfRegion.rectangle(
            const Offset(60 / 595.28, 135 / 841.89),
            const Offset(170 / 595.28, 175 / 841.89),
          ),
        );
      }))!;
      expect(await apply(piece), isTrue);
      var first = editor.coreInfo.pages.first;
      final image = first.images.single as PngEditorImage;
      expect((image.imageProvider! as MemoryImage).bytes, piece.png);
      // As wide as it was on its own page: 110 of 595 points of a page
      // that is 1000 wide here.
      expect(image.dstRect.width, closeTo(1000 * 110 / 595.28, 1));
      expect(
        image.dstRect.width / image.dstRect.height,
        closeTo(piece.pixelSize.width / piece.pixelSize.height, 0.01),
      );
      expect(image.dstRect.center.dx, closeTo(500, 1));
      expect(image.dstRect.top, greaterThanOrEqualTo(0));
      expect(image.dstRect.bottom, lessThanOrEqualTo(first.size.height));
      expect(editor.coreInfo.pages.length, 2, reason: 'and an empty page');
      // It can be undone like a photo.
      editor.undo();
      await tester.pump();
      expect(editor.coreInfo.pages.first.images, isEmpty);
      editor.redo();
      await tester.pump();
      expect(editor.coreInfo.pages.first.images.single, same(image));

      // -- text, as typed text on the open page
      expect(await apply(const PdfPickText('  Defter PDF\nPage 1 ')), isTrue);
      ScaffoldMessenger.of(
        tester.element(find.byType(Editor)),
      ).removeCurrentSnackBar();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      first = editor.coreInfo.pages.first;
      String typed() => first.quill.controller.document.toPlainText();
      expect(typed(), 'Defter PDF\nPage 1\n');
      // More text goes on a line of its own under it.
      expect(await apply(const PdfPickText('V = I R')), isTrue);
      ScaffoldMessenger.of(
        tester.element(find.byType(Editor)),
      ).removeCurrentSnackBar();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(typed(), 'Defter PDF\nPage 1\nV = I R\n');
      // Nothing but spaces is nothing.
      expect(await apply(const PdfPickText('  \n ')), isFalse);
      expect(typed(), 'Defter PDF\nPage 1\nV = I R\n');

      // -- chosen pages, as pages of the note
      expect(await apply(const PdfPickPages([1, 4, 5])), isTrue);
      final pages = editor.coreInfo.pages;
      final pdfPages = [
        for (final page in pages)
          if (page.backgroundImage case final PdfEditorImage background)
            (page, background),
      ];
      expect([for (final (_, background) in pdfPages) background.pdfPage], [
        1,
        4,
        5,
      ]);
      // Each keeps the shape of its own page.
      for (final (page, background) in pdfPages) {
        final size = samplePdfSizes[background.pdfPage % samplePdfSizes.length];
        expect(
          page.size.height,
          closeTo(EditorPage.defaultWidth * size.height / size.width, 1),
        );
      }
      expect(pages.last.isEmpty, isTrue);
      expect(pages.first.images.single, same(image), reason: 'still there');

      // -- everything is saved with the note and found again
      await tester.runAsync(
        () => editor.saveToFile().timeout(const Duration(seconds: 60)),
      );
      await wait();
      await tester.pump();
      expect(editor.savingState.value, SavingState.saved);
      final disk = (await tester.runAsync(
        () => EditorCoreInfo.loadFromFilePath(path),
      ))!;
      addTearDown(disk.dispose);
      expect(
        disk.pages.first.quill.controller.document.toPlainText(),
        'Defter PDF\nPage 1\nV = I R\n',
      );
      expect(disk.pages.first.images.single, isA<PngEditorImage>());
      expect(disk.pages.first.images.single.dstRect.width,
          closeTo(image.dstRect.width, 0.5));
      expect(
        [
          for (final page in disk.pages)
            if (page.backgroundImage case final PdfEditorImage background)
              background.pdfPage,
        ],
        [1, 4, 5],
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
    });
  });
}
