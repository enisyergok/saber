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
/// - [ShapeKind.curve]: [points] holds a smoothed version of the stroke.
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
/// Everything here works on plain points, so it is easy to test. The stroke
/// is resampled, smoothed and its corners found from how sharply it turns.
abstract class ShapeAnalysis {
  /// Strokes smaller than this (the diagonal of their bounding box, in page
  /// units) are never turned into shapes: they are writing, not diagrams.
  static const minSize = 40.0;

  /// How many points the stroke is resampled to.
  static const _samples = 64;

  /// Turning sharper than this over the corner window counts as a corner.
  static const _cornerAngle = 28 * pi / 180;

  /// Turning gentler than this counts as part of a straight side.
  static const _straightAngle = 15 * pi / 180;

  /// The most corners a polygon can have.
  static const maxCorners = 6;

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
    final closed = gap <= 0.18 * length;
    return closed
        ? _closed(_trimOverlap(points), diagonal)
        : _open(points, length);
  }

  /// A loop that overshoots its start is cut where it comes closest to it.
  static List<Offset> _trimOverlap(List<Offset> points) {
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

  // -- open strokes ---------------------------------------------------------

  static ShapeGuess? _open(List<Offset> points, double length) {
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

    // An arc: turns the same way throughout, with no sharp corners.
    final smooth = _smooth(_resample(points, 48, closed: false), closed: false);
    const window = 3;
    final turning = _turning(smooth, window, closed: false);
    var signed = 0.0, absolute = 0.0, sharpest = 0.0;
    for (final angle in turning) {
      signed += angle;
      absolute += angle.abs();
      sharpest = max(sharpest, angle.abs());
    }
    if (sharpest > 40 * pi / 180) return null;
    if (absolute <= 0 || signed.abs() / absolute < 0.85) return null;
    if (signed.abs() < 0.45) return null;

    final curve = [...smooth]
      ..[0] = first
      ..[smooth.length - 1] = last;
    return ShapeGuess(kind: ShapeKind.curve, points: curve);
  }

  // -- closed strokes -------------------------------------------------------

  static ShapeGuess? _closed(List<Offset> points, double diagonal) {
    final ring = _smooth(_resample(points, _samples, closed: true), closed: true);
    const window = _samples ~/ 16;
    final turning = _turning(ring, window, closed: true);
    final corners = _pickCorners(turning, window);

    var straight = 0;
    for (final angle in turning) {
      if (angle.abs() < _straightAngle) straight++;
    }
    final straightShare = straight / turning.length;

    var cornerTurn = 0.0;
    for (final i in corners) {
      cornerTurn += turning[i].abs();
    }
    final meanCorner = corners.isEmpty ? 0.0 : cornerTurn / corners.length;

    final fit = _ellipseFit(ring, turning);
    ShapeGuess? polygon;
    if (corners.length >= 3 &&
        corners.length <= maxCorners &&
        straightShare >= 0.3 &&
        meanCorner >= 38 * pi / 180) {
      polygon = _polygon(ring, corners, diagonal);
    }

    // A clearly smooth outline is an ellipse, even one with tight ends.
    if (polygon != null && fit != null && fit.mean <= 0.02 && fit.worst <= 0.05) {
      polygon = null;
    }
    if (polygon != null) return polygon;
    if (fit != null && fit.mean <= 0.08 && fit.worst <= 0.22) return fit.guess;
    return null;
  }

  /// Picks the sharpest turns, at least [window] samples apart.
  static List<int> _pickCorners(List<double> turning, int window) {
    final n = turning.length;
    final order = [
      for (var i = 0; i < n; i++)
        if (turning[i].abs() >= _cornerAngle) i,
    ]..sort((a, b) => turning[b].abs().compareTo(turning[a].abs()));

    final accepted = <int>[];
    for (final i in order) {
      final farEnough = accepted.every((j) {
        final d = (i - j).abs();
        return min(d, n - d) >= window;
      });
      if (farEnough) accepted.add(i);
    }
    return accepted..sort();
  }

  /// The polygon through [corners]: each side is a straight line fitted to
  /// the stroke between two corners, and each corner is where two lines meet.
  static ShapeGuess? _polygon(
    List<Offset> ring,
    List<int> corners,
    double diagonal,
  ) {
    final n = ring.length;
    final k = corners.length;

    // One fitted line per side, as (point on line, direction).
    final sides = <(Offset, Offset)>[];
    for (var s = 0; s < k; s++) {
      final from = corners[s];
      final to = corners[(s + 1) % k];
      final count = (to - from + n) % n;
      if (count < 3) return null;
      final skip = max(1, count ~/ 4);
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

    final vertices = <Offset>[];
    for (var c = 0; c < k; c++) {
      final before = sides[(c - 1 + k) % k];
      final after = sides[c];
      var vertex = _intersect(before, after);
      final fallback = ring[corners[c]];
      if (vertex == null || (vertex - fallback).distance > 0.25 * diagonal) {
        vertex = fallback;
      }
      vertices.add(vertex);
    }

    // Sides must not be tiny, and the polygon must follow the stroke.
    var perimeter = 0.0;
    for (var i = 0; i < k; i++) {
      perimeter += (vertices[(i + 1) % k] - vertices[i]).distance;
    }
    if (perimeter <= 0) return null;
    for (var i = 0; i < k; i++) {
      if ((vertices[(i + 1) % k] - vertices[i]).distance < 0.08 * perimeter) {
        return null;
      }
    }
    var worst = 0.0;
    for (final p in ring) {
      var nearest = double.infinity;
      for (var i = 0; i < k; i++) {
        nearest = min(
          nearest,
          _segmentDistance(p, vertices[i], vertices[(i + 1) % k]),
        );
      }
      worst = max(worst, nearest);
    }
    if (worst > 0.07 * diagonal) return null;

    if (k == 4) {
      final rect = _axisAlignedRectangle(vertices);
      if (rect != null) {
        return ShapeGuess(kind: ShapeKind.rectangle, rect: rect);
      }
    }
    return ShapeGuess(kind: ShapeKind.polygon, points: vertices);
  }

  /// The rectangle for four [vertices] if they form one with sides that are
  /// (nearly) horizontal and vertical, otherwise null.
  static Rect? _axisAlignedRectangle(List<Offset> vertices) {
    final sinLimit = sin(8 * pi / 180);
    for (var i = 0; i < 4; i++) {
      final side = vertices[(i + 1) % 4] - vertices[i];
      final next = vertices[(i + 2) % 4] - vertices[(i + 1) % 4];
      final length = side.distance, nextLength = next.distance;
      if (length <= 0 || nextLength <= 0) return null;
      // Corners are right angles.
      final cosAngle = (side.dx * next.dx + side.dy * next.dy) /
          (length * nextLength);
      if (cosAngle.abs() > 0.2) return null;
      // Sides run along an axis.
      if (min(side.dx.abs(), side.dy.abs()) / length > sinLimit) return null;
    }
    var left = vertices.first.dx, right = left;
    var top = vertices.first.dy, bottom = top;
    for (final v in vertices) {
      left = min(left, v.dx);
      right = max(right, v.dx);
      top = min(top, v.dy);
      bottom = max(bottom, v.dy);
    }
    return Rect.fromLTRB(left, top, right, bottom);
  }

  /// The ellipse that best fits a closed loop that turns the same way
  /// throughout, and how far the loop strays from it. Null if the loop
  /// can't be an ellipse at all.
  static _EllipseFit? _ellipseFit(List<Offset> ring, List<double> turning) {
    var signed = 0.0, absolute = 0.0;
    for (final angle in turning) {
      signed += angle;
      absolute += angle.abs();
    }
    if (absolute <= 0 || signed.abs() / absolute < 0.85) return null;

    // Principal axes of the points.
    var mx = 0.0, my = 0.0;
    for (final p in ring) {
      mx += p.dx;
      my += p.dy;
    }
    mx /= ring.length;
    my /= ring.length;
    var sxx = 0.0, syy = 0.0, sxy = 0.0;
    for (final p in ring) {
      final dx = p.dx - mx, dy = p.dy - my;
      sxx += dx * dx;
      syy += dy * dy;
      sxy += dx * dy;
    }
    final rotation = 0.5 * atan2(2 * sxy, sxx - syy);
    final cosR = cos(rotation), sinR = sin(rotation);

    // Extent along each axis.
    var minU = double.infinity, maxU = -double.infinity;
    var minV = double.infinity, maxV = -double.infinity;
    for (final p in ring) {
      final dx = p.dx - mx, dy = p.dy - my;
      final u = dx * cosR + dy * sinR;
      final v = -dx * sinR + dy * cosR;
      minU = min(minU, u);
      maxU = max(maxU, u);
      minV = min(minV, v);
      maxV = max(maxV, v);
    }
    final a = (maxU - minU) / 2, b = (maxV - minV) / 2;
    if (a < 12 || b < 12) return null;
    if (min(a, b) / max(a, b) < 0.15) return null;
    final centerU = (maxU + minU) / 2, centerV = (maxV + minV) / 2;
    final center = Offset(
      mx + centerU * cosR - centerV * sinR,
      my + centerU * sinR + centerV * cosR,
    );

    // How far the stroke strays from the fitted ellipse.
    var total = 0.0, worst = 0.0;
    for (final p in ring) {
      final dx = p.dx - center.dx, dy = p.dy - center.dy;
      final u = (dx * cosR + dy * sinR) / a;
      final v = (-dx * sinR + dy * cosR) / b;
      final off = (sqrt(u * u + v * v) - 1).abs();
      total += off;
      worst = max(worst, off);
    }
    final guess = max(a, b) / min(a, b) < 1.15
        ? ShapeGuess(
            kind: ShapeKind.circle,
            center: center,
            radiusX: (a + b) / 2,
            radiusY: (a + b) / 2,
          )
        : ShapeGuess(
            kind: ShapeKind.ellipse,
            center: center,
            radiusX: a,
            radiusY: b,
            rotation: rotation,
          );
    return _EllipseFit(guess, total / ring.length, worst);
  }

  // -- geometry helpers -----------------------------------------------------

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

  /// How much the path turns at each point (radians, signed), comparing the
  /// direction [window] points before with the direction [window] after.
  static List<double> _turning(
    List<Offset> points,
    int window, {
    required bool closed,
  }) {
    final n = points.length;
    final result = List<double>.filled(n, 0);
    for (var i = 0; i < n; i++) {
      var before = i - window, after = i + window;
      if (closed) {
        before = (before % n + n) % n;
        after = after % n;
      } else if (before < 0 || after >= n) {
        continue;
      }
      final v1 = points[i] - points[before];
      final v2 = points[after] - points[i];
      result[i] = atan2(
        v1.dx * v2.dy - v1.dy * v2.dx,
        v1.dx * v2.dx + v1.dy * v2.dy,
      );
    }
    return result;
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

/// An ellipse fitted to a stroke, with how far the stroke strays from it
/// (as a fraction of the radius): on average and at the worst point.
class _EllipseFit {
  const _EllipseFit(this.guess, this.mean, this.worst);

  final ShapeGuess guess;
  final double mean, worst;
}
