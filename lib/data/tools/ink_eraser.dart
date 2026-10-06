import 'dart:math' as math;
import 'dart:ui';

import 'package:saber/components/canvas/_circle_stroke.dart';
import 'package:saber/components/canvas/_stroke.dart';

/// What became of a stroke the eraser went over: [before] is the stroke as
/// it was, [after] what is left of it (nothing, if all of it was erased).
class StrokeReplacement {
  const StrokeReplacement({
    required this.before,
    required this.after,
    required this.next,
  });

  final Stroke before;
  final List<Stroke> after;

  /// The stroke that came right after [before] on the page (null if it was
  /// the last), so that undoing puts it back where it was, under and over
  /// the same strokes.
  final Stroke? next;
}

class _Run {
  _Run(this.points, {required this.cutStart});
  final List<InkPoint> points;
  final bool cutStart;
  bool cutEnd = false;

  double get length {
    var total = 0.0;
    for (var i = 1; i < points.length; i++) {
      total += (points[i].at - points[i - 1].at).distance;
    }
    return total;
  }

  double get widest {
    var widest = 0.0;
    for (final point in points) {
      widest = math.max(widest, point.radius);
    }
    return widest;
  }
}

class _Ink {
  _Ink(this.line) : bounds = _boundsOf(line);

  final List<InkPoint> line;

  /// The box around the ink (the line and its width).
  final Rect bounds;

  static Rect _boundsOf(List<InkPoint> line) {
    if (line.isEmpty) return Rect.zero;
    var left = double.infinity, top = double.infinity;
    var right = double.negativeInfinity, bottom = double.negativeInfinity;
    for (final point in line) {
      left = math.min(left, point.at.dx - point.radius);
      right = math.max(right, point.at.dx + point.radius);
      top = math.min(top, point.at.dy - point.radius);
      bottom = math.max(bottom, point.at.dy + point.radius);
    }
    return Rect.fromLTRB(left, top, right, bottom);
  }
}

/// The eraser that rubs out only what it passes over.
///
/// A stroke is the line the pen followed, drawn with some width. Where the
/// eraser's circle covers that line the line is cut, and what is left on
/// either side stays a stroke of its own, exactly where and as wide as it
/// was: nothing but the part under the eraser changes.
///
/// One of these lasts for one drag of the eraser: it remembers what each
/// stroke it met has become, for undoing (see [finish]).
class InkEraser {
  /// How much of the ink's half width counts towards the eraser's reach:
  /// the eraser rubs out a line a little before it gets to the middle of
  /// it. For a pen line that is a hair's breadth.
  static const reach = 0.5;

  /// The most the ink's width adds to the eraser's reach, as a part of the
  /// eraser's own radius: what is rubbed out of a broad stroke (a
  /// highlighter) is about as wide as the eraser, not as the stroke.
  static const maxReach = 0.25;

  /// How close to [centre] the line of ink [radius] wide (to either side)
  /// has to be for an eraser of [eraser] radius there to rub it out.
  static double reachOf(double eraser, double radius) =>
      eraser + math.min(reach * radius, maxReach * eraser);

  /// What is left of a stroke is dropped if it is shorter than this (in
  /// page units) or than a quarter of its own width: such crumbs are too
  /// small to be of use and only get in the way.
  static const crumb = 1.0;

  /// The most steps the eraser's way from one position to the next is
  /// taken in (each is one circle).
  static const maxSteps = 64;

  final _inks = Map<Stroke, _Ink>.identity();

  /// The stroke each piece came from, and what has become of each stroke
  /// that was on the page when the drag began.
  final _origin = Map<Stroke, Stroke>.identity();
  final _pieces = Map<Stroke, List<Stroke>>.identity();
  List<Stroke> _onPageAtStart = const [];

  Offset? _last;

  /// Begins a drag over [strokes], the page's own list.
  void begin(List<Stroke> strokes) {
    _inks.clear();
    _origin.clear();
    _pieces.clear();
    _onPageAtStart = List.of(strokes);
    _last = null;
  }

