import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:saber/components/canvas/save_indicator.dart';
import 'package:saber/components/editor_gn/gn_actions.dart';
import 'package:saber/components/editor_gn/gn_bar.dart';
import 'package:saber/components/editor_gn/gn_controller.dart';
import 'package:saber/components/theming/defter_design.dart';
import 'package:saber/components/theming/uni_icon.dart';
import 'package:saber/data/benchmark/pen_latency_probe.dart';
import 'package:saber/data/defter_strings.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/tools/eraser.dart';
import 'package:saber/data/tools/highlighter.dart';
import 'package:saber/data/tools/laser_pointer.dart';
import 'package:saber/data/tools/pencil.dart';
import 'package:saber/data/tools/select.dart';
import 'package:saber/data/tools/shape_pen.dart';
import 'package:saber/i18n/strings.g.dart';

/// The floating editor layout: the page fills the whole screen and the
/// controls float over it in rounded capsules, as in the low latency note
/// apps for tablets.
///
///  * on the left, getting around: back, the note's name, its pages, a new
///    page, the open notes, the page sidebar;
///  * in the middle, the tool box: undo, redo and drawing with the finger,
///    then every tool, then the switch for the tool's quick options (which
///    hang under the tool box, see GnOverlay);
///  * on the right: ask the notes, export, the menu.
///
/// On a narrow screen the tool box moves to a second row under the other
/// two. It takes everything it needs from the [GnEditorBar] description
/// [from], so that both layouts do exactly the same things.
class FloatEditorBar extends StatelessWidget {
  const FloatEditorBar({super.key, required this.from, required this.onBack});

  final GnEditorBar from;
  final VoidCallback onBack;

  /// The height of a capsule, the size of the buttons in it, and the space
  /// around capsules.
  static const capsuleHeight = 44.0;
  static const buttonSize = 36.0;
  static const spacing = 8.0;

  /// From this width on, all three capsules fit in one row.
  static const oneRowWidth = 1000.0;

  /// How far down from under the status bar the controls reach on a screen
  /// [width] wide: the capsules and the quick options strip under the tool
  /// box. The first page starts below this.
  static double reservedHeight(double width) {
    final rows = width >= oneRowWidth ? 2 : 3;
    return spacing + rows * (capsuleHeight + spacing);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(listenable: from.controller, builder: _build);
  }

