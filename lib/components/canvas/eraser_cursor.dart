import 'package:flutter/material.dart';

/// The eraser's footprint, drawn over the page while it is rubbing: what
/// is inside the circle is what gets erased.
///
/// It fills the area it is given (put it over the page). Where the eraser
/// is comes from [EraserCursor.at], in global coordinates.
class EraserCursor extends StatelessWidget {
  const EraserCursor({super.key});

  /// The centre and the radius of the eraser on screen, or null while it
  /// is not rubbing.
  static final at = ValueNotifier<({Offset centre, double radius})?>(null);

  @override
  Widget build(BuildContext context) {
    final colors = ColorScheme.of(context);
    return ValueListenableBuilder(
      valueListenable: at,
      builder: (context, value, _) {
        if (value == null) return const SizedBox.expand();
        // Where the eraser is, seen from this widget's own corner.
        final box = context.findRenderObject();
        final centre = box is RenderBox && box.hasSize
            ? box.globalToLocal(value.centre)
            : value.centre;
        return CustomPaint(
          key: const ValueKey('eraserCursor'),
          size: Size.infinite,
          painter: EraserCursorPainter(
            centre: centre,
            radius: value.radius,
            edge: colors.onSurface.withValues(alpha: 0.55),
            fill: colors.surface.withValues(alpha: 0.35),
          ),
        );
      },
    );
  }
}

class EraserCursorPainter extends CustomPainter {
  const EraserCursorPainter({
    required this.centre,
    required this.radius,
    required this.edge,
    required this.fill,
  });

  final Offset centre;
  final double radius;
  final Color edge, fill;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..drawCircle(centre, radius, Paint()..color = fill)
      ..drawCircle(
        centre,
        radius,
        Paint()
          ..color = edge
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
  }

  @override
  bool shouldRepaint(EraserCursorPainter oldDelegate) =>
      oldDelegate.centre != centre ||
      oldDelegate.radius != radius ||
      oldDelegate.edge != edge ||
      oldDelegate.fill != fill;
}
