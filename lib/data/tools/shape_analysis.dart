import 'dart:math';
import 'dart:ui';

/// What a drawn stroke was recognised as.
enum ShapeKind { line, circle, ellipse, rectangle, polygon, curve }

/// A recognised shape. Which fields matter depends on [kind]:
/// - [ShapeKind.line]: [points] holds the two ends.
/// - [ShapeKind.circle] and [ShapeKind.ellipse]: [center], [radiusX],
///   [radiusY] and [rotation] (radians, of the x radius).
/// - [ShapeKind.rectangle]: an axis-aligned [rect].
/// - [ShapeKind.polygon]: [points] holds the corners, without repeating the
///   first one.
/// - [ShapeKind.curve]: [points] holds the points of a circular arc.
class ShapeGuess {
  const ShapeGuess({
    required this.kind,
    this.points = const [],
    this.center = Offset.zero,
    this.radiusX = 0,
    this.radiusY = 0,
    this.rotation = 0,
    this.rect = Rect.zero,
  });

  final ShapeKind kind;
  final List<Offset> points;
  final Offset center;
  final double radiusX, radiusY, rotation;
  final Rect rect;

  /// The shape as a list of points to draw or save. Closed shapes end on
  /// their first point.
  List<Offset> outline({int samples = 96}) {
    switch (kind) {
      case ShapeKind.line:
      case ShapeKind.curve:
        return points;
      case ShapeKind.polygon:
        return [...points, points.first];
      case ShapeKind.rectangle:
        return [
          rect.topLeft,
          rect.topRight,
          rect.bottomRight,
          rect.bottomLeft,
          rect.topLeft,
        ];
      case ShapeKind.circle:
      case ShapeKind.ellipse:
        final cosR = cos(rotation), sinR = sin(rotation);
        Offset at(int i) {
          final t = 2 * pi * (i % samples) / samples;
          final u = radiusX * cos(t), v = radiusY * sin(t);
          return center + Offset(u * cosR - v * sinR, u * sinR + v * cosR);
        }

        return [for (var i = 0; i <= samples; i++) at(i)];
    }
  }
}

/// Recognises lines, circles, ellipses, rectangles, polygons and arcs in
/// hand-drawn strokes.
///
/// Everything here works on plain points, so it is easy to test.
///
/// A stroke is not matched against templates. Each shape it might be is
/// *fitted* to it, the way a draughtsman would trace it: an ellipse, a
/// rectangle (tilted or not), a triangle, a pentagon, a hexagon, a straight
/// line, a circular arc. Every fit is measured by how far the stroke strays
/// from the fitted outline, and the shape that explains the stroke best,
/// with a small price for every extra corner so that a wobbly curve is not
/// "explained" by a polygon with many sides, wins. A stroke that no shape
/// explains well, or that wanders (loops, notches, waves), is left alone.
abstract class ShapeAnalysis {
  /// Strokes smaller than this (the diagonal of their bounding box, in page
  /// units) are never turned into shapes: they are writing, not diagrams.
  static const minSize = 40.0;

  /// The most corners a polygon can have.
  static const maxCorners = 6;

  /// How many points a closed stroke is resampled to.
  static const _ringSize = 96;

  /// A price for a model, as a share of the stroke's size, added to how far
  /// the stroke strays from it: for an ellipse, for each corner of a polygon
  /// beyond two, and for a rectangle.
  static const _priceEllipse = 0.0025;
  static const _priceCorner = 0.0006;
  static const _priceRectangle = 0.0003;

  /// Polygons and rectangles are believed more than their raw fit says:
  /// a hand-drawn corner is rounder than a corner, so a polygon always
  /// fits a little worse than the ink of someone who meant a polygon.
  static const _polygonBias = 0.75;
  static const _rectangleBias = 0.55;

  /// A closed shape is only accepted if the stroke strays from it by no
  /// more than this on average, and at the worst point (shares of the
  /// stroke's size).
  static const _acceptAverage = 0.026;
  static const _acceptWorst = 0.085;

  /// A closed stroke has to turn the same way throughout, at least this
  /// much of the time, to be a shape (a heart or a star does not).
  static const _convexShare = 0.83;

  /// An ellipse whose long side is less than this many times the short
  /// side is a circle.
  static const _circleRatio = 1.12;

  /// A rectangle whose sides are within this of level and upright is made
  /// exactly so; so is an ellipse within [_ellipseAxisSnap].
  static const _axisSnap = 8 * pi / 180;
  static const _ellipseAxisSnap = 5 * pi / 180;

  /// Four corners are a rectangle if the angles are right angles, give or
  /// take this, and opposite sides run parallel, give or take that.
  static const _rightAngleSlack = 16.0; // degrees
  static const _parallelSlack = 12 * pi / 180;

  /// A side of a polygon is at least this share of its perimeter, and a
  /// corner turns the stroke by at least this many degrees.
  static const _shortestSide = 0.07;
  static const _leastTurn = 22.0;

