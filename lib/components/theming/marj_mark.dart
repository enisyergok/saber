import 'package:flutter/material.dart';
import 'package:saber/components/eink/eink_scope.dart';

/// Marj's mark: an M written on the margin line of a page.
///
/// The left stem of the M stands on the thin margin rule, which runs the
/// whole height of the mark the way it runs down a sheet of ruled paper.
/// It is the launcher icon's drawing (scripts/make_marj_icon.py) without
/// its ink ground, so it can sit next to the name inside the app.
class MarjMark extends StatelessWidget {
  const new({super.key, this.size = 24, this.color, this.marginColor});

  /// The colour of the margin line on real ruled paper.
  static const marginRed = Color(0xFFFF8A73);

  final double size;

  /// The colour of the M; the accent if none is given.
  final Color? color;

  /// The colour of the margin line; [marginRed] if none is given (a grey
  /// on an e-ink screen, where nothing of the app is coloured).
  final Color? marginColor;

  @override
  Widget build(BuildContext context) {
    final colors = ColorScheme.of(context);
    final eInk = EInkScope.maybeOf(context) != null;
    return CustomPaint(
      size: Size.square(size),
      painter: MarjMarkPainter(
        color: color ?? colors.primary,
        marginColor: marginColor ?? (eInk ? colors.outline : marginRed),
      ),
    );
  }
}

class MarjMarkPainter extends CustomPainter {
  const new({required this.color, required this.marginColor});

  final Color color;
  final Color marginColor;

  // The launcher icon's numbers, on its 108-unit canvas: the part of it
  // that is shown here is the square of [_side] units around the M.
  static const _side = 44.0;
  static const _left = 32.0, _top = 32.5;
  static const _stemLeft = 38.0, _stemRight = 70.0;
  static const _mTop = 40.0, _mBottom = 69.0, _dip = 60.0;
  static const _mWidth = 6.2, _marginWidth = 2.4;

  /// The M's corners in a square of [size]: bottom left, top left, the
  /// dip, top right, bottom right.
  static List<Offset> pointsIn(double size) {
    final scale = size / _side;
    Offset at(double x, double y) =>
        Offset((x - _left) * scale, (y - _top) * scale);
    return [
      at(_stemLeft, _mBottom),
      at(_stemLeft, _mTop),
      at((_stemLeft + _stemRight) / 2, _dip),
      at(_stemRight, _mTop),
      at(_stemRight, _mBottom),
    ];
  }

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final scale = side / _side;
    final points = pointsIn(side);

    canvas.drawLine(
      Offset(points.first.dx, 0),
      Offset(points.first.dx, side),
      Paint()
        ..color = marginColor
        ..strokeWidth = _marginWidth * scale,
    );

    final m = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      m.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(
      m,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = _mWidth * scale
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(MarjMarkPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.marginColor != marginColor;
}
