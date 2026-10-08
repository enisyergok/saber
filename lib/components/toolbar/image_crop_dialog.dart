import 'dart:math';

import 'package:flutter/material.dart';
import 'package:saber/components/canvas/image/editor_image.dart';
import 'package:saber/data/defter_strings.dart';

/// Where the part of a picture that is shown lies, seen as the picture is
/// shown (turned) rather than as it is stored.
///
/// A crop is stored as fractions of the picture's own, unturned, width and
/// height; the person sees the picture turned and cuts it as they see it.
abstract final class CropGeometry {
  /// [crop] (unturned) as it lies in the picture turned [quarterTurns]
  /// quarter turns clockwise.
  static Rect toShown(Rect crop, int quarterTurns) => _map(crop, quarterTurns);

  /// The unturned crop for [shown], a crop of the picture as it is shown
  /// turned [quarterTurns] quarter turns clockwise.
  static Rect fromShown(Rect shown, int quarterTurns) =>
      _map(shown, (4 - quarterTurns % 4) % 4);

  static Rect _map(Rect r, int turns) {
    Offset turn(Offset p) => switch (turns % 4) {
      1 => Offset(1 - p.dy, p.dx),
      2 => Offset(1 - p.dx, 1 - p.dy),
      3 => Offset(p.dy, 1 - p.dx),
      _ => p,
    };
    return Rect.fromPoints(turn(r.topLeft), turn(r.bottomRight));
  }
}

/// Lets the person cut a picture down to a part of it, by dragging the
/// sides and corners of a frame over the picture.
class ImageCropDialog extends StatefulWidget {
  const ImageCropDialog({
    super.key,
    required this.image,
    required this.onApply,
  });

  final EditorImage image;

  /// Called with the part to keep (unturned fractions, see
  /// [EditorImage.crop]).
  final void Function(Rect crop) onApply;

  @override
  State<ImageCropDialog> createState() => _ImageCropDialogState();
}

enum _Grip { move, left, top, right, bottom, topLeft, topRight, bottomLeft, bottomRight }

class _ImageCropDialogState extends State<ImageCropDialog> {
  late Rect _shown = CropGeometry.toShown(
    widget.image.crop,
    widget.image.quarterTurns,
  );
  _Grip? _grip;

  static const _reach = 28.0;

  Size get _turnedNaturalSize {
    final natural = widget.image.naturalSize;
    final size = natural.isEmpty ? widget.image.dstRect.size : natural;
    return widget.image.quarterTurns.isOdd
        ? Size(size.height, size.width)
        : size;
  }

  _Grip? _gripAt(Offset p, Size box) {
    final r = Rect.fromLTRB(
      _shown.left * box.width,
      _shown.top * box.height,
      _shown.right * box.width,
      _shown.bottom * box.height,
    );
    final nearLeft = (p.dx - r.left).abs() <= _reach;
    final nearRight = (p.dx - r.right).abs() <= _reach;
    final nearTop = (p.dy - r.top).abs() <= _reach;
    final nearBottom = (p.dy - r.bottom).abs() <= _reach;
    final within = r.inflate(_reach).contains(p);
    if (!within) return null;
    if (nearLeft && nearTop) return _Grip.topLeft;
    if (nearRight && nearTop) return _Grip.topRight;
    if (nearLeft && nearBottom) return _Grip.bottomLeft;
    if (nearRight && nearBottom) return _Grip.bottomRight;
    if (nearLeft) return _Grip.left;
    if (nearRight) return _Grip.right;
    if (nearTop) return _Grip.top;
    if (nearBottom) return _Grip.bottom;
    return r.contains(p) ? _Grip.move : null;
  }

