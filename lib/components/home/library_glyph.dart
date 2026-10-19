import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Library-specific outlines on a 24-unit grid. These are drawn as vectors so
/// Android's Material font does not change their shape or stroke weight.
class LibraryGlyph extends StatelessWidget {
  const LibraryGlyph(this.icon, {super.key, this.size = 23, this.color});
  final IconData icon;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(
      painter: _GlyphPainter(
        icon,
        color ?? IconTheme.of(context).color ?? Colors.black,
      ),
    ),
  );
}

class _GlyphPainter extends CustomPainter {
  const _GlyphPainter(this.icon, this.color);
  final IconData icon;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final pen = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.45
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    void line(double x, double y, double x2, double y2) =>
        canvas.drawLine(Offset(x, y), Offset(x2, y2), pen);
    void path(Path p) => canvas.drawPath(p, pen);
    void fill(Path p, Color c) => canvas.drawPath(p, Paint()..color = c);
    Path star(double cx, double cy, double radius) {
      final p = Path();
      for (var i = 0; i < 10; i++) {
        final angle = -math.pi / 2 + i * math.pi / 5;
        final r = i.isEven ? radius : radius * .46;
        final x = cx + math.cos(angle) * r, y = cy + math.sin(angle) * r;
        if (i == 0) {
          p.moveTo(x, y);
        } else {
          p.lineTo(x, y);
        }
      }
      return p..close();
    }

