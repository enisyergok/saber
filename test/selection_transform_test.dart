import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfect_freehand/perfect_freehand.dart';
import 'package:saber/components/canvas/_stroke.dart';
import 'package:saber/data/tools/select.dart';
import 'package:saber/data/tools/selection_transform.dart';
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

SelectResult _selection(List<Stroke> strokes) => SelectResult(
  pageIndex: 0,
  strokes: strokes,
  images: [],
  path: Path()..addRect(const Rect.fromLTWH(0, 0, 200, 200)),
);

void main() {
  group('Selection transform:', () {
    test('scaling about a point keeps that point fixed', () {
      final m = SelectionTransform.scaleAbout(const Offset(10, 10), 2);
      final p = MatrixUtils.transformPoint(m, const Offset(10, 10));
      expect(p.dx, closeTo(10, 1e-9));
      expect(p.dy, closeTo(10, 1e-9));
      final q = MatrixUtils.transformPoint(m, const Offset(20, 30));
      expect(q, const Offset(30, 50));
    });

    test('a stroke scales and its width follows', () {
      final stroke = _stroke([const Offset(10, 10), const Offset(50, 30)]);
      final size = stroke.options.size;
      stroke.transform(SelectionTransform.scaleAbout(const Offset(10, 10), 2));
      expect(stroke.points.first.dx, closeTo(10, 1e-6));
      expect(stroke.points.last.dx, closeTo(90, 1e-6));
      expect(stroke.points.last.dy, closeTo(50, 1e-6));
      expect(stroke.options.size, closeTo(size * 2, 1e-9));
    });

    test('rotating by 90 degrees and back restores the stroke', () {
      final stroke = _stroke([const Offset(10, 10), const Offset(50, 30)]);
      final m = SelectionTransform.rotateAbout(const Offset(30, 20), pi / 2);
      stroke.transform(m);
      expect(stroke.points.first.dx, closeTo(40, 1e-6));
      expect(stroke.points.first.dy, closeTo(0, 1e-6));
      stroke.transform(SelectionTransform.inverse(m));
      expect(stroke.points.first.dx, closeTo(10, 1e-6));
      expect(stroke.points.first.dy, closeTo(10, 1e-6));
    });

    test('apply moves the selection outline too', () {
      final selection = _selection([
        _stroke([const Offset(10, 10), const Offset(50, 30)]),
      ]);
      SelectionTransform.apply(
        selection,
        SelectionTransform.scaleAbout(Offset.zero, 2),
      );
      expect(selection.path.getBounds().right, closeTo(400, 1e-6));
    });

    test('handles are found near their corners only', () {
      final selection = _selection([
        _stroke([const Offset(100, 100), const Offset(200, 200)]),
      ]);
      final bounds = SelectionTransform.contentBounds(selection)!;
      expect(
        SelectionTransform.handleAt(selection, bounds.bottomRight, 1),
        SelectHandle.scale,
      );
      expect(
        SelectionTransform.handleAt(
          selection,
          SelectionTransform.rotateHandlePosition(bounds, 1),
          1,
        ),
        SelectHandle.rotate,
      );
      expect(
        SelectionTransform.handleAt(selection, bounds.center, 1),
        isNull,
      );
    });

    test('scale steps stop at the limits', () {
      final step = SelectionTransform.scaleStep(
        anchor: Offset.zero,
        previous: const Offset(10, 0),
        current: const Offset(20, 0),
        totalScaleSoFar: 1,
      );
      expect(step, isNotNull);
      expect(
        SelectionTransform.scaleStep(
          anchor: Offset.zero,
          previous: const Offset(10, 0),
          current: const Offset(20, 0),
          totalScaleSoFar: 9,
        ),
        isNull,
      );
    });
  });
}