  Widget _build(BuildContext context, Widget? _) {
    final dark = Theme.brightnessOf(context) == Brightness.dark;
    final width = MediaQuery.sizeOf(context).width;
    final actions = GnActions(from.spec, from.controller);
    final nav = _navigation(context);
    final tools = CompositedTransformTarget(
      link: from.controller.barLink,
      child: _toolbox(context, actions),
    );
    final end = _endActions(context);

    final Widget layout;
    if (width >= oneRowWidth) {
      layout = SizedBox(
        height: capsuleHeight,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(alignment: AlignmentDirectional.centerStart, child: nav),
            Align(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: width * 0.5),
                child: tools,
              ),
            ),
            Align(alignment: AlignmentDirectional.centerEnd, child: end),
          ],
        ),
      );
    } else {
      layout = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Flexible(child: nav),
              const Spacer(),
              end,
            ],
          ),
          const SizedBox(height: spacing),
          tools,
        ],
      );
    }
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: layout,
    );
  }

  // -- left: getting around ----------------------------------------------------

  Widget _navigation(BuildContext context) {
    final colors = ColorScheme.of(context);
    final tabs = from.paths;
    return _Capsule(
      children: [
        _CapsuleButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          icon: const Icon(Symbols.arrow_back_rounded),
          onPressed: onBack,
        ),
        SaveIndicator(savingState: from.savingState, triggerSave: from.triggerSave),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 200),
          child: TextButton(
            key: const Key('floatNoteName'),
            onPressed: from.onRename,
            style: TextButton.styleFrom(
              foregroundColor: colors.onSurface,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: Text(
              from.currentName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const _Divider(),
        Tooltip(
          message: t.editor.pages,
          child: TextButton.icon(
            key: const Key('floatPages'),
            onPressed: from.onPages,
            style: TextButton.styleFrom(
              foregroundColor: colors.onSurface,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            icon: const Icon(Symbols.grid_view_rounded, size: 20),
            label: ValueListenableBuilder<int>(
              valueListenable: from.visiblePage,
              builder: (context, page, _) =>
                  Text('${(page < 0 ? 0 : page) + 1} / ${from.pageCount}'),
            ),
          ),
        ),
        _CapsuleButton(
          tooltip: t.editor.menu.insertPage,
          icon: const Icon(Symbols.note_add_rounded),
          onPressed: from.spec.readOnly ? null : from.onAddPage,
        ),
        _TabsButton(
          paths: tabs,
          currentPath: from.currentPath,
          onSelect: from.onSelectTab,
          onClose: from.onCloseTab,
          onNew: from.onNewTab,
        ),
        if (from.sidebarAvailable)
          _CapsuleButton(
            tooltip: DefterStrings.pageSidebar,
            selected: from.sidebarShown,
            icon: Icon(
              from.sidebarShown
                  ? Icons.view_sidebar_rounded
                  : Symbols.view_sidebar_rounded,
            ),
            onPressed: from.onToggleSidebar,
          ),
      ],
    );
  }

  // -- middle: the tool box ------------------------------------------------------

  Widget _toolbox(BuildContext context, GnActions actions) {
    final spec = from.spec;
    final controller = from.controller;
    final readOnly = spec.readOnly;
    final tool = actions.tool;

    /// A pen's button: picks it, or opens its settings when it is already
    /// in use.
    VoidCallback? pen(bool selected, VoidCallback select) {
      if (readOnly) return null;
      return () {
        if (selected) {
          controller.toggle(GnPanel.penSettings);
        } else {
          select();
        }
      };
    }

    final penSelected = actions.isPen;
    return _Capsule(
      scrolls: true,
      children: [
        _CapsuleButton(
          tooltip: t.editor.toolbar.undo,
          icon: const Icon(Symbols.undo_rounded),
          onPressed: !readOnly && spec.isUndoPossible ? spec.undo : null,
        ),
        _CapsuleButton(
          tooltip: t.editor.toolbar.redo,
          icon: const Icon(Symbols.redo_rounded),
          onPressed: !readOnly && spec.isRedoPossible ? spec.redo : null,
        ),
        if (!stows.hideFingerDrawingToggle.value)
          ValueListenableBuilder<bool>(
            valueListenable: stows.editorFingerDrawing,
            builder: (context, on, _) => _CapsuleButton(
              key: const Key('floatFingerDrawing'),
              tooltip: t.editor.toolbar.toggleFingerDrawing,
              selected: on,
              icon: Icon(on ? Symbols.draw_rounded : Symbols.do_not_touch_rounded),
              onPressed: readOnly ? null : spec.toggleFingerDrawing,
            ),
          ),
        const _Divider(),
        CompositedTransformTarget(
          link: controller.links[GnPanel.penSettings]!,
          child: _CapsuleButton(
            key: const Key('floatPen'),
            tooltip: actions.writingPen.name,
            selected: penSelected,
            icon: UniIcon(actions.writingPen.icon, size: 22),
            onPressed: pen(penSelected, actions.selectPen),
          ),
        ),
        _CapsuleButton(
          key: const Key('floatPencil'),
          tooltip: t.editor.pens.pencil,
          selected: actions.isPencil,
          icon: const Icon(Pencil.pencilIcon),
          onPressed: pen(actions.isPencil, actions.selectPencil),
        ),
        _CapsuleButton(
          key: const Key('floatHighlighter'),
          tooltip: t.editor.pens.highlighter,
          selected: actions.isHighlighter,
          icon: const Icon(Highlighter.highlighterIcon),
          onPressed: pen(actions.isHighlighter, actions.selectHighlighter),
        ),
        _CapsuleButton(
          key: const Key('floatEraser'),
          tooltip: t.editor.toolbar.toggleEraser,
          selected: tool is Eraser,
          icon: const Icon(Symbols.ink_eraser_rounded),
          onPressed: readOnly ? null : actions.selectEraser,
        ),
        _CapsuleButton(
          key: const Key('floatLasso'),
          tooltip: t.editor.toolbar.select,
          selected: tool is Select,
          icon: const Icon(Symbols.lasso_select_rounded),
          onPressed: readOnly ? null : actions.selectLasso,
        ),
        _CapsuleButton(
          key: const Key('floatShape'),
          tooltip: t.editor.pens.shapePen,
          selected: actions.isShape,
          icon: const Icon(ShapePen.shapePenIcon),
          onPressed: pen(actions.isShape, actions.toggleShape),
        ),
        _CapsuleButton(
          key: const Key('floatText'),
          tooltip: t.editor.toolbar.text,
          selected: spec.textEditing,
          icon: const Icon(Symbols.text_fields_rounded),
          onPressed: readOnly ? null : spec.toggleTextEditing,
        ),
        _CapsuleButton(
          tooltip: t.editor.toolbar.photo,
          icon: const Icon(Symbols.photo_rounded),
          onPressed: readOnly ? null : spec.pickPhoto,
        ),
        if (spec.takePhoto != null)
          _CapsuleButton(
            key: const Key('gnTakePhoto'),
            tooltip: DefterStrings.takePhoto,
            icon: const Icon(Symbols.photo_camera_rounded),
            onPressed: readOnly ? null : spec.takePhoto,
          ),
        _CapsuleButton(
          key: const Key('floatLaser'),
          tooltip: t.editor.pens.laserPointer,
          selected: tool is LaserPointer,
          icon: const Icon(Symbols.highlight_alt_rounded),
          onPressed: actions.selectLaser,
        ),
        _CapsuleButton(
          tooltip: DefterStrings.recordings,
          icon: const Icon(Symbols.mic_rounded),
          onPressed: from.onRecordings,
        ),
        const _Divider(),
        _CapsuleButton(
          key: const Key('floatQuickControls'),
          tooltip: DefterStrings.floatQuickControls,
          selected: controller.quickControls,
          icon: Icon(
            controller.quickControls
                ? Symbols.keyboard_arrow_up_rounded
                : Symbols.tune_rounded,
          ),
          onPressed: controller.toggleQuickControls,
        ),
      ],
    );
  }

  // -- right ---------------------------------------------------------------------

  Widget _endActions(BuildContext context) {
    return _Capsule(
      children: [
        if (from.onPenProbe != null)
          ValueListenableBuilder<bool>(
            valueListenable: PenLatencyProbe.instance.recording,
            builder: (context, recording, _) {
              if (!from.showPenProbe && !recording) {
                return const SizedBox.shrink();
              }
              return _CapsuleButton(
                tooltip: recording
                    ? DefterStrings.penProbeStop
                    : DefterStrings.penProbeStart,
                selected: recording,
                icon: Icon(
                  recording ? Icons.stop_circle_rounded : Symbols.speed_rounded,
                  color: recording ? Colors.red : null,
                ),
                onPressed: from.onPenProbe,
              );
            },
          ),
        _CapsuleButton(
          tooltip: DefterStrings.askNotes,
          icon: const Icon(Symbols.auto_awesome_rounded),
          onPressed: from.onAskNotes,
        ),
        CompositedTransformTarget(
          link: from.controller.links[GnPanel.export]!,
          child: _CapsuleButton(
            tooltip: t.editor.toolbar.export,
            icon: const Icon(Symbols.ios_share_rounded),
            onPressed: () => from.controller.toggle(GnPanel.export),
          ),
        ),
        CompositedTransformTarget(
          link: from.controller.links[GnPanel.more]!,
          child: _CapsuleButton(
            tooltip: DefterStrings.gnMoreTools,
            selected: from.controller.panel == GnPanel.more,
            icon: const Icon(Symbols.apps_rounded),
            onPressed: () => from.controller.toggle(GnPanel.more),
          ),
        ),
        _CapsuleButton(
          tooltip: DefterStrings.gnMenu,
          icon: const Icon(Symbols.more_horiz_rounded),
          onPressed: from.onMore,
        ),
      ],
    );
  }
}

/// A rounded capsule floating over the page, holding a row of buttons.
class _Capsule extends StatelessWidget {
  const _Capsule({required this.children, this.scrolls = false});

  final List<Widget> children;

  /// Whether the row scrolls sideways when it doesn't fit.
  final bool scrolls;

  @override
  Widget build(BuildContext context) {
    final row = Row(mainAxisSize: MainAxisSize.min, children: children);
    return SizedBox(
      height: FloatEditorBar.capsuleHeight,
      child: FloatingPanel.pill(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: scrolls
              ? SingleChildScrollView(scrollDirection: Axis.horizontal, child: row)
              : row,
        ),
      ),
    );
  }
}

