
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:saber/components/editor_gn/gn_actions.dart';
import 'package:saber/components/editor_gn/gn_controller.dart';
import 'package:saber/components/theming/dynamic_material_app.dart';
import 'package:saber/components/theming/uni_icon.dart';
import 'package:saber/components/toolbar/color_bar.dart';
import 'package:saber/components/toolbar/export_bar.dart';
import 'package:saber/components/toolbar/note_link_dialog.dart';
import 'package:saber/components/editor_gn/gn_pen_settings.dart';
import 'package:saber/components/toolbar/quick_style_bar.dart';
import 'package:saber/components/toolbar/selection_bar.dart';
import 'package:saber/components/toolbar/toolbar.dart';
import 'package:saber/data/defter_strings.dart';
import 'package:saber/data/editor/page.dart';
import 'package:saber/data/links/note_link.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/tools/eraser.dart';
import 'package:saber/data/tools/highlighter.dart';
import 'package:saber/data/tools/pen.dart';
import 'package:saber/data/tools/pencil.dart';
import 'package:saber/data/tools/select.dart';
import 'package:saber/data/tools/shape_pen.dart';
import 'package:saber/i18n/strings.g.dart';

/// What hangs from the top bar over the page: undo and redo, the strip with
/// the options of the tool in use, and the panels that open from the bar's
/// buttons. It is drawn above the page without taking it over: only what is
/// drawn in it catches touches.
class GnOverlay extends StatefulWidget {
  const GnOverlay({
    super.key,
    required this.controller,
    required this.spec,
    required this.child,
  });

  final GnController controller;
  final Toolbar spec;

  /// The page area.
  final Widget child;

  @override
  State<GnOverlay> createState() => _GnOverlayState();
}

class _GnOverlayState extends State<GnOverlay> {
  final _portal = OverlayPortalController();

  @override
  void initState() {
    super.initState();
    // the overlay can only be shown once this has been built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _portal.show();
    });
  }

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: (context) => ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) => _content(context),
      ),
      child: widget.child,
    );
  }

  Widget _content(BuildContext context) {
    final controller = widget.controller;
    final actions = GnActions(widget.spec, controller);
    final strip = _strip(context, actions);
    final panel = controller.panel;
    return Positioned.fill(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (panel != GnPanel.none)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: controller.close,
              ),
            ),
          Positioned(
            top: 0,
            left: 0,
            child: CompositedTransformFollower(
              link: controller.barLink,
              targetAnchor: Alignment.bottomLeft,
              followerAnchor: Alignment.topLeft,
              offset: const Offset(64, 8),
              showWhenUnlinked: false,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width - 24,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _UndoRedo(spec: widget.spec),
                    if (strip != null) ...[
                      const SizedBox(width: 8),
                      Flexible(child: strip),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (panel != GnPanel.none) _panelAt(context, panel, actions),
        ],
      ),
    );
  }

  Widget? _strip(BuildContext context, GnActions actions) {
    final spec = widget.spec;
    if (spec.readOnly) return null;
    final tool = actions.tool;
    final colors = ColorScheme.of(context);
    final invert =
        stows.editorAutoInvert.value && Theme.brightnessOf(context) == .dark;

    Widget? content;
    if (spec.textEditing) {
      content = ValueListenableBuilder<QuillStruct?>(
        valueListenable: spec.quillFocus,
        builder: (context, quill, _) {
          if (quill == null) return const SizedBox.shrink();
          return SizedBox(
            height: 44,
            child: QuillSimpleToolbar(
              controller: quill.controller,
              config: QuillSimpleToolbarConfig(
                axis: Axis.horizontal,
                multiRowsDisplay: false,
                showUndo: false,
                showRedo: false,
                showFontSize: false,
                showFontFamily: false,
                showClearFormat: false,
                customButtons: [
                  QuillToolbarCustomButtonOptions(
                    icon: const Icon(Icons.note_add_outlined),
                    tooltip: DefterStrings.linkToNote,
                    onPressed: () async {
                      final path = await NoteLinkDialog.show(
                        context,
                        excludePath: spec.currentNotePath,
                      );
                      if (path == null) return;
                      NoteLink.apply(quill.controller, path);
                    },
                  ),
                ],
              ),
            ),
          );
        },
      );
    } else if (tool is Pen) {
      final currentColor = tool.color;
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PenChip(
            selected: actions.isPen,
            tooltip: actions.writingPen.name,
            onTap: actions.selectPen,
            child: UniIcon(actions.writingPen.icon, size: 18),
          ),
          _PenChip(
            selected: actions.isPencil,
            tooltip: t.editor.pens.pencil,
            onTap: actions.selectPencil,
            child: const FaIcon(Pencil.pencilIcon, size: 18),
          ),
          _PenChip(
            selected: actions.isHighlighter,
            tooltip: t.editor.pens.highlighter,
            onTap: actions.selectHighlighter,
            child: const FaIcon(Highlighter.highlighterIcon, size: 18),
          ),
          _PenChip(
            selected: actions.isShape,
            tooltip: t.editor.pens.shapePen,
            onTap: actions.toggleShape,
            child: const FaIcon(ShapePen.shapePenIcon, size: 18),
          ),
          QuickStyleBar(
            pen: tool,
            currentColor: currentColor,
            invert: invert,
            setColor: spec.setColor,
            onSizeChanged: () => setState(() {}),
          ),
          CompositedTransformTarget(
            link: widget.controller.links[GnPanel.color]!,
            child: IconButton(
              tooltip: t.editor.toolbar.toggleColors,
              icon: Icon(Icons.palette_outlined, color: colors.onSurface),
              onPressed: () => widget.controller.toggle(GnPanel.color),
            ),
          ),
        ],
      );
    } else if (tool is Eraser) {
      content = EraserSizeBar(
        eraser: tool,
        onSizeChanged: () => setState(() {}),
      );
    } else if (tool is Select && tool.doneSelecting) {
      content = SelectionBar(
        duplicateSelection: spec.duplicateSelection,
        deleteSelection: spec.deleteSelection,
        recognizeSelection: spec.recognizeSelection,
      );
    }
    if (content == null) return null;
    return Material(
      color: colors.surfaceContainerHigh,
      elevation: 3,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: content,
      ),
    );
  }

  Widget _panelAt(BuildContext context, GnPanel panel, GnActions actions) {
    final controller = widget.controller;
    final spec = widget.spec;
    final rightSide = panel == GnPanel.export || panel == GnPanel.more;
    final width = MediaQuery.sizeOf(context).width;
    final Widget body;
    switch (panel) {
      case GnPanel.penSettings:
        body = GnPenSettings(
          getTool: () => spec.currentTool,
          setTool: spec.setTool,
        );
      case GnPanel.color:
        final tool = spec.currentTool;
        body = SizedBox(
          width: width < 520 ? width - 24 : 480,
          child: ColorBar(
            axis: Axis.horizontal,
            setColor: spec.setColor,
            currentColor: tool is Pen ? tool.color : null,
            invert:
                stows.editorAutoInvert.value &&
                Theme.brightnessOf(context) == .dark,
          ),
        );
      case GnPanel.export:
        body = ExportBar(
          axis: Axis.horizontal,
          toggleExportBar: controller.close,
          exportAsSba: spec.exportAsSba,
          exportAsPdf: spec.exportAsPdf,
          exportAsPng: spec.exportAsPng,
        );
      case GnPanel.more:
        body = _MoreTools(actions: actions, controller: controller, spec: spec);
      case GnPanel.stickers:
      case GnPanel.none:
        body = const SizedBox.shrink();
    }
    return Positioned(
      top: 0,
      left: 0,
      child: CompositedTransformFollower(
        link: controller.links[panel]!,
        targetAnchor: rightSide ? Alignment.bottomRight : Alignment.bottomCenter,
        followerAnchor: rightSide ? Alignment.topRight : Alignment.topCenter,
        offset: const Offset(0, 8),
        showWhenUnlinked: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: width - 16),
          child: Material(
            color: ColorScheme.of(context).surfaceContainerHigh,
            elevation: 8,
            borderRadius: BorderRadius.circular(18),
            clipBehavior: Clip.antiAlias,
            child: Padding(padding: const EdgeInsets.all(10), child: body),
          ),
        ),
      ),
    );
  }
}

