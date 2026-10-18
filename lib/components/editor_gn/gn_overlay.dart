import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:saber/components/editor_gn/gn_actions.dart';
import 'package:saber/components/editor_gn/gn_bar.dart';
import 'package:saber/components/editor_gn/gn_controller.dart';
import 'package:saber/components/editor_gn/float_bar.dart';
import 'package:saber/components/theming/defter_design.dart';
import 'package:saber/components/theming/dynamic_material_app.dart';
import 'package:saber/components/toolbar/color_bar.dart';
import 'package:saber/components/toolbar/export_bar.dart';
import 'package:saber/components/toolbar/note_link_dialog.dart';
import 'package:saber/components/editor_gn/gn_pen_settings.dart';
import 'package:saber/components/editor_gn/pen_fan.dart';
import 'package:saber/components/toolbar/quick_style_bar.dart';
import 'package:saber/components/toolbar/selection_bar.dart';
import 'package:saber/components/toolbar/toolbar.dart';
import 'package:saber/data/defter_strings.dart';
import 'package:saber/data/editor/page.dart';
import 'package:saber/data/links/note_link.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/tools/notewise_tools.dart';
import 'package:saber/data/tools/eraser.dart';
import 'package:saber/data/tools/pen.dart';
import 'package:saber/data/tools/select.dart';
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
    this.topBar,
  });

  final GnController controller;
  final Toolbar spec;

  /// The floating layout's controls (see FloatEditorBar), drawn at the top
  /// over the page; null for the layout with the top bar. With them the
  /// tool's options hang centred under the tool box instead of from the
  /// left of the bar, and undo and redo are in the tool box.
  final Widget? topBar;

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
    final floating = widget.topBar != null;
    final strip = floating && !controller.quickControls
        ? null
        : _strip(context, actions);
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
          if (floating)
            Positioned(
              top:
                  MediaQuery.viewPaddingOf(context).top +
                  FloatEditorBar.spacing,
              left:
                  FloatEditorBar.spacing +
                  MediaQuery.viewPaddingOf(context).left,
              right:
                  FloatEditorBar.spacing +
                  MediaQuery.viewPaddingOf(context).right,
              child: widget.topBar!,
            ),
          if (floating && strip != null)
            Positioned(
              top: 0,
              left: 0,
              child: CompositedTransformFollower(
                link: controller.barLink,
                targetAnchor: Alignment.bottomCenter,
                followerAnchor: Alignment.topCenter,
                offset: const Offset(0, FloatEditorBar.spacing),
                showWhenUnlinked: false,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.sizeOf(context).width - 24,
                  ),
                  child: strip,
                ),
              ),
            ),
          if (!floating && strip != null)
            Positioned(
              top: 0,
              left: 0,
              child: CompositedTransformFollower(
                link: controller.barLink,
                targetAnchor: Alignment.bottomLeft,
                followerAnchor: Alignment.topLeft,
                offset: const Offset(12, 8),
                showWhenUnlinked: false,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.sizeOf(context).width - 24,
                  ),
                  child: strip,
                ),
              ),
            ),
          if (panel != GnPanel.none)
            _panelAt(context, panel, actions, stripShown: strip != null),
          if (!widget.spec.readOnly && !widget.spec.textEditing)
            Positioned.fill(
              child: ValueListenableBuilder<bool>(
                valueListenable: stows.penFan,
                builder: (context, on, _) =>
                    on ? PenFan(actions: actions) : const SizedBox.shrink(),
              ),
            ),
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
                    icon: const Icon(Symbols.note_add_rounded),
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
      final floating = widget.topBar != null;
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
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
              icon: Icon(Symbols.palette_rounded, color: colors.onSurface),
              onPressed: () => widget.controller.toggle(GnPanel.color),
            ),
          ),
          if (floating)
            IconButton(
              key: const Key('floatPenDetails'),
              tooltip: DefterStrings.floatPenDetails,
              icon: Icon(Symbols.tune_rounded, color: colors.onSurface),
              isSelected: widget.controller.panel == GnPanel.penSettings,
              onPressed: () => widget.controller.toggle(GnPanel.penSettings),
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
    return FloatingPanel(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: content,
      ),
    );
  }

  Widget _panelAt(
    BuildContext context,
    GnPanel panel,
    GnActions actions, {
    required bool stripShown,
  }) {
    final floating = widget.topBar != null;
    final controller = widget.controller;
    final spec = widget.spec;
    final rightSide = panel == GnPanel.export || panel == GnPanel.more;
    final width = MediaQuery.sizeOf(context).width;
    final Widget body;
    switch (panel) {
      case GnPanel.penSettings:
        // The pen panel hangs from the left of the bar and brings its own
        // cards (the settings, and the profiles next to them).
        return Positioned(
          top: 0,
          left: 0,
          child: CompositedTransformFollower(
            link: controller.barLink,
            targetAnchor: floating
                ? Alignment.bottomCenter
                : Alignment.bottomLeft,
            followerAnchor: floating ? Alignment.topCenter : Alignment.topLeft,
            // In the floating layout: under the tool box, and under the
            // tool's options when they are shown.
            offset: floating
                ? Offset(
                    0,
                    FloatEditorBar.spacing +
                        (stripShown
                            ? FloatEditorBar.capsuleHeight +
                                  FloatEditorBar.spacing
                            : 0),
                  )
                : const Offset(12, 8),
            showWhenUnlinked: false,
            child: Appear(
              alignment: floating ? Alignment.topCenter : Alignment.topLeft,
              child: GnPenSettings(
                getTool: () => spec.currentTool,
                setTool: spec.setTool,
                setColor: spec.setColor,
                onClose: controller.close,
                openColorPicker: () => controller.toggle(GnPanel.color),
                toggleGrid: spec.toggleGrid,
                gridOn: spec.gridOn,
                // From under the bar (the panel hangs 8 below it) to just
                // above the bottom of the screen.
                maxHeight: math.max(
                  80.0,
                  MediaQuery.sizeOf(context).height -
                      MediaQuery.viewPaddingOf(context).vertical -
                      (floating
                          ? FloatEditorBar.reservedHeight(
                              MediaQuery.sizeOf(context).width,
                            )
                          : GnEditorBar.contentHeight) -
                      20,
                ),
              ),
            ),
          ),
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
        link: floating ? controller.links[panel]! : controller.barLink,
        targetAnchor: rightSide
            ? Alignment.bottomRight
            : floating
            ? Alignment.bottomCenter
            : Alignment.bottomLeft,
        followerAnchor: rightSide
            ? Alignment.topRight
            : floating
            ? Alignment.topCenter
            : Alignment.topLeft,
        offset: Offset(
          floating
              ? 0
              : rightSide
              ? -12
              : 12,
          8,
        ),
        showWhenUnlinked: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: width - 24,
            maxHeight: math.max(
              80,
              MediaQuery.sizeOf(context).height -
                  MediaQuery.viewPaddingOf(context).vertical -
                  (floating
                      ? FloatEditorBar.reservedHeight(width)
                      : GnEditorBar.contentHeight) -
                  24,
            ),
          ),
          child: Appear(
            key: ValueKey(panel),
            alignment: rightSide ? Alignment.topRight : Alignment.topCenter,
            child: FloatingPanel(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(10),
                child: body,
              ),
            ),
          ),
        ),
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
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              dense: true,
              leading: const Icon(Symbols.highlight_alt_rounded),
              title: Text(t.editor.pens.laserPointer),
              onTap: actions.selectLaser,
            ),
            const Divider(height: 8),
            ListTile(
              dense: true,
              leading: const Icon(Symbols.vertical_align_center_rounded),
              title: Text(DefterStrings.insertTools),
              subtitle: Text(
                '${DefterStrings.toolTable}, ${DefterStrings.toolStickyNote}, ${DefterStrings.toolSticker}',
              ),
            ),
            _insertToolTile(
              actions,
              NotewiseInsertTool.tape,
              Symbols.sticky_note_2_rounded,
              DefterStrings.toolTape,
            ),
            _insertToolTile(
              actions,
              NotewiseInsertTool.table,
              Symbols.table_chart_rounded,
              DefterStrings.toolTable,
            ),
            _insertToolTile(
              actions,
              NotewiseInsertTool.stickyNote,
              Symbols.note_alt_rounded,
              DefterStrings.toolStickyNote,
            ),
            _insertToolTile(
              actions,
              NotewiseInsertTool.sticker,
              Symbols.stars_rounded,
              DefterStrings.toolSticker,
            ),
            _insertToolTile(
              actions,
              NotewiseInsertTool.widget,
              Symbols.dashboard_customize_rounded,
              DefterStrings.toolWidget,
            ),
            _insertToolTile(
              actions,
              NotewiseInsertTool.zoomBox,
              Symbols.zoom_in_map_rounded,
              DefterStrings.toolZoomBox,
            ),
            if (!stows.hideFingerDrawingToggle.value)
              ValueListenableBuilder(
                valueListenable: stows.editorFingerDrawing,
                builder: (context, value, _) => SwitchListTile(
                  dense: true,
                  secondary: const Icon(Symbols.touch_app_rounded),
                  title: Text(t.editor.toolbar.toggleFingerDrawing),
                  value: value,
                  onChanged: spec.readOnly
                      ? null
                      : (_) => spec.toggleFingerDrawing(),
                ),
              ),
            ListTile(
              dense: true,
              leading: const Icon(Symbols.fullscreen_rounded),
              title: Text(t.editor.toolbar.fullscreen),
              onTap: () {
                controller.close();
                DynamicMaterialApp.setFullscreen(true, updateSystem: true);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _insertToolTile(
    GnActions actions,
    NotewiseInsertTool tool,
    IconData icon,
    String title,
  ) => ListTile(
    dense: true,
    leading: Icon(icon),
    title: Text(title),
    enabled: !spec.readOnly && spec.insertNotewiseTool != null,
    onTap: () => actions.insertNotewiseTool(tool),
  );
}
