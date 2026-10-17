import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// A temporary, interactive page magnifier.
///
/// The source image is captured from the editor canvas when the tool is
/// selected. Keeping this as an overlay means it does not pollute the note
/// with bitmap data and can be dismissed without changing history.
class ZoomBoxOverlay extends StatefulWidget {
  const ZoomBoxOverlay({
    required this.image,
    required this.onClose,
    super.key,
  });

  final ui.Image image;
  final VoidCallback onClose;

  @override
  State<ZoomBoxOverlay> createState() => _ZoomBoxOverlayState();
}

class _ZoomBoxOverlayState extends State<ZoomBoxOverlay> {
  Offset? _center;

  static const _magnification = 2.0;
  static const _boxSize = Size(320, 210);

  void _move(DragUpdateDetails details, Size size) {
    final current = _center ?? size.center(Offset.zero);
    final half = Offset(_boxSize.width / 2, _boxSize.height / 2);
    final next = current + details.delta;
    setState(() {
      _center = Offset(
        next.dx.clamp(half.dx + 8, size.width - half.dx - 8),
        next.dy.clamp(half.dy + 8, size.height - half.dy - 8),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final center = _center ?? size.center(Offset.zero);
        final rect = Rect.fromCenter(center: center, size: _boxSize);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: (details) => _move(details, size),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _ZoomBoxPainter(
                    image: widget.image,
                    center: center,
                    boxSize: _boxSize,
                    magnification: _magnification,
                  ),
                ),
              ),
              Positioned(
                left: rect.right - 42,
                top: rect.top - 42,
                child: Material(
                  color: Theme.of(context).colorScheme.surface,
                  elevation: 4,
                  shape: const CircleBorder(),
                  child: IconButton(
                    tooltip: 'Close zoom box',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: widget.onClose,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ZoomBoxPainter extends CustomPainter {
  const _ZoomBoxPainter({
    required this.image,
    required this.center,
    required this.boxSize,
    required this.magnification,
  });

  final ui.Image image;
  final Offset center;
  final Size boxSize;
  final double magnification;

  @override
  void paint(Canvas canvas, Size size) {
    final box = Rect.fromCenter(center: center, size: boxSize);
    final sourceSize = Size(
      box.width / magnification,
      box.height / magnification,
    );
    final imageSize = Size(image.width.toDouble(), image.height.toDouble());
    final sourceCenter = Offset(
      center.dx.clamp(sourceSize.width / 2, imageSize.width - sourceSize.width / 2),
      center.dy.clamp(sourceSize.height / 2, imageSize.height - sourceSize.height / 2),
    );
    final source = Rect.fromCenter(center: sourceCenter, size: sourceSize);

    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.28)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawRRect(
      RRect.fromRectAndRadius(box.shift(const Offset(0, 6)), const Radius.circular(22)),
      shadow,
    );

    final clip = RRect.fromRectAndRadius(box, const Radius.circular(22));
    canvas.save();
    canvas.clipRRect(clip);
    canvas.drawImageRect(image, source, box, Paint());
    canvas.restore();

    final border = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRRect(clip, border);

    final label = TextPainter(
      text: const TextSpan(
        text: '2×',
        style: TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w700,
          shadows: [Shadow(blurRadius: 3, color: Colors.black)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(canvas, box.topLeft + const Offset(14, 12));
  }

  @override
  bool shouldRepaint(covariant _ZoomBoxPainter oldDelegate) =>
      oldDelegate.image != image ||
      oldDelegate.center != center ||
      oldDelegate.boxSize != boxSize ||
      oldDelegate.magnification != magnification;
}
