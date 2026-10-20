import 'package:flutter/material.dart';

import '../../data/notebooks/recovered_template.dart';
import 'packaged_template_painter.dart';

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
