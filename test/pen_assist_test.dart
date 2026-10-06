import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfect_freehand/perfect_freehand.dart';
import 'package:saber/components/canvas/_circle_stroke.dart';
import 'package:saber/components/canvas/_rectangle_stroke.dart';
import 'package:saber/components/canvas/_stroke.dart';
import 'package:saber/data/tools/pen_assist.dart';
import 'package:saber/data/tools/shape_analysis.dart';
import 'package:sbn/has_size.dart';

Stroke _stroke([StrokeOptions? options]) => Stroke(
  color: Stroke.defaultColor,
  pressureEnabled: true,
  options: options ?? StrokeOptions(size: 4),
  pageIndex: 0,
  page: const HasSize(Size(1000, 1400)),
  toolId: .fountainPen,
);

Stroke _line(Offset a, Offset b) => _stroke()..setVertexHandles([a, b]);

List<Offset> _circle(double radius, {Offset center = const Offset(300, 300)}) => [
  for (var i = 0; i <= 80; i++)
    center + Offset.fromDirection(2 * pi * i / 80, radius),
];

/// The bounding box of some lines.
Rect _boundsOf(List<List<Offset>> lines) {
  final all = [for (final line in lines) ...line];
  var rect = Rect.fromPoints(all.first, all.first);
  for (final p in all) {
    rect = rect.expandToInclude(Rect.fromPoints(p, p));
  }
  return rect;
}