  /// Looks at [raw] (the points of a stroke, in order) and returns the shape
  /// it most likely was, or null when it doesn't look like a shape.
  static ShapeGuess? analyze(List<Offset> raw) {
    final points = _dedupe(raw);
    if (points.length < 4) return null;

    final length = _pathLength(points);
    final box = _bounds(points);
    final diagonal = sqrt(box.width * box.width + box.height * box.height);
    if (diagonal < minSize || length <= 0) return null;

    final gap = (points.first - points.last).distance;
    if (gap > 0.18 * length) {
      // An open stroke, unless a tail or a hook at an end is all that keeps
      // it from closing.
      final open = _open(points, length, diagonal);
      if (open != null) return open;
    }
    return _closedTrimmed(points, diagonal);
  }

  /// How much of the stroke's length may be trimmed off each end, to get
  /// rid of a flick where the pen came down or a hook where it was lifted.
  static const _trims = [0.0, 0.04, 0.08];

  /// A trimmed reading has to beat the untrimmed one by this much (shares
  /// of the stroke's size), plus [_trimPrice] for every share trimmed.
  static const _trimMargin = 0.004;
  static const _trimPrice = 0.01;

  /// The best reading of [points] as a closed shape, trying the stroke as
  /// it is and with its ends trimmed. The stroke as it is wins unless a
  /// trimmed one is clearly better.
  static ShapeGuess? _closedTrimmed(List<Offset> points, double size) {
    _Model? whole;
    _Model? best;
    var bestScore = double.infinity;
    for (final start in _trims) {
      for (final end in _trims) {
        final part = _trimEnds(points, start, end);
        if (part.length < 8) continue;
        final gap = (part.first - part.last).distance;
        if (gap > 0.18 * _pathLength(part)) continue;
        final model = _closed(_closeLoop(part), size);
        if (model == null) continue;
        if (start == 0 && end == 0) {
          whole = model;
          continue;
        }
        final score = model.score + _trimMargin + _trimPrice * (start + end);
        if (score < bestScore) {
          bestScore = score;
          best = model;
        }
      }
    }
    if (whole == null) return best?.guess;
    if (best != null && bestScore < whole.score) return best.guess;
    return whole.guess;
  }

  /// [points] without [start] of the path length at the start and [end] of
  /// it at the end.
  static List<Offset> _trimEnds(List<Offset> points, double start, double end) {
    if (start == 0 && end == 0) return points;
    final total = _pathLength(points);
    var walked = 0.0, low = 0, high = points.length - 1;
    for (var i = 1; i < points.length; i++) {
      walked += (points[i] - points[i - 1]).distance;
      if (walked < start * total) low = i;
      if (walked <= (1 - end) * total) high = i;
    }
    return points.sublist(low, high + 1);
  }

  // -- closing a loop -------------------------------------------------------

  /// A loop that overshoots its start is cut where it crosses its own
  /// beginning, or if it never does, where it comes closest to it.
  static List<Offset> _closeLoop(List<Offset> points) {
    return _cutAtCrossing(points) ?? _cutAtNearest(points);
  }

  static List<Offset> _cutAtNearest(List<Offset> points) {
    final n = points.length;
    var best = n - 1;
    var bestDistance = (points.first - points.last).distance;
    for (var i = (n * 0.7).floor(); i < n; i++) {
      final d = (points.first - points[i]).distance;
      if (d < bestDistance - 1e-9) {
        bestDistance = d;
        best = i;
      }
    }
    return points.sublist(0, best + 1);
  }

  /// The loop from where the stroke's end crosses its start to the crossing
  /// again, or null if the end never crosses the start.
  static List<Offset>? _cutAtCrossing(List<Offset> points) {
    final n = points.length;
    if (n < 12) return null;
    final total = _pathLength(points);
    final along = List<double>.filled(n, 0);
    for (var i = 1; i < n; i++) {
      along[i] = along[i - 1] + (points[i] - points[i - 1]).distance;
    }
    for (var i = 0; i < n - 1; i++) {
      if (along[i] < 0.6 * total) continue;
      for (var j = 0; j < n - 1; j++) {
        if (along[j + 1] > 0.4 * total) break;
        final hit = _crossing(points[i], points[i + 1], points[j], points[j + 1]);
        if (hit != null) {
          return [hit, ...points.sublist(j + 1, i + 1), hit];
        }
      }
    }
    return null;
  }

  /// Where the segments a-b and c-d cross, or null.
  static Offset? _crossing(Offset a, Offset b, Offset c, Offset d) {
    final r = b - a, s = d - c;
    final denominator = r.dx * s.dy - r.dy * s.dx;
    if (denominator.abs() < 1e-12) return null;
    final t = ((c.dx - a.dx) * s.dy - (c.dy - a.dy) * s.dx) / denominator;
    final u = ((c.dx - a.dx) * r.dy - (c.dy - a.dy) * r.dx) / denominator;
    if (t < 0 || t > 1 || u < 0 || u > 1) return null;
    return a + r * t;
  }

  // -- open strokes ---------------------------------------------------------

