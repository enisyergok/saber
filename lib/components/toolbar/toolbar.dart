import 'dart:io';

import 'package:collapsible/collapsible.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:saber/components/toolbar/note_link_dialog.dart';
import 'package:saber/data/defter_strings.dart';
import 'package:saber/data/links/note_link.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:keybinder/keybinder.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:saber/components/theming/adaptive_icon.dart';
import 'package:saber/components/theming/dynamic_material_app.dart';
import 'package:saber/components/theming/uni_icon.dart';
import 'package:saber/components/toolbar/color_bar.dart';
import 'package:saber/components/toolbar/export_bar.dart';
import 'package:saber/components/toolbar/pen_modal.dart';
import 'package:saber/components/toolbar/quick_style_bar.dart';
import 'package:saber/components/toolbar/selection_bar.dart';
import 'package:saber/components/toolbar/size_picker.dart';
import 'package:saber/components/toolbar/toolbar_button.dart';
import 'package:saber/data/editor/page.dart';
import 'package:saber/data/extensions/color_extensions.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/tools/_tool.dart';
import 'package:saber/data/tools/eraser.dart';
import 'package:saber/data/tools/highlighter.dart';
import 'package:saber/data/tools/laser_pointer.dart';
import 'package:saber/data/tools/pen.dart';
import 'package:saber/data/tools/pencil.dart';
import 'package:saber/data/tools/select.dart';
import 'package:saber/data/tools/shape_pen.dart';
import 'package:saber/i18n/strings.g.dart';

class Toolbar extends StatefulWidget {
  const new({
    super.key,
    required this.readOnly,
    required this.setTool,
    required this.currentTool,
    required this.setColor,
    required this.quillFocus,
    required this.textEditing,
    required this.toggleTextEditing,
    required this.undo,
    required this.isUndoPossible,
    required this.redo,
    required this.isRedoPossible,
    required this.toggleFingerDrawing,
    required this.pickPhoto,
    this.takePhoto,
    required this.paste,
    required this.duplicateSelection,
    required this.deleteSelection,
    required this.recognizeSelection,
    this.currentNotePath,
    required this.exportAsSba,
    required this.exportAsPdf,
    required this.exportAsPng,
    this.toggleGrid,
    this.gridOn = false,
  });

  final bool readOnly;

  final ValueChanged<Tool> setTool;
  final Tool currentTool;
  final ValueChanged<Color> setColor;

  final ValueNotifier<QuillStruct?> quillFocus;
  final bool textEditing;
  final VoidCallback toggleTextEditing;

  final VoidCallback undo;
  final bool isUndoPossible;
  final VoidCallback redo;
  final bool isRedoPossible;

  final VoidCallback toggleFingerDrawing;

  final VoidCallback pickPhoto;

  /// Takes a photo with the camera, or null if the device can't.
  final VoidCallback? takePhoto;

  final VoidCallback paste;

  final VoidCallback duplicateSelection;
  final VoidCallback deleteSelection;
  final VoidCallback recognizeSelection;

  /// The path of the note being edited, left out of the link picker.
  final String? currentNotePath;

  final Future Function(BuildContext)? exportAsSba;
  final Future Function(BuildContext)? exportAsPdf;
  final Future Function(BuildContext)? exportAsPng;

  /// Switches the page's squared paper on and off (the grid of the pen
  /// panel), if the note can be changed.
  final VoidCallback? toggleGrid;

  /// Whether the page is on squared paper.
  final bool gridOn;

  @override
  State<Toolbar> createState() => _ToolbarState();

  static const _buttonPaddingHorizontal = EdgeInsets.symmetric(horizontal: 6);
  static const _buttonPaddingVertical = EdgeInsets.symmetric(vertical: 6);
}

class _ToolbarState extends State<Toolbar> {
  ValueNotifier<bool> showExportOptions = ValueNotifier(false);
  ValueNotifier<bool> showColorOptions = ValueNotifier(false);
  ValueNotifier<ToolOptions> toolOptionsType = ValueNotifier(ToolOptions.hide);