  _Ink _inkOf(Stroke stroke) => _inks[stroke] ??= _Ink(stroke.inkLine());

  /// Whether [stroke] could be within [radius] of [centre], judged by the
  /// box around it, with room to spare for how the box is come by (it is
  /// that of a rougher drawing of the stroke).
  bool _isNear(Stroke stroke, Offset centre, double radius) {
    final known = _inks[stroke];
    if (known != null) return known.bounds.inflate(radius).contains(centre);
    final Rect box;
    if (stroke is CircleStroke) {
      box = Rect.fromCircle(center: stroke.center, radius: stroke.radius);
    } else {
      box = stroke.bounds;
    }
    return box.inflate(radius + stroke.options.size + 8).contains(centre);
  }

  /// The part of the line from [a] to [b] that is closer than [distance]
  /// to [centre], as the range of t it covers (0 at [a], 1 at [b]); null
  /// if no part is.
  static (double, double)? within(
    Offset a,
    Offset b,
    Offset centre,
    double distance,
  ) {
    final d = b - a, f = a - centre;
    final qa = d.dx * d.dx + d.dy * d.dy;
    final qc = f.dx * f.dx + f.dy * f.dy - distance * distance;
    if (qa < 1e-18) return qc < 0 ? (0.0, 1.0) : null;
    final qb = 2 * (f.dx * d.dx + f.dy * d.dy);
    final discriminant = qb * qb - 4 * qa * qc;
    if (discriminant <= 0) return null;
    final root = math.sqrt(discriminant);
    final t0 = (-qb - root) / (2 * qa), t1 = (-qb + root) / (2 * qa);
    if (t1 <= 0 || t0 >= 1) return null;
    return (math.max(t0, 0.0), math.min(t1, 1.0));
  }

  static InkPoint _between(InkPoint a, InkPoint b, double t) => (
    at: Offset.lerp(a.at, b.at, t)!,
    radius: a.radius + (b.radius - a.radius) * t,
  );

  /// What is left of [stroke] once an eraser of [radius] at [centre] has
  /// rubbed out what it covers: no strokes if it covers all of it, one or
  /// more if it covers part. Null if the eraser doesn't touch the stroke,
  /// which is then left as it is.
  List<Stroke>? cut(Stroke stroke, Offset centre, double radius) {
    final ink = _inkOf(stroke);
    final line = ink.line;
    if (line.isEmpty) return null;
    if (!ink.bounds.inflate(radius).contains(centre)) return null;

    const eps = 1e-6;
    if (line.length == 1) {
      final touched =
          (line.first.at - centre).distance <
          reachOf(radius, line.first.radius);
      return touched ? const [] : null;
    }

    final runs = <_Run>[];
    _Run? run = _Run([line.first], cutStart: false);
    var touched = false;
    void close({required bool cut}) {
      run!.cutEnd = cut;
      runs.add(run!);
      run = null;
    }

    for (var i = 0; i + 1 < line.length; i++) {
      final a = line[i], b = line[i + 1];
      final covered = within(
        a.at,
        b.at,
        centre,
        reachOf(radius, (a.radius + b.radius) / 2),
      );
      if (covered == null) {
        (run ??= _Run([a], cutStart: true)).points.add(b);
        continue;
      }
      touched = true;
      final (t0, t1) = covered;
      if (t0 > eps) {
        (run ??= _Run([a], cutStart: true)).points.add(_between(a, b, t0));
      }
      if (run != null) close(cut: true);
      if (t1 < 1 - eps) {
        run = _Run([_between(a, b, t1), b], cutStart: true);
      }
    }
    if (run != null) close(cut: false);
    if (!touched) return null;

    // A closed outline that was not cut where it begins and ends is one
    // piece there, not two that happen to meet.
    if (stroke.inkLineIsClosed &&
        runs.length >= 2 &&
        !runs.first.cutStart &&
        !runs.last.cutEnd) {
      final last = runs.removeLast(), first = runs.removeAt(0);
      runs.insert(
        0,
        _Run([
          ...last.points,
          ...first.points.skip(1),
        ], cutStart: last.cutStart)..cutEnd = first.cutEnd,
      );
    }

    final straight = stroke.vertexHandles?.length == 2;
    final pieces = <Stroke>[];
    for (final piece in runs) {
      if (piece.points.length < 2) continue;
      final length = piece.length;
      if (length < math.max(crumb, piece.widest / 2)) continue;
      // An end the eraser made earlier stays square.
      final flatStart = piece.cutStart || !stroke.options.start.cap;
      final flatEnd = piece.cutEnd || !stroke.options.end.cap;
      final Stroke left;
      if (straight) {
        // What is left of a straight line is a straight line: its ends can
        // still be moved.
        left = stroke.lineLike(
          piece.points.first.at,
          piece.points.last.at,
          flatStart: flatStart,
          flatEnd: flatEnd,
        );
        _inks[left] = _Ink([piece.points.first, piece.points.last]);
      } else {
        left = Stroke.fromInkLine(
          stroke,
          piece.points,
          flatStart: flatStart,
          flatEnd: flatEnd,
        );
        // Further cuts in this drag are made in the line as it was first
        // worked out, so that going over a stroke many times is as exact
        // as going over it once.
        _inks[left] = _Ink(piece.points);
      }
      pieces.add(left);
    }
    return pieces;
  }