class _CapsuleButton extends StatelessWidget {
  const _CapsuleButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.selected = false,
  });

  final String tooltip;
  final Widget icon;
  final VoidCallback? onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = ColorScheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: IconButton(
        tooltip: tooltip,
        isSelected: selected,
        onPressed: onPressed,
        iconSize: 22,
        style: IconButton.styleFrom(
          fixedSize: const Size.square(FloatEditorBar.buttonSize),
          minimumSize: const Size.square(FloatEditorBar.buttonSize),
          padding: EdgeInsets.zero,
          foregroundColor: selected ? colors.primary : colors.onSurface,
          disabledForegroundColor: colors.onSurface.withValues(alpha: 0.35),
          backgroundColor: selected
              ? colors.primary.withValues(alpha: 0.16)
              : Colors.transparent,
          shape: const CircleBorder(),
        ),
        icon: icon,
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: SizedBox(
        width: 2,
        height: 24,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: ColorScheme.of(context).outlineVariant,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      ),
    );
  }
}

/// The open notes: a list to switch between them or close them, and a way
/// to open another one.
class _TabsButton extends StatelessWidget {
  const _TabsButton({
    required this.paths,
    required this.currentPath,
    required this.onSelect,
    required this.onClose,
    required this.onNew,
  });

  final List<String> paths;
  final String? currentPath;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onClose;
  final VoidCallback onNew;

