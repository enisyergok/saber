import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:one_dollar_unistroke_recognizer/one_dollar_unistroke_recognizer.dart';
import 'package:path_drawing/path_drawing.dart';
import 'package:perfect_freehand/perfect_freehand.dart';
import 'package:saber/components/canvas/_circle_stroke.dart';
import 'package:saber/components/canvas/_rectangle_stroke.dart';
import 'package:saber/components/canvas/_stroke.dart';
import 'package:saber/data/editor/page.dart';
import 'package:saber/data/eink/eink_style.dart';
import 'package:saber/data/extensions/color_extensions.dart';
import 'package:saber/data/tools/highlighter.dart';
import 'package:saber/data/tools/shape_analysis.dart';
import 'package:saber/data/tools/shape_snap.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/tools/laser_pointer.dart';
import 'package:saber/data/tools/pen_prediction.dart';
import 'package:saber/data/tools/select.dart';
import 'package:saber/data/tools/selection_transform.dart';
import 'package:saber/data/tools/shape_pen.dart';

/// Which part of a page's ink a [CanvasPainter] draws.
///
/// The two layers are painted by separate painters in separate repaint
/// boundaries, so drawing a stroke only repaints the (small) live layer.
enum InkLayer {
  /// Finished strokes. Repainted only when the strokes themselves change.
  dry,

  /// Everything that changes while the pen is moving: the current stroke,
  /// laser strokes, the detected shape and the selection outline.
  live,
}

class CanvasPainter extends CustomPainter {
  const new({
    super.repaint,
    required this.layer,
    this.invert = false,
    this.eInk,
    required this.strokes,
    required this.laserStrokes,
    required this.currentStroke,
    required this.currentSelection,
    required this.primaryColor,
    required this.page,
    required this.showPageIndicator,
    required this.pageIndex,
    required this.totalPages,
    required this.currentScale,
    required this.defaultTextStyle,
  });

  final InkLayer layer;
  final bool invert;

  /// The e-ink look, or null when e-ink mode is off. Pen colours are shown
  /// as greys (the strokes themselves keep their colour).
  final EInkStyle? eInk;
  final List<Stroke> strokes;
  final List<LaserStroke> laserStrokes;
  final Stroke? currentStroke;
  final SelectResult? currentSelection;
  final Color primaryColor;
  final EditorPage page;
  final bool showPageIndicator;
  final int pageIndex;
  final int totalPages;
  final double currentScale;
  final TextStyle defaultTextStyle;

  /// A pen colour as shown: inverted in dark mode, or grey in e-ink mode.
  Color _ink(Color color) =>
      eInk != null ? eInk!.mapInk(color) : color.withInversion(invert);

  /// The colour of the current stroke, or black when there is none.
  Color _currentInk() => currentStroke != null
      ? _ink(currentStroke!.color)
      : (eInk?.ink ?? Colors.black);

  /// Called at the start of every [paint], so tests can count repaints.
  @visibleForTesting
  static void Function(InkLayer layer)? debugOnPaint;

  @override
  void paint(Canvas canvas, Size size) {
    debugOnPaint?.call(layer);
    final canvasRect = Offset.zero & size;

    switch (layer) {
      case .dry:
        _drawHighlighterStrokes(canvas, canvasRect);
        _drawNonHighlighterStrokes(canvas);
        // The page number only changes with the page, so it is cached with
        // the strokes (and repainted with them once fonts have loaded).
        _drawPageIndicator(canvas, size);
      case .live:
        for (final stroke in laserStrokes) _drawLaserStroke(canvas, stroke);
        _drawCurrentStroke(canvas);
        _drawDetectedShape(canvas);
        _drawShapeSnapPreview(canvas);
        _drawSelection(canvas);
    }
  }

