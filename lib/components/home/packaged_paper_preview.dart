import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:saber/components/home/packaged_template_painter.dart';
import 'package:saber/data/notebooks/recovered_template.dart';

/// Renders the same materialized SVG geometry that is embedded in the note.
class PackagedPaperPreview extends StatelessWidget {
  const PackagedPaperPreview({
    super.key,
    required this.asset,
    required this.pageSize,
    required this.fallback,
    this.paperColor,
  });
  final String asset;
  final Size pageSize;
  final Color? paperColor;
  final Widget fallback;
  static const assets = RecoveredTemplates.paperAssets;

  @override
  Widget build(BuildContext context) {
    if (asset.startsWith('assets/goodnotes/catalog/')) {
      return SvgPicture.asset(
        asset,
        width: pageSize.width,
        height: pageSize.height,
        fit: BoxFit.fill,
        placeholderBuilder: (_) => fallback,
      );
    }
    if (!RecoveredTemplates.contains(asset)) return fallback;
    return SizedBox.fromSize(
      size: pageSize,
      child: CustomPaint(
        painter: PackagedTemplatePainter(
          asset,
          pageSize,
          paperColor: paperColor,
        ),
      ),
    );
  }
}
