import 'package:flutter/material.dart';
import 'package:saber/components/eink/eink_scope.dart';

/// The colours of the editor's document chrome: quiet paper surfaces with a
/// clear accent for the active tool, or plain grey in e-ink mode.
class GnPalette {
  const GnPalette({
    required this.header,
    required this.onHeader,
    required this.activeTab,
    required this.selectedTool,
    required this.selectedToolForeground,
  });

  final Color header;
  final Color onHeader;

  /// The tab of the open notebook.
  final Color activeTab;

  /// Behind the selected tool button.
  final Color selectedTool;

  /// The ink used by the selected tool button.
  final Color selectedToolForeground;

  static GnPalette of(BuildContext context) {
    final colors = ColorScheme.of(context);
    if (EInkScope.maybeOf(context) != null) {
      return GnPalette(
        header: colors.surfaceContainerHigh,
        onHeader: colors.onSurface,
        activeTab: colors.surface,
        selectedTool: colors.onSurface.withValues(alpha: 0.14),
        selectedToolForeground: colors.onSurface,
      );
    }
    // Goodnotes keeps the document chrome quiet and lets the selected tool
    // carry the accent. Marj keeps its ink blue in the active state instead
    // of making the whole editor header a heavy colour block.
    final header = colors.brightness == Brightness.light
        ? colors.surfaceContainerLow
        : colors.surfaceContainerHigh;
    return GnPalette(
      header: header,
      onHeader: colors.onSurface,
      activeTab: colors.surface,
      selectedTool: colors.primaryContainer,
      selectedToolForeground: colors.onPrimaryContainer,
    );
  }
}
