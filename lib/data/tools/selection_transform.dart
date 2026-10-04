import 'dart:math';
import 'dart:ui';

import 'package:flutter/painting.dart' show MatrixUtils;
import 'package:saber/components/canvas/_stroke.dart';
import 'package:saber/data/tools/select.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4;

/// The two handles shown around a finished selection.
enum SelectHandle {
  /// Drag to resize the selection about its top-left corner.
  scale,

  /// Drag to rotate the selection about its centre.
  rotate,
}

/// Resizing and rotating the strokes and images of a [SelectResult].
abstract class SelectionTransform {
  /// How far (on screen, in logical pixels) the handles are from the box.
  static const rotateHandleDistance = 36.0;

  /// How close (on screen) a touch has to be to grab a handle.
  static const handleHitRadius = 26.0;

  /// The smallest and largest total scale a drag can reach.
  static const minTotalScale = 0.1;
  static const maxTotalScale = 10.0;

  /// A matrix that scales by [factor] about [anchor].
  static Matrix4 scaleAbout(Offset anchor, double factor) =>
      Matrix4.translationValues(anchor.dx, anchor.dy, 0)
        ..scaleByDouble(factor, factor, 1, 1)
        ..translateByDouble(-anchor.dx, -anchor.dy, 0, 1);

  /// A matrix that rotates by [radians] about [center].
  static Matrix4 rotateAbout(Offset center, double radians) =>
      Matrix4.translationValues(center.dx, center.dy, 0)
        ..rotateZ(radians)
        ..translateByDouble(-center.dx, -center.dy, 0, 1);

  /// The inverse of [matrix], for undoing it.
  static Matrix4 inverse(Matrix4 matrix) => Matrix4.copy(matrix)..invert();

  /// The uniform scale factor of [matrix].
  static double scaleOf(Matrix4 matrix) => Stroke.scaleOfMatrix(matrix);

  static bool hasRotation(Matrix4 matrix) =>
      matrix.entry(1, 0).abs() > 1e-9 || matrix.entry(0, 1).abs() > 1e-9;

  /// The bounding box of everything selected, or null if nothing is.
  static Rect? contentBounds(SelectResult selection) {
    Rect? bounds;
    for (final stroke in selection.strokes) {
      bounds = bounds == null ? stroke.bounds : bounds.expandToInclude(stroke.bounds);
    }
    for (final image in selection.images) {
      bounds = bounds == null
          ? image.dstRect
          : bounds.expandToInclude(image.dstRect);
    }
    return bounds;
  }

  /// Images and rectangles can't be rotated.
  static bool canRotate(SelectResult selection) =>
      selection.images.isEmpty &&
      selection.strokes.every((stroke) => stroke.canRotate);

  static Offset scaleHandlePosition(Rect bounds) => bounds.bottomRight;

  static Offset rotateHandlePosition(Rect bounds, double viewScale) => Offset(
    bounds.center.dx,
    bounds.top - rotateHandleDistance / viewScale,
  );

  /// The handle at [position] (in page coordinates), if any.
  /// [viewScale] is how zoomed in the page is, so handles keep their size on
  /// screen.
  static SelectHandle? handleAt(
    SelectResult selection,
    Offset position,
    double viewScale,
  ) {
    final bounds = contentBounds(selection);
    if (bounds == null) return null;
    final radius = handleHitRadius / viewScale;

    final rotateDistance =
        (position - rotateHandlePosition(bounds, viewScale)).distance;
    final scaleDistance = (position - scaleHandlePosition(bounds)).distance;

    if (canRotate(selection) && rotateDistance <= radius) {
      return scaleDistance < rotateDistance ? SelectHandle.scale : SelectHandle.rotate;
    }
    if (scaleDistance <= radius) return SelectHandle.scale;
    return null;
  }

  /// Applies [matrix] to everything in [selection], including its outline.
  /// Images are only scaled and moved; they can't be rotated.
  static void apply(SelectResult selection, Matrix4 matrix) {
    for (final stroke in selection.strokes) {
      stroke.transform(matrix);
    }
    if (!hasRotation(matrix)) {
      for (final image in selection.images) {
        image.dstRect = Rect.fromPoints(
          MatrixUtils.transformPoint(matrix, image.dstRect.topLeft),
          MatrixUtils.transformPoint(matrix, image.dstRect.bottomRight),
        );
      }
    }
    selection.path = selection.path.transform(matrix.storage);
  }

  /// The matrix for dragging the scale handle from [previous] to [current],
  /// about [anchor]. Null if the drag shouldn't change anything, which
  /// includes going past the limits of [minTotalScale] and [maxTotalScale].
  static Matrix4? scaleStep({
    required Offset anchor,
    required Offset previous,
    required Offset current,
    required double totalScaleSoFar,
  }) {
    final before = (previous - anchor).distance;
    final after = (current - anchor).distance;
    if (before < 1e-3 || after < 1e-3) return null;

    final factor = after / before;
    final total = totalScaleSoFar * factor;
    if (total < minTotalScale || total > maxTotalScale) return null;
    return scaleAbout(anchor, factor);
  }

  /// The matrix for dragging the rotate handle from [previous] to [current],
  /// about [center].
  static Matrix4? rotateStep({
    required Offset center,
    required Offset previous,
    required Offset current,
  }) {
    final from = previous - center;
    final to = current - center;
    if (from.distance < 1e-3 || to.distance < 1e-3) return null;

    var angle = to.direction - from.direction;
    // The shortest way round.
    while (angle > pi) {
      angle -= 2 * pi;
    }
    while (angle < -pi) {
      angle += 2 * pi;
    }
    return rotateAbout(center, angle);
  }
}