  /// Rubs out what an eraser of [radius] at [centre] covers of [strokes]
  /// (the page's own list, which is changed in place: each stroke that is
  /// touched makes way for what is left of it, in the same place among the
  /// others). Returns whether anything was rubbed out.
  bool eraseAt(Offset centre, double radius, List<Stroke> strokes) {
    var changed = false;
    for (var i = 0; i < strokes.length; i++) {
      final stroke = strokes[i];
      // Most strokes are nowhere near the eraser: those are passed over
      // without working out how they are drawn.
      if (!_isNear(stroke, centre, radius)) continue;
      final pieces = cut(stroke, centre, radius);
      if (pieces == null) continue;

      strokes
        ..removeAt(i)
        ..insertAll(i, pieces);
      i += pieces.length - 1;
      changed = true;

      final root = _origin.remove(stroke) ?? stroke;
      _inks.remove(stroke);
      final known = _pieces[root];
      if (known == null) {
        _pieces[root] = [...pieces];
      } else {
        final at = known.indexOf(stroke);
        if (at >= 0) {
          known
            ..removeAt(at)
            ..insertAll(at, pieces);
        }
      }
      for (final piece in pieces) {
        _origin[piece] = root;
      }
    }
    return changed;
  }

  /// Moves the eraser to [position], rubbing out everything on the way
  /// there from where it was last. Returns whether anything was rubbed out.
  bool moveTo(Offset position, double radius, List<Stroke> strokes) {
    final from = _last ?? position;
    _last = position;
    final distance = (position - from).distance;
    // Circles half a radius apart leave no gaps to speak of between them.
    final steps = radius <= 0
        ? 1
        : (distance / (radius / 2)).ceil().clamp(1, maxSteps).toInt();
    var changed = false;
    for (var step = 1; step <= steps; step++) {
      final at = Offset.lerp(from, position, step / steps)!;
      if (eraseAt(at, radius, strokes)) changed = true;
    }
    return changed;
  }

  /// Ends the drag: what became of every stroke the eraser touched, in the
  /// order the strokes were on the page.
  List<StrokeReplacement> finish() {
    final result = <StrokeReplacement>[];
    final atStart = _onPageAtStart;
    for (var i = 0; i < atStart.length; i++) {
      final pieces = _pieces[atStart[i]];
      if (pieces == null) continue;
      result.add(
        StrokeReplacement(
          before: atStart[i],
          after: pieces,
          next: i + 1 < atStart.length ? atStart[i + 1] : null,
        ),
      );
    }
    begin(const []);
    return result;
  }
}