  /// The pen that was in use before the shape button was pressed, so
  /// pressing it again (or the pen button) goes back to it.
  Pen? _penBeforeShape;

  /// The pen the pen button stands for: never the shape pen, which has a
  /// button of its own.
  Pen get _writingPen => Pen.currentPen is ShapePen
      ? (_penBeforeShape ?? Pen.fountainPen())
      : Pen.currentPen;

  void toggleShapePen() {
    toolOptionsType.value = .hide;
    if (widget.currentTool is ShapePen) {
      widget.setTool(_writingPen);
    } else {
      if (Pen.currentPen is! ShapePen) _penBeforeShape = Pen.currentPen;
      widget.setTool(ShapePen());
    }
  }

  /// A thin line between groups of buttons.
  Widget _groupDivider(bool vertical, ColorScheme colorScheme) {
    return Padding(
      padding: vertical
          ? const EdgeInsets.symmetric(vertical: 4)
          : const EdgeInsets.symmetric(horizontal: 4),
      child: SizedBox(
        width: vertical ? 24 : 1,
        height: vertical ? 1 : 24,
        child: ColoredBox(color: colorScheme.outlineVariant),
      ),
    );
  }

  @override
  void initState() {
    _assignKeybindings();

    DynamicMaterialApp.addFullscreenListener(_setState);

    super.initState();
  }

  void _setState() => setState(() {});

  Keybinding? _ctrlF;
  Keybinding? _ctrlE;
  Keybinding? _ctrlC;
  Keybinding? _ctrlShiftS;
  Keybinding? _f11;
  Keybinding? _ctrlV;
  void _assignKeybindings() {
    _ctrlF = Keybinding([
      KeyCode.ctrl,
      KeyCode.from(LogicalKeyboardKey.keyF),
    ], inclusive: true);
    _ctrlE = Keybinding([
      KeyCode.ctrl,
      KeyCode.from(LogicalKeyboardKey.keyE),
    ], inclusive: true);
    _ctrlC = Keybinding([
      KeyCode.ctrl,
      KeyCode.from(LogicalKeyboardKey.keyC),
    ], inclusive: true);
    _ctrlShiftS = Keybinding([
      KeyCode.ctrl,
      KeyCode.shift,
      KeyCode.from(LogicalKeyboardKey.keyS),
    ], inclusive: true);
    _f11 = Keybinding([KeyCode.from(LogicalKeyboardKey.f11)], inclusive: true);
    _ctrlV = Keybinding([
      KeyCode.ctrl,
      KeyCode.from(LogicalKeyboardKey.keyV),
    ], inclusive: true);

    Keybinder.bind(_ctrlF!, widget.toggleFingerDrawing);
    Keybinder.bind(_ctrlE!, toggleEraser);
    Keybinder.bind(_ctrlC!, toggleColorOptions);
    Keybinder.bind(_ctrlShiftS!, toggleExportBar);
    Keybinder.bind(_f11!, toggleFullscreen);
    Keybinder.bind(_ctrlV!, widget.paste);
  }

  void _removeKeybindings() {
    if (_ctrlF != null) Keybinder.remove(_ctrlF!);
    if (_ctrlE != null) Keybinder.remove(_ctrlE!);
    if (_ctrlC != null) Keybinder.remove(_ctrlC!);
    if (_ctrlShiftS != null) Keybinder.remove(_ctrlShiftS!);
    if (_f11 != null) Keybinder.remove(_f11!);
    if (_ctrlV != null) Keybinder.remove(_ctrlV!);
  }

  void toggleEraser() {
    toolOptionsType.value = .hide;
    widget.setTool(Eraser()); // this toggles eraser
  }

  void toggleColorOptions() {
    showColorOptions.value = !showColorOptions.value;
  }

