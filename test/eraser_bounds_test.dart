import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfect_freehand/perfect_freehand.dart';
import 'package:saber/components/canvas/_stroke.dart';
import 'package:saber/data/tools/eraser.dart';
import 'package:sbn/has_size.dart';

Stroke _stroke(Iterable<Offset> points) {
  final stroke = Stroke(
    color: Stroke.defaultColor,
    pressureEnabled: Stroke.defaultPressureEnabled,
    options: StrokeOptions(size: 2),
    pageIndex: 0,
    page: const HasSize(Size(1000, 1000)),
    toolId: .fountainPen,
  );
  for (final point in points) stroke.addPoint(point);
  return stroke;
}

void main() {
  group('Stroke bounds:', () {
    test('contain every vertex of the outline', () {
      final stroke = _stroke([
        const Offset(10, 20),
        const Offset(60, 5),
        const Offset(90, 70),
        const Offset(30, 80),
      ]);
      final bounds = stroke.bounds;
      for (final vertex in stroke.lowQualityPolygon) {
        expect(bounds.inflate(1e-9).contains(vertex), isTrue);
      }
      // ...and are tight: some vertex lies on every side.
      final xs = stroke.lowQualityPolygon.map((p) => p.dx);
      final ys = stroke.lowQualityPolygon.map((p) => p.dy);
      expect(bounds.left, xs.reduce(min));
      expect(bounds.right, xs.reduce(max));
      expect(bounds.top, ys.reduce(min));
      expect(bounds.bottom, ys.reduce(max));
    });

    test('follow the stroke when it is shifted', () {
      final stroke = _stroke([const Offset(10, 10), const Offset(40, 40)]);
      final before = stroke.bounds;
      stroke.shift(const Offset(100, -5));
      expect(stroke.bounds.left, closeTo(before.left + 100, 1e-6));
      expect(stroke.bounds.top, closeTo(before.top - 5, 1e-6));
      expect(stroke.bounds.size.width, closeTo(before.size.width, 1e-6));
    });

    test('grow when a point is added', () {
      final stroke = _stroke([const Offset(10, 10), const Offset(20, 20)]);
      final before = stroke.bounds;
      stroke.addPoint(const Offset(200, 200));
      expect(stroke.bounds.right, greaterThan(before.right + 100));
    });
  });

  group('Eraser with bounds:', () {
    test('a shifted stroke is erased at its new place only', () {
      final eraser = Eraser(size: 10);
      final stroke = _stroke([const Offset(10, 10), const Offset(40, 40)]);

      expect(
        eraser.checkForOverlappingStrokes(const Offset(25, 25), [stroke]),
        [stroke],
      );
      stroke.shift(const Offset(300, 0));
      expect(
        eraser.checkForOverlappingStrokes(const Offset(25, 25), [stroke]),
        isEmpty,
      );
      expect(
        eraser.checkForOverlappingStrokes(const Offset(325, 25), [stroke]),
        [stroke],
      );
    });

    test('finds exactly what a check of every vertex finds', () {
      final random = Random(42);
      final eraser = Eraser(size: 12);
      final strokes = [
        for (var i = 0; i < 200; i++)
          _stroke([
            for (var j = 0; j < 2 + random.nextInt(8); j++)
              Offset(random.nextDouble() * 1000, random.nextDouble() * 1000),
          ]),
      ];
      // Brute force below checks every vertex, as the eraser does for small
      // outlines. It has no skipping, so keep outlines below that limit.
      for (final stroke in strokes) {
        expect(stroke.lowQualityPolygon.length, lessThan(100));
      }

      var hits = 0;
      for (var i = 0; i < 500; i++) {
        // Half of the positions are near a stroke's own vertices, so there
        // are plenty of hits and near misses.
        final pos = i.isEven
            ? Offset(random.nextDouble() * 1000, random.nextDouble() * 1000)
            : strokes[random.nextInt(strokes.length)].lowQualityPolygon[0] +
                  Offset(
                    random.nextDouble() * 30 - 15,
                    random.nextDouble() * 30 - 15,
                  );

        final expected = {
          for (final stroke in strokes)
            if (stroke.length <= 3 && stroke.lowQualityPath.contains(pos) ||
                stroke.lowQualityPolygon.any(
                  (v) => sqrDistanceBetween(v, pos) <= square(12),
                ))
              stroke,
        };
        final actual = eraser.checkForOverlappingStrokes(pos, strokes).toSet();
        eraser.onDragEnd();
        expect(actual, expected, reason: 'at $pos');
        hits += actual.length;
      }
      expect(hits, greaterThan(50), reason: 'test should hit strokes');
    });
  });
}
