import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:saber/components/canvas/save_indicator.dart';
import 'package:saber/components/editor_gn/gn_actions.dart';
import 'package:saber/components/editor_gn/gn_controller.dart';
import 'package:saber/components/editor_gn/gn_palette.dart';
import 'package:saber/components/home/catalog_icon.dart';
import 'package:saber/components/toolbar/toolbar.dart';
import 'package:saber/data/benchmark/pen_latency_probe.dart';
import 'package:saber/data/defter_strings.dart';
import 'package:saber/data/tools/eraser.dart';
import 'package:saber/data/tools/select.dart';
import 'package:saber/data/tools/shape_pen.dart';
import 'package:saber/i18n/strings.g.dart';

/// The editor's top bar: the open notebooks as tabs, and under them the main
/// tools on the left of centre and the page actions on the right.
class GnEditorBar extends StatelessWidget {
  const GnEditorBar({
    super.key,
    required this.controller,
    required this.spec,
    required this.paths,
    required this.currentPath,
    required this.currentName,
    required this.onSelectTab,
    required this.onCloseTab,
    required this.onNewTab,
    required this.onRename,
    required this.savingState,
    required this.triggerSave,
    required this.sidebarAvailable,
    required this.sidebarShown,
    required this.onToggleSidebar,
    required this.onSearch,
    required this.onAskNotes,
    required this.onAddPage,
    required this.onRecordings,
    required this.onMore,
    required this.visiblePage,
    required this.pageCount,
    required this.onPages,
    this.showPenProbe = false,
    this.onPenProbe,
  });

  final GnController controller;
  final Toolbar spec;

  /// The open notebooks (paths without extension) and the one on screen.
  final List<String> paths;
  final String? currentPath;

  /// The name of the notebook on screen, for when it isn't among [paths].
  final String currentName;
  final ValueChanged<String> onSelectTab;
  final ValueChanged<String> onCloseTab;
  final VoidCallback onNewTab;
  final VoidCallback onRename;

  final ValueNotifier<SavingState> savingState;
  final VoidCallback triggerSave;

  final bool sidebarAvailable;
  final bool sidebarShown;
  final VoidCallback onToggleSidebar;
  final VoidCallback onSearch;
  final VoidCallback onAskNotes;
  final VoidCallback onAddPage;
  final VoidCallback onRecordings;
  final VoidCallback onMore;

  /// The page in view and how many there are ("2 / 5"); tapping the label
  /// shows all pages.
  final ValueListenable<int> visiblePage;
  final int pageCount;
  final VoidCallback onPages;

  /// Whether the pen latency button is shown (Settings > Pen latency
  /// measurement). It is also shown while a recording runs, so that it can
  /// be stopped.
  final bool showPenProbe;
  final VoidCallback? onPenProbe;

