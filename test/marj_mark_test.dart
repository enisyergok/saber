import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saber/components/eink/eink_scope.dart';
import 'package:saber/components/theming/defter_design.dart';
import 'package:saber/components/theming/marj_mark.dart';
import 'package:saber/data/defter_strings.dart';
import 'package:saber/data/eink/eink_style.dart';

void main() {
  test('the app is called Marj', () {
    expect(DefterStrings.appName, 'Marj');
  });

  group('The mark:', () {
    test('is an M standing on the margin line', () {
      const size = 44.0;
      final points = MarjMarkPainter.pointsIn(size);
      final [bottomLeft, topLeft, dip, topRight, bottomRight] = points;

      // Two upright stems of the same height
      expect(bottomLeft.dx, topLeft.dx);
      expect(bottomRight.dx, topRight.dx);
      expect(topLeft.dy, topRight.dy);
      expect(bottomLeft.dy, bottomRight.dy);
      expect(topLeft.dy, lessThan(bottomLeft.dy));

      // The dip is halfway between them, below the tops and above the feet
      expect(dip.dx, closeTo((topLeft.dx + topRight.dx) / 2, 1e-9));
      expect(dip.dy, greaterThan(topLeft.dy));
      expect(dip.dy, lessThan(bottomLeft.dy));

      // All of it, with the roundness of the pen, stays inside the square
      for (final point in points) {
        expect(point.dx, inInclusiveRange(4, size - 4));
        expect(point.dy, inInclusiveRange(4, size - 4));
      }
    });

    test('is the same drawing at every size', () {
      final small = MarjMarkPainter.pointsIn(24);
      final large = MarjMarkPainter.pointsIn(96);
      for (var i = 0; i < small.length; i++) {
        expect(large[i].dx, closeTo(small[i].dx * 4, 1e-9));
        expect(large[i].dy, closeTo(small[i].dy * 4, 1e-9));
      }
    });

    testWidgets('is written in the accent, on a red margin line', (
      tester,
    ) async {
      final scheme = DefterDesign.colorScheme(Brightness.light);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(colorScheme: scheme),
          home: const Center(child: MarjMark(size: 48)),
        ),
      );

      final paint = tester.widget<CustomPaint>(
        find.descendant(
          of: find.byType(MarjMark),
          matching: find.byType(CustomPaint),
        ),
      );
      final painter = paint.painter! as MarjMarkPainter;
      expect(painter.color, DefterDesign.ink);
      expect(painter.marginColor, MarjMark.marginRed);
      expect(tester.getSize(find.byType(MarjMark)), const Size(48, 48));
    });

    testWidgets('has no colour of its own on an e-ink screen', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: EInkScope(
            style: EInkStyle(texture: 0),
            child: Center(child: MarjMark()),
          ),
        ),
      );

      final paint = tester.widget<CustomPaint>(
        find.descendant(
          of: find.byType(MarjMark),
          matching: find.byType(CustomPaint),
        ),
      );
      final painter = paint.painter! as MarjMarkPainter;
      expect(painter.marginColor, isNot(MarjMark.marginRed));
    });

    testWidgets('looks like the launcher icon', (tester) async {
      // The launcher icon is drawn by scripts/make_marj_icon.py from the
      // same numbers; this picture is how the two are kept alike by eye.
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: RepaintBoundary(
              child: ColoredBox(
                color: DefterDesign.ink,
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: MarjMark(size: 96, color: Colors.white),
                ),
              ),
            ),
          ),
        ),
      );

      await expectLater(
        find.byType(RepaintBoundary).first,
        matchesGoldenFile('goldens/marj_mark.png'),
      );
    });
  });
}