  static ShapeGuess? _open(List<Offset> points, double length, double size) {
    final first = points.first, last = points.last;
    final chord = (last - first).distance;
    if (chord < minSize * 0.8) return null;

    var maxDeviation = 0.0;
    for (final p in points) {
      maxDeviation = max(maxDeviation, _lineDistance(p, first, last));
    }
    if (maxDeviation <= 0.06 * chord && length <= 1.15 * chord) {
      return ShapeGuess(kind: ShapeKind.line, points: [first, last]);
    }

    // An arc: part of a circle that the stroke follows, turning the same
    // way throughout.
    final path = _resample(points, 64, closed: false);
    final circle = _circleFit(path);
    if (circle == null) return null;
    final (center, radius) = circle;
    if (radius > 20 * size) return null;

    var squares = 0.0, worst = 0.0;
    for (final p in path) {
      final off = ((p - center).distance - radius).abs();
      squares += off * off;
      worst = max(worst, off);
    }
    final average = sqrt(squares / path.length);

    final start = (path.first - center).direction;
    var previous = start, sweep = 0.0, travelled = 0.0;
    for (var i = 1; i < path.length; i++) {
      final angle = (path[i] - center).direction;
      final step = _wrapAngle(angle - previous);
      sweep += step;
      travelled += step.abs();
      previous = angle;
    }
    if (sweep.abs() < 0.5 || sweep.abs() > 5.6) return null;
    if (sweep.abs() / (travelled + 1e-9) <= 0.92) return null;
    if (average > 0.022 * radius + 0.003 * size) return null;
    if (worst > 0.07 * radius + 0.01 * size) return null;

    final count = max(12, (sweep.abs() / 0.1).floor());
    return ShapeGuess(
      kind: ShapeKind.curve,
      points: [
        for (var i = 0; i <= count; i++)
          center + Offset.fromDirection(start + sweep * i / count, radius),
      ],
    );
  }

  // -- closed strokes -------------------------------------------------------

  static _Model? _closed(List<Offset> stroke, double size) {
    final ring = _smooth(
      _resample(stroke, _ringSize, closed: true),
      closed: true,
      passes: 1,
    );
    final n = ring.length;
    final window = max(2, n ~/ 24);
    if (_turningShare(ring, max(3, n ~/ 12)) < _convexShare) return null;

    final models = <_Model>[];

    // An ellipse (or a circle).
    final ellipse = _ellipseFit(ring);
    if (ellipse != null) {
      var squares = 0.0, worst = 0.0;
      for (final p in ring) {
        final d = ellipse.distanceTo(p);
        squares += d * d;
        worst = max(worst, d);
      }
      final average = sqrt(squares / n);
      if (ellipse.b / ellipse.a >= 0.15 && ellipse.a >= 10) {
        models.add(
          _Model(
            _ellipseGuess(ellipse),
            average / size,
            worst / size,
            average / size + _priceEllipse,
          ),
        );
      }
    }

    // Polygons with three to six corners.
    final corners = _cornerCandidates(ring, window, 10 * pi / 180);
    final polygons = <int, _Polygon>{};
    for (var k = 3; k <= maxCorners; k++) {
      final polygon = _fitPolygon(ring, corners, k, size);
      if (polygon != null) polygons[k] = polygon;
    }

    final fourCorners = polygons[4];
    final rectangle = fourCorners == null
        ? null
        : _rectangleFrom(ring, fourCorners, size);
    if (rectangle != null) models.add(rectangle);

    for (final MapEntry(key: k, value: polygon) in polygons.entries) {
      if (k == 4 && rectangle != null) continue;
      models.add(
        _Model(
          ShapeGuess(kind: ShapeKind.polygon, points: polygon.corners),
          polygon.average / size,
          polygon.worst / size,
          _polygonBias * polygon.average / size + _priceCorner * (k - 2),
        ),
      );
    }

    models.removeWhere((m) => m.average > _acceptAverage || m.worst > _acceptWorst);
    if (models.isEmpty) return null;
    models.sort((a, b) => a.score.compareTo(b.score));
    return models.first;
  }

  /// How much of the way round a closed stroke it turns the same way: 1
  /// for a convex shape, much less for a figure with notches or loops.
  static double _turningShare(List<Offset> ring, int window) {
    var signed = 0.0, absolute = 0.0;
    for (var i = 0; i < ring.length; i++) {
      final angle = _turnAt(ring, i, window);
      signed += angle;
      absolute += angle.abs();
    }
    return absolute > 0 ? signed.abs() / absolute : 0;
  }

  static double _turnAt(List<Offset> ring, int i, int window) {
    final n = ring.length;
    final v1 = ring[i] - ring[(i - window) % n];
    final v2 = ring[(i + window) % n] - ring[i];
    return atan2(v1.dx * v2.dy - v1.dy * v2.dx, v1.dx * v2.dx + v1.dy * v2.dy);
  }

  /// The places along [ring] where it turns sharply (the local maxima of
  /// how much it turns), at least [window] points apart.
  static List<int> _cornerCandidates(
    List<Offset> ring,
    int window,
    double leastTurn,
  ) {
    final n = ring.length;
    final turn = [for (var i = 0; i < n; i++) _turnAt(ring, i, window).abs()];
    final found = <int>[];
    for (var i = 0; i < n; i++) {
      if (turn[i] < leastTurn) continue;
      var isPeak = true;
      for (var d = -window; d <= window; d++) {
        if (d != 0 && turn[i] < turn[(i + d) % n]) {
          isPeak = false;
          break;
        }
      }
      if (!isPeak) continue;
      if (found.every((j) => min((i - j) % n, (j - i) % n) >= window)) {
        found.add(i);
      }
    }
    return found;
  }

