import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saber/data/editor/page.dart';
import 'package:saber/data/flavor_config.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/tools/pen.dart';
import 'package:saber/data/tools/pen_assist.dart';
import 'package:saber/data/tools/pen_feel.dart';
import 'package:saber/data/tools/pressure_calibration.dart';
import 'package:saber/data/tools/pressure_curve.dart';
import 'package:saber/data/tools/shape_snap.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlavorConfig.setup();

  final page = EditorPage();

  setUp(() {
    PressureCalibration.reset();
    // No timers in these tests: nothing is held still.
    stows.shapeHoldToSnap.value = false;
    stows.pressureCurve.value = '';
  });
  tearDown(() {
    stows.shapeHoldToSnap.value = true;
    stows.rulerMode.value = false;
    stows.angleGuide.value = false;
    stows.measureMode.value = false;
    stows.pressureCurve.value = '';
    PenAssist.showReadout(null);
  });

  group('Ruler', () {
    test('every line is straight from where the pen went down', () {
      stows.rulerMode.value = true;
      final pen = Pen.fountainPen();
      pen.onDragStart(const Offset(100, 100), page, 0, 0.2);
      pen.onDragUpdate(const Offset(180, 160), 0.9);
      // while drawing, the line already follows the pen
      expect(Pen.currentStroke!.pointOffsets, const [
        Offset(100, 100),
        Offset(180, 160),
      ]);
      pen.onDragUpdate(const Offset(300, 110), 0.5);
      final stroke = pen.onDragEnd()!;

      expect(stroke.vertexHandles, const [Offset(100, 100), Offset(300, 110)]);
      // an even line with blunt ends, whatever the pen's settings
      expect(stroke.options.start.taperEnabled, isFalse);
      expect(stroke.options.end.taperEnabled, isFalse);
      expect(stroke.points.map((p) => p.pressure).toSet(), {0.5});
      expect(stroke.options.isComplete, isTrue);
      // nothing left to recognise
      expect(ShapeSnap.lastWasSnapped, isTrue);
    });

    test('with the angle guide the line turns in steps of 15 degrees', () {
      stows.rulerMode.value = true;
      stows.angleGuide.value = true;
      final pen = Pen.ballpointPen();
      pen.onDragStart(const Offset(100, 100), page, 0, null);
      pen.onDragUpdate(const Offset(300, 110), null);
      final ends = pen.onDragEnd()!.vertexHandles!;
      expect(ends.first, const Offset(100, 100));
      expect(ends.last.dy, closeTo(100, 1e-6));
      expect((ends.last - ends.first).distance, closeTo(sqrt(40100), 1e-6));
    });

    test('a tap with the ruler draws nothing', () {
      stows.rulerMode.value = true;
      final pen = Pen.fountainPen();
      pen.onDragStart(const Offset(100, 100), page, 0, 0.5);
      expect(pen.onDragEnd(), isNull);
    });

    test('measuring shows the length and angle of the ruled line', () {
      stows.rulerMode.value = true;
      stows.measureMode.value = true;
      final pen = Pen.fountainPen();
      pen.onDragStart(const Offset(100, 500), page, 0, 0.5);
      pen.onDragUpdate(const Offset(385.7, 500), 0.5);
      expect(PenAssist.readout.value, '60 mm  ∠ 0°');
      pen.onDragEnd();
    });

    test('without the ruler the pen writes as usual', () {
      final pen = Pen.fountainPen();
      pen.onDragStart(const Offset(100, 100), page, 0, 0.5);
      for (var i = 1; i <= 20; i++) {
        pen.onDragUpdate(Offset(100 + i * 5, 100 + sin(i / 2) * 12), 0.5);
      }
      final stroke = pen.onDragEnd()!;
      expect(stroke.length, greaterThan(15));
      expect(stroke.vertexHandles, isNull);
    });
  });

  group('Pressure', () {
    test('the fountain pen draws with the pressure curve applied', () {
      final pen = Pen.fountainPen();
      pen.onDragStart(const Offset(100, 100), page, 0, 0.25);
      pen.onDragUpdate(const Offset(130, 100), 0.25);
      pen.onDragUpdate(const Offset(160, 100), 1);
      final stroke = pen.onDragEnd()!;
      expect(stroke.points.first.pressure, closeTo(0.4, 1e-9));
      expect(stroke.points.last.pressure, closeTo(1, 1e-9));
    });

    test('a curve changed in the panel is used by the next line', () {
      stows.pressureCurve.value = PressureCurve.linear.encode();
      final pen = Pen.fountainPen();
      pen.onDragStart(const Offset(100, 100), page, 0, 0.25);
      pen.onDragUpdate(const Offset(130, 100), 0.25);
      final stroke = pen.onDragEnd()!;
      expect(stroke.points.first.pressure, closeTo(0.25, 1e-9));
      expect(PenFeel.curve, PressureCurve.linear);
    });

    test('measuring freehand shows how long the line is', () {
      stows.measureMode.value = true;
      final pen = Pen.ballpointPen();
      pen.onDragStart(const Offset(0, 100), page, 0, null);
      pen.onDragUpdate(const Offset(100, 100), null);
      pen.onDragUpdate(const Offset(100, 200), null);
      // 200 units along the path
      expect(PenAssist.readout.value, '42 mm');
      pen.onDragEnd();
    });
  });

  group('Calligraphy pen', () {
    /// The pressures of a line drawn from (200, 200) in steps of [step].
    List<double> drawn(Offset step, {double? pressure}) {
      final pen = Pen.calligraphyPen();
      var position = const Offset(200, 200);
      pen.onDragStart(position, page, 0, pressure);
      for (var i = 0; i < 30; i++) {
        position += step;
        pen.onDragUpdate(position, pressure);
      }
      return pen.onDragEnd()!.points.map((p) => p.pressure!).toList();
    }

    test('lines along the nib are thin, across it thick', () {
      final along = drawn(const Offset(4, -4));
      final across = drawn(const Offset(4, 4));
      expect(along.last, lessThan(0.1));
      expect(across.last, greaterThan(0.9));
      // sideways is in between
      final level = drawn(const Offset(5, 0));
      expect(level.last, inInclusiveRange(0.6, 0.8));
    });

    test('it works with a finger too, and pressing harder adds a little', () {
      final soft = drawn(const Offset(4, 4), pressure: 0.05);
      final hard = drawn(const Offset(4, 4), pressure: 1);
      expect(soft.last, greaterThan(0.6));
      expect(hard.last, greaterThan(soft.last));
    });

    test('its stroke options carry the contrast, with blunt ends', () {
      final pen = Pen.calligraphyPen();
      final thinning = pen.options.thinning;
      addTearDown(() => pen.options.thinning = thinning);
      pen.options.thinning = 0.5;
      final options = pen.strokeOptions;
      expect(options.thinning, closeTo(0.75, 1e-9));
      expect(options.end.taperEnabled, isFalse);
      // the sensitivity as set in the panel is left alone
      expect(pen.options.thinning, 0.5);
    });
  });
}