  static String _name(String path) => path.substring(path.lastIndexOf('/') + 1);

  @override
  Widget build(BuildContext context) {
    final colors = ColorScheme.of(context);
    final count = paths.length;
    return MenuAnchor(
      menuChildren: [
        for (final path in paths)
          MenuItemButton(
            leadingIcon: Icon(
              path == currentPath
                  ? Symbols.radio_button_checked_rounded
                  : Symbols.description_rounded,
              size: 20,
            ),
            trailingIcon: IconButton(
              iconSize: 18,
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              onPressed: () => onClose(path),
              icon: const Icon(Symbols.close_rounded),
            ),
            onPressed: path == currentPath ? null : () => onSelect(path),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 260),
              child: Text(
                _name(path),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: path == currentPath ? FontWeight.w700 : null,
                ),
              ),
            ),
          ),
        if (paths.isNotEmpty) const Divider(height: 8),
        MenuItemButton(
          leadingIcon: const Icon(Symbols.add_rounded, size: 20),
          onPressed: onNew,
          child: Text(DefterStrings.gnNewTab),
        ),
      ],
      builder: (context, menu, _) => Badge(
        isLabelVisible: count > 1,
        label: Text('$count'),
        backgroundColor: colors.primary,
        textColor: colors.onPrimary,
        offset: const Offset(-2, 2),
        child: _CapsuleButton(
          key: const Key('floatTabs'),
          tooltip: DefterStrings.floatTabs,
          selected: menu.isOpen,
          icon: const Icon(Symbols.tab_rounded),
          onPressed: () => menu.isOpen ? menu.close() : menu.open(),
        ),
      ),
    );
  }
}