  /// The best [k]-cornered polygon through some of the [candidates], as
  /// the corners where its sides meet, or null if there is none worth
  /// having (too few corners to choose from, sides that are tiny, or
  /// corners that hardly turn).
  static _Polygon? _fitPolygon(
    List<Offset> ring,
    List<int> candidates,
    int k,
    double size,
  ) {
    final chosen = _bestCorners(ring, candidates, k);
    if (chosen == null) return null;
    final corners = _meetingPoints(ring, chosen, size);
    if (corners == null) return null;

    var perimeter = 0.0, shortest = double.infinity;
    for (var i = 0; i < k; i++) {
      final side = (corners[(i + 1) % k] - corners[i]).distance;
      perimeter += side;
      shortest = min(shortest, side);
    }
    if (perimeter <= 0 || shortest < _shortestSide * perimeter) return null;
    for (final angle in _interiorAngles(corners)) {
      if (180 - angle < _leastTurn) return null;
    }

    var squares = 0.0, worst = 0.0;
    for (final p in ring) {
      var nearest = double.infinity;
      for (var i = 0; i < k; i++) {
        nearest = min(
          nearest,
          _segmentDistance(p, corners[i], corners[(i + 1) % k]),
        );
      }
      squares += nearest * nearest;
      worst = max(worst, nearest);
    }
    return _Polygon(corners, sqrt(squares / ring.length), worst);
  }

  /// The [k] of the [candidates] at which cutting [ring] into [k] straight
  /// chords leaves the least distance between the ring and the chords
  /// (dynamic programming round the ring).
  static List<int>? _bestCorners(List<Offset> ring, List<int> candidates, int k) {
    final m = candidates.length;
    if (m < k) return null;
    final n = ring.length;

    final cost = List.generate(m, (_) => List<double>.filled(m, 0));
    for (var a = 0; a < m; a++) {
      for (var b = 0; b < m; b++) {
        if (a == b) continue;
        final from = candidates[a], to = candidates[b];
        final steps = (to - from) % n;
        var sum = 0.0;
        for (var s = 1; s < steps; s++) {
          final d = _segmentDistance(ring[(from + s) % n], ring[from], ring[to]);
          sum += d * d;
        }
        cost[a][b] = sum;
      }
    }

    var bestCost = double.infinity;
    List<int>? best;
    for (var start = 0; start < m; start++) {
      final order = [for (var d = 0; d < m; d++) (start + d) % m];
      final table = List.generate(k, (_) => List<double>.filled(m, double.infinity));
      final parent = List.generate(k, (_) => List<int>.filled(m, -1));
      table[0][0] = 0;
      for (var q = 1; q < k; q++) {
        for (var b = q; b < m; b++) {
          for (var a = q - 1; a < b; a++) {
            if (table[q - 1][a] == double.infinity) continue;
            final value = table[q - 1][a] + cost[order[a]][order[b]];
            if (value < table[q][b]) {
              table[q][b] = value;
              parent[q][b] = a;
            }
          }
        }
      }
      for (var b = k - 1; b < m; b++) {
        if (table[k - 1][b] == double.infinity) continue;
        final total = table[k - 1][b] + cost[order[b]][order[0]];
        if (total < bestCost) {
          bestCost = total;
          final sequence = <int>[b];
          var q = k - 1, at = b;
          while (q > 0) {
            at = parent[q][at];
            sequence.add(at);
            q--;
          }
          best = [for (final x in sequence.reversed) candidates[order[x]]];
        }
      }
    }
    return best;
  }

  /// The corners of the polygon whose sides are straight lines fitted to
  /// the stretches of [ring] between the corners [at]: each corner is
  /// where two neighbouring lines meet.
  static List<Offset>? _meetingPoints(List<Offset> ring, List<int> at, double size) {
    final n = ring.length;
    final k = at.length;
    final sides = <(Offset, Offset)>[];
    for (var s = 0; s < k; s++) {
      final from = at[s];
      final to = at[(s + 1) % k];
      final count = (to - from) % n;
      if (count < 3) return null;
      final skip = max(1, count ~/ 5);
      final samples = <Offset>[
        for (var i = skip; i <= count - skip; i++) ring[(from + i) % n],
      ];
      if (samples.length < 2) {
        samples
          ..clear()
          ..addAll([ring[from], ring[to]]);
      }
      sides.add(_fitLine(samples));
    }
    final corners = <Offset>[];
    for (var c = 0; c < k; c++) {
      var corner = _intersect(sides[(c - 1 + k) % k], sides[c]);
      final fallback = ring[at[c]];
      if (corner == null || (corner - fallback).distance > 0.2 * size) {
        corner = fallback;
      }
      corners.add(corner);
    }
    return corners;
  }

