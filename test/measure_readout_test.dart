import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saber/components/canvas/measure_readout.dart';
import 'package:saber/data/tools/pen_assist.dart';

void main() {
  setUp(() {
    PenAssist.showReadout(null);
    PenAssist.readoutAt.value = null;
  });
  tearDown(() {
    PenAssist.showReadout(null);
    PenAssist.readoutAt.value = null;
  });

  group('Where the readout goes', () {
    const area = Size(1000, 700);
    const chip = Size(120, 36);

    test('above the pen, centred on it', () {
      final at = MeasureReadout.place(area, chip, const Offset(500, 400));
      expect(at.dx, 440);
      expect(at.dy + chip.height, 400 - MeasureReadout.lift);
    });

    test('below the pen when there is no room above', () {
      final at = MeasureReadout.place(area, chip, const Offset(500, 40));
      expect(at.dy, greaterThan(40));
      expect(at.dy, lessThan(120));
    });

    test('never off the edge', () {
      for (final pen in const [
        Offset(0, 0),
        Offset(1000, 0),
        Offset(0, 700),
        Offset(1000, 700),
        Offset(-50, 350),
        Offset(1200, 900),
      ]) {
        final at = MeasureReadout.place(area, chip, pen);
        expect(at.dx, greaterThanOrEqualTo(8), reason: '$pen');
        expect(at.dy, greaterThanOrEqualTo(8), reason: '$pen');
        expect(at.dx + chip.width, lessThanOrEqualTo(992), reason: '$pen');
        expect(at.dy + chip.height, lessThanOrEqualTo(692), reason: '$pen');
      }
    });

    test('at the top in the middle when the pen is not known', () {
      final at = MeasureReadout.place(area, chip, null);
      expect(at.dx, 440);
      expect(at.dy, 16);
    });

    test('an area too small for it does not break it', () {
      final at = MeasureReadout.place(const Size(60, 20), chip, const Offset(30, 10));
      expect(at.dx.isFinite && at.dy.isFinite, isTrue);
    });
  });

  group('The readout', () {
    Future<void> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Padding(
              // the page does not start at the corner of the screen
              padding: EdgeInsets.only(top: 100, left: 50),
              child: Stack(
                children: [
                  Positioned.fill(child: ColoredBox(color: Colors.white)),
                  Positioned.fill(child: IgnorePointer(child: MeasureReadout())),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final chip = find.byKey(const ValueKey('measureReadout'));

    testWidgets('shows nothing until there is something to show', (
      tester,
    ) async {
      await pump(tester);
      expect(chip, findsNothing);
    });

    testWidgets('follows the pen while a line is drawn', (tester) async {
      await pump(tester);
      PenAssist.readoutAt.value = const Offset(500, 500);
      PenAssist.showReadout('42 mm  ∠ 15°');
      await tester.pump();
      expect(find.text('42 mm  ∠ 15°'), findsOneWidget);
      var rect = tester.getRect(chip);
      expect(rect.center.dx, closeTo(500, 1));
      expect(rect.bottom, closeTo(500 - MeasureReadout.lift, 1));

      PenAssist.readoutAt.value = const Offset(700, 420);
      PenAssist.showReadout('63 mm  ∠ 15°');
      await tester.pump();
      rect = tester.getRect(chip);
      expect(rect.center.dx, closeTo(700, 1));
      expect(rect.bottom, closeTo(420 - MeasureReadout.lift, 1));

      // It stays for as long as the line is being drawn.
      await tester.pump(const Duration(seconds: 10));
      expect(chip, findsOneWidget);
    });

    testWidgets('a finished measurement goes away after a few seconds', (
      tester,
    ) async {
      await pump(tester);
      PenAssist.readoutAt.value = const Offset(400, 400);
      PenAssist.showBriefly('60 mm  ∠ 0°');
      await tester.pump();
      expect(chip, findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      expect(chip, findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      expect(chip, findsNothing);
      expect(PenAssist.readout.value, isNull);
    });

    testWidgets('a new line keeps the readout from going away early', (
      tester,
    ) async {
      await pump(tester);
      PenAssist.readoutAt.value = const Offset(400, 400);
      PenAssist.showBriefly('60 mm  ∠ 0°');
      await tester.pump(const Duration(seconds: 3));
      // the pen is down again and measuring
      PenAssist.readoutAt.value = const Offset(410, 400);
      PenAssist.showReadout('5,0 mm');
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('5,0 mm'), findsOneWidget);
    });

    testWidgets('does not get in the way of the pen', (tester) async {
      await pump(tester);
      PenAssist.readoutAt.value = const Offset(500, 500);
      PenAssist.showReadout('42 mm');
      await tester.pump();
      final result = tester.hitTestOnBinding(tester.getCenter(chip));
      expect(
        result.path.any(
          (entry) => entry.target.toString().contains('RenderPhysicalShape'),
        ),
        isFalse,
        reason: 'touches go through to the page',
      );
    });
  });
}
