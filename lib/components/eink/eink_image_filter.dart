import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:saber/components/eink/eink_scope.dart';
import 'package:saber/data/eink/eink_style.dart';
import 'package:saber/data/eink/eink_texture.dart';

/// Shows continuous-tone content (photos, PDF pages, thumbnails) in the
/// e-ink range while e-ink mode is on: black becomes the ink colour, white
/// the paper colour, with a little extra contrast and the paper grain over
/// it. Outside e-ink mode it is just [child].
///
/// The conversion is a colour matrix applied while drawing: it costs no extra
/// memory (the picture is never copied or converted) and works on every
/// Android version, with no shader needed. Pen strokes and text are never
/// drawn through this; they have their own colour mapping.
class EInkImageFilter extends StatelessWidget {
  const EInkImageFilter({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final style = EInkScope.maybeOf(context);
    if (style == null) return child;
    final grain = style.textureStep > 0
        ? EInkTexture.readyImage(style.textureStep)
        : null;
    return ColorFiltered(
      colorFilter: ColorFilter.matrix(style.imageMatrix),
      child: grain == null
          ? child
          : CustomPaint(foregroundPainter: _GrainPainter(grain), child: child),
    );
  }
}

class _GrainPainter extends CustomPainter {
  const _GrainPainter(this.grain);

  final ui.Image grain;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ImageShader(
          grain,
          TileMode.repeated,
          TileMode.repeated,
          Matrix4.identity().storage,
          filterQuality: FilterQuality.low,
        ),
    );
  }

  @override
  bool shouldRepaint(_GrainPainter old) => old.grain != grain;
}
