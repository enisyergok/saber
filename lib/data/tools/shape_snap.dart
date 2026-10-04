import 'dart:async';
import 'dart:ui';

import 'package:perfect_freehand/perfect_freehand.dart';
import 'package:saber/components/canvas/_circle_stroke.dart';
import 'package:saber/components/canvas/_rectangle_stroke.dart';
import 'package:saber/components/canvas/_stroke.dart';
import 'package:saber/data/tools/shape_analysis.dart';
import 'package:sbn/tool_id.dart';

/// Turns strokes into the shapes found by [ShapeAnalysis].
abstract class ShapeBuilder {
  /// The stroke that replaces [raw] once it is recognised as [guess].
  /// Lines keep and reuse [raw]; anything else is a new stroke.
  static Stroke build(
    Stroke raw,
    ShapeGuess guess, {
    bool arrows = false,
  }) {
    // Highlighter strokes are drawn from their points, so a circle or
    // rectangle becomes an outline made of points.
    if (raw.toolId == ToolId.highlighter) {
      if (guess.kind == ShapeKind.circle) {
        guess = ShapeGuess(
          kind: ShapeKind.ellipse,
          center: guess.center,
          radiusX: guess.radiusX,
          radiusY: guess.radiusY,
        );
      } else if (guess.kind == ShapeKind.rectangle) {
        guess = ShapeGuess(
          kind: ShapeKind.polygon,
          points: guess.outline().sublist(0, 4),
        );
      }
    }
    switch (guess.kind) {
      case ShapeKind.line:
        raw.convertToLine();
        if (arrows) raw.convertToArrow();
        return raw;
      case ShapeKind.circle:
        return CircleStroke(
          color: raw.color,
          pressureEnabled: raw.pressureEnabled,
          options: raw.options,
          pageIndex: raw.pageIndex,
          page: raw.page,
          toolId: raw.toolId,
          radius: guess.radiusX,
          center: guess.center,
        );
      case ShapeKind.rectangle:
        return RectangleStroke(
          color: raw.color,
          pressureEnabled: raw.pressureEnabled,
          options: raw.options,
          pageIndex: raw.pageIndex,
          page: raw.page,
          toolId: raw.toolId,
          rect: guess.rect,
        );
      case ShapeKind.ellipse:
      case ShapeKind.polygon:
      case ShapeKind.curve:
        // Fresh end options: the pen's own ones are shared with the copy.
        final options = raw.options.copyWith(
          smoothing: 0,
          streamline: 0,
          simulatePressure: false,
          isComplete: true,
          start: StrokeEndOptions.start(taperEnabled: false),
          end: StrokeEndOptions.end(taperEnabled: false),
        );
        final stroke = Stroke(
          color: raw.color,
          pressureEnabled: false,
          options: options,
          pageIndex: raw.pageIndex,
          page: raw.page,
          toolId: raw.toolId,
        );
        // The last point is repeated: that is how shape strokes are told
        // apart from handwriting (see [Stroke.vertexHandles]).
        final outline = guess.outline();
        stroke.addPoints([...outline, outline.last]);
        stroke.options.isComplete = true;
        return stroke;
    }
  }
}

/// Snap-to-shape while writing: draw a shape, then hold the pen still, and
/// the stroke straightens into the shape it was meant to be.
class ShapeSnap {
  /// The shape the stroke being drawn would turn into, once the pen has
  /// been held still. Drawn as a preview.
  static ShapeGuess? preview;

  /// Called when [preview] appears or goes away, to repaint.
  static VoidCallback? redraw;

  /// True if the stroke that just ended was snapped to a shape.
  static bool lastWasSnapped = false;

  /// How long the pen is held still before the stroke snaps.
  static Duration _hold = const Duration(milliseconds: 600);

  /// Movement smaller than this (page units) still counts as holding still.
  static const moveTolerance = 4.0;

  /// Once snapped, moving the pen further than this lets go of the shape.
  static const releaseDistance = 10.0;

  /// Only strokes at least this long (page units) can snap.
  static const minStrokeLength = 60.0;

  static final Stopwatch _clock = Stopwatch()..start();
  static Stroke? _stroke;
  static Timer? _timer;
  static Offset _anchor = Offset.zero;
  static int _lastMoveMs = 0;
  static double _length = 0;
  static Offset _previous = Offset.zero;

