import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saber/components/canvas/_stroke.dart';
import 'package:saber/data/editor/page.dart';
import 'package:saber/data/flavor_config.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/tools/highlighter.dart';
import 'package:saber/data/tools/pen.dart';
import 'package:saber/data/tools/pencil.dart';
import 'package:saber/data/tools/shape_pen.dart';
import 'package:saber/data/tools/shape_snap.dart';

/// The box around the ink of [stroke] as it is drawn.
Rect _ink(Stroke stroke) {
  final polygon = stroke.highQualityPolygon;
  expect(polygon, isNotEmpty);
  var left = polygon.first.dx, right = left;
  var top = polygon.first.dy, bottom = top;
  for (final point in polygon) {
    left = math.min(left, point.dx);
    right = math.max(right, point.dx);
    top = math.min(top, point.dy);
    bottom = math.max(bottom, point.dy);
  }
  return Rect.fromLTRB(left, top, right, bottom);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlavorConfig.setup();

  late EditorPage page;

  setUp(() {
    page = EditorPage(size: const Size(1000, 1400));
    // The pressures of these tests are the ones the pens are given.
    stows.pressureAuto.value = false;
    stows.pressureCurve.value = stows.pressureCurve.defaultValue;
    stows.shapeHoldToSnap.value = false;
    stows.rulerMode.value = false;
    stows.angleGuide.value = false;
    stows.measureMode.value = false;
    // The pen of the photograph: pointed ends, width by pressure.
    stows.fountainTipSharpness.value = 0.75;
  });
  tearDown(() {
    for (final stow in [
      stows.pressureAuto,
      stows.shapeHoldToSnap,
    ]) {
      stow.value = stow.defaultValue;
    }
    stows.fountainTipSharpness.value = stows.fountainTipSharpness.defaultValue;
  });

  /// Puts [pen] down at the first of [points] and lifts it at the last.
  Stroke? mark(
    Pen pen,
    List<Offset> points, {
    double pressure = 0.01,
  }) {
    pen.onDragStart(points.first, page, 0, pressure);
    for (final point in points.skip(1)) {
      pen.onDragUpdate(point, pressure);
    }
    return pen.onDragEnd();
  }

  /// A quick tap as the tablet reports it: four points on nearly the same
  /// spot, all at the pressure of first contact (0.01).
  const tap = [
    Offset(300, 400),
    Offset(300.2, 400.1),
    Offset(300.3, 400.3),
    Offset(300.4, 400.3),
  ];

  Pen fountain({double size = 5, double sensitivity = 0.5}) {
    final pen = Pen.fountainPen();
    pen.options
      ..size = size
      ..thinning = sensitivity;
    return pen;
  }

  group('A tap with the pen:', () {
    test('leaves a dot the width of the fountain pen', () {
      final stroke = mark(fountain(), tap)!;
      final ink = _ink(stroke);

      // About as wide as the pen writes (5), not a speck
      expect(ink.shortestSide, greaterThan(4));
      expect(ink.longestSide, lessThan(8));
      // ... where the pen was
      expect((ink.center - const Offset(300.2, 400.15)).distance, lessThan(1.5));
      // ... and round: its pointed ends are for lines
      expect(stroke.options.start.taperEnabled, isFalse);
      expect(stroke.options.end.taperEnabled, isFalse);
      expect(stroke.options.isComplete, isTrue);
      expect(stroke.length, 1);
    });

    test('leaves a dot at every sensitivity and tip sharpness', () {
      for (final sensitivity in [0.0, 0.5, 1.0]) {
        for (final sharpness in [0.0, 0.5, 1.0]) {
          stows.fountainTipSharpness.value = sharpness;
          final ink = _ink(mark(fountain(sensitivity: sensitivity), tap)!);
          expect(
            ink.shortestSide,
            greaterThan(4),
            reason: 'sensitivity $sensitivity, sharpness $sharpness',
          );
        }
      }
    });

    test('leaves a dot with every pen that writes', () {
      final pens = <String, Pen>{
        'fountain': Pen.fountainPen(),
        'ballpoint': Pen.ballpointPen(),
        'brush': Pen.brushPen(),
        'calligraphy': Pen.calligraphyPen(),
        'pencil': Pencil(),
      };
      for (final MapEntry(key: name, value: pen) in pens.entries) {
        final size = pen.options.size;
        final ink = _ink(mark(pen, tap)!);
        expect(ink.shortestSide, greaterThan(size * 0.8), reason: name);
        expect(ink.longestSide, lessThan(size * 1.6 + 2), reason: name);
      }
    });

    test('a single point is a dot too', () {
      final ink = _ink(mark(fountain(), const [Offset(120, 80)])!);
      expect(ink.shortestSide, greaterThan(4));
      expect((ink.center - const Offset(120, 80)).distance, lessThan(1.5));
    });

    test('a dot pressed hard is bigger, never smaller', () {
      final light = _ink(mark(fountain(), tap)!);
      final firm = _ink(mark(fountain(), tap, pressure: 1)!);
      expect(firm.shortestSide, greaterThan(light.shortestSide * 1.3));
    });

    test('a pen held on one spot is still a dot', () {
      // The tip wanders a long way without going anywhere.
      final wandering = [
        for (var i = 0; i < 60; i++)
          Offset(500 + math.cos(i * 1.3) * 1.2, 500 + math.sin(i * 1.7) * 1.2),
      ];
      final stroke = mark(fountain(), wandering)!;
      expect(stroke.length, 1);
      expect(_ink(stroke).shortestSide, greaterThan(4));
    });

    test('is not taken for a shape', () {
      stows.shapeHoldToSnap.value = true;
      final stroke = mark(fountain(), tap)!;
      expect(ShapeSnap.lastWasSnapped, isFalse);
      expect(stroke.length, 1);
      expect(stroke.vertexHandles, isNull);
    });
  });

  group('What is not a tap:', () {
    test('a short line stays a line with its pointed ends', () {
      // 20 long, four times the width of the pen
      final line = [for (var x = 0.0; x <= 20; x += 2) Offset(200 + x, 300)];
      final stroke = mark(fountain(), line, pressure: 0.5)!;
      expect(stroke.length, line.length);
      expect(
        stroke.options.start.taperEnabled || stroke.options.end.taperEnabled,
        isTrue,
      );
      final ink = _ink(stroke);
      expect(ink.width, greaterThan(15));
      expect(ink.height, lessThan(7));
    });

    test('the limit is one and a half pen widths', () {
      Stroke line(double length) => mark(fountain(), [
        for (var i = 0; i <= 4; i++) Offset(200 + length * i / 4, 300),
      ], pressure: 0.5)!;
      expect(line(5 * Pen.dotReach - 0.2).length, 1);
      expect(line(5 * Pen.dotReach + 0.2).length, 5);
    });

    test('the highlighter and the shape pen are left as they were', () {
      expect(Highlighter().makesDots, isFalse);
      expect(ShapePen().makesDots, isFalse);
      final stroke = mark(Highlighter(), tap)!;
      expect(stroke.length, tap.length);
    });
  });

  group('Stroke.becomeDot', () {
    Stroke stroke({bool pressure = true}) => Stroke(
      color: Colors.black,
      pressureEnabled: pressure,
      options: Pen.fountainPenOptions,
      pageIndex: 0,
      page: page,
      toolId: .fountainPen,
    );

    test('the dot is in the middle of where the points were', () {
      final s = stroke()
        ..addPoint(const Offset(10, 20), 0.1)
        ..addPoint(const Offset(14, 20), 0.1)
        ..addPoint(const Offset(14, 26), 0.1);
      expect(s.reach, closeTo(math.sqrt(16 + 36), 1e-9));
      s.becomeDot();
      expect(s.pointOffsets, [const Offset(12, 23)]);
      expect(s.reach, 0);
    });

    test('pressure is lifted to the least a dot needs, and kept if more', () {
      final light = stroke()..addPoint(const Offset(10, 20), 0.01);
      final firm = stroke()..addPoint(const Offset(10, 20), 0.9);
      light.becomeDot();
      firm.becomeDot();
      expect(_ink(light).shortestSide, greaterThan(4));
      expect(
        _ink(firm).shortestSide,
        greaterThan(_ink(light).shortestSide),
      );
    });

    test('a pen without pressure gets a dot of its own width', () {
      final s = stroke(pressure: false)
        ..addPoint(const Offset(10, 20))
        ..addPoint(const Offset(10.5, 20));
      s.becomeDot();
      expect(s.length, 1);
      expect(_ink(s).shortestSide, greaterThan(3.5));
    });

    test('an empty stroke stays empty', () {
      final s = stroke()..becomeDot();
      expect(s.isEmpty, isTrue);
      expect(s.reach, 0);
    });
  });
}