  static const tabRowHeight = 44.0;
  static const toolRowHeight = 56.0;
  static const navigationRowHeight = 48.0;
  static const contentHeight =
      tabRowHeight + navigationRowHeight + toolRowHeight;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(listenable: controller, builder: _buildBar);
  }

  Widget _buildBar(BuildContext context, Widget? _) {
    final palette = GnPalette.of(context);
    final actions = GnActions(spec, controller);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: Theme.brightnessOf(context) == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: IconButtonTheme(
        data: IconButtonThemeData(
          style: IconButton.styleFrom(foregroundColor: palette.onHeader),
        ),
        child: DefaultTextStyle.merge(
          style: TextStyle(color: palette.onHeader),
          child: Material(
            color: palette.header,
            child: SafeArea(
              bottom: false,
              child: CompositedTransformTarget(
                link: controller.barLink,
                child: SizedBox(
                  height: contentHeight,
                  child: Column(
                    children: [
                      _tabRow(context, palette),
                      _navigationRow(context, palette),
                      _toolRow(context, palette, actions),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tabRow(BuildContext context, GnPalette palette) {
    final shown = paths.isEmpty && currentPath == null
        ? [currentName]
        : paths.map((p) => p.substring(p.lastIndexOf('/') + 1)).toList();
    return SizedBox(
      height: tabRowHeight,
      child: Row(
        children: [
          SaveIndicator(savingState: savingState, triggerSave: triggerSave),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(top: 6),
              itemCount: shown.length,
              separatorBuilder: (_, _) => const SizedBox(width: 4),
              itemBuilder: (context, index) {
                final path = paths.length > index ? paths[index] : null;
                final selected = path == null || path == currentPath;
                return _Tab(
                  name: shown[index],
                  selected: selected,
                  palette: palette,
                  onTap: selected ? null : () => onSelectTab(path),
                  onRename: selected ? onRename : null,
                  onClose: path == null ? null : () => onCloseTab(path),
                );
              },
            ),
          ),
          IconButton(
            tooltip: DefterStrings.gnNewTab,
            icon: const Icon(Symbols.add_rounded),
            onPressed: onNewTab,
          ),
        ],
      ),
    );
  }

  Widget _navigationRow(BuildContext context, GnPalette palette) {
    return Container(
      height: navigationRowHeight,
      decoration: BoxDecoration(
        color: palette.activeTab,
        border: Border(
          bottom: BorderSide(color: ColorScheme.of(context).outlineVariant),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: DefterStrings.pageSidebar,
            icon: Icon(
              sidebarShown
                  ? Icons.view_sidebar_rounded
                  : Symbols.view_sidebar_rounded,
            ),
            onPressed: sidebarAvailable ? onToggleSidebar : null,
          ),
          IconButton(
            tooltip: DefterStrings.searchNotes,
            icon: const CatalogIcon('search.svg'),
            onPressed: onSearch,
          ),
          IconButton(
            tooltip: DefterStrings.askNotes,
            icon: const Icon(Symbols.auto_awesome_rounded),
            onPressed: onAskNotes,
          ),
          const SizedBox(height: 24, child: VerticalDivider(width: 12)),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 34) return const SizedBox.shrink();
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onRename,
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              currentName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(
                            Symbols.keyboard_arrow_down_rounded,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          TextButton(
            onPressed: onPages,
            style: TextButton.styleFrom(
              foregroundColor: palette.onHeader,
              visualDensity: VisualDensity.compact,
            ),
            child: ValueListenableBuilder<int>(
              valueListenable: visiblePage,
              builder: (context, page, _) =>
                  Text('${(page < 0 ? 0 : page) + 1} / $pageCount'),
            ),
          ),
          const SizedBox(height: 24, child: VerticalDivider(width: 12)),
          IconButton(
            tooltip: t.editor.menu.insertPage,
            icon: const Icon(Symbols.note_add_rounded),
            onPressed: spec.readOnly ? null : onAddPage,
          ),
          CompositedTransformTarget(
            link: controller.links[GnPanel.export]!,
            child: IconButton(
              tooltip: t.editor.toolbar.export,
              icon: const CatalogIcon('share.svg'),
              onPressed: () => controller.toggle(GnPanel.export),
            ),
          ),
          IconButton(
            tooltip: DefterStrings.gnMenu,
            icon: const CatalogIcon('more.svg'),
            onPressed: onMore,
          ),
        ],
      ),
    );
  }

  Widget _toolRow(BuildContext context, GnPalette palette, GnActions actions) {
    final readOnly = spec.readOnly;
    final tool = actions.tool;
    Widget toolButton({
      Key? key,
      required Widget icon,
      required String tooltip,
      required bool selected,
      required VoidCallback? onPressed,
      GnPanel? panel,
    }) {
      final button = _ToolButton(
        key: key,
        icon: icon,
        tooltip: tooltip,
        selected: selected,
        palette: palette,
        onPressed: onPressed,
      );
      if (panel == null) return button;
      return CompositedTransformTarget(
        link: controller.links[panel]!,
        child: button,
      );
    }

    return SizedBox(
      height: toolRowHeight,
      child: Row(
        children: [
          IconButton(
            tooltip: t.editor.toolbar.undo,
            icon: const Icon(Symbols.undo_rounded),
            onPressed: !readOnly && spec.isUndoPossible ? spec.undo : null,
          ),
          IconButton(
            tooltip: t.editor.toolbar.redo,
            icon: const Icon(Symbols.redo_rounded),
            onPressed: !readOnly && spec.isRedoPossible ? spec.redo : null,
          ),
          const SizedBox(height: 24, child: VerticalDivider(width: 12)),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    toolButton(
                      icon: const CatalogIcon('lasso.svg'),
                      tooltip: t.editor.toolbar.select,
                      selected: tool is Select,
                      onPressed: readOnly ? null : actions.selectLasso,
                    ),
                    toolButton(
                      icon: const CatalogIcon('pen.svg', preserveColors: true),
                      tooltip: actions.writingPen.name,
                      selected: actions.isPen,
                      panel: GnPanel.penSettings,
                      onPressed: readOnly
                          ? null
                          : () {
                              if (actions.isPen) {
                                controller.toggle(GnPanel.penSettings);
                              } else {
                                actions.selectPen();
                              }
                            },
                    ),
                    toolButton(
                      icon: const CatalogIcon('pencil.svg', preserveColors: true),
                      tooltip: t.editor.pens.pencil,
                      selected: actions.isPencil,
                      onPressed: readOnly
                          ? null
                          : () {
                              if (actions.isPencil) {
                                controller.toggle(GnPanel.penSettings);
                              } else {
                                actions.selectPencil();
                              }
                            },
                    ),
                    toolButton(
                      icon: const CatalogIcon('highlighter.svg', preserveColors: true),
                      tooltip: t.editor.pens.highlighter,
                      selected: actions.isHighlighter,
                      onPressed: readOnly
                          ? null
                          : () {
                              if (actions.isHighlighter) {
                                controller.toggle(GnPanel.penSettings);
                              } else {
                                actions.selectHighlighter();
                              }
                            },
                    ),
                    toolButton(
                      icon: const Icon(ShapePen.shapePenIcon),
                      tooltip: t.editor.pens.shapePen,
                      selected: actions.isShape,
                      onPressed: readOnly ? null : actions.toggleShape,
                    ),
                    toolButton(
                      icon: const CatalogIcon('eraser.svg'),
                      tooltip: t.editor.toolbar.toggleEraser,
                      selected: tool is Eraser,
                      onPressed: readOnly ? null : actions.selectEraser,
                    ),
                    toolButton(
                      icon: const CatalogIcon('text.svg'),
                      tooltip: t.editor.toolbar.text,
                      selected: spec.textEditing,
                      onPressed: readOnly ? null : spec.toggleTextEditing,
                    ),
                    toolButton(
                      icon: const CatalogIcon('image.svg'),
                      tooltip: t.editor.toolbar.photo,
                      selected: false,
                      onPressed: readOnly ? null : spec.pickPhoto,
                    ),
                    if (spec.takePhoto != null)
                      toolButton(
                        key: const Key('gnTakePhoto'),
                        icon: const Icon(Symbols.photo_camera_rounded),
                        tooltip: DefterStrings.takePhoto,
                        selected: false,
                        onPressed: readOnly ? null : spec.takePhoto,
                      ),
                    toolButton(
                      icon: const Icon(Symbols.expand_more_rounded),
                      tooltip: DefterStrings.gnMoreTools,
                      selected: controller.panel == GnPanel.more,
                      panel: GnPanel.more,
                      onPressed: () => controller.toggle(GnPanel.more),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 28, child: VerticalDivider(width: 12)),
          _ToolButton(
            key: const Key('gnRecordings'),
            icon: const Icon(Symbols.mic_rounded),
            tooltip: DefterStrings.recordings,
            selected: false,
            palette: palette,
            onPressed: onRecordings,
          ),
          if (onPenProbe != null)
            ValueListenableBuilder<bool>(
              valueListenable: PenLatencyProbe.instance.recording,
              builder: (context, recording, _) {
                if (!showPenProbe && !recording) {
                  return const SizedBox.shrink();
                }
                return _ToolButton(
                  icon: Icon(
                    recording
                        ? Icons.stop_circle_rounded
                        : Symbols.speed_rounded,
                    color: recording ? Colors.red : null,
                  ),
                  tooltip: recording
                      ? DefterStrings.penProbeStop
                      : DefterStrings.penProbeStart,
                  selected: recording,
                  palette: palette,
                  onPressed: onPenProbe,
                );
              },
            ),
        ],
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.palette,
    required this.onPressed,
  });

  final Widget icon;
  final String tooltip;
  final bool selected;
  final GnPalette palette;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: IconButton(
        tooltip: tooltip,
        isSelected: selected,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          foregroundColor: selected
              ? palette.selectedToolForeground
              : palette.onHeader,
          disabledForegroundColor: palette.onHeader.withValues(alpha: 0.4),
          backgroundColor: selected ? palette.selectedTool : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          minimumSize: const Size(44, 44),
        ),
        icon: icon,
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.name,
    required this.selected,
    required this.palette,
    required this.onTap,
    required this.onRename,
    required this.onClose,
  });

  final String name;
  final bool selected;
  final GnPalette palette;
  final VoidCallback? onTap;
  final VoidCallback? onRename;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: palette.onHeader,
      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      fontSize: 14,
    );
    return Material(
      color: selected ? palette.activeTab : Colors.transparent,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap ?? onRename,
        child: Padding(
          padding: const EdgeInsetsDirectional.only(start: 14, end: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 200),
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: style,
                ),
              ),
              if (selected && onRename != null)
                Icon(
                  Symbols.keyboard_arrow_down_rounded,
                  size: 18,
                  color: palette.onHeader,
                ),
              if (onClose != null)
                IconButton(
                  iconSize: 16,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 28,
                    height: 28,
                  ),
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  onPressed: onClose,
                  icon: Icon(Symbols.close_rounded, color: palette.onHeader),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
