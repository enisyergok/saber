import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:saber/components/theming/adaptive_icon.dart';
import 'package:saber/components/toolbar/color_bar.dart';
import 'package:saber/data/defter_strings.dart';
import 'package:saber/i18n/strings.g.dart';

class SelectionBar extends StatelessWidget {
  final VoidCallback duplicateSelection;
  final VoidCallback deleteSelection;

  /// Reads the selected handwriting as text. Null hides the button.
  final VoidCallback? recognizeSelection;

  /// Applies a new colour to the selected strokes. Null hides the button.
  final ValueChanged<Color>? setColor;

  /// The dominant colour of the current selection.
  final Color? currentColor;

  /// Whether the colour swatches should be inverted for the current theme.
  final bool invertColors;

  const new({
    super.key,
    required this.duplicateSelection,
    required this.deleteSelection,
    this.recognizeSelection,
    this.setColor,
    this.currentColor,
    this.invertColors = false,
  });

  Future<void> _openColorBar(BuildContext context) async {
    final setColor = this.setColor;
    if (setColor == null) return;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: ColorBar(
            axis: Axis.horizontal,
            currentColor: currentColor,
            invert: invertColors,
            setColor: (color) {
              setColor(color);
              Navigator.of(sheetContext).pop();
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: .center,
      children: [
        if (recognizeSelection != null)
          IconButton(
            onPressed: recognizeSelection,
            style: TextButton.styleFrom(
              foregroundColor: ColorScheme.of(context).secondary,
              backgroundColor: Colors.transparent,
              shape: const CircleBorder(),
            ),
            tooltip: DefterStrings.recognize,
            icon: const Icon(Symbols.text_fields_rounded),
          ),
        if (setColor != null)
          IconButton(
            onPressed: () => _openColorBar(context),
            style: TextButton.styleFrom(
              foregroundColor: ColorScheme.of(context).secondary,
              backgroundColor: Colors.transparent,
              shape: const CircleBorder(),
            ),
            tooltip: DefterStrings.colorAndStyle,
            icon: const Icon(Symbols.palette_rounded),
          ),
        IconButton(
          onPressed: duplicateSelection,
          style: TextButton.styleFrom(
            foregroundColor: ColorScheme.of(context).secondary,
            backgroundColor: Colors.transparent,
            shape: const CircleBorder(),
          ),
          tooltip: t.editor.selectionBar.duplicate,
          icon: const AdaptiveIcon(
            icon: Symbols.content_copy_rounded,
            cupertinoIcon: CupertinoIcons.doc_on_clipboard,
          ),
        ),
        IconButton(
          onPressed: deleteSelection,
          style: TextButton.styleFrom(
            foregroundColor: ColorScheme.of(context).secondary,
            backgroundColor: Colors.transparent,
            shape: const CircleBorder(),
          ),
          tooltip: t.editor.selectionBar.delete,
          icon: const AdaptiveIcon(
            icon: Symbols.delete_rounded,
            cupertinoIcon: CupertinoIcons.delete,
          ),
        ),
      ],
    );
  }
}
