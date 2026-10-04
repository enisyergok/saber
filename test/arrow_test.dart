import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfect_freehand/perfect_freehand.dart';
import 'package:saber/components/canvas/_stroke.dart';
import 'package:sbn/has_size.dart';

Stroke _line(Offset a, Offset b) {
  final stroke = Stroke(
    color: Stroke.defaultColor,
    pressureEnabled: false,
    options: StrokeOptions(size: 3),
    pageIndex: 0,
    page: const HasSize(Size(1000, 1000)),
    toolId: .shapePen,
  );
  stroke.addPoint(a);
  stroke.addPoint(Offset.lerp(a, b, 0.5)!);
  stroke.addPoint(b);
  return stroke;
}

void main() {
  group('Arrows:', () {
    test('the wings sit behind the tip, equally far from it', () {
      const tail = Offset(0, 0), tip = Offset(100, 0);
      final (left, right) = Stroke.arrowHead(tail, tip, headLength: 20);
      expect((left - tip).distance, closeTo(20, 1e-9));
      expect((right - tip).distance, closeTo(20, 1e-9));
      expect(left.dx, lessThan(tip.dx));
      expect(right.dx, lessThan(tip.dx));
      expect(left.dy, closeTo(-right.dy, 1e-9));
    });

    test('works for any direction', () {
      const tail = Offset(10, 10), tip = Offset(10, 110);
      final (left, right) = Stroke.arrowHead(tail, tip, headLength: 20);
      expect(left.dy, lessThan(tip.dy));
      expect(right.dy, lessThan(tip.dy));
      expect(left.dx + right.dx, closeTo(2 * tip.dx, 1e-9));
    });

    test('a line becomes a line with a head, ending at the same tip', () {
      final stroke = _line(const Offset(10, 10), const Offset(210, 10));
      stroke.convertToLine();
      final tip = stroke.points[1];
      stroke.convertToArrow();
      expect(stroke.points.first, const Offset(10, 10));
      expect(stroke.points[1], tip);
      expect(stroke.points[3], tip);
      expect((stroke.points[2] - tip).distance, closeTo((stroke.points[4] - tip).distance, 1e-6));
      expect(stroke.bounds.right, greaterThanOrEqualTo(210));
    });

    test('a tiny line is left alone', () {
      final stroke = _line(const Offset(10, 10), const Offset(10.2, 10));
      stroke.convertToLine();
      final before = stroke.points.length;
      stroke.convertToArrow();
      expect(stroke.points.length, before);
    });

    test('the head is never longer than the shaft allows', () {
      final stroke = _line(const Offset(0, 0), const Offset(30, 0));
      stroke.convertToLine();
      stroke.convertToArrow();
      expect((stroke.points[2] - stroke.points[1]).distance, lessThanOrEqualTo(30 * 0.4 + 1e-6));
      expect(stroke.points[2].dy.abs(), lessThan(pi * 30));
    });
  });
}