    if (icon == Icons.space_dashboard_outlined) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(1.5, 3.5, 21, 17),
          const Radius.circular(1.5),
        ),
        pen,
      );
      line(9, 4, 9, 20);
      for (final y in [7.0, 10.0, 13.0]) line(4, y, 6.5, y);
    } else if (icon == Icons.folder_outlined || icon == Icons.folder) {
      final back = Path()
        ..moveTo(2, 8)
        ..lineTo(2, 5)
        ..quadraticBezierTo(2, 3.5, 3.5, 3.5)
        ..lineTo(8, 3.5)
        ..lineTo(10.8, 6)
        ..lineTo(20.5, 6)
        ..quadraticBezierTo(22, 6, 22, 8)
        ..lineTo(22, 18)
        ..quadraticBezierTo(22, 20, 20, 20)
        ..lineTo(4, 20)
        ..quadraticBezierTo(2, 20, 2, 18)
        ..close();
      final front = Path()
        ..moveTo(2, 8)
        ..quadraticBezierTo(2, 7.2, 3.5, 7.2)
        ..lineTo(20.5, 7.2)
        ..quadraticBezierTo(22, 7.2, 22, 9)
        ..lineTo(22, 19)
        ..quadraticBezierTo(22, 20.5, 20, 20.5)
        ..lineTo(4, 20.5)
        ..quadraticBezierTo(2, 20.5, 2, 19)
        ..close();
      if (icon == Icons.folder) {
        fill(back, const Color(0xffdf9852));
        fill(front, const Color(0xfff4bf7c));
        line(3, 20.5, 21, 20.5);
      } else {
        fill(back, const Color(0xff9cdce9));
        path(back);
        fill(front, const Color(0xff80d2e3));
        path(front);
      }
    } else if (icon == Icons.bookmark_border) {
      path(
        Path()
          ..moveTo(6, 21)
          ..lineTo(6, 4)
          ..quadraticBezierTo(6, 2.5, 7.5, 2.5)
          ..lineTo(16.5, 2.5)
          ..quadraticBezierTo(18, 2.5, 18, 4)
          ..lineTo(18, 21)
          ..lineTo(12, 17)
          ..close(),
      );
      fill(star(12, 8.5, 3.7), color);
    } else if (icon == Icons.search) {
      canvas.drawCircle(const Offset(10, 10), 7, pen);
      line(15.2, 15.2, 21, 21);
    } else if (icon == Icons.people_outline) {
      path(
        Path()
          ..moveTo(9, 4)
          ..cubicTo(4, 4, 4, 12, 9, 12)
          ..cubicTo(14, 12, 14, 4, 9, 4),
      );
      path(
        Path()
          ..moveTo(15, 4)
          ..cubicTo(20, 4, 20, 11, 16, 12),
      );
      path(
        Path()
          ..moveTo(1.5, 21)
          ..cubicTo(2, 14, 15, 13, 17, 21),
      );
      path(
        Path()
          ..moveTo(16, 15)
          ..quadraticBezierTo(21, 16, 22, 20),
      );
    } else if (icon == Icons.storefront_outlined) {
      path(
        Path()
          ..moveTo(3, 9)
          ..lineTo(3, 20)
          ..quadraticBezierTo(3, 21, 4, 21)
          ..lineTo(20, 21)
          ..lineTo(20, 9),
      );
      path(
        Path()
          ..moveTo(2, 9)
          ..lineTo(4, 3)
          ..lineTo(19, 3)
          ..lineTo(22, 9)
          ..quadraticBezierTo(19, 13, 16, 9)
          ..quadraticBezierTo(12, 13, 8, 9)
          ..quadraticBezierTo(5, 13, 2, 9),
      );
      path(
        Path()
          ..moveTo(9, 21)
          ..lineTo(9, 14)
          ..lineTo(15, 14)
          ..lineTo(15, 21),
      );
    } else if (icon == Icons.notifications_none) {
      path(
        Path()
          ..moveTo(4, 18)
          ..quadraticBezierTo(7, 14, 7, 8)
          ..cubicTo(7, 1, 17, 1, 17, 8)
          ..quadraticBezierTo(17, 14, 20, 18)
          ..quadraticBezierTo(12, 20, 4, 18),
      );
      path(
        Path()
          ..moveTo(10, 22)
          ..quadraticBezierTo(12, 23, 14, 22),
      );
    } else if (icon == Icons.settings_outlined) {
      final gear = Path();
      for (var i = 0; i < 64; i++) {
        final r = [8.0, 8.0, 10.0, 10.0, 10.0, 10.0, 8.0, 8.0][i % 8];
        final a = i * math.pi / 32;
        final x = 12 + math.cos(a) * r, y = 12 + math.sin(a) * r;
        if (i == 0) {
          gear.moveTo(x, y);
        } else {
          gear.lineTo(x, y);
        }
      }
      path(gear..close());
      canvas.drawCircle(const Offset(12, 12), 3.4, pen);
    } else if (icon == Icons.check_circle ||
        icon == Icons.check_circle_outline) {
      if (icon == Icons.check_circle)
        canvas.drawCircle(
          const Offset(12, 12),
          9.2,
          Paint()..color = color.withValues(alpha: .15),
        );
      canvas.drawCircle(const Offset(12, 12), 9.2, pen);
      path(
        Path()
          ..moveTo(7, 12)
          ..lineTo(10.5, 15.5)
          ..lineTo(17, 8.5),
      );
    } else if (icon == Icons.format_list_bulleted) {
      for (final y in [6.0, 12.0, 18.0]) {
        canvas.drawCircle(Offset(3, y), 1.3, Paint()..color = color);
        line(8, y, 22, y);
      }
    } else if (icon == Icons.grid_view) {
      for (final x in [3.0, 14.0]) {
        for (final y in [3.0, 14.0]) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(x, y, 7, 7),
              const Radius.circular(1),
            ),
            pen,
          );
        }
      }
    } else if (icon == Icons.star || icon == Icons.star_border) {
      final p = star(12, 12, 10);
      if (icon == Icons.star)
        fill(p, color);
      else
        path(p);
    } else if (icon == Icons.keyboard_arrow_down) {
      path(
        Path()
          ..moveTo(4, 8)
          ..lineTo(12, 16)
          ..lineTo(20, 8),
      );
    } else if (icon == Icons.chevron_right) {
      path(
        Path()
          ..moveTo(9, 6)
          ..lineTo(15, 12)
          ..lineTo(9, 18),
      );
    } else if (icon == Icons.add) {
      pen.strokeWidth = 2.5;
      line(5, 12, 19, 12);
      line(12, 5, 12, 19);
    } else if (icon == Icons.file_download_outlined) {
      path(
        Path()
          ..moveTo(4, 16)
          ..lineTo(4, 21)
          ..lineTo(20, 21)
          ..lineTo(20, 16),
      );
      line(12, 3, 12, 15);
      path(
        Path()
          ..moveTo(7, 10)
          ..lineTo(12, 15)
          ..lineTo(17, 10),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GlyphPainter oldDelegate) =>
      oldDelegate.icon != icon || oldDelegate.color != color;
}
