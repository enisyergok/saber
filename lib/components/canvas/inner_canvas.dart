import 'dart:ui' as ui;

import 'package:defer_pointer/defer_pointer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:go_router/go_router.dart';
import 'package:one_dollar_unistroke_recognizer/one_dollar_unistroke_recognizer.dart';
import 'package:saber/components/canvas/_canvas_background_painter.dart';
import 'package:saber/components/canvas/_canvas_painter.dart';
import 'package:saber/components/canvas/_stroke.dart';
import 'package:saber/components/canvas/canvas_image.dart';
import 'package:saber/components/canvas/image/editor_image.dart';
import 'package:saber/components/eink/eink_scope.dart';
import 'package:saber/data/eink/eink_style.dart';
import 'package:saber/data/eink/eink_texture.dart';
import 'package:saber/data/editor/editor_core_info.dart';
import 'package:saber/data/links/note_link.dart';
import 'package:saber/data/routes.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/tools/select.dart';
import 'package:saber/i18n/strings.g.dart';
import 'package:sbn/canvas_background_pattern.dart';
import 'package:sbn/quill_styles.dart';
import 'package:url_launcher/url_launcher.dart';

class InnerCanvas extends StatefulWidget {
  const new({
    super.key,
    required this.pageIndex,
    this.redrawPageListenable,
    this.liveInkListenable,
    required this.width,
    required this.height,
    this.showPageIndicator = true,
    this.textEditing = false,
    required this.coreInfo,
    required this.currentStroke,
    required this.currentStrokeDetectedShape,
    required this.currentSelection,
    this.setAsBackground,
    this.onRenderObjectChange,
    required this.currentToolIsSelect,
    required this.currentScale,
  });

  final int pageIndex;
  final Listenable? redrawPageListenable;

  /// Fires on every pen move; repaints only the live ink layer.
  /// Defaults to [redrawPageListenable].
  final Listenable? liveInkListenable;
  final double width;
  final double height;
  final bool showPageIndicator;
  final bool textEditing;
  final EditorCoreInfo coreInfo;
  final Stroke? currentStroke;
  final RecognizedUnistroke? currentStrokeDetectedShape;
  final SelectResult? currentSelection;
  final void Function(EditorImage image)? setAsBackground;
  final ValueChanged<RenderObject>? onRenderObjectChange;

  final bool currentToolIsSelect;

  final double currentScale;

  static const defaultBackgroundColor = Color(0xFFFCFCFC);

  @override
  State<InnerCanvas> createState() => _InnerCanvasState();
}

class _InnerCanvasState extends State<InnerCanvas> {
  int _loadingGrainStep = 0;