void main() {
  group('Lengths and angles', () {
    test('page units are written as millimetres', () {
      // A page is 1000 units for 210 mm.
      expect(PenAssist.toMm(1000), closeTo(210, 1e-9));
      expect(PenAssist.formatLength(100), '21 mm');
      expect(PenAssist.formatLength(20), '4,2 mm');
      expect(PenAssist.formatLength(20, comma: false), '4.2 mm');
      expect(PenAssist.formatLength(285.7), '60 mm');
    });

    test('angles are counted anticlockwise from the right, as on paper', () {
      const o = Offset(100, 100);
      expect(PenAssist.angleDegrees(o, const Offset(200, 100)), closeTo(0, 1e-9));
      expect(PenAssist.angleDegrees(o, const Offset(100, 0)), closeTo(90, 1e-9));
      expect(PenAssist.angleDegrees(o, const Offset(0, 100)), closeTo(180, 1e-9));
      expect(PenAssist.angleDegrees(o, const Offset(200, 0)), closeTo(45, 1e-9));
      expect(PenAssist.angleDegrees(o, const Offset(100, 200)), closeTo(270, 1e-9));
    });

    test('the angle guide turns a line to the nearest 15 degrees', () {
      const start = Offset(100, 100);
      for (final (drawn, expected) in [(17.0, 15.0), (40.0, 45.0), (3.0, 0.0), (88.0, 90.0), (-52.0, -45.0)]) {
        final end = start + Offset.fromDirection(drawn * pi / 180, 200);
        final snapped = PenAssist.snapAngle(start, end);
        expect(
          (snapped - start).direction * 180 / pi,
          closeTo(expected, 1e-6),
          reason: '$drawn',
        );
        expect((snapped - start).distance, closeTo(200, 1e-6));
      }
      expect(PenAssist.snapAngle(start, start), start);
    });
  });

  group('Tidy shapes', () {
    test('a nearly square rectangle becomes a square', () {
      final tidy = PenAssist.regularize(
        const ShapeGuess(
          kind: ShapeKind.rectangle,
          rect: Rect.fromLTWH(100, 100, 100, 108),
        ),
      );
      expect(tidy.rect.width, closeTo(104, 1e-9));
      expect(tidy.rect.height, closeTo(104, 1e-9));
      expect(tidy.rect.center, const Offset(150, 154));
    });

    test('a rectangle that was meant to be one stays as drawn', () {
      const guess = ShapeGuess(
        kind: ShapeKind.rectangle,
        rect: Rect.fromLTWH(100, 100, 100, 150),
      );
      expect(PenAssist.regularize(guess).rect, guess.rect);
    });

    test('a nearly round ellipse becomes a circle', () {
      final tidy = PenAssist.regularize(
        const ShapeGuess(
          kind: ShapeKind.ellipse,
          center: Offset(200, 200),
          radiusX: 50,
          radiusY: 54,
        ),
      );
      expect(tidy.kind, ShapeKind.circle);
      expect(tidy.radiusX, closeTo(52, 1e-9));
      expect(tidy.center, const Offset(200, 200));

      const flat = ShapeGuess(
        kind: ShapeKind.ellipse,
        center: Offset(200, 200),
        radiusX: 80,
        radiusY: 40,
      );
      expect(PenAssist.regularize(flat).kind, ShapeKind.ellipse);
    });

    test('a nearly regular triangle gets equal sides and a level base', () {
      final tidy = PenAssist.regularize(
        const ShapeGuess(
          kind: ShapeKind.polygon,
          points: [Offset(100, 300), Offset(304, 306), Offset(198, 128)],
        ),
      );
      final p = tidy.points;
      expect(p, hasLength(3));
      final sides = [
        for (var i = 0; i < 3; i++) (p[(i + 1) % 3] - p[i]).distance,
      ];
      expect(sides[1], closeTo(sides[0], 1e-6));
      expect(sides[2], closeTo(sides[0], 1e-6));
      // one side is level
      expect(
        [for (var i = 0; i < 3; i++) (p[(i + 1) % 3].dy - p[i].dy).abs()],
        contains(lessThan(1e-6)),
      );
    });

    test('an uneven triangle stays as drawn', () {
      const guess = ShapeGuess(
        kind: ShapeKind.polygon,
        points: [Offset(100, 300), Offset(400, 300), Offset(120, 200)],
      );
      expect(PenAssist.regularize(guess).points, guess.points);
    });
  });

  group('Shapes without holding', () {
    test('a big circle is recognised when the pen is lifted', () {
      final drawn = _stroke()..addPoints(_circle(80));
      final shape = PenAssist.autoShape(drawn, tidy: true);
      expect(shape, isA<CircleStroke>());
      expect((shape as CircleStroke).radius, closeTo(80, 4));
    });

    test('a small loop is writing, not a circle', () {
      final drawn = _stroke()..addPoints(_circle(20));
      expect(PenAssist.autoShape(drawn, tidy: true), same(drawn));
    });

    test('a drawn square becomes a rectangle stroke', () {
      final drawn = _stroke()
        ..addPoints([
          for (var x = 100.0; x <= 260; x += 8) Offset(x, 100),
          for (var y = 100.0; y <= 266; y += 8) Offset(260, y),
          for (var x = 260.0; x >= 100; x -= 8) Offset(x, 266),
          for (var y = 266.0; y >= 100; y -= 8) Offset(100, y),
        ]);
      final shape = PenAssist.autoShape(drawn, tidy: true);
      expect(shape, isA<RectangleStroke>());
      final rect = (shape as RectangleStroke).rect;
      // tidied into a square
      expect(rect.width, closeTo(rect.height, 1e-6));
    });

    test('a straight line is left to the line helpers', () {
      final drawn = _stroke()
        ..addPoints([for (var x = 0.0; x <= 300; x += 10) Offset(x, 200)]);
      expect(PenAssist.autoShape(drawn, tidy: true), same(drawn));
    });
  });

  group('Dimensions', () {
    test('figures are written with strokes, left to right', () {
      final lines = PenAssist.textLines(
        '60 mm',
        origin: const Offset(100, 100),
        along: const Offset(1, 0),
        up: const Offset(0, -1),
      );
      // 6 and 0 are one stroke each, each m is three.
      expect(lines, hasLength(8));
      final bounds = _boundsOf(lines);
      expect(bounds.left, greaterThanOrEqualTo(100));
      expect(bounds.width, lessThanOrEqualTo(PenAssist.textWidth('60 mm')));
      // above the baseline, as tall as asked
      expect(bounds.bottom, lessThanOrEqualTo(100 + 1e-9));
      expect(bounds.height, closeTo(PenAssist.textHeight, 0.5));
      // characters that can't be written are skipped, not drawn wrong
      expect(
        PenAssist.textLines(
          'x',
          origin: Offset.zero,
          along: const Offset(1, 0),
          up: const Offset(0, -1),
        ),
        isEmpty,
      );
    });

    test('a line gets two arrowheads and its length above the middle', () {
      // 285.7 units is 60 mm.
      const a = Offset(100, 500), b = Offset(385.7, 500);
      final lines = PenAssist.lineDimension(a, b);
      // two heads, then "60 mm"
      expect(lines, hasLength(2 + 8));
      expect(lines[0][1], a);
      expect(lines[1][1], b);
      final text = _boundsOf(lines.sublist(2));
      expect(text.bottom, lessThan(500));
      expect(text.center.dx, closeTo((a.dx + b.dx) / 2, 2));

      // Drawn the other way, it still reads from the left, above the line.
      final reversed = PenAssist.lineDimension(b, a);
      final reversedText = _boundsOf(reversed.sublist(2));
      expect(reversedText.bottom, lessThan(500));
      expect(reversed[2].first.dx, lessThan(reversed.last.first.dx));
    });

    test('an upright line is read from below, on its left', () {
      final lines = PenAssist.lineDimension(
        const Offset(300, 100),
        const Offset(300, 500),
      );
      final text = _boundsOf(lines.sublist(2));
      expect(text.right, lessThan(300));
      expect(text.center.dy, closeTo(300, 2));
      // the first figure is the lowest: reading goes upwards
      expect(lines[2].first.dy, greaterThan(lines.last.first.dy));
    });

    test('dimension strokes are thin ink like the line they belong to', () {
      final line = _line(const Offset(100, 500), const Offset(385.7, 500));
      final strokes = PenAssist.dimensionStrokes(line);
      expect(strokes, hasLength(10));
      for (final stroke in strokes) {
        expect(stroke.color, line.color);
        expect(stroke.options.size, lessThan(line.options.size));
        expect(stroke.pressureEnabled, isFalse);
        expect(stroke.isEmpty, isFalse);
        // handwriting has no dimensions of its own
        expect(PenAssist.dimensionStrokes(stroke), isEmpty);
      }
    });

    test('circles get a diameter, rectangles a width and a height', () {
      final circle = PenAssist.autoShape(
        _stroke()..addPoints(_circle(100)),
        tidy: true,
      );
      final diameter = PenAssist.dimensionsOf(circle);
      expect(diameter, isNotEmpty);
      // above the circle
      expect(_boundsOf(diameter).bottom, lessThan(300 - 95));

      final rectangle = RectangleStroke(
        color: Stroke.defaultColor,
        pressureEnabled: false,
        options: StrokeOptions(size: 4),
        pageIndex: 0,
        page: const HasSize(Size(1000, 1400)),
        toolId: .fountainPen,
        rect: const Rect.fromLTWH(100, 100, 285.7, 190.5),
      );
      final sides = PenAssist.dimensionsOf(rectangle);
      // "60 mm" above and "40 mm" beside: eight strokes each
      expect(sides, hasLength(16));
      expect(_boundsOf(sides.sublist(0, 8)).bottom, lessThan(100));
      expect(_boundsOf(sides.sublist(8)).left, greaterThan(385.7));
      expect(PenAssist.describe(rectangle), '60 mm × 40 mm');
    });
  });

  group('Measuring and finishing', () {
    test('a line is described by its length and angle', () {
      expect(
        PenAssist.describeLine(const Offset(0, 100), const Offset(285.7, 100)),
        '60 mm  ∠ 0°',
      );
      final line = _line(const Offset(100, 500), const Offset(100, 214.3));
      expect(PenAssist.describe(line), '60 mm  ∠ 90°');
      final curve = _stroke()
        ..addPoints([const Offset(0, 0), const Offset(100, 0), const Offset(100, 100)]);
      expect(PenAssist.describe(curve), '42 mm');
    });

    test('the angle guide straightens a finished line', () {
      const a = Offset(100, 100);
      final b = a + Offset.fromDirection(18 * pi / 180, 200);
      final line = _line(a, b);
      final extras = PenAssist.finish(
        line,
        angleGuide: true,
        dimensions: false,
        measure: false,
      );
      expect(extras, isEmpty);
      final ends = line.vertexHandles!;
      expect(ends.first, a);
      expect((ends.last - a).direction * 180 / pi, closeTo(15, 1e-6));
    });

    test('the angle a line was turned to is shown when it is finished', () {
      PenAssist.showReadout(null);
      const a = Offset(100, 500);
      // up and to the right, 18 degrees above level
      final line = _line(a, a + Offset.fromDirection(-18 * pi / 180, 200));
      final before = PenAssist.readoutFinished.value;
      PenAssist.finish(line, angleGuide: true, dimensions: false, measure: false);
      expect(PenAssist.readout.value, '∠ 15°');
      expect(PenAssist.readoutFinished.value, before + 1);

      // with measuring on, the length comes with it
      PenAssist.finish(line, angleGuide: true, dimensions: false, measure: true);
      expect(PenAssist.readout.value, '42 mm  ∠ 15°');

      // what is no line has no angle to show
      final writing = _stroke();
      for (var i = 0; i < 40; i++) {
        writing.addPoint(Offset(i * 3.0, sin(i / 3) * 10));
      }
      PenAssist.finish(writing, angleGuide: true, dimensions: false, measure: false);
      expect(PenAssist.readout.value, isNull);
    });

    test('while a line is drawn, what is shown follows what it is', () {
      const start = Offset(100, 500);
      String? live(
        Offset position,
        double pathLength, {
        bool measure = false,
        bool angleGuide = false,
      }) => PenAssist.liveReadout(
        start: start,
        position: position,
        pathLength: pathLength,
        measure: measure,
        angleGuide: angleGuide,
      );

      // nothing is on: nothing is shown
      expect(live(const Offset(400, 500), 300), isNull);

      // the angle guide alone shows the angle the line will be turned to
      final towards = start + Offset.fromDirection(-18 * pi / 180, 200);
      expect(live(towards, 200, angleGuide: true), '∠ 15°');
      // not while the line is too short to have a direction
      expect(live(const Offset(110, 498), 10.2, angleGuide: true), isNull);
      // and not once the line bends: that will not be a straight line
      expect(live(towards, 320, angleGuide: true), isNull);

      // measuring shows length and angle of a straight line as it is
      expect(live(towards, 200, measure: true), '42 mm  ∠ 18°');
      // with the guide, as it will be
      expect(live(towards, 200, measure: true, angleGuide: true), '42 mm  ∠ 15°');
      // and of a bent line how long it is along its path
      expect(live(towards, 320, measure: true), '67 mm');
      expect(live(const Offset(110, 500), 10, measure: true), '2,1 mm');
    });

    test('a line drawn by hand counts as straight, writing does not', () {
      // straight but unsteady: two units to either side over 300
      final unsteady = _stroke();
      for (var i = 0; i <= 40; i++) {
        unsteady.addPoint(Offset(100 + i * 7.5, 400 + i * 2.0 + sin(i * 0.9) * 2));
      }
      expect(PenAssist.isLine(unsteady), isTrue);

      final wave = _stroke();
      for (var i = 0; i <= 40; i++) {
        wave.addPoint(Offset(100 + i * 7.5, 400 + sin(i / 3) * 30));
      }
      expect(PenAssist.isLine(wave), isFalse);

      // too short to be anything but writing
      final dash = _stroke();
      for (var i = 0; i <= 10; i++) {
        dash.addPoint(Offset(100 + i * 2.0, 400));
      }
      expect(PenAssist.isLine(dash), isFalse);
      expect(PenAssist.isLine(_stroke()..addPoints(_circle(100))), isFalse);
    });

    test('handwriting is left alone by the angle guide', () {
      final writing = _stroke();
      for (var i = 0; i < 30; i++) {
        writing.addPoint(Offset(i * 3.0, sin(i / 3) * 10));
      }
      final before = writing.pointOffsets;
      final extras = PenAssist.finish(
        writing,
        angleGuide: true,
        dimensions: true,
        measure: false,
      );
      expect(extras, isEmpty);
      expect(writing.pointOffsets, before);
    });

    test('dimensions are added to a finished line', () {
      final line = _line(const Offset(100, 500), const Offset(385.7, 500));
      final extras = PenAssist.finish(
        line,
        angleGuide: false,
        dimensions: true,
        measure: false,
      );
      expect(extras, hasLength(10));
    });
  });
}
