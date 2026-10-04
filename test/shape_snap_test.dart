import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfect_freehand/perfect_freehand.dart';
import 'package:saber/components/canvas/_circle_stroke.dart';
import 'package:saber/components/canvas/_rectangle_stroke.dart';
import 'package:saber/components/canvas/_stroke.dart';
import 'package:saber/data/tools/shape_analysis.dart';
import 'package:saber/data/tools/shape_snap.dart';
import 'package:sbn/has_size.dart';

Stroke _stroke([StrokeOptions? options]) => Stroke(
  color: Stroke.defaultColor,
  pressureEnabled: true,
  options: options ?? StrokeOptions(size: 4),
  pageIndex: 0,
  page: const HasSize(Size(1000, 1000)),
  toolId: .fountainPen,
);

List<Offset> _circle(double radius, {Offset center = const Offset(300, 300)}) => [
  for (var i = 0; i <= 80; i++)
    center + Offset.fromDirection(2 * pi * i / 80, radius),
];

const _square = [
  Offset(100, 100),
  Offset(220, 100),
  Offset(220, 220),
  Offset(100, 220),
];

ShapeGuess _polygon(List<Offset> corners) =>
    ShapeGuess(kind: ShapeKind.polygon, points: corners);

void main() {
  group('ShapeBuilder', () {
    test('a circle becomes a circle stroke', () {
      final raw = _stroke()..addPoints(_circle(70));
      final guess = ShapeAnalysis.analyze(raw.pointOffsets)!;
      final built = ShapeBuilder.build(raw, guess);
      expect(built, isA<CircleStroke>());
      expect((built as CircleStroke).radius, closeTo(70, 3));
    });

    test('a rectangle becomes a rectangle stroke', () {
      final raw = _stroke();
      final built = ShapeBuilder.build(
        raw,
        ShapeGuess(kind: ShapeKind.rectangle, rect: Rect.fromLTWH(10, 20, 100, 50)),
      );
      expect(built, isA<RectangleStroke>());
      expect((built as RectangleStroke).rect, Rect.fromLTWH(10, 20, 100, 50));
    });

    test('a polygon keeps its corners, which can then be edited', () {
      final built = ShapeBuilder.build(_stroke(), _polygon(_square));
      expect(built.vertexHandles, _square);
    });

    test('a highlighter circle is made of points, not a circle stroke', () {
      final raw = Stroke(
        color: Stroke.defaultColor,
        pressureEnabled: false,
        options: StrokeOptions(size: 30),
        pageIndex: 0,
        page: const HasSize(Size(1000, 1000)),
        toolId: .highlighter,
      );
      final built = ShapeBuilder.build(
        raw,
        ShapeGuess(
          kind: ShapeKind.circle,
          center: const Offset(300, 300),
          radiusX: 60,
          radiusY: 60,
        ),
      );
      expect(built, isNot(isA<CircleStroke>()));
      expect(built.length, greaterThan(50));
    });

    test("building a shape doesn't change the pen's own options", () {
      final options = StrokeOptions(size: 4);
      options.start.taperEnabled = true;
      options.end.taperEnabled = true;
      ShapeBuilder.build(_stroke(options), _polygon(_square));
      expect(options.start.taperEnabled, isTrue);
      expect(options.end.taperEnabled, isTrue);
    });
  });

  group('Corner handles', () {
    test('a line has two, a polygon one per corner', () {
      final line = _stroke()
        ..addPoints([const Offset(0, 0), const Offset(100, 0), const Offset(100, 0)]);
      expect(line.vertexHandles, [const Offset(0, 0), const Offset(100, 0)]);

      final polygon = ShapeBuilder.build(_stroke(), _polygon(_square));
      expect(polygon.vertexHandles, hasLength(4));
    });

    test('handwriting and ellipses have none', () {
      final handwriting = _stroke();
      for (var i = 0; i < 30; i++) {
        handwriting.addPoint(Offset(i * 3.0, sin(i / 3) * 10));
      }
      expect(handwriting.vertexHandles, isNull);

      final ellipse = ShapeBuilder.build(
        _stroke(),
        ShapeGuess(
          kind: ShapeKind.ellipse,
          center: const Offset(300, 300),
          radiusX: 100,
          radiusY: 50,
        ),
      );
      expect(ellipse.vertexHandles, isNull);
    });

    test('an arrow is not edited corner by corner', () {
      final line = _stroke()
        ..addPoints([const Offset(10, 10), const Offset(210, 10), const Offset(210, 10)]);
      line.convertToArrow();
      expect(line.vertexHandles, isNull);
    });

    test('moving a corner changes only that corner', () {
      final polygon = ShapeBuilder.build(_stroke(), _polygon(_square));
      final corners = polygon.vertexHandles!;
      corners[2] = const Offset(260, 260);
      polygon.setVertexHandles(corners);
      expect(polygon.vertexHandles, [
        _square[0],
        _square[1],
        const Offset(260, 260),
        _square[3],
      ]);
    });

    test('moving the first corner keeps the shape closed', () {
      final polygon = ShapeBuilder.build(_stroke(), _polygon(_square));
      final corners = polygon.vertexHandles!;
      corners[0] = const Offset(80, 90);
      polygon.setVertexHandles(corners);
      expect(polygon.vertexHandles!.first, const Offset(80, 90));
      expect(polygon.vertexHandles, hasLength(4));
    });

    test('corners survive moving and resizing the stroke', () {
      final polygon = ShapeBuilder.build(_stroke(), _polygon(_square));
      polygon.shift(const Offset(13, -7));
      expect(polygon.vertexHandles, hasLength(4));
    });
  });

  group('Snapping to other shapes', () {
    test('an end near another shape\'s corner jumps onto it', () {
      final square = ShapeBuilder.build(_stroke(), _polygon(_square));
      final line = _stroke()
        ..addPoints([const Offset(224, 96), const Offset(400, 96), const Offset(400, 96)]);
      final changed = ShapeSnap.snapToEndpoints(line, [square, line]);
      expect(changed, isTrue);
      expect(line.vertexHandles!.first, const Offset(220, 100));
      expect(line.vertexHandles!.last, const Offset(400, 96));
    });

    test('an end far from every shape stays', () {
      final square = ShapeBuilder.build(_stroke(), _polygon(_square));
      final line = _stroke()
        ..addPoints([const Offset(300, 300), const Offset(400, 300), const Offset(400, 300)]);
      expect(ShapeSnap.snapToEndpoints(line, [square]), isFalse);
      expect(line.vertexHandles!.first, const Offset(300, 300));
    });

    test('handwriting is never moved', () {
      final square = ShapeBuilder.build(_stroke(), _polygon(_square));
      final writing = _stroke();
      for (var i = 0; i < 30; i++) {
        writing.addPoint(Offset(222.0 + i * 3, 98 + sin(i / 3) * 10));
      }
      expect(ShapeSnap.snapToEndpoints(writing, [square]), isFalse);
    });

    test('snaps onto the corner of a rectangle stroke', () {
      final rectangle = RectangleStroke(
        color: Stroke.defaultColor,
        pressureEnabled: false,
        options: StrokeOptions(size: 4),
        pageIndex: 0,
        page: const HasSize(Size(1000, 1000)),
        toolId: .shapePen,
        rect: Rect.fromLTWH(100, 100, 200, 100),
      );
      final line = _stroke()
        ..addPoints([const Offset(305, 205), const Offset(500, 400), const Offset(500, 400)]);
      ShapeSnap.snapToEndpoints(line, [rectangle]);
      expect(line.vertexHandles!.first, const Offset(300, 200));
    });
  });

  group('Hold to snap', () {
    tearDown(() {
      ShapeSnap.reset();
      ShapeSnap.redraw = null;
    });

    Future<void> drawAndHold(Stroke stroke, List<Offset> path) async {
      ShapeSnap.begin(stroke, path.first, hold: const Duration(milliseconds: 60));
      for (final p in path) {
        stroke.addPoint(p);
        ShapeSnap.onMove(p);
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }

    test('a circle snaps once the pen is held still', () async {
      var redraws = 0;
      ShapeSnap.redraw = () => redraws++;
      final stroke = _stroke();
      await drawAndHold(stroke, _circle(80));
      expect(ShapeSnap.preview?.kind, ShapeKind.circle);
      expect(redraws, 1);

      final result = ShapeSnap.finish(stroke);
      expect(result, isA<CircleStroke>());
      expect(ShapeSnap.lastWasSnapped, isTrue);
      expect(ShapeSnap.preview, isNull);
    });

    test('nothing snaps if the pen keeps moving', () async {
      final stroke = _stroke();
      final path = _circle(80);
      ShapeSnap.begin(stroke, path.first, hold: const Duration(milliseconds: 60));
      for (final p in path) {
        stroke.addPoint(p);
        ShapeSnap.onMove(p);
        await Future<void>.delayed(const Duration(milliseconds: 4));
      }
      expect(ShapeSnap.preview, isNull);
      expect(ShapeSnap.finish(stroke), same(stroke));
      expect(ShapeSnap.lastWasSnapped, isFalse);
    });

    test('moving on after the snap lets go of the shape', () async {
      final stroke = _stroke();
      await drawAndHold(stroke, _circle(80));
      expect(ShapeSnap.preview, isNotNull);
      ShapeSnap.onMove(const Offset(500, 500));
      expect(ShapeSnap.preview, isNull);
    });

    test('short strokes never snap', () async {
      final stroke = _stroke();
      await drawAndHold(stroke, [
        for (var i = 0; i < 6; i++) Offset(100 + i * 5.0, 100),
      ]);
      expect(ShapeSnap.preview, isNull);
    });

    test('a held straight line is snapped to horizontal', () async {
      final stroke = _stroke();
      await drawAndHold(stroke, [
        for (var i = 0; i <= 40; i++) Offset(100 + i * 6.0, 100 + i * 0.15),
      ]);
      expect(ShapeSnap.preview?.kind, ShapeKind.line);
      expect(ShapeSnap.preview!.points.first.dy, ShapeSnap.preview!.points.last.dy);
    });
  });
}
