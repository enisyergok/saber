import 'package:flutter/material.dart';
import 'package:saber/components/eink/eink_scope.dart';

/// The same notebook/nib monogram used by the Android launcher.
class MarjMark extends StatelessWidget {
  const new({super.key, this.size = 24, this.color});
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final eInk = EInkScope.maybeOf(context) != null;
    final tint = color ?? (eInk ? ColorScheme.of(context).onSurface : null);
    return Image.asset(
      tint == null
          ? 'assets/icon/noteva-preview.png'
          : 'assets/icon/noteva-foreground-source.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      color: tint,
      colorBlendMode: BlendMode.srcIn,
      excludeFromSemantics: true,
    );
  }
}
