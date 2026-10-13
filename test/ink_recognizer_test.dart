import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:saber/data/ocr/ink_recognizer.dart';

void main() {
  group('groupLines:', () {
    Rect at(double x, double y) => Rect.fromLTWH(x, y, 20, 30);

    test('nothing gives no lines', () {
      expect(groupLines<Rect>([], (r) => r), isEmpty);
    });

    test('strokes on one line stay together', () {
      final lines = groupLines<Rect>([at(0, 100), at(30, 104), at(60, 98)], (r) => r);
      expect(lines, hasLength(1));
      expect(lines.single, hasLength(3));
    });

    test('two lines are told apart, top line first', () {
      final items = [at(0, 300), at(30, 304), at(0, 100), at(30, 98)];
      final lines = groupLines<Rect>(items, (r) => r);
      expect(lines, hasLength(2));
      expect(lines.first.map((r) => r.top), [100, 98]);
      expect(lines.last.map((r) => r.top), [300, 304]);
    });

    test('descender loops stay with their line', () {
      final items = [
        at(0, 100),
        at(30, 100),
        Rect.fromLTWH(60, 125, 20, 25), // loop of a y, lower than the rest
        at(90, 102),
        at(0, 300),
      ];
      final lines = groupLines<Rect>(items, (r) => r);
      expect(lines, hasLength(2));
      expect(lines.first, hasLength(4));
    });

    test('drawing order is kept inside a line', () {
      final items = [at(90, 100), at(0, 102), at(40, 99)];
      final lines = groupLines<Rect>(items, (r) => r);
      expect(lines.single.map((r) => r.left), [90, 0, 40]);
    });

    test('every stroke ends up in exactly one line', () {
      final items = [for (var i = 0; i < 20; i++) at(i * 25.0, (i % 4) * 120.0)];
      final lines = groupLines<Rect>(items, (r) => r);
      expect(lines.expand((l) => l), hasLength(items.length));
    });
  });

  group('inkPoints:', () {
    test('times only go up, with a gap between strokes', () {
      final points = inkPoints([
        [const Offset(0, 0), const Offset(1, 1)],
        [const Offset(5, 5)],
      ]);
      expect(points, hasLength(2));
      final all = points.expand((s) => s).map((p) => p.t).toList();
      expect(all, [...all]..sort());
      expect(points[1].first.t - points[0].last.t, greaterThan(100));
    });

    test('coordinates are kept', () {
      final points = inkPoints([
        [const Offset(3, 4)],
      ]);
      expect((points.single.single.x, points.single.single.y), (3.0, 4.0));
    });
  });
}