  /// The paper grain for e-ink mode, once its tile has been made.
  ui.Image? _grainFor(EInkStyle? eInk) {
    final step = eInk?.textureStep ?? 0;
    if (step == 0) return null;
    final ready = EInkTexture.readyImage(step);
    if (ready != null) return ready;
    if (_loadingGrainStep != step) {
      _loadingGrainStep = step;
      EInkTexture.load(step, maxAlpha: EInkStyle.maxGrainAlpha).then((_) {
        if (mounted) setState(() {});
      });
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final brightness = theme.brightness;
    final eInk = EInkScope.maybeOf(context);
    final invert =
        stows.editorAutoInvert.value && brightness == .dark && eInk == null;
    final Color backgroundColor =
        widget.coreInfo.backgroundColor ?? InnerCanvas.defaultBackgroundColor;
    final grain = _grainFor(eInk);

    if (widget.coreInfo.pages.isEmpty) {
      return SizedBox(width: widget.width, height: widget.height);
    }

    final page = widget.coreInfo.pages[widget.pageIndex];

    final quillEditor = widget.coreInfo.pages.isNotEmpty
        ? QuillEditor(
            controller:
                widget.coreInfo.pages[widget.pageIndex].quill.controller,
            config: QuillEditorConfig(
              customStyles: SaberQuillStyles.get(
                invert: invert,
                secondary: colorScheme.secondary,
                lineHeight: widget.coreInfo.lineHeight,
              ),
              scrollable: false,
              autoFocus: false,
              expands: true,
              placeholder: widget.textEditing
                  ? t.editor.quill.typeSomething
                  : null,
              showCursor: true,
              keyboardAppearance: invert ? .dark : .light,
              padding: .only(
                top: widget.coreInfo.lineHeight * 1.2,
                left: widget.coreInfo.lineHeight * 0.5,
                right: widget.coreInfo.lineHeight * 0.5,
                bottom: widget.coreInfo.lineHeight * 0.5,
              ),
              showCodeBlockLineNumbers: false,
              onLaunchUrl: (url) async {
                final notePath = NoteLink.decode(url);
                if (notePath != null) {
                  context.push(RoutePaths.editFilePath(notePath));
                } else {
                  final uri = Uri.tryParse(url);
                  if (uri != null) await launchUrl(uri);
                }
              },
            ),
            scrollController: ScrollController(),
            focusNode: widget.coreInfo.pages[widget.pageIndex].quill.focusNode,
          )
        : null;

    final staticPage = RepaintBoundary(
      child: CustomPaint(
        painter: CanvasBackgroundPainter(
          invert: invert,
          eInk: eInk != null,
          grain: grain,
          backgroundColor: () {
            final Color color = page.backgroundImage != null
                ? Colors.white
                : backgroundColor;
            return eInk?.mapPaper(color) ?? color;
          }(),
          backgroundPattern: () {
            if (page.backgroundImage != null) {
              return CanvasBackgroundPattern.none;
            } else {
              return widget.coreInfo.backgroundPattern;
            }
          }(),
          lineHeight: widget.coreInfo.lineHeight,
          lineThickness: widget.coreInfo.lineThickness,
          primaryColor: colorScheme.primary,
          secondaryColor: colorScheme.secondary,
        ),
        foregroundPainter: CanvasPainter(
          layer: .dry,
          repaint: widget.redrawPageListenable,
          invert: invert,
          eInk: eInk,
          strokes: page.strokes,
          laserStrokes: page.laserStrokes,
          currentStroke: widget.currentStroke,
          currentSelection: widget.currentSelection,
          primaryColor: colorScheme.primary,
          page: page,
          showPageIndicator: widget.showPageIndicator,
          pageIndex: widget.pageIndex,
          totalPages: widget.coreInfo.pages.length,
          currentScale: widget.currentScale,
          defaultTextStyle: theme.textTheme.bodyMedium!,
        ),
        isComplex: true,
        // The finished strokes don't change while writing (only the live
        // layer on top does), so the engine may keep them as a bitmap.
        willChange: false,
        child: SizedBox(
          width: widget.width,
          height: widget.height,
          child: DeferredPointerHandler(
            child: Stack(
              children: [
                if (page.backgroundImage != null)
                  CanvasImage(
                    filePath: widget.coreInfo.filePath,
                    image: page.backgroundImage!,
                    pageSize: Size(widget.width, widget.height),
                    setAsBackground: null,
                    isBackground: true,
                    readOnly: true,
                  ),
                Positioned(
                  top: 0,
                  left: 0,
                  width: widget.width,
                  height: widget.height,
                  child: IgnorePointer(
                    ignoring: widget.coreInfo.readOnly || !widget.textEditing,
                    child: quillEditor,
                  ),
                ),
                for (int i = 0; i < page.images.length; i++)
                  CanvasImage(
                    filePath: widget.coreInfo.filePath,
                    image: page.images[i],
                    pageSize: Size(widget.width, widget.height),
                    setAsBackground: widget.setAsBackground,
                    readOnly:
                        widget.coreInfo.readOnly || !widget.currentToolIsSelect,
                    selected:
                        widget.currentSelection?.images.contains(
                          page.images[i],
                        ) ??
                        false,
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    // The live ink layer sits above the page in its own repaint boundary, so
    // drawing a stroke only repaints this layer, not the page below it.
    return Stack(
      children: [
        staticPage,
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: CanvasPainter(
                  layer: .live,
                  repaint:
                      widget.liveInkListenable ?? widget.redrawPageListenable,
                  invert: invert,
                  eInk: eInk,
                  strokes: page.strokes,
                  laserStrokes: page.laserStrokes,
                  currentStroke: widget.currentStroke,
                  currentSelection: widget.currentSelection,
                  primaryColor: colorScheme.primary,
                  page: page,
                  showPageIndicator: widget.showPageIndicator,
                  pageIndex: widget.pageIndex,
                  totalPages: widget.coreInfo.pages.length,
                  currentScale: widget.currentScale,
                  defaultTextStyle: theme.textTheme.bodyMedium!,
                ),
                isComplex: false,
                willChange: true,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
