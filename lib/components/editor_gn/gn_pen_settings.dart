import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:perfect_freehand/perfect_freehand.dart';
import 'package:saber/components/theming/uni_icon.dart';
import 'package:saber/data/defter_strings.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/tools/_tool.dart';
import 'package:saber/data/tools/pen.dart';
import 'package:saber/data/tools/pen_feel.dart';
import 'package:saber/data/tools/shape_pen.dart';
import 'package:saber/data/tools/stylus_action.dart';
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
  void _save() {
    // Pen options are changed in place, so listeners are told by hand.
    stows.lastFountainPenOptions.notifyListeners();
    stows.lastBallpointPenOptions.notifyListeners();
    stows.lastBrushPenOptions.notifyListeners();
    stows.lastHighlighterOptions.notifyListeners();
    stows.lastPencilOptions.notifyListeners();
  }

  Future<void> _showGestures() => showDialog<void>(
    context: context,
    builder: (context) => const _PenGesturesDialog(),
  );

  @override
  Widget build(BuildContext context) {
    final tool = widget.getTool();
    if (tool is! Pen) return const SizedBox.shrink();
    final colors = ColorScheme.of(context);
    final options = tool.options;
    final kind = tool.kind;
    final isShapePen = tool is ShapePen;
    final sectionStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: colors.onSurfaceVariant,
      letterSpacing: 0.5,
    );

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
                options: tool.strokeOptions,
                color: tool.color,
                pressure: tool.pressureEnabled,
              ),
            ),
          ),
          if (kind != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                _typeButton(
                  context,
                  icon: Pen.fountainPenIcon,
                  label: t.editor.pens.fountainPen,
                  selected: kind == PenKind.fountain,
                  onTap: () => setState(() => widget.setTool(Pen.fountainPen())),
                ),
                _typeButton(
                  context,
                  icon: Pen.ballpointPenIcon,
                  label: t.editor.pens.ballpointPen,
                  selected: kind == PenKind.ballpoint,
                  onTap: () =>
                      setState(() => widget.setTool(Pen.ballpointPen())),
                ),
                _typeButton(
                  context,
                  icon: Pen.brushPenIcon,
                  label: DefterStrings.brushPen,
                  selected: kind == PenKind.brush,
                  onTap: () => setState(() => widget.setTool(Pen.brushPen())),
                ),
              ],
            ),
          ],
          const Divider(height: 20),
          if (kind == PenKind.fountain || kind == PenKind.brush)
            _slider(
              context,
              label: DefterStrings.tipSharpness,
              valueText: '${(tool.tipSharpness * 100).round()}%',
              value: tool.tipSharpness.clamp(0, 1),
              min: 0,
              max: 1,
              divisions: 4,
              onChanged: (v) => setState(() => tool.tipSharpness = v),
            ),
          if (tool.pressureEnabled && !isShapePen)
            _slider(
              context,
              label: DefterStrings.pressureSensitivity,
              valueText: '${(options.thinning * 100).round()}%',
              value: options.thinning.clamp(0, 1),
              min: 0,
              max: 1,
              divisions: 4,
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
          const Divider(height: 20),
          Text(
            DefterStrings.penSettingsSection.toUpperCase(),
            style: sectionStyle,
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
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(DefterStrings.penGestures),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: _showGestures,
          ),
        ],
      ),
    );
  }

  Widget _typeButton(
    BuildContext context, {
    required Object icon,
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  UniIcon(
                    icon,
                    size: 18,
                    color: selected ? colors.secondary : colors.onSurface,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w600 : null,
                      color: selected ? colors.secondary : colors.onSurface,
                    ),
                  ),
                ],
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

/// What the pen's double tap (or side button) does.
class _PenGesturesDialog extends StatelessWidget {
  const _PenGesturesDialog();

  @override
  Widget build(BuildContext context) {
    final names = {
      StylusAction.none: DefterStrings.stylusNone,
      StylusAction.toggleEraser: DefterStrings.stylusToggleEraser,
      StylusAction.previousTool: DefterStrings.stylusPreviousTool,
      StylusAction.lasso: DefterStrings.stylusLasso,
      StylusAction.highlighter: DefterStrings.stylusHighlighter,
      StylusAction.undo: DefterStrings.stylusUndo,
      StylusAction.redo: DefterStrings.stylusRedo,
    };
    return ValueListenableBuilder<int>(
      valueListenable: stows.stylusAction,
      builder: (context, current, _) => SimpleDialog(
        title: Text(DefterStrings.stylusAction),
        children: [
          for (final action in StylusAction.values)
            ListTile(
              title: Text(names[action]!),
              trailing: action.index == current
                  ? Icon(Icons.check, color: ColorScheme.of(context).primary)
                  : null,
              onTap: () => stows.stylusAction.value = action.index,
            ),
        ],
      ),
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