  /// The inside angles (degrees) of a polygon at each of its corners.
  static List<double> _interiorAngles(List<Offset> corners) {
    final k = corners.length;
    return [
      for (var i = 0; i < k; i++)
        () {
          final a = corners[(i - 1 + k) % k] - corners[i];
          final b = corners[(i + 1) % k] - corners[i];
          final la = a.distance, lb = b.distance;
          if (la == 0 || lb == 0) return 0.0;
          final c = ((a.dx * b.dx + a.dy * b.dy) / (la * lb)).clamp(-1.0, 1.0);
          return acos(c) * 180 / pi;
        }(),
    ];
  }

  // -- rectangles -----------------------------------------------------------

  /// The rectangle that four corners are, if they form one: right angles
  /// (give or take [_rightAngleSlack]) and opposite sides parallel. Fitted
  /// to the stroke as a whole, and made level or upright if it nearly is.
  static _Model? _rectangleFrom(List<Offset> ring, _Polygon four, double size) {
    final corners = four.corners;
    for (final angle in _interiorAngles(corners)) {
      if ((angle - 90).abs() > _rightAngleSlack) return null;
    }
    final directions = [
      for (var i = 0; i < 4; i++)
        (corners[(i + 1) % 4] - corners[i]).direction,
    ];
    double apart(double a, double b) => (pi - _wrapAngle(a - b).abs()).abs();
    if (max(apart(directions[0], directions[2]), apart(directions[1], directions[3])) >
        _parallelSlack) {
      return null;
    }

    // The tilt of the sides, taken round the quarter turn.
    var sumCos = 0.0, sumSin = 0.0;
    for (var i = 0; i < 4; i++) {
      final side = corners[(i + 1) % 4] - corners[i];
      final length = side.distance;
      sumCos += cos(4 * side.direction) * length;
      sumSin += sin(4 * side.direction) * length;
    }
    final fit = _rectangleFit(ring, atan2(sumSin, sumCos) / 4);

    final quarters = (fit.tilt / (pi / 2)).round();
    final slack = fit.tilt - quarters * (pi / 2);
    if (slack.abs() <= _axisSnap) {
      // Level and upright.
      final swapped = quarters.isOdd;
      final width = swapped ? fit.height : fit.width;
      final height = swapped ? fit.width : fit.height;
      var squares = 0.0, worst = 0.0;
      for (final p in ring) {
        final d = _rectangleDistance(
          p,
          fit.center,
          fit.width,
          fit.height,
          quarters * (pi / 2),
        );
        squares += d * d;
        worst = max(worst, d);
      }
      final average = sqrt(squares / ring.length);
      return _Model(
        ShapeGuess(
          kind: ShapeKind.rectangle,
          rect: Rect.fromCenter(center: fit.center, width: width, height: height),
        ),
        average / size,
        worst / size,
        _rectangleBias * average / size + _priceRectangle,
      );
    }

    var squares = 0.0, worst = 0.0;
    for (final p in ring) {
      final d = _rectangleDistance(p, fit.center, fit.width, fit.height, fit.tilt);
      squares += d * d;
      worst = max(worst, d);
    }
    final average = sqrt(squares / ring.length);
    final c = cos(fit.tilt), s = sin(fit.tilt);
    Offset corner(double x, double y) =>
        fit.center + Offset(x * c - y * s, x * s + y * c);
    final hw = fit.width / 2, hh = fit.height / 2;
    return _Model(
      ShapeGuess(
        kind: ShapeKind.polygon,
        points: [corner(-hw, -hh), corner(hw, -hh), corner(hw, hh), corner(-hw, hh)],
      ),
      average / size,
      worst / size,
      _rectangleBias * average / size + _priceRectangle,
    );
  }

  /// How far [p] is from the outline of the rectangle of [width] by
  /// [height] about [center], turned by [tilt].
  static double _rectangleDistance(
    Offset p,
    Offset center,
    double width,
    double height,
    double tilt,
  ) {
    final c = cos(tilt), s = sin(tilt);
    final dx = p.dx - center.dx, dy = p.dy - center.dy;
    final u = (dx * c + dy * s).abs();
    final v = (-dx * s + dy * c).abs();
    final qx = u - width / 2, qy = v - height / 2;
    final outside = sqrt(max(qx, 0) * max(qx, 0) + max(qy, 0) * max(qy, 0));
    final inside = min(max(qx, qy), 0.0);
    return (outside + inside).abs();
  }

  /// The rectangle that best fits [ring], starting from one tilted by
  /// [tilt0].
  static _RectangleFit _rectangleFit(List<Offset> ring, double tilt0) {
    var mx = 0.0, my = 0.0;
    for (final p in ring) {
      mx += p.dx;
      my += p.dy;
    }
    mx /= ring.length;
    my /= ring.length;
    final c = cos(tilt0), s = sin(tilt0);
    var minU = double.infinity, maxU = -double.infinity;
    var minV = double.infinity, maxV = -double.infinity;
    for (final p in ring) {
      final u = (p.dx - mx) * c + (p.dy - my) * s;
      final v = -(p.dx - mx) * s + (p.dy - my) * c;
      minU = min(minU, u);
      maxU = max(maxU, u);
      minV = min(minV, v);
      maxV = max(maxV, v);
    }
    final cu = (maxU + minU) / 2, cv = (maxV + minV) / 2;
    final start = [
      mx + cu * c - cv * s,
      my + cu * s + cv * c,
      maxU - minU,
      maxV - minV,
      tilt0,
    ];
    final x = _levenbergMarquardt(
      (x) => [
        for (final p in ring)
          _rectangleDistance(p, Offset(x[0], x[1]), x[2].abs(), x[3].abs(), x[4]),
      ],
      start,
      iterations: 40,
    );
    return _RectangleFit(Offset(x[0], x[1]), x[2].abs(), x[3].abs(), x[4]);
  }