  /// Starts watching [stroke], which was just begun at [position].
  static void begin(
    Stroke stroke,
    Offset position, {
    required Duration hold,
  }) {
    _cancel();
    _hold = hold;
    _stroke = stroke;
    _anchor = position;
    _previous = position;
    _length = 0;
    _lastMoveMs = _clock.elapsedMilliseconds;
    lastWasSnapped = false;
  }

  /// The pen moved to [position].
  static void onMove(Offset position) {
    if (_stroke == null) return;
    _length += (position - _previous).distance;
    _previous = position;

    if (preview != null) {
      if ((position - _anchor).distance > releaseDistance) {
        preview = null;
        _anchor = position;
        _lastMoveMs = _clock.elapsedMilliseconds;
        redraw?.call();
        _arm();
      }
      return;
    }

    if ((position - _anchor).distance > moveTolerance) {
      _anchor = position;
      _lastMoveMs = _clock.elapsedMilliseconds;
    }
    _arm();
  }

  static void _arm() {
    if (_timer?.isActive ?? false) return;
    _timer = Timer(_hold, _fire);
  }

  static void _fire() {
    final stroke = _stroke;
    if (stroke == null || preview != null) return;

    final idle = _clock.elapsedMilliseconds - _lastMoveMs;
    final hold = _hold.inMilliseconds;
    if (idle < hold - 20) {
      _timer = Timer(Duration(milliseconds: hold - idle), _fire);
      return;
    }
    if (_length < minStrokeLength) return;

    final guess = ShapeAnalysis.analyze(stroke.pointOffsets);
    if (guess == null) return;
    preview = _withSnappedLine(guess);
    redraw?.call();
  }

  /// Lines close to horizontal or vertical are shown (and made) exactly so.
  static ShapeGuess _withSnappedLine(ShapeGuess guess) {
    if (guess.kind != ShapeKind.line) return guess;
    final (a, b) = Stroke.snapLine(
      PointVector.fromOffset(offset: guess.points.first),
      PointVector.fromOffset(offset: guess.points.last),
    );
    return ShapeGuess(
      kind: ShapeKind.line,
      points: [Offset(a.dx, a.dy), Offset(b.dx, b.dy)],
    );
  }

  /// The pen was lifted: returns [stroke], or the shape it snapped to.
  static Stroke finish(Stroke stroke) {
    final guess = preview;
    final watched = _stroke;
    _cancel();
    if (guess == null || !identical(watched, stroke)) {
      lastWasSnapped = false;
      return stroke;
    }
    lastWasSnapped = true;
    return ShapeBuilder.build(stroke, guess);
  }

  /// Forget everything about the stroke being drawn.
  static void reset() => _cancel();

  static void _cancel() {
    _timer?.cancel();
    _timer = null;
    _stroke = null;
    preview = null;
  }

  // -- snapping to other shapes --------------------------------------------

  /// How close (page units) an end or corner has to be to another shape's
  /// to snap to it.
  static const endpointDistance = 16.0;

  /// Moves the ends or corners of [stroke] onto nearby ends and corners of
  /// [others], so shapes drawn one stroke at a time join up.
  static bool snapToEndpoints(
    Stroke stroke,
    Iterable<Stroke> others, {
    double distance = endpointDistance,
  }) {
    final handles = stroke.vertexHandles;
    if (handles == null) return false;

    final targets = <Offset>[];
    for (final other in others) {
      if (identical(other, stroke)) continue;
      if (other is RectangleStroke) {
        targets.addAll([
          other.rect.topLeft,
          other.rect.topRight,
          other.rect.bottomRight,
          other.rect.bottomLeft,
        ]);
      } else {
        final otherHandles = other.vertexHandles;
        if (otherHandles != null) targets.addAll(otherHandles);
      }
    }
    if (targets.isEmpty) return false;

    var changed = false;
    for (var i = 0; i < handles.length; i++) {
      Offset? nearest;
      var best = distance;
      for (final target in targets) {
        final d = (target - handles[i]).distance;
        if (d < best && d > 0.01) {
          best = d;
          nearest = target;
        }
      }
      if (nearest != null) {
        handles[i] = nearest;
        changed = true;
      }
    }
    if (changed) stroke.setVertexHandles(handles);
    return changed;
  }

  /// Which of [handles] is within [radius] of [position], the nearest one.
  static int? nearestHandle(
    List<Offset> handles,
    Offset position,
    double radius,
  ) {
    int? found;
    var best = radius;
    for (var i = 0; i < handles.length; i++) {
      final d = (handles[i] - position).distance;
      if (d <= best) {
        best = d;
        found = i;
      }
    }
    return found;
  }
}
