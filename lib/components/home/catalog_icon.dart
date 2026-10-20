import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Renders the original recovered paths/bitmaps without redrawing their shape.
class CatalogIcon extends StatelessWidget {
  const CatalogIcon(
    this.asset, {
    super.key,
    this.size = 24,
    this.color,
    this.preserveColors = false,
  });

  final String asset;
  final double size;
  final Color? color;
  final bool preserveColors;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? IconTheme.of(context).color ?? Colors.black;
    final path = 'assets/goodnotes/icons/$asset';
    return SizedBox.square(
      dimension: size,
      child: asset.endsWith('.png')
          ? Image.asset(
              path,
              fit: BoxFit.contain,
              color: preserveColors ? null : tint,
            )
          : SvgPicture.asset(
              path,
              fit: BoxFit.contain,
              colorFilter: preserveColors
                  ? null
                  : ColorFilter.mode(tint, BlendMode.srcIn),
            ),
    );
  }
}