  void toggleExportBar() {
    showExportOptions.value = !showExportOptions.value;
  }

  void toggleFullscreen() async {
    DynamicMaterialApp.setFullscreen(
      !DynamicMaterialApp.isFullscreen,
      updateSystem: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);

    final brightness = Theme.brightnessOf(context);
    final invert = stows.editorAutoInvert.value && brightness == .dark;

    final isToolbarVertical =
        stows.editorToolbarAlignment.value == AxisDirection.left ||
        stows.editorToolbarAlignment.value == AxisDirection.right;

    final buttonPadding = isToolbarVertical
        ? Toolbar._buttonPaddingVertical
        : Toolbar._buttonPaddingHorizontal;

    final currentColor = switch (widget.currentTool) {
      final Pen pen => pen.color,
      final Select select => select.getDominantStrokeColor(),
      _ => null,
    };

    if (widget.currentTool == Select.currentSelect) {
      // Enable selection bar only when selection is done
      toolOptionsType.value = Select.currentSelect.doneSelecting
          ? .select
          : .hide;
    }

    final bars = <Widget>[
      ValueListenableBuilder(
        valueListenable: showExportOptions,
        builder: (context, showExportOptions, child) {
          return Collapsible(
            axis: isToolbarVertical
                ? CollapsibleAxis.horizontal
                : CollapsibleAxis.vertical,
            maintainState: true,
            collapsed: !showExportOptions,
            child: child!,
          );
        },
        child: ExportBar(
          axis: isToolbarVertical ? Axis.vertical : Axis.horizontal,
          toggleExportBar: toggleExportBar,
          exportAsSba: widget.exportAsSba,
          exportAsPdf: widget.exportAsPdf,
          exportAsPng: widget.exportAsPng,
        ),
      ),
      ValueListenableBuilder(
        valueListenable: toolOptionsType,
        builder: (context, toolOptionsType, _) {
          return Collapsible(
            axis: isToolbarVertical
                ? CollapsibleAxis.horizontal
                : CollapsibleAxis.vertical,
            maintainState: true,
            collapsed: toolOptionsType == .hide,
            child: switch (toolOptionsType) {
              .hide => const SizedBox.square(dimension: SizePicker.smallLength),
              .pen => PenModal(
                getTool: () => Pen.currentPen,
                setTool: widget.setTool,
              ),
              .highlighter => PenModal(
                getTool: () => Highlighter.currentHighlighter,
                setTool: widget.setTool,
              ),
              .pencil => PenModal(
                getTool: () => Pencil.currentPencil,
                setTool: widget.setTool,
              ),
              .select => SelectionBar(
                duplicateSelection: widget.duplicateSelection,
                deleteSelection: widget.deleteSelection,
                recognizeSelection: widget.recognizeSelection,
              ),
            },
          );
        },
      ),
      ValueListenableBuilder(
        valueListenable: showColorOptions,
        builder: (context, showColorOptions, child) {
          return Collapsible(
            axis: isToolbarVertical
                ? CollapsibleAxis.horizontal
                : CollapsibleAxis.vertical,
            maintainState: true,
            collapsed: !showColorOptions,
            child: child!,
          );
        },
        child: ColorBar(
          axis: isToolbarVertical ? Axis.vertical : Axis.horizontal,
          setColor: widget.setColor,
          currentColor: currentColor,
          invert: invert,
        ),
      ),
      ValueListenableBuilder(
        valueListenable: widget.quillFocus,
        builder: (context, quill, _) {
          final baseButtonStyle =
              IconButtonTheme.of(context).style ?? const ButtonStyle();

          final iconTheme = QuillIconTheme(
            iconButtonUnselectedData: IconButtonData(
              style: baseButtonStyle.copyWith(
                backgroundColor: WidgetStateProperty.all(Colors.transparent),
                foregroundColor: WidgetStateProperty.all(colorScheme.primary),
              ),
            ),
            iconButtonSelectedData: IconButtonData(
              style: baseButtonStyle.copyWith(
                backgroundColor: WidgetStateProperty.all(colorScheme.primary),
                foregroundColor: WidgetStateProperty.all(colorScheme.onPrimary),
              ),
            ),
          );
          return Collapsible(
            axis: isToolbarVertical
                ? CollapsibleAxis.horizontal
                : CollapsibleAxis.vertical,
            maintainState: false,
            collapsed: !widget.textEditing || quill == null,
            child: quill != null
                ? QuillSimpleToolbar(
                    controller: quill.controller,
                    config: QuillSimpleToolbarConfig(
                      axis: isToolbarVertical ? Axis.vertical : Axis.horizontal,
                      buttonOptions: QuillSimpleToolbarButtonOptions(
                        base: QuillToolbarBaseButtonOptions(
                          iconTheme: iconTheme,
                        ),
                      ),
                      // scrollable on Android and iOS
                      multiRowsDisplay: !Platform.isAndroid && !Platform.isIOS,
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
                              excludePath: widget.currentNotePath,
                            );
                            if (path == null) return;
                            NoteLink.apply(quill.controller, path);
                          },
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          );
        },
      ),
      Center(
        child: Padding(
          padding: const .all(8),
          child: Wrap(
            direction: isToolbarVertical ? Axis.vertical : Axis.horizontal,
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 8,
            children: [
              ToolbarIconButton(
                tooltip: _writingPen.name,
                selected:
                    widget.currentTool == Pen.currentPen &&
                    widget.currentTool is! ShapePen,
                enabled: !widget.readOnly,
                onPressed: () {
                  if (widget.currentTool == Pen.currentPen &&
                      widget.currentTool is! ShapePen) {
                    if (toolOptionsType.value == .pen) {
                      toolOptionsType.value = .hide;
                    } else {
                      toolOptionsType.value = .pen;
                    }
                  } else {
                    toolOptionsType.value = .hide;
                    widget.setTool(_writingPen);
                  }
                },
                padding: buttonPadding,
                child: UniIcon(_writingPen.icon, size: 16),
              ),
              ToolbarIconButton(
                tooltip: t.editor.pens.pencil,
                selected: widget.currentTool == Pencil.currentPencil,
                enabled: !widget.readOnly,
                onPressed: () {
                  if (widget.currentTool == Pencil.currentPencil) {
                    if (toolOptionsType.value == .pencil) {
                      toolOptionsType.value = .hide;
                    } else {
                      toolOptionsType.value = .pencil;
                    }
                  } else {
                    toolOptionsType.value = .hide;
                    widget.setTool(Pencil.currentPencil);
                  }
                },
                padding: buttonPadding,
                child: const FaIcon(Pencil.pencilIcon, size: 16),
              ),
              ToolbarIconButton(
                tooltip: t.editor.pens.highlighter,
                selected: widget.currentTool == Highlighter.currentHighlighter,
                enabled: !widget.readOnly,
                onPressed: () {
                  if (widget.currentTool == Highlighter.currentHighlighter) {
                    if (toolOptionsType.value == .highlighter) {
                      toolOptionsType.value = .hide;
                    } else {
                      toolOptionsType.value = .highlighter;
                    }
                  } else {
                    toolOptionsType.value = .hide;
                    widget.setTool(Highlighter.currentHighlighter);
                  }
                },
                padding: buttonPadding,
                child: const FaIcon(Highlighter.highlighterIcon, size: 16),
              ),
              ToolbarIconButton(
                tooltip: t.editor.pens.shapePen,
                selected: widget.currentTool is ShapePen,
                enabled: !widget.readOnly,
                onPressed: toggleShapePen,
                padding: buttonPadding,
                child: const FaIcon(ShapePen.shapePenIcon, size: 16),
              ),
              ValueListenableBuilder(
                valueListenable: showColorOptions,
                builder: (context, showColorOptions, child) {
                  return ToolbarIconButton(
                    tooltip: t.editor.toolbar.toggleColors,
                    selected: showColorOptions,
                    enabled: !widget.readOnly,
                    onPressed: toggleColorOptions,
                    padding: buttonPadding,
                    child: child!,
                  );
                },
                child: currentColor == null
                    ? const Icon(Icons.palette)
                    : Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: currentColor
                              .withInversion(invert)
                              .withValues(alpha: 1),
                          shape: .circle,
                          border: Border.all(
                            color: colorScheme.primary,
                            width: 2,
                          ),
                        ),
                      ),
              ),
              _groupDivider(isToolbarVertical, colorScheme),
              ToolbarIconButton(
                tooltip: t.editor.toolbar.select,
                selected: widget.currentTool is Select,
                enabled: !widget.readOnly,
                onPressed: () {
                  toolOptionsType.value = .hide;
                  widget.setTool(Select.currentSelect);
                },
                padding: buttonPadding,
                child: Icon(
                  CupertinoIcons.lasso,
                  shadows: !widget.readOnly
                      ? [
                          BoxShadow(
                            color: colorScheme.primary,
                            blurRadius: 0.1,
                            spreadRadius: 10,
                            blurStyle: BlurStyle.solid,
                          ),
                        ]
                      : null,
                ),
              ),
              ToolbarIconButton(
                tooltip: t.editor.toolbar.toggleEraser,
                selected: widget.currentTool is Eraser,
                enabled: !widget.readOnly,
                onPressed: toggleEraser,
                padding: buttonPadding,
                child: const FaIcon(FontAwesomeIcons.eraser, size: 16),
              ),
              ToolbarIconButton(
                tooltip: t.editor.pens.laserPointer,
                selected:
                    widget.currentTool == LaserPointer.currentLaserPointer,
                enabled: true, // even in read-only mode
                onPressed: () {
                  toolOptionsType.value = .hide;
                  widget.setTool(LaserPointer.currentLaserPointer);
                },
                padding: buttonPadding,
                child: const Icon(Symbols.stylus_laser_pointer),
              ),
              _groupDivider(isToolbarVertical, colorScheme),
              ToolbarIconButton(
                tooltip: t.editor.toolbar.photo,
                enabled: !widget.readOnly,
                onPressed: widget.pickPhoto,
                padding: buttonPadding,
                child: const AdaptiveIcon(
                  icon: Icons.photo,
                  cupertinoIcon: CupertinoIcons.photo,
                ),
              ),
              if (widget.takePhoto != null)
                ToolbarIconButton(
                  key: const Key('takePhoto'),
                  tooltip: DefterStrings.takePhoto,
                  enabled: !widget.readOnly,
                  onPressed: widget.takePhoto,
                  padding: buttonPadding,
                  child: const AdaptiveIcon(
                    icon: Icons.photo_camera,
                    cupertinoIcon: CupertinoIcons.camera,
                  ),
                ),
              ToolbarIconButton(
                tooltip: t.editor.toolbar.text,
                selected: widget.textEditing,
                enabled: !widget.readOnly,
                onPressed: widget.toggleTextEditing,
                padding: buttonPadding,
                child: const AdaptiveIcon(
                  icon: Icons.text_fields,
                  cupertinoIcon: CupertinoIcons.text_cursor,
                ),
              ),
              _groupDivider(isToolbarVertical, colorScheme),
              Wrap(
                direction: isToolbarVertical ? Axis.vertical : Axis.horizontal,
                children: [
                  ToolbarIconButton(
                    tooltip: t.editor.toolbar.undo,
                    enabled: !widget.readOnly && widget.isUndoPossible,
                    onPressed: widget.undo,
                    padding: buttonPadding,
                    child: const AdaptiveIcon(
                      icon: Icons.undo,
                      cupertinoIcon: CupertinoIcons.arrow_uturn_left,
                    ),
                  ),
                  ToolbarIconButton(
                    tooltip: t.editor.toolbar.redo,
                    enabled: !widget.readOnly && widget.isRedoPossible,
                    onPressed: widget.redo,
                    padding: buttonPadding,
                    child: const AdaptiveIcon(
                      icon: Icons.redo,
                      cupertinoIcon: CupertinoIcons.arrow_uturn_right,
                    ),
                  ),
                ],
              ),
              _groupDivider(isToolbarVertical, colorScheme),
              if (!stows.hideFingerDrawingToggle.value)
                ValueListenableBuilder(
                  valueListenable: stows.editorFingerDrawing,
                  builder: (context, value, child) {
                    return ToolbarIconButton(
                      tooltip: t.editor.toolbar.toggleFingerDrawing,
                      selected: value,
                      enabled: !widget.readOnly,
                      onPressed: widget.toggleFingerDrawing,
                      padding: buttonPadding,
                      child: const Icon(CupertinoIcons.hand_draw),
                    );
                  },
                ),
              ToolbarIconButton(
                tooltip: t.editor.toolbar.fullscreen,
                selected: DynamicMaterialApp.isFullscreen,
                enabled: !widget.readOnly,
                onPressed: toggleFullscreen,
                padding: buttonPadding,
                child: AdaptiveIcon(
                  icon: DynamicMaterialApp.isFullscreen
                      ? Icons.fullscreen_exit
                      : Icons.fullscreen,
                  cupertinoIcon: DynamicMaterialApp.isFullscreen
                      ? CupertinoIcons.fullscreen_exit
                      : CupertinoIcons.fullscreen,
                ),
              ),
              ValueListenableBuilder(
                valueListenable: showExportOptions,
                builder: (context, showExportOptions, child) {
                  return ToolbarIconButton(
                    tooltip: t.editor.toolbar.export,
                    selected: showExportOptions,
                    enabled: !widget.readOnly,
                    onPressed: toggleExportBar,
                    padding: buttonPadding,
                    child: child!,
                  );
                },
                child: const AdaptiveIcon(
                  icon: Icons.share,
                  cupertinoIcon: CupertinoIcons.share,
                ),
              ),
              if (!isToolbarVertical && !widget.readOnly)
                if (widget.currentTool case final Pen pen)
                  QuickStyleBar(
                    pen: pen,
                    currentColor: currentColor,
                    invert: invert,
                    setColor: widget.setColor,
                    onSizeChanged: _setState,
                  )
                else if (widget.currentTool case final Eraser eraser)
                  EraserSizeBar(eraser: eraser, onSizeChanged: _setState),
            ],
          ),
        ),
      ),
    ];

    final edge = BorderSide(color: colorScheme.outlineVariant);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        // A line on the side that faces the page.
        border: switch (stows.editorToolbarAlignment.value) {
          AxisDirection.up => Border(bottom: edge),
          AxisDirection.left => Border(right: edge),
          AxisDirection.right => Border(left: edge),
          _ => Border(top: edge),
        },
      ),
      child: Flex(
      direction: isToolbarVertical ? Axis.horizontal : Axis.vertical,
      textDirection: switch (stows.editorToolbarAlignment.value) {
        AxisDirection.left => .rtl,
        AxisDirection.right => .ltr,
        _ => null,
      },
      verticalDirection: switch (stows.editorToolbarAlignment.value) {
        AxisDirection.down => VerticalDirection.down,
        AxisDirection.up => VerticalDirection.up,
        _ => VerticalDirection.down,
      },
      children: bars,
      ),
    );
  }

  @override
  void dispose() {
    DynamicMaterialApp.removeFullscreenListener(_setState);
    DynamicMaterialApp.setFullscreen(false, updateSystem: true);

    _removeKeybindings();
    super.dispose();
  }
}

enum ToolOptions { hide, pen, highlighter, pencil, select }