  @override
  bool shouldRepaint(CanvasPainter oldDelegate) {
    if (layer == .dry) {
      // The finished strokes don't change while a stroke is being drawn.
      // [strokes] is the page's own (mutated) list, so a stroke being added
      // or removed is noticed through the page's repaint listenable, or by
      // the current stroke starting/ending.
      return currentStroke != oldDelegate.currentStroke ||
          invert != oldDelegate.invert ||
          eInk != oldDelegate.eInk ||
          strokes.length != oldDelegate.strokes.length ||
          currentSelection != oldDelegate.currentSelection ||
          primaryColor != oldDelegate.primaryColor ||
          page != oldDelegate.page ||
          currentScale != oldDelegate.currentScale ||
          showPageIndicator != oldDelegate.showPageIndicator ||
          pageIndex != oldDelegate.pageIndex ||
          totalPages != oldDelegate.totalPages;
    }

    return false ||
        // Current stroke is being drawn, so always repaint if present
        (currentStroke != null || oldDelegate.currentStroke != null) ||
        // Laser strokes are always fading out, so always repaint if present
        (laserStrokes.isNotEmpty || oldDelegate.laserStrokes.isNotEmpty) ||
        // Check for any other changes
        invert != oldDelegate.invert ||
        eInk != oldDelegate.eInk ||
        currentSelection != oldDelegate.currentSelection ||
        primaryColor != oldDelegate.primaryColor ||
        page != oldDelegate.page ||
        currentScale != oldDelegate.currentScale;
  }

  void _drawHighlighterStrokes(Canvas canvas, Rect canvasRect) {
    final layerPaint = Paint()
      ..blendMode = invert ? BlendMode.lighten : BlendMode.darken
      ..color = Colors.white.withAlpha(Highlighter.alpha);
    bool needToRestoreCanvasLayer = false;

    Color? lastColor;
    for (final stroke in strokes) {
      if (stroke.toolId != .highlighter) continue;

      final color = _ink(stroke.color.withValues(alpha: 1));

      if (color != lastColor) {
        // new layer for each color
        if (needToRestoreCanvasLayer) canvas.restore();
        canvas.saveLayer(canvasRect, layerPaint);

        needToRestoreCanvasLayer = true;
        lastColor = color;
      }

      canvas.drawPath(_selectPath(stroke), Paint()..color = color);
    }

    if (needToRestoreCanvasLayer) canvas.restore();
  }

  void _drawNonHighlighterStrokes(Canvas canvas) {
    late final paint = Paint();

    for (final stroke in strokes) {
      if (stroke.toolId == .highlighter) continue;

      var color = _ink(stroke.color);
      if (currentSelection?.strokes.contains(stroke) ?? false) {
        color = Color.lerp(color, primaryColor, 0.5)!;
      }

      paint.color = color;
      paint.shader = null;
      paint.maskFilter = null;
      if (stroke.toolId == .pencil) {
        if (shouldUsePencilShader(stroke.options.size)) {
          paint.color = Colors.white;
          paint.shader = page.pencilShader
            ..setFloat(0, color.r)
            ..setFloat(1, color.g)
            ..setFloat(2, color.b);
          paint.maskFilter = _getPencilMaskFilter(stroke.options.size);
        } else {
          // Fast imitation of pencil when zoomed out
          final background =
              eInk?.paper ?? (invert ? Colors.black : Colors.white);
          paint.color = Color.lerp(background, color, 0.6)!;
        }
      }

      late final shapePaint = Paint()
        ..color = paint.color
        ..style = .stroke
        ..strokeWidth = stroke.options.size;

      if (stroke is CircleStroke) {
        canvas.drawCircle(stroke.center, stroke.radius, shapePaint);
      } else if (stroke is RectangleStroke) {
        final strokeSize = stroke.options.size;
        canvas.drawRRect(
          RRect.fromRectAndRadius(stroke.rect, Radius.circular(strokeSize / 4)),
          shapePaint,
        );
      } else {
        canvas.drawPath(_selectPath(stroke), paint);
      }
    }
  }