class _UndoRedo extends StatelessWidget {
  const _UndoRedo({required this.spec});

  final Toolbar spec;

  @override
  Widget build(BuildContext context) {
    final colors = ColorScheme.of(context);
    return Material(
      color: colors.surfaceContainerHigh,
      elevation: 3,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: t.editor.toolbar.undo,
              icon: const Icon(Icons.undo),
              onPressed: !spec.readOnly && spec.isUndoPossible ? spec.undo : null,
            ),
            IconButton(
              tooltip: t.editor.toolbar.redo,
              icon: const Icon(Icons.redo),
              onPressed: !spec.readOnly && spec.isRedoPossible ? spec.redo : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _PenChip extends StatelessWidget {
  const _PenChip({
    required this.selected,
    required this.tooltip,
    required this.onTap,
    required this.child,
  });

  final bool selected;
  final String tooltip;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = ColorScheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        isSelected: selected,
        style: IconButton.styleFrom(
          foregroundColor: selected ? colors.primary : colors.onSurface,
          backgroundColor: selected
              ? colors.primary.withValues(alpha: 0.16)
              : Colors.transparent,
        ),
        icon: child,
      ),
    );
  }
}

/// The rarely needed tools and switches behind the arrow of the top bar.
class _MoreTools extends StatelessWidget {
  const _MoreTools({
    required this.actions,
    required this.controller,
    required this.spec,
  });

  final GnActions actions;
  final GnController controller;
  final Toolbar spec;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            dense: true,
            leading: const Icon(Icons.highlight_alt),
            title: Text(t.editor.pens.laserPointer),
            onTap: actions.selectLaser,
          ),
          if (!stows.hideFingerDrawingToggle.value)
            ValueListenableBuilder(
              valueListenable: stows.editorFingerDrawing,
              builder: (context, value, _) => SwitchListTile(
                dense: true,
                secondary: const Icon(Icons.touch_app_outlined),
                title: Text(t.editor.toolbar.toggleFingerDrawing),
                value: value,
                onChanged: spec.readOnly
                    ? null
                    : (_) => spec.toggleFingerDrawing(),
              ),
            ),
          ListTile(
            dense: true,
            leading: const Icon(Icons.fullscreen),
            title: Text(t.editor.toolbar.fullscreen),
            onTap: () {
              controller.close();
              DynamicMaterialApp.setFullscreen(true, updateSystem: true);
            },
          ),
        ],
      ),
    );
  }
}
