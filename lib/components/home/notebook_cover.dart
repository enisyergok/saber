import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Width divided by height of a notebook cover in the library grid.
const kNotebookCoverAspectRatio = 0.74;

/// The vertical space below a cover reserved for its title and date.
const kNotebookCaptionHeight = 64.0;

/// A bound notebook: nearly square on the spine side, rounded on the open side.
const kNotebookCoverRadius = BorderRadiusDirectional.horizontal(
  start: Radius.circular(4),
  end: Radius.circular(10),
);

/// The soft shadow under a notebook cover.
List<BoxShadow> notebookCoverShadow(Brightness brightness) => [
  BoxShadow(
    color: Colors.black.withValues(alpha: brightness == .dark ? 0.5 : 0.16),
    blurRadius: 10,
    offset: const Offset(0, 4),
  ),
];

/// The darker strip along the bound edge of a notebook cover.
///
/// Must be placed in a [Stack].
class NotebookSpine extends StatelessWidget {
  const NotebookSpine({super.key});

  @override
  Widget build(BuildContext context) {
    return PositionedDirectional(
      start: 0,
      top: 0,
      bottom: 0,
      width: 14,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: AlignmentDirectional.centerStart,
              end: AlignmentDirectional.centerEnd,
              colors: [
                Colors.black.withValues(alpha: 0.16),
                Colors.black.withValues(alpha: 0.05),
                Colors.black.withValues(alpha: 0.10),
                Colors.black.withValues(alpha: 0),
              ],
              stops: const [0, 0.55, 0.7, 1],
            ),
          ),
        ),
      ),
    );
  }
}

/// The title (and optional subtitle) shown under a cover in the library grid.
class NotebookCaption extends StatelessWidget {
  const NotebookCaption({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final textTheme = TextTheme.of(context);
    final colorScheme = ColorScheme.of(context);
    // Never scrolls; this only stops large text scales from overflowing.
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 8, left: 2, right: 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The dashed "new" tile that leads the library grid.
class NewNotebookTile extends StatelessWidget {
  const NewNotebookTile({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    final radius = kNotebookCoverRadius.resolve(Directionality.of(context));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: kNotebookCoverAspectRatio,
          child: Material(
            color: colorScheme.primary.withValues(alpha: 0.06),
            borderRadius: radius,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: CustomPaint(
                painter: _DashedBorderPainter(
                  color: colorScheme.primary.withValues(alpha: 0.7),
                  radius: radius,
                ),
                child: Center(
                  child: Icon(Icons.add, size: 44, color: colorScheme.primary),
                ),
              ),
            ),
          ),
        ),
        Expanded(child: NotebookCaption(title: label)),
      ],
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final BorderRadius radius;

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 1.5;
    const dash = 7.0;
    const gap = 5.0;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final path = Path()
      ..addRRect(radius.toRRect(Offset.zero & size).deflate(strokeWidth / 2));

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = math.min(distance + dash, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}