  // -- ellipses and circles -------------------------------------------------

  static ShapeGuess _ellipseGuess(_EllipseFit e) {
    if (e.a / e.b < _circleRatio) {
      final radius = (e.a + e.b) / 2;
      return ShapeGuess(
        kind: ShapeKind.circle,
        center: e.center,
        radiusX: radius,
        radiusY: radius,
      );
    }
    // Level or upright if it nearly is.
    var tilt = e.tilt;
    final quarters = (tilt / (pi / 2)).round();
    if ((tilt - quarters * (pi / 2)).abs() <= _ellipseAxisSnap) {
      tilt = quarters.isEven ? 0 : pi / 2;
    }
    return ShapeGuess(
      kind: ShapeKind.ellipse,
      center: e.center,
      radiusX: e.a,
      radiusY: e.b,
      rotation: tilt,
    );
  }

  /// The ellipse that best fits [ring] (long side first), found by
  /// adjusting an ellipse set up from the stroke's principal axes until
  /// the distance to it is as small as it gets. Null if that fails.
  static _EllipseFit? _ellipseFit(List<Offset> ring) {
    final n = ring.length;
    var mx = 0.0, my = 0.0;
    for (final p in ring) {
      mx += p.dx;
      my += p.dy;
    }
    mx /= n;
    my /= n;
    var sxx = 0.0, syy = 0.0, sxy = 0.0;
    for (final p in ring) {
      final dx = p.dx - mx, dy = p.dy - my;
      sxx += dx * dx;
      syy += dy * dy;
      sxy += dx * dy;
    }
    final rotation = 0.5 * atan2(2 * sxy, sxx - syy);
    final c = cos(rotation), s = sin(rotation);
    var minU = double.infinity, maxU = -double.infinity;
    var minV = double.infinity, maxV = -double.infinity;
    for (final p in ring) {
      final u = (p.dx - mx) * c + (p.dy - my) * s;
      final v = -(p.dx - mx) * s + (p.dy - my) * c;
      minU = min(minU, u);
      maxU = max(maxU, u);
      minV = min(minV, v);
      maxV = max(maxV, v);
    }
    final a = (maxU - minU) / 2, b = (maxV - minV) / 2;
    if (a < 1 || b < 1) return null;
    final cu = (maxU + minU) / 2, cv = (maxV + minV) / 2;

    final x = _levenbergMarquardt(
      (x) => [for (final p in ring) _ellipseResidual(p, x)],
      [mx + cu * c - cv * s, my + cu * s + cv * c, a, b, rotation],
      iterations: 40,
    );
    var long = x[2].abs(), short = x[3].abs(), tilt = x[4];
    if (!long.isFinite || !short.isFinite || !tilt.isFinite || short <= 0) {
      return null;
    }
    if (short > long) {
      final swap = long;
      long = short;
      short = swap;
      tilt += pi / 2;
    }
    tilt = (tilt + pi / 2) % pi - pi / 2;
    return _EllipseFit(Offset(x[0], x[1]), long, short, tilt);
  }

  /// An (approximate) distance from [p] to the ellipse in [x]: centre x and
  /// y, the two radii and the tilt.
  static double _ellipseResidual(Offset p, List<double> x) {
    final a = x[2].abs() + 1e-6, b = x[3].abs() + 1e-6;
    final c = cos(x[4]), s = sin(x[4]);
    final dx = p.dx - x[0], dy = p.dy - x[1];
    final u = dx * c + dy * s, v = -dx * s + dy * c;
    final f = (u / a) * (u / a) + (v / b) * (v / b);
    final gx = 2 * u / (a * a), gy = 2 * v / (b * b);
    return (f - 1) / (sqrt(gx * gx + gy * gy) + 1e-9);
  }

  /// The circle (centre, radius) that best fits [points].
  static (Offset, double)? _circleFit(List<Offset> points) {
    final n = points.length;
    var mx = 0.0, my = 0.0;
    for (final p in points) {
      mx += p.dx;
      my += p.dy;
    }
    mx /= n;
    my /= n;
    var suu = 0.0, suv = 0.0, svv = 0.0;
    var suuu = 0.0, svvv = 0.0, suvv = 0.0, svuu = 0.0;
    for (final p in points) {
      final u = p.dx - mx, v = p.dy - my;
      suu += u * u;
      suv += u * v;
      svv += v * v;
      suuu += u * u * u;
      svvv += v * v * v;
      suvv += u * v * v;
      svuu += v * u * u;
    }
    final determinant = suu * svv - suv * suv;
    if (determinant.abs() < 1e-9) return null;
    final uc = (svv * (suuu + suvv) - suv * (svvv + svuu)) / (2 * determinant);
    final vc = (suu * (svvv + svuu) - suv * (suuu + suvv)) / (2 * determinant);
    var radius = 0.0;
    for (final p in points) {
      radius += (p - Offset(mx + uc, my + vc)).distance;
    }
    radius /= n;

    final x = _levenbergMarquardt(
      (x) => [
        for (final p in points) (p - Offset(x[0], x[1])).distance - x[2],
      ],
      [mx + uc, my + vc, radius],
      iterations: 15,
    );
    if (!x.every((v) => v.isFinite) || x[2].abs() <= 0) return null;
    return (Offset(x[0], x[1]), x[2].abs());
  }

