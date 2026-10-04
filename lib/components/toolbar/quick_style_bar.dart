import 'package:flutter/material.dart';
import 'package:saber/data/defter_strings.dart';
import 'package:saber/data/extensions/color_extensions.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/tools/eraser.dart';
import 'package:saber/data/tools/highlighter.dart';
import 'package:saber/data/tools/pen.dart';
import 'package:saber/data/tools/pencil.dart';

/// One-tap color and thickness presets shown next to the tools,
/// so the common choices don't need the full color bar or size slider.
class QuickStyleBar extends StatelessWidget {
  const QuickStyleBar({
    super.key,
    required this.pen,
    required this.currentColor,
    required this.invert,
    required this.setColor,
    required this.onSizeChanged,
  });

  final Pen pen;
  final Color? currentColor;
  final bool invert;
  final ValueChanged<Color> setColor;

  /// Called after a size preset has been applied to [pen].
  final VoidCallback onSizeChanged;

  static const _penColors = <Color>[
    Colors.black,
    Colors.blue,
    Colors.red,
    Colors.green,
  ];
  static const _highlighterColors = <Color>[
    Colors.yellow,
    Colors.green,
    Colors.pink,
    Colors.cyan,
  ];

  /// The three thickness presets for [pen], thinnest first.
  static List<double> sizesFor(Pen pen) {
    if (pen is Highlighter) return const [20, 50, 80];
    if (pen is Pencil) return const [2, 5, 9];
    return const [2, 5, 10];
  }

  /// The diameters used to draw the three thickness presets.
  static const _sizeDotDiameters = <double>[5, 9, 13];

  /// The opacities a pen cycles through, most opaque first.
  static const opacities = <double>[1, 0.6, 0.3];

  /// The opacity after [current]: the next preset, wrapping round.
  static double nextOpacity(double current) {
    for (var i = 0; i < opacities.length; i++) {
      if ((current - opacities[i]).abs() < 0.08) {
        return opacities[(i + 1) % opacities.length];
      }
    }
    return opacities.first;
  }

  /// Whether [pen] draws with a color that can be see-through.
  static bool supportsOpacity(Pen pen) => pen is! Highlighter && pen is! Pencil;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    final colors = pen is Highlighter ? _highlighterColors : _penColors;
    final sizes = sizesFor(pen);
    final currentArgb = currentColor?.withAlpha(255).toARGB32();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 1,
          height: 24,
          margin: const EdgeInsets.symmetric(horizontal: 10),
          color: colorScheme.outlineVariant,
        ),
        for (final color in colors)
          _ColorDot(
            color: color.withInversion(invert),
            selected: currentArgb == color.withAlpha(255).toARGB32(),
            onTap: () {
              // Keep a see-through setting when picking another color.
              final alpha = currentColor?.a ?? 1;
              setColor(
                pen is Highlighter || alpha >= 1
                    ? color
                    : color.withValues(alpha: alpha),
              );
            },
          ),
        if (supportsOpacity(pen) && currentColor != null)
          IconButton(
            tooltip:
                '${DefterStrings.opacity}: ${(currentColor!.a * 100).round()}%',
            visualDensity: VisualDensity.compact,
            icon: Icon(
              Icons.opacity,
              size: 20,
              color: colorScheme.onSurface.withValues(
                alpha: 0.35 + 0.65 * currentColor!.a,
              ),
            ),
            onPressed: () => setColor(
              currentColor!.withValues(alpha: nextOpacity(currentColor!.a)),
            ),
          ),
        const SizedBox(width: 10),
        for (var i = 0; i < sizes.length; i++)
          _SizeDot(
            diameter: _sizeDotDiameters[i],
            selected: pen.options.size == sizes[i],
            tooltip: '${DefterStrings.thickness}: ${sizes[i].round()}',
            onTap: () {
              pen.options.size = sizes[i];
              onSizeChanged();
            },
          ),
      ],
    );
  }
}

/// Three eraser sizes, shown next to the tools while the eraser is selected.
class EraserSizeBar extends StatelessWidget {
  const EraserSizeBar({
    super.key,
    required this.eraser,
    required this.onSizeChanged,
  });

  final Eraser eraser;
  final VoidCallback onSizeChanged;

  /// The diameters used to draw the three size presets.
  static const _sizeDotDiameters = <double>[7, 12, 18];

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 1,
          height: 24,
          margin: const EdgeInsets.symmetric(horizontal: 10),
          color: colorScheme.outlineVariant,
        ),
        for (var i = 0; i < Eraser.sizePresets.length; i++)
          _SizeDot(
            diameter: _sizeDotDiameters[i],
            selected: eraser.size == Eraser.sizePresets[i],
            tooltip:
                '${DefterStrings.eraserSize}: ${Eraser.sizePresets[i].round()}',
            onTap: () {
              eraser.size = Eraser.sizePresets[i];
              stows.eraserSize.value = eraser.size;
              onSizeChanged();
            },
          ),
      ],
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: InkResponse(
        onTap: onTap,
        radius: 20,
        child: Container(
          width: 28,
          height: 28,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? colorScheme.primary : Colors.transparent,
              width: 2,
            ),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              border: Border.all(
                color: colorScheme.onSurface.withValues(alpha: 0.2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SizeDot extends StatelessWidget {
  const _SizeDot({
    required this.diameter,
    required this.selected,
    required this.tooltip,
    required this.onTap,
  });

  final double diameter;
  final bool selected;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    return Tooltip(
      message: tooltip,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: InkResponse(
          onTap: onTap,
          radius: 20,
          child: Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected
                  ? colorScheme.primary.withValues(alpha: 0.16)
                  : Colors.transparent,
            ),
            child: Container(
              width: diameter,
              height: diameter,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? colorScheme.primary : colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
