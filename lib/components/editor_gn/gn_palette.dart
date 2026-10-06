import 'package:flutter/material.dart';
import 'package:saber/components/eink/eink_scope.dart';
import 'package:saber/components/theming/defter_design.dart';

/// The colours of the editor's top bar: dark blue like the notebook apps it
/// follows, or plain grey in e-ink mode.
class GnPalette {
  const GnPalette({
    required this.header,
    required this.onHeader,
    required this.activeTab,
    required this.selectedTool,
  });

  final Color header;
  final Color onHeader;

  /// The tab of the open notebook.
  final Color activeTab;

  /// Behind the selected tool button.
  final Color selectedTool;

  static GnPalette of(BuildContext context) {
    final colors = ColorScheme.of(context);
    if (EInkScope.maybeOf(context) != null) {
      return GnPalette(
        header: colors.surfaceContainerHigh,
        onHeader: colors.onSurface,
        activeTab: colors.surface,
        selectedTool: colors.onSurface.withValues(alpha: 0.14),
      );
    }
    // The accent, deep enough to carry white icons: the same ink as the
    // main buttons, a few shades down.
    final header = DefterDesign.headerOf(colors);
    return GnPalette(
      header: header,
      onHeader: Colors.white,
      activeTab: Color.lerp(header, Colors.white, 0.14)!,
      selectedTool: const Color(0x33FFFFFF),
    );
  }
}