  // -- numerical fitting ----------------------------------------------------

  /// Adjusts [start] until the sum of the squares of [residual] is as small
  /// as it gets (Levenberg-Marquardt, with a numerical Jacobian: the
  /// models here have five numbers at most).
  static List<double> _levenbergMarquardt(
    List<double> Function(List<double>) residual,
    List<double> start, {
    int iterations = 30,
  }) {
    var x = List<double>.of(start);
    var r = residual(x);
    var cost = _sumOfSquares(r);
    var damping = 1e-2;
    final n = x.length;
    for (var iteration = 0; iteration < iterations; iteration++) {
      final jacobian = <List<double>>[];
      for (var j = 0; j < n; j++) {
        final h = 1e-4 * max(1.0, x[j].abs());
        final shifted = List<double>.of(x)..[j] += h;
        final rj = residual(shifted);
        jacobian.add([for (var i = 0; i < r.length; i++) (rj[i] - r[i]) / h]);
      }
      final normal = List.generate(
        n,
        (a) => [
          for (var b = 0; b < n; b++)
            () {
              var sum = 0.0;
              for (var i = 0; i < r.length; i++) {
                sum += jacobian[a][i] * jacobian[b][i];
              }
              return sum;
            }(),
        ],
      );
      final gradient = [
        for (var a = 0; a < n; a++)
          () {
            var sum = 0.0;
            for (var i = 0; i < r.length; i++) {
              sum += jacobian[a][i] * r[i];
            }
            return sum;
          }(),
      ];

      var improved = false;
      for (var attempt = 0; attempt < 6; attempt++) {
        final damped = [
          for (var a = 0; a < n; a++)
            [
              for (var b = 0; b < n; b++)
                normal[a][b] + (a == b ? damping * (normal[a][a] + 1e-9) : 0),
            ],
        ];
        final step = _solve(damped, [for (final g in gradient) -g]);
        if (step == null) {
          damping *= 10;
          continue;
        }
        final next = [for (var i = 0; i < n; i++) x[i] + step[i]];
        final rn = residual(next);
        final cn = _sumOfSquares(rn);
        if (cn.isFinite && cn < cost) {
          x = next;
          r = rn;
          cost = cn;
          damping = max(damping / 3, 1e-9);
          improved = true;
          break;
        }
        damping *= 4;
      }
      if (!improved) break;
    }
    return x;
  }

  static double _sumOfSquares(List<double> values) {
    var sum = 0.0;
    for (final v in values) {
      sum += v * v;
    }
    return sum;
  }

  /// Solves a x = b by Gaussian elimination, or null if a is singular.
  static List<double>? _solve(List<List<double>> a, List<double> b) {
    final n = b.length;
    final m = [
      for (var i = 0; i < n; i++) [...a[i], b[i]],
    ];
    for (var col = 0; col < n; col++) {
      var pivot = col;
      for (var r = col + 1; r < n; r++) {
        if (m[r][col].abs() > m[pivot][col].abs()) pivot = r;
      }
      if (m[pivot][col].abs() < 1e-14) return null;
      final swap = m[col];
      m[col] = m[pivot];
      m[pivot] = swap;
      for (var r = col + 1; r < n; r++) {
        final factor = m[r][col] / m[col][col];
        for (var c = col; c <= n; c++) {
          m[r][c] -= factor * m[col][c];
        }
      }
    }
    final x = List<double>.filled(n, 0);
    for (var r = n - 1; r >= 0; r--) {
      var sum = m[r][n];
      for (var k = r + 1; k < n; k++) {
        sum -= m[r][k] * x[k];
      }
      x[r] = sum / m[r][r];
    }
    return x.every((v) => v.isFinite) ? x : null;
  }

  // -- geometry helpers -----------------------------------------------------

  /// [angle] brought into -pi..pi.
  static double _wrapAngle(double angle) =>
      (angle + pi) % (2 * pi) - pi;

  static List<Offset> _dedupe(List<Offset> points) {
    final result = <Offset>[];
    for (final p in points) {
      if (!p.isFinite) continue;
      if (result.isEmpty || (p - result.last).distance > 0.01) result.add(p);
    }
    return result;
  }

  static double _pathLength(List<Offset> points) {
    var total = 0.0;
    for (var i = 1; i < points.length; i++) {
      total += (points[i] - points[i - 1]).distance;
    }
    return total;
  }

