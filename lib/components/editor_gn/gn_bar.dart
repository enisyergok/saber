import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:saber/components/canvas/save_indicator.dart';
import 'package:saber/components/editor_gn/gn_actions.dart';
import 'package:saber/components/editor_gn/gn_controller.dart';
import 'package:saber/components/editor_gn/gn_palette.dart';
import 'package:saber/components/theming/uni_icon.dart';
import 'package:saber/components/toolbar/toolbar.dart';
import 'package:saber/data/defter_strings.dart';
import 'package:saber/data/tools/eraser.dart';
import 'package:saber/data/tools/select.dart';
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
    required this.onAskNotes,
    required this.onAddPage,
    required this.onRecordings,
    required this.onMore,
    required this.visiblePage,
    required this.pageCount,
    required this.onPages,
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
  final VoidCallback onAskNotes;
  final VoidCallback onAddPage;
  final VoidCallback onRecordings;
  final VoidCallback onMore;

  /// The page in view and how many there are ("2 / 5"); tapping the label
  /// shows all pages.
  final ValueListenable<int> visiblePage;
  final int pageCount;
  final VoidCallback onPages;

  static const tabRowHeight = 44.0;
  static const toolRowHeight = 56.0;
  static const contentHeight = tabRowHeight + toolRowHeight;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: _buildBar,
    );
  }

  Widget _buildBar(BuildContext context, Widget? _) {
    final palette = GnPalette.of(context);
    final actions = GnActions(spec, controller);
    return IconButtonTheme(
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
                    _toolRow(context, palette, actions),
                  ],
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
                  onTap: selected || path == null ? null : () => onSelectTab(path),
                  onRename: selected ? onRename : null,
                  onClose: path == null ? null : () => onCloseTab(path),
                );
              },
            ),
          ),
          IconButton(
            tooltip: DefterStrings.gnNewTab,
            icon: const Icon(Icons.add),
            onPressed: onNewTab,
          ),
        ],
      ),
    );
  }

  Widget _toolRow(BuildContext context, GnPalette palette, GnActions actions) {
    final readOnly = spec.readOnly;
    final tool = actions.tool;
    Widget toolButton({
      required Widget icon,
      required String tooltip,
      required bool selected,
      required VoidCallback? onPressed,
      GnPanel? panel,
    }) {
      final button = _ToolButton(
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
            tooltip: DefterStrings.pageSidebar,
            icon: Icon(
              sidebarShown ? Icons.view_sidebar : Icons.view_sidebar_outlined,
            ),
            onPressed: sidebarAvailable ? onToggleSidebar : null,
          ),
          IconButton(
            tooltip: DefterStrings.askNotes,
            icon: const Icon(Icons.auto_awesome_outlined),
            onPressed: onAskNotes,
          ),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    toolButton(
                      icon: const Icon(CupertinoIcons.lasso),
                      tooltip: t.editor.toolbar.select,
                      selected: tool is Select,
                      onPressed: readOnly ? null : actions.selectLasso,
                    ),
                    toolButton(
                      icon: UniIcon(actions.writingPen.icon, size: 18),
                      tooltip: actions.writingPen.name,
                      selected: actions.isDrawing,
                      panel: GnPanel.penSettings,
                      onPressed: readOnly ? null : actions.tapPenButton,
                    ),
                    toolButton(
                      icon: const FaIcon(FontAwesomeIcons.eraser, size: 18),
                      tooltip: t.editor.toolbar.toggleEraser,
                      selected: tool is Eraser,
                      onPressed: readOnly ? null : actions.selectEraser,
                    ),
                    toolButton(
                      icon: const Icon(Icons.text_fields),
                      tooltip: t.editor.toolbar.text,
                      selected: spec.textEditing,
                      onPressed: readOnly ? null : spec.toggleTextEditing,
                    ),
                    toolButton(
                      icon: const Icon(Icons.photo_outlined),
                      tooltip: t.editor.toolbar.photo,
                      selected: false,
                      onPressed: readOnly ? null : spec.pickPhoto,
                    ),
                    toolButton(
                      icon: const Icon(Icons.expand_more),
                      tooltip: DefterStrings.gnMoreTools,
                      selected: controller.panel == GnPanel.more,
                      panel: GnPanel.more,
                      onPressed: () => controller.toggle(GnPanel.more),
                    ),
                    toolButton(
                      icon: const Icon(Icons.mic_none),
                      tooltip: DefterStrings.recordings,
                      selected: false,
                      onPressed: onRecordings,
                    ),
                  ],
                ),
              ),
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
          IconButton(
            tooltip: t.editor.menu.insertPage,
            icon: const Icon(Icons.note_add_outlined),
            onPressed: spec.readOnly ? null : onAddPage,
          ),
          CompositedTransformTarget(
            link: controller.links[GnPanel.export]!,
            child: IconButton(
              tooltip: t.editor.toolbar.export,
              icon: const Icon(Icons.ios_share),
              onPressed: () => controller.toggle(GnPanel.export),
            ),
          ),
          IconButton(
            tooltip: DefterStrings.gnMenu,
            icon: const Icon(Icons.more_horiz),
            onPressed: onMore,
          ),
        ],
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
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
          foregroundColor: palette.onHeader,
          disabledForegroundColor: palette.onHeader.withValues(alpha: 0.4),
          backgroundColor: selected ? palette.selectedTool : Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          minimumSize: const Size(46, 40),
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
      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
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
                Icon(Icons.keyboard_arrow_down, size: 18, color: palette.onHeader),
              if (onClose != null)
                IconButton(
                  iconSize: 16,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(width: 28, height: 28),
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  onPressed: onClose,
                  icon: Icon(Icons.close, color: palette.onHeader),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
