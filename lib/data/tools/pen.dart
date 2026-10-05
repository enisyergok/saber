import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:perfect_freehand/perfect_freehand.dart';
import 'package:saber/components/canvas/_stroke.dart';
import 'package:saber/data/editor/page.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/tools/_tool.dart';
import 'package:saber/data/tools/highlighter.dart';
import 'package:saber/data/tools/pen_prediction.dart';
import 'package:saber/data/tools/pressure_calibration.dart';
import 'package:saber/data/tools/pencil.dart';
import 'package:saber/data/tools/shape_snap.dart';
import 'package:saber/i18n/strings.g.dart';
import 'package:sbn/tool_id.dart';

class Pen extends Tool {
  @protected
  @visibleForTesting
  new({
    required this.name,
    required this.sizeMin,
    required this.sizeMax,
    required this.sizeStep,
    required this.icon,
    required this.options,
    required this.pressureEnabled,
    required this.color,
    required this.toolId,
  });

  new fountainPen()
    : name = t.editor.pens.fountainPen,
      sizeMin = 1,
      sizeMax = 25,
      sizeStep = 1,
      icon = fountainPenIcon,
      options = stows.lastFountainPenOptions.value,
      pressureEnabled = true,
      color = Color(stows.lastFountainPenColor.value),
      toolId = .fountainPen;

  new ballpointPen()
    : name = t.editor.pens.ballpointPen,
      sizeMin = 1,
      sizeMax = 25,
      sizeStep = 1,
      icon = ballpointPenIcon,
      options = stows.lastBallpointPenOptions.value,
      pressureEnabled = false,
      color = Color(stows.lastBallpointPenColor.value),
      toolId = .ballpointPen;

  final String name;
  final double sizeMin, sizeMax, sizeStep;
  late final int sizeStepsBetweenMinAndMax = ((sizeMax - sizeMin) / sizeStep)
      .round();
  final Object icon;

  @override
  final ToolId toolId;

  static const fountainPenIcon = FontAwesomeIcons.penFancy;
  static const ballpointPenIcon = FontAwesomeIcons.pen;

  static Stroke? currentStroke;
  Color color;
  bool pressureEnabled;
  StrokeOptions options;

  static var _currentPen = Pen.fountainPen();
  static Pen get currentPen => _currentPen;
  static set currentPen(Pen currentPen) {
    assert(
      currentPen is! Highlighter,
      'Use Highlighter.currentHighlighter instead',
    );
    assert(currentPen is! Pencil, 'Use Pencil.currentPencil instead');
    _currentPen = currentPen;
  }

  void onDragStart(
    Offset position,
    EditorPage page,
    int pageIndex,
    double? pressure,
  ) {
    currentStroke = Stroke(
      color: color,
      pressureEnabled: pressureEnabled,
      options: options.copyWith(isComplete: false),
      pageIndex: pageIndex,
      page: page,
      toolId: toolId,
    );
    PenPrediction.reset();
    _rawLow = double.infinity;
    _rawHigh = double.negativeInfinity;
    _rawCount = 0;
    _fallback = pressureEnabled &&
        stows.pressureAuto.value &&
        PressureCalibration.isFlat;
    // Without usable pressure the width follows the pen's speed instead.
    if (_fallback) currentStroke!.options.simulatePressure = true;
    if (holdsToSnap && stows.shapeHoldToSnap.value) {
      ShapeSnap.begin(
        currentStroke!,
        position,
        hold: Duration(milliseconds: stows.shapeHoldDelay.value),
      );
    }
    onDragUpdate(position, pressure);
  }

  double _rawLow = double.infinity, _rawHigh = double.negativeInfinity;
  int _rawCount = 0;
  bool _fallback = false;

  void onDragUpdate(Offset position, double? pressure) {
    if (pressureEnabled && pressure != null && stows.pressureAuto.value) {
      _rawLow = math.min(_rawLow, pressure);
      _rawHigh = math.max(_rawHigh, pressure);
      _rawCount++;
      pressure = _fallback ? null : PressureCalibration.map(pressure);
    }
    currentStroke?.addPoint(position, pressure);
    if (holdsToSnap && stows.shapeHoldToSnap.value) {
      ShapeSnap.onMove(position);
    }
    if (stows.penPrediction.value && predictsAhead) {
      PenPrediction.add(position, _clock.elapsed);
    }
  }

  /// Measures time between pen movements for [PenPrediction].
  static final _clock = Stopwatch()..start();

  /// Whether the line is drawn a little ahead of the pen. Not for the
  /// highlighter and pencil, which are drawn differently, nor the shape pen,
  /// which turns the line into a shape.
  bool get predictsAhead =>
      toolId == .fountainPen || toolId == .ballpointPen;

  /// Whether holding the pen still after drawing a shape straightens it
  /// (see [ShapeSnap]). Not for the pencil, which is textured, nor the shape
  /// pen, which recognises shapes on its own.
  bool get holdsToSnap =>
      toolId == .fountainPen ||
      toolId == .ballpointPen ||
      toolId == .highlighter;

  Stroke? onDragEnd() {
    final stroke = currentStroke;
    currentStroke = null;
    PenPrediction.reset();
    if (stroke == null) {
      ShapeSnap.reset();
      return null;
    }

    if (_rawCount > 0) {
      PressureCalibration.addStroke(_rawLow, _rawHigh, _rawCount);
      _rawCount = 0;
    }
    stroke
      ..options.isComplete = true
      ..markPolygonNeedsUpdating();
    return holdsToSnap ? ShapeSnap.finish(stroke) : stroke;
  }

  /// The default stroke options.
  ///
  /// Note that these are different to the default options in [StrokeOptions]
  /// e.g. [StrokeOptions.defaultSize] for historical reasons
  /// (i.e. [StrokeOptions.toJson] does not include default values.)
  static final defaultOptions = StrokeOptions(size: 5);

  static StrokeOptions get fountainPenOptions => defaultOptions.copyWith();
  static StrokeOptions get ballpointPenOptions => defaultOptions.copyWith();
  static StrokeOptions get shapePenOptions =>
      defaultOptions.copyWith(smoothing: 0, streamline: 0);
  static StrokeOptions get highlighterOptions =>
      defaultOptions.copyWith(size: 50);
  static StrokeOptions get pencilOptions => defaultOptions.copyWith(
    streamline: 0.1,
    start: StrokeEndOptions.start(taperEnabled: true, customTaper: 1),
    end: StrokeEndOptions.end(taperEnabled: true, customTaper: 1),
  );
}