  void _drawCurrentStroke(Canvas canvas) {
    if (currentStroke == null) return;

    if (currentStroke! is LaserStroke) {
      return _drawLaserStroke(canvas, currentStroke as LaserStroke);
    }

    final color = _ink(currentStroke!.color);
    final paint = Paint();

    paint.color = color;
    paint.shader = null;
    paint.maskFilter = null;
    if (currentStroke!.toolId == .pencil) {
      paint.color = Colors.white;
      paint.shader = page.pencilShader
        ..setFloat(0, color.r)
        ..setFloat(1, color.g)
        ..setFloat(2, color.b);
      paint.maskFilter = _getPencilMaskFilter(currentStroke!.options.size);
    }

    // Current stroke always uses high quality
    canvas.drawPath(currentStroke!.highQualityPath, paint);

    // A short guess of where the pen is heading, so the line doesn't trail
    // behind a fast-moving tip. It is only drawn, never part of the stroke.
    final tip = PenPrediction.tip;
    final points = currentStroke!.points;
    if (tip != null && points.isNotEmpty && stows.penPrediction.value) {
      canvas.drawLine(
        points.last,
        tip,
        paint
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = currentStroke!.options.size * 0.9,
      );
    }
  }

  void _drawLaserStroke(Canvas canvas, LaserStroke stroke) {
    canvas.drawPath(
      _selectPath(stroke),
      Paint()
        ..color = _ink(stroke.color)
        ..maskFilter = MaskFilter.blur(
          BlurStyle.solid,
          stroke.options.size * 0.4,
        ),
    );
    canvas.drawPath(stroke.innerPath, Paint()..color = const Color(0xDDffffff));
  }

  /// The shape a held pen would snap the current stroke to.
  void _drawShapeSnapPreview(Canvas canvas) {
    final guess = ShapeSnap.preview;
    if (guess == null || currentStroke == null) return;
    _drawGuess(canvas, guess);
  }

  void _drawGuess(Canvas canvas, ShapeGuess guess) {
    final color = _currentInk();
    final paint = Paint()
      ..color = Color.lerp(color, primaryColor, 0.5)!.withValues(alpha: 0.7)
      ..style = .stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = currentStroke?.options.size ?? 3;
    final outline = guess.outline();
    if (outline.length < 2) return;
    canvas.drawPath(Path()..addPolygon(outline, false), paint);
  }

  void _drawDetectedShape(Canvas canvas) {
    final guess = ShapePen.detectedGuess;
    if (guess != null && currentStroke != null) {
      _drawGuess(canvas, guess);
      return;
    }

    final shape = ShapePen.detectedShape;
    if (shape == null) return;

    final color = _currentInk();
    final shapePaint = Paint()
      ..color = Color.lerp(color, primaryColor, 0.5)!.withValues(alpha: 0.7)
      ..style = .stroke
      ..strokeWidth = currentStroke?.options.size ?? 3;

    switch (shape.name) {
      case null:
        break;
      case DefaultUnistrokeNames.line:
        var (firstPoint, lastPoint) = shape.convertToLine();
        (firstPoint, lastPoint) = Stroke.snapLine(
          firstPoint is PointVector
              ? firstPoint
              : PointVector.fromOffset(offset: firstPoint),
          lastPoint is PointVector
              ? lastPoint
              : PointVector.fromOffset(offset: lastPoint),
        );
        canvas.drawLine(firstPoint, lastPoint, shapePaint);
      case DefaultUnistrokeNames.rectangle:
        final rect = shape.convertToRect();
        canvas.drawRect(rect, shapePaint);
      case DefaultUnistrokeNames.circle:
        final (center, radius) = shape.convertToCircle();
        canvas.drawCircle(center, radius, shapePaint);
      case DefaultUnistrokeNames.triangle:
      case DefaultUnistrokeNames.star:
        final polygon = shape.convertToCanonicalPolygon();
        canvas.drawPath(Path()..addPolygon(polygon, true), shapePaint);
    }
  }

