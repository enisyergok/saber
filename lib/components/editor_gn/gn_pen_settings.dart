import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:perfect_freehand/perfect_freehand.dart';
import 'package:saber/data/defter_strings.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/tools/_tool.dart';
import 'package:saber/data/tools/highlighter.dart';
import 'package:saber/data/tools/pen.dart';
import 'package:saber/data/tools/pencil.dart';
import 'package:saber/data/tools/shape_pen.dart';
import 'package:saber/i18n/strings.g.dart';

/// The pen settings popover: a live preview of the line, the pen type and
/// sliders for how the line behaves. Every slider changes the pen's real
/// stroke options (the preview is drawn with the same code as the page).
class GnPenSettings extends StatefulWidget {
  const GnPenSettings({
    super.key,
    required this.getTool,
    required this.setTool,
  });

  final Tool Function() getTool;
  final void Function(Pen) setTool;

  static const width = 340.0;

  @override
  State<GnPenSettings> createState() => _GnPenSettingsState();
}

class _GnPenSettingsState extends State<GnPenSettings> {
  /// Tip sharpness is stored as the taper of both line ends. 0 is a blunt
  /// end; the taper length is a multiple of the pen size.
  static double sharpnessOf(StrokeOptions o) =>
      o.end.taperEnabled ? 1 : 0;

  void _save() {
    // Pen options are changed in place, so listeners are told by hand.
    stows.lastFountainPenOptions.notifyListeners();
    stows.lastBallpointPenOptions.notifyListeners();
    stows.lastHighlighterOptions.notifyListeners();
    stows.lastPencilOptions.notifyListeners();
  }

  @override
  Widget build(BuildContext context) {
    final tool = widget.getTool();
    if (tool is! Pen) return const SizedBox.shrink();
    final colors = ColorScheme.of(context);
    final options = tool.options;
    final canChangeType = tool is! Highlighter && tool is! Pencil;
    final isShapePen = tool is ShapePen;

    return SizedBox(
      width: GnPenSettings.width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tool.name, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          SizedBox(
            height: 96,
            width: double.infinity,
            child: CustomPaint(
              painter: PenPreviewPainter(
                options: options,
                color: tool.color,
                pressure: tool.pressureEnabled,
              ),
            ),
          ),
          if (canChangeType) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                _typeButton(
                  context,
                  label: t.editor.pens.fountainPen,
                  selected: tool.icon == Pen.fountainPenIcon,
                  onTap: () => setState(() => widget.setTool(Pen.fountainPen())),
                ),
                _typeButton(
                  context,
                  label: t.editor.pens.ballpointPen,
                  selected: tool.icon == Pen.ballpointPenIcon,
                  onTap: () =>
                      setState(() => widget.setTool(Pen.ballpointPen())),
                ),
                _typeButton(
                  context,
                  label: t.editor.pens.shapePen,
                  selected: isShapePen,
                  onTap: () => setState(() => widget.setTool(ShapePen())),
                ),
              ],
            ),
          ],
          const Divider(height: 20),
          _slider(
            context,
            label: t.editor.penOptions.size,
            valueText: options.size.round().toString(),
            value: options.size.clamp(tool.sizeMin, tool.sizeMax),
            min: tool.sizeMin,
            max: tool.sizeMax,
            divisions: tool.sizeStepsBetweenMinAndMax,
            onChanged: (v) => setState(() => options.size = v),
          ),
          if (!isShapePen && tool.toolId != .highlighter)
            _slider(
              context,
              label: DefterStrings.tipSharpness,
              valueText: '${(sharpnessOf(options) * 100).round()}%',
              value: sharpnessOf(options),
              min: 0,
              max: 1,
              divisions: 1,
              onChanged: (v) => setState(() {
                final on = v > 0.5;
                // The taper length follows the pen size, so a thick pen
                // gets a longer point.
                options.start.taperEnabled = false;
                options.end.taperEnabled = on;
                if (on) options.end.customTaper = options.size * 4;
              }),
            ),
          if (tool.pressureEnabled && !isShapePen)
            _slider(
              context,
              label: DefterStrings.pressureSensitivity,
              valueText: '${(options.thinning * 100).round()}%',
              value: options.thinning.clamp(0, 1),
              min: 0,
              max: 1,
              divisions: 20,
              onChanged: (v) => setState(() => options.thinning = v),
            ),
          if (!isShapePen)
            _slider(
              context,
              label: DefterStrings.lineStabilization,
              valueText: '${(options.streamline * 100).round()}%',
              value: options.streamline.clamp(0, 1),
              min: 0,
              max: 1,
              divisions: 20,
              onChanged: (v) => setState(() => options.streamline = v),
            ),
          const Divider(height: 20),
          Text(
            DefterStrings.penSettingsSection,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: stows.shapeHoldToSnap,
            builder: (context, on, _) => SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(DefterStrings.drawAndHold),
              value: on,
              onChanged: (v) => stows.shapeHoldToSnap.value = v,
            ),
          ),
        ],
      ),
    );
  }

  Widget _typeButton(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final colors = ColorScheme.of(context);
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Material(
          color: selected
              ? colors.secondary.withValues(alpha: 0.14)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Center(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w600 : null,
                    color: selected ? colors.secondary : colors.onSurface,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _slider(
    BuildContext context, {
    required String label,
    required String valueText,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: ColorScheme.of(context).onSurfaceVariant,
      letterSpacing: 0.5,
    );
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label.toUpperCase(), style: style),
            Text(valueText, style: style),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            overlayShape: SliderComponentShape.noOverlay,
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
            onChangeEnd: (_) => _save(),
          ),
        ),
      ],
    );
  }
}

/// A short wavy line drawn with the pen's own options, with a little
/// deterministic jitter so that line stabilization can be seen working.
class PenPreviewPainter extends CustomPainter {
  const PenPreviewPainter({
    required this.options,
    required this.color,
    required this.pressure,
  });

  final StrokeOptions options;
  final Color color;
  final bool pressure;

  /// The points of the sample line, in a 0..1 box.
  @visibleForTesting
  static List<PointVector> samplePoints(Size size, {required bool pressure}) {
    const n = 60;
    final points = <PointVector>[];
    for (var i = 0; i < n; i++) {
      final u = i / (n - 1);
      final x = size.width * (0.08 + 0.84 * u);
      final y =
          size.height * (0.5 + 0.28 * math.sin(u * math.pi * 1.6 - 0.9)) +
          math.sin(i * 2.7) * 1.2;
      final p = pressure ? 0.25 + 0.7 * math.sin(u * math.pi) : null;
      points.add(PointVector(x, y, p));
    }
    return points;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final polygon = getStroke(
      samplePoints(size, pressure: pressure),
      options: options.copyWith(
        isComplete: true,
        simulatePressure: false,
      ),
    );
    if (polygon.length < 3) return;
    final path = Path()..moveTo(polygon.first.dx, polygon.first.dy);
    for (final p in polygon.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(PenPreviewPainter old) => true;
}