  void _drag(Offset delta, Size box) {
    final grip = _grip;
    if (grip == null) return;
    final dx = delta.dx / box.width;
    final dy = delta.dy / box.height;
    const least = EditorImage.minCrop;
    var l = _shown.left, t = _shown.top, r = _shown.right, b = _shown.bottom;
    switch (grip) {
      case _Grip.move:
        final w = r - l, h = b - t;
        l = (l + dx).clamp(0.0, 1 - w).toDouble();
        t = (t + dy).clamp(0.0, 1 - h).toDouble();
        r = l + w;
        b = t + h;
      default:
        if (const {_Grip.left, _Grip.topLeft, _Grip.bottomLeft}.contains(grip)) {
          l = (l + dx).clamp(0.0, r - least).toDouble();
        }
        if (const {_Grip.right, _Grip.topRight, _Grip.bottomRight}.contains(grip)) {
          r = (r + dx).clamp(l + least, 1.0).toDouble();
        }
        if (const {_Grip.top, _Grip.topLeft, _Grip.topRight}.contains(grip)) {
          t = (t + dy).clamp(0.0, b - least).toDouble();
        }
        if (const {_Grip.bottom, _Grip.bottomLeft, _Grip.bottomRight}.contains(grip)) {
          b = (b + dy).clamp(t + least, 1.0).toDouble();
        }
    }
    setState(() => _shown = Rect.fromLTRB(l, t, r, b));
  }

  @override
  Widget build(BuildContext context) {
    final colors = ColorScheme.of(context);
    final turned = _turnedNaturalSize;
    final aspect = turned.isEmpty ? 1.0 : turned.width / turned.height;
    final screen = MediaQuery.sizeOf(context);
    final maxWidth = min(screen.width * 0.8, 560.0);
    final maxHeight = screen.height * 0.5;
    final width = min(maxWidth, maxHeight * aspect);
    final box = Size(width, width / aspect);

    return AlertDialog(
      title: Text(DefterStrings.imageCrop),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.fromSize(
              size: box,
              child: GestureDetector(
                key: const Key('imageCropArea'),
                behavior: HitTestBehavior.opaque,
                onPanStart: (d) => _grip = _gripAt(d.localPosition, box),
                onPanUpdate: (d) => _drag(d.delta, box),
                onPanEnd: (_) => _grip = null,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    RotatedBox(
                      quarterTurns: widget.image.quarterTurns,
                      child: widget.image.buildImageWidget(
                        context: context,
                        overrideBoxFit: BoxFit.fill,
                        isBackground: false,
                        invert: false,
                      ),
                    ),
                    CustomPaint(
                      painter: _FramePainter(
                        shown: _shown,
                        dim: Colors.black.withValues(alpha: 0.55),
                        line: colors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              DefterStrings.imageCropHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('imageCropReset'),
          onPressed: () => setState(() => _shown = EditorImage.wholePicture),
          child: Text(DefterStrings.pdfCropReset),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          key: const Key('imageCropApply'),
          onPressed: () {
            widget.onApply(
              CropGeometry.fromShown(_shown, widget.image.quarterTurns),
            );
            Navigator.of(context).pop();
          },
          child: Text(DefterStrings.pdfCropApply),
        ),
      ],
    );
  }
}

class _FramePainter extends CustomPainter {
  _FramePainter({required this.shown, required this.dim, required this.line});

  final Rect shown;
  final Color dim;
  final Color line;

  @override
  void paint(Canvas canvas, Size size) {
    final frame = Rect.fromLTRB(
      shown.left * size.width,
      shown.top * size.height,
      shown.right * size.width,
      shown.bottom * size.height,
    );
    final outside = Path()
      ..addRect(Offset.zero & size)
      ..addRect(frame)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(outside, Paint()..color = dim);

    final stroke = Paint()
      ..color = line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(frame, stroke);
    final thin = Paint()
      ..color = line.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    for (var i = 1; i < 3; i++) {
      final x = frame.left + frame.width * i / 3;
      final y = frame.top + frame.height * i / 3;
      canvas.drawLine(Offset(x, frame.top), Offset(x, frame.bottom), thin);
      canvas.drawLine(Offset(frame.left, y), Offset(frame.right, y), thin);
    }
    final fill = Paint()..color = line;
    for (final corner in [
      frame.topLeft,
      frame.topRight,
      frame.bottomLeft,
      frame.bottomRight,
      frame.centerLeft,
      frame.centerRight,
      frame.topCenter,
      frame.bottomCenter,
    ]) {
      canvas.drawCircle(corner, 6, fill);
    }
  }

  @override
  bool shouldRepaint(_FramePainter old) =>
      shown != old.shown || dim != old.dim || line != old.line;
}