  void _drawSelection(Canvas canvas) {
    if (currentSelection == null) return;

    // draw translucent fill
    canvas.drawPath(
      currentSelection!.path,
      Paint()..color = primaryColor.withValues(alpha: 0.1),
    );

    // draw dashed stroke
    canvas.drawPath(
      dashPath(
        currentSelection!.path,
        dashArray: CircularIntervalList([10, 10]),
      ),
      Paint()
        ..color = primaryColor
        ..strokeWidth = 3
        ..style = .stroke,
    );

    if (Select.currentSelect.doneSelecting) _drawSelectionHandles(canvas);
  }

  void _drawSelectionHandles(Canvas canvas) {
    final selection = currentSelection!;
    final bounds = SelectionTransform.contentBounds(selection);
    if (bounds == null) return;
    final scale = currentScale <= 0 ? 1.0 : currentScale;

    final fill = Paint()..color = Colors.white;
    final ring = Paint()
      ..color = primaryColor
      ..strokeWidth = 2 / scale
      ..style = .stroke;
    final radius = 9 / scale;

    canvas.drawRect(bounds, ring);

    final scaleHandle = SelectionTransform.scaleHandlePosition(bounds);
    canvas.drawRect(
      Rect.fromCenter(center: scaleHandle, width: radius * 2, height: radius * 2),
      fill,
    );
    canvas.drawRect(
      Rect.fromCenter(center: scaleHandle, width: radius * 2, height: radius * 2),
      ring,
    );

    if (SelectionTransform.canRotate(selection)) {
      final rotateHandle = SelectionTransform.rotateHandlePosition(bounds, scale);
      canvas.drawLine(Offset(bounds.center.dx, bounds.top), rotateHandle, ring);
      canvas.drawCircle(rotateHandle, radius, fill);
      canvas.drawCircle(rotateHandle, radius, ring);
    }

    // A single shape also shows its corners, which can be dragged.
    final vertices = SelectionTransform.vertexHandles(selection);
    if (vertices != null) {
      for (final vertex in vertices) {
        canvas.drawCircle(vertex, radius * 1.15, fill);
        canvas.drawCircle(vertex, radius * 1.15, ring);
      }
    }
  }

  static const double _pageIndicatorFontSize = 20;
  static const double _pageIndicatorPadding = 5;
  void _drawPageIndicator(Canvas canvas, Size pageSize) {
    if (!showPageIndicator) return;

    final style = ui.ParagraphStyle(
      textAlign: .end,
      textDirection: .ltr,
      maxLines: 1,
    );

    final builder = ui.ParagraphBuilder(style)
      ..pushStyle(
        ui.TextStyle(
          color: _ink(Colors.black).withValues(alpha: 0.5),
          fontSize: _pageIndicatorFontSize,
          fontFamily: defaultTextStyle.fontFamily,
          fontFamilyFallback: defaultTextStyle.fontFamilyFallback,
        ),
      )
      ..addText('${pageIndex + 1} / $totalPages');

    final paragraph = builder.build();
    paragraph.layout(
      ui.ParagraphConstraints(
        width: pageSize.width - 2 * _pageIndicatorPadding,
      ),
    );

    canvas.drawParagraph(
      paragraph,
      Offset(
        _pageIndicatorPadding,
        pageSize.height - _pageIndicatorPadding - _pageIndicatorFontSize * 1.2,
      ),
    );
  }

  static MaskFilter _getPencilMaskFilter(double size) =>
      MaskFilter.blur(BlurStyle.normal, min(size * 0.2, 3));
  bool shouldUsePencilShader(double strokeSize) =>
      currentScale >= _zoomThreshold && (strokeSize * currentScale) >= 3;

  static const _zoomThreshold = 0.9;
  Path _selectPath(Stroke stroke) => switch (currentScale) {
    < _zoomThreshold => stroke.lowQualityPath,
    _ => stroke.highQualityPath,
  };
}
