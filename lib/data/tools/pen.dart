import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:perfect_freehand/perfect_freehand.dart';
import 'package:saber/components/canvas/_stroke.dart';
import 'package:saber/data/editor/page.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/tools/_tool.dart';
import 'package:saber/data/tools/highlighter.dart';
import 'package:saber/data/defter_strings.dart';
import 'package:saber/data/tools/pen_assist.dart';
import 'package:saber/data/tools/pen_feel.dart';
import 'package:saber/data/tools/pen_prediction.dart';
import 'package:saber/data/tools/pressure_calibration.dart';
import 'package:saber/data/tools/pressure_curve.dart';
import 'package:saber/data/tools/pencil.dart';
import 'package:saber/data/tools/shape_snap.dart';
import 'package:saber/i18n/strings.g.dart';
import 'package:sbn/tool_id.dart';

/// The pens that are stored as fountain pen lines.
enum PenVariant { plain, brush, calligraphy }

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
    this.variant = PenVariant.plain,
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
      toolId = .fountainPen,
      variant = PenVariant.plain;

  /// A brush pen. Its lines are stored like the fountain pen's (the same
  /// [toolId]), so notes stay readable by versions without it.
  new brushPen()
    : name = DefterStrings.brushPen,
      sizeMin = 1,
      sizeMax = 40,
      sizeStep = 1,
      icon = brushPenIcon,
      options = stows.lastBrushPenOptions.value,
      pressureEnabled = true,
      color = Color(stows.lastFountainPenColor.value),
      toolId = .fountainPen,
      variant = PenVariant.brush;

  /// A calligraphy pen with a flat nib: how thick it draws depends on the
  /// direction of the line. Stored like the fountain pen's lines too.
  new calligraphyPen()
    : name = DefterStrings.calligraphyPen,
      sizeMin = 2,
      sizeMax = 40,
      sizeStep = 1,
      icon = calligraphyPenIcon,
      options = stows.lastCalligraphyPenOptions.value,
      pressureEnabled = true,
      color = Color(stows.lastFountainPenColor.value),
      toolId = .fountainPen,
      variant = PenVariant.calligraphy;

  new ballpointPen()
    : name = t.editor.pens.ballpointPen,
      sizeMin = 1,
      sizeMax = 25,
      sizeStep = 1,
      icon = ballpointPenIcon,
      options = stows.lastBallpointPenOptions.value,
      pressureEnabled = true,
      color = Color(stows.lastBallpointPenColor.value),
      toolId = .ballpointPen,
      variant = PenVariant.plain;

  /// Which pen this is among those that share a [toolId].
  final PenVariant variant;

  /// Whether this is the brush pen (see [Pen.brushPen]).
  bool get brush => variant == PenVariant.brush;

  /// Which of the pen panel's writing pens this is, if any.
  PenKind? get kind => switch (toolId) {
    .fountainPen => switch (variant) {
      PenVariant.plain => PenKind.fountain,
      PenVariant.brush => PenKind.brush,
      PenVariant.calligraphy => PenKind.calligraphy,
    },
    .ballpointPen => PenKind.ballpoint,
    _ => null,
  };

  /// How pointed the ends of this pen's lines are, 0..1.
  double get tipSharpness => switch (kind) {
    PenKind.fountain => stows.fountainTipSharpness.value,
    PenKind.brush => stows.brushTipSharpness.value,
    _ => 0,
  };
  set tipSharpness(double value) {
    switch (kind) {
      case PenKind.fountain:
        stows.fountainTipSharpness.value = value;
      case PenKind.brush:
        stows.brushTipSharpness.value = value;
      case PenKind.ballpoint:
      case PenKind.calligraphy:
      case null:
        break;
    }
  }

  /// The options this pen's lines are drawn with right now.
  StrokeOptions get strokeOptions {
    final kind = this.kind;
    return kind == null
        ? options.copyWith()
        : PenFeel.apply(kind, options, sharpness: tipSharpness);
  }

  final String name;
  final double sizeMin, sizeMax, sizeStep;
  late final int sizeStepsBetweenMinAndMax = ((sizeMax - sizeMin) / sizeStep)
      .round();
  final Object icon;

  @override
  final ToolId toolId;

  static const fountainPenIcon = FontAwesomeIcons.penFancy;
  static const ballpointPenIcon = FontAwesomeIcons.pen;
  static const brushPenIcon = FontAwesomeIcons.paintbrush;
  static const calligraphyPenIcon = FontAwesomeIcons.penNib;

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
    PenFeel.curve = PressureCurve.parse(stows.pressureCurve.value);
    // What the last line measured makes way for this one.
    PenAssist.showReadout(null);
    _ruler = usesAssists && stows.rulerMode.value;
    _start = position;
    _pathLength = 0;
    _nibAt = position;
    _nibPressure = 0.5;
    _nibMoved = false;
    currentStroke = Stroke(
      color: color,
      pressureEnabled: pressureEnabled,
      options: _ruler
          // A ruled line is even from end to end.
          ? strokeOptions.copyWith(
              isComplete: false,
              simulatePressure: false,
              start: StrokeEndOptions.start(taperEnabled: false),
              end: StrokeEndOptions.end(taperEnabled: false),
            )
          : strokeOptions.copyWith(isComplete: false),
      pageIndex: pageIndex,
      page: page,
      toolId: toolId,
    );
    PenPrediction.reset();
    if (_ruler) {
      ShapeSnap.reset();
      onDragUpdate(position, pressure);
      return;
    }
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
        tidy: stows.shapeAutoCorrect.value,
      );
    }
    onDragUpdate(position, pressure);
  }

  /// Whether the technical helpers of the pen panel (ruler, angle guide,
  /// measuring) work with this pen: every pen but the shape pen, which
  /// makes shapes on its own.
  bool get usesAssists => toolId != .shapePen;

  bool _ruler = false;
  Offset _start = Offset.zero;
  double _pathLength = 0;
  Offset _nibAt = Offset.zero;
  double _nibPressure = 0.5;
  bool _nibMoved = false;
  double _nibDirection = 0;

  /// The end of the ruled line being drawn towards [position].
  Offset _ruledEnd(Offset position) => stows.angleGuide.value
      ? PenAssist.snapAngle(_start, position)
      : position;

  double _rawLow = double.infinity, _rawHigh = double.negativeInfinity;
  int _rawCount = 0;
  bool _fallback = false;
  Offset _measuredAt = Offset.zero;

  void onDragUpdate(Offset position, double? pressure) {
    final stroke = currentStroke;
    if (_ruler && stroke != null) {
      final end = _ruledEnd(position);
      stroke.setLine(_start, end);
      if (stows.measureMode.value) {
        PenAssist.showReadout(PenAssist.describeLine(_start, end));
      } else if (stows.angleGuide.value) {
        PenAssist.showReadout(
          (end - _start).distance >= PenAssist.liveLineMinLength
              ? PenAssist.describeAngle(_start, end)
              : null,
        );
      }
      return;
    }
    if (usesAssists &&
        stroke != null &&
        (stows.measureMode.value || stows.angleGuide.value)) {
      if (stroke.length > 0) _pathLength += (position - _measuredAt).distance;
      _measuredAt = position;
      PenAssist.showReadout(
        PenAssist.liveReadout(
          start: _start,
          position: position,
          pathLength: _pathLength,
          measure: stows.measureMode.value,
          angleGuide: stows.angleGuide.value,
        ),
      );
    }
    if (pressureEnabled && pressure != null && stows.pressureAuto.value) {
      _rawLow = math.min(_rawLow, pressure);
      _rawHigh = math.max(_rawHigh, pressure);
      _rawCount++;
      pressure = _fallback ? null : PressureCalibration.map(pressure);
    }
    if (pressure != null && kind != null) {
      pressure = PenFeel.pressure(pressure);
    }
    if (kind == PenKind.calligraphy) {
      // The flat nib: thick or thin by the direction the pen moves in,
      // and a little by how hard it is pressed.
      final moved = position - _nibAt;
      if (moved.distance >= 1.5) {
        _nibDirection = moved.direction;
        _nibAt = position;
        _nibMoved = true;
      }
      if (_nibMoved) {
        final target = PenFeel.nibPressure(_nibDirection);
        _nibPressure += (target - _nibPressure) * 0.45;
      }
      pressure = (_nibPressure * (pressure == null ? 1 : 0.7 + 0.3 * pressure))
          .clamp(0.0, 1.0);
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

    if (_ruler) {
      _ruler = false;
      ShapeSnap.reset();
      final ends = stroke.pointOffsets;
      // A tap with the ruler draws nothing.
      if (ends.length < 2 || (ends.last - ends.first).distance < 2) {
        PenAssist.showReadout(null);
        return null;
      }
      stroke
        ..setVertexHandles([ends.first, ends.last])
        ..options.isComplete = true
        ..markPolygonNeedsUpdating();
      // Already a straight line: nothing further to recognise.
      ShapeSnap.lastWasSnapped = true;
      return stroke;
    }

    if (_rawCount > 0) {
      PressureCalibration.addStroke(_rawLow, _rawHigh, _rawCount);
      _rawCount = 0;
    }
    if (kind != null) _limitTapers(stroke);
    stroke
      ..options.isComplete = true
      ..markPolygonNeedsUpdating();
    if (!holdsToSnap) {
      ShapeSnap.lastWasSnapped = false;
      return stroke;
    }
    final result = ShapeSnap.finish(stroke);
    if (ShapeSnap.lastWasSnapped && kind != null) {
      // A shape has even ends, whatever the pen's tip sharpness. These end
      // options were made for this line alone (see [strokeOptions]).
      result.options.start.taperEnabled = false;
      result.options.end.taperEnabled = false;
      result.markPolygonNeedsUpdating();
    }
    return result;
  }

  /// Shortens the pointed ends of a finished line that is itself short.
  static void _limitTapers(Stroke stroke) {
    final limit = PenFeel.maxTaper(stroke.pathLength);
    for (final end in [stroke.options.start, stroke.options.end]) {
      final taper = end.customTaper;
      if (end.taperEnabled && taper != null && taper > limit) {
        end.customTaper = math.max(limit, 0.01);
      }
    }
  }

  /// The default stroke options.
  ///
  /// Note that these are different to the default options in [StrokeOptions]
  /// e.g. [StrokeOptions.defaultSize] for historical reasons
  /// (i.e. [StrokeOptions.toJson] does not include default values.)
  static final defaultOptions = StrokeOptions(size: 5);

  static StrokeOptions get fountainPenOptions => defaultOptions.copyWith();
  static StrokeOptions get ballpointPenOptions => defaultOptions.copyWith();
  static StrokeOptions get brushPenOptions =>
      defaultOptions.copyWith(size: 12, thinning: 0.5);
  static StrokeOptions get calligraphyPenOptions =>
      defaultOptions.copyWith(size: 10, thinning: 0.5);
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