  static Rect _bounds(List<Offset> points) {
    var left = points.first.dx, right = left;
    var top = points.first.dy, bottom = top;
    for (final p in points) {
      left = min(left, p.dx);
      right = max(right, p.dx);
      top = min(top, p.dy);
      bottom = max(bottom, p.dy);
    }
    return Rect.fromLTRB(left, top, right, bottom);
  }

  /// [count] points spread evenly along [path]. For a [closed] shape the
  /// path is joined end to start and the last point is not repeated.
  static List<Offset> _resample(
    List<Offset> path,
    int count, {
    required bool closed,
  }) {
    final line = closed ? [...path, path.first] : path;
    final total = _pathLength(line);
    if (total <= 0) return List.filled(count, path.first);
    final step = total / (closed ? count : count - 1);

    final result = <Offset>[line.first];
    var walked = 0.0;
    for (var i = 1; i < line.length && result.length < count; i++) {
      final a = line[i - 1], b = line[i];
      final length = (b - a).distance;
      if (length <= 0) continue;
      while (result.length < count &&
          walked + length >= result.length * step - 1e-9) {
        final t = ((result.length * step - walked) / length).clamp(0.0, 1.0);
        result.add(Offset.lerp(a, b, t)!);
      }
      walked += length;
    }
    while (result.length < count) {
      result.add(line.last);
    }
    return result;
  }

  /// Averages each point with its neighbours. The ends of an open stroke stay
  /// where they are.
  static List<Offset> _smooth(
    List<Offset> points, {
    required bool closed,
    int passes = 2,
  }) {
    var current = points;
    for (var pass = 0; pass < passes; pass++) {
      final n = current.length;
      final next = List<Offset>.of(current);
      for (var i = 0; i < n; i++) {
        if (!closed && (i == 0 || i == n - 1)) continue;
        final before = current[(i - 1 + n) % n];
        final after = current[(i + 1) % n];
        next[i] = (before + current[i] + after) / 3;
      }
      current = next;
    }
    return current;
  }

  /// Distance from [p] to the infinite line through [a] and [b].
  static double _lineDistance(Offset p, Offset a, Offset b) {
    final d = b - a;
    final length = d.distance;
    if (length <= 0) return (p - a).distance;
    return ((p.dx - a.dx) * d.dy - (p.dy - a.dy) * d.dx).abs() / length;
  }

  /// Distance from [p] to the segment from [a] to [b].
  static double _segmentDistance(Offset p, Offset a, Offset b) {
    final d = b - a;
    final lengthSquared = d.dx * d.dx + d.dy * d.dy;
    if (lengthSquared <= 0) return (p - a).distance;
    final t =
        (((p.dx - a.dx) * d.dx + (p.dy - a.dy) * d.dy) / lengthSquared).clamp(
          0.0,
          1.0,
        );
    return (p - (a + d * t)).distance;
  }

  /// The straight line that best fits [samples], as (centre, unit direction).
  static (Offset, Offset) _fitLine(List<Offset> samples) {
    var mx = 0.0, my = 0.0;
    for (final p in samples) {
      mx += p.dx;
      my += p.dy;
    }
    mx /= samples.length;
    my /= samples.length;
    var sxx = 0.0, syy = 0.0, sxy = 0.0;
    for (final p in samples) {
      final dx = p.dx - mx, dy = p.dy - my;
      sxx += dx * dx;
      syy += dy * dy;
      sxy += dx * dy;
    }
    final angle = 0.5 * atan2(2 * sxy, sxx - syy);
    return (Offset(mx, my), Offset(cos(angle), sin(angle)));
  }

  /// Where two lines (see [_fitLine]) cross, or null if they are almost
  /// parallel.
  static Offset? _intersect((Offset, Offset) first, (Offset, Offset) second) {
    final (p, d) = first;
    final (q, e) = second;
    final cross = d.dx * e.dy - d.dy * e.dx;
    if (cross.abs() < 0.2) return null;
    final t = ((q.dx - p.dx) * e.dy - (q.dy - p.dy) * e.dx) / cross;
    return p + d * t;
  }
}

/// A shape fitted to a closed stroke, with how far the stroke strays from
/// it (as shares of the stroke's size) on average and at the worst point,
/// and the score that decides between shapes (lower is better).
class _Model {
  const _Model(this.guess, this.average, this.worst, this.score);

  final ShapeGuess guess;
  final double average, worst, score;
}

/// A polygon fitted to a closed stroke: its corners, and how far the stroke
/// strays from it on average and at worst (page units).
class _Polygon {
  const _Polygon(this.corners, this.average, this.worst);

  final List<Offset> corners;
  final double average, worst;
}

class _EllipseFit {
  const _EllipseFit(this.center, this.a, this.b, this.tilt);

  final Offset center;

  /// The long and the short radius, and the tilt of the long one.
  final double a, b, tilt;

  /// An (approximate) distance from [p] to the outline.
  double distanceTo(Offset p) =>
      ShapeAnalysis._ellipseResidual(p, [center.dx, center.dy, a, b, tilt]).abs();
}

class _RectangleFit {
  const _RectangleFit(this.center, this.width, this.height, this.tilt);

  final Offset center;
  final double width, height, tilt;
}
