import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_screenshot/golden_screenshot.dart';
import 'package:saber/components/home/packaged_paper_preview.dart';

void main() {
  // Missing bundle declarations or a broken SVG loader must leave the fallback
  // visible and fail these tests, rather than silently producing empty papers.
  for (final asset in [
    'blank.svg',
    'ruledNarrow.svg',
    'ruledWide.svg',
    'grid.svg',
    'dottedgrid.svg',
    'legal.svg',
  ]) {
    testWidgets('$asset loads and paints its packaged artwork', (tester) async {
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: RepaintBoundary(
              key: boundaryKey,
              child: PackagedPaperPreview(
                asset: asset,
                pageSize: const Size(160, 240),
                fallback: const Text('loading paper'),
              ),
            ),
          ),
        ),
      );
      await tester.loadAssets();
      await tester.pumpAndSettle();
      expect(find.text('loading paper'), findsNothing);
      expect(tester.getSize(find.byKey(boundaryKey)), const Size(160, 240));
      expect(tester.takeException(), isNull);

      if (asset == 'grid.svg') {
        final boundary =
            boundaryKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1);
          try {
            final bytes = (await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!;
            List<int> pixel(int x, int y) => [
              for (var c = 0; c < 4; c++)
                bytes.getUint8((y * image.width + x) * 4 + c),
            ];
            // Hand-checked against the source SVG: cream paper, lines at 8+16n.
            expect(pixel(4, 4), [247, 246, 233, 255]);
            expect(pixel(8, 4), isNot(pixel(4, 4)));
            expect(pixel(4, 8), isNot(pixel(4, 4)));
            expect(pixel(24, 4), pixel(8, 4));
          } finally {
            image.dispose();
          }
        });
      }
    });
  }

  testWidgets('missing artwork retains the usable fallback', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PackagedPaperPreview(
          asset: 'missing-paper.svg',
          pageSize: Size(160, 240),
          fallback: Text('fallback paper'),
        ),
      ),
    );
    await tester.loadAssets();
    await tester.pumpAndSettle();
    expect(find.text('fallback paper'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
