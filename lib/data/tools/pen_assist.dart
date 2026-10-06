import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:perfect_freehand/perfect_freehand.dart';
import 'package:saber/components/canvas/_circle_stroke.dart';
import 'package:saber/components/canvas/_rectangle_stroke.dart';
import 'package:saber/components/canvas/_stroke.dart';
import 'package:saber/data/tools/shape_analysis.dart';
import 'package:saber/data/tools/shape_snap.dart';

/// The technical drawing helpers of the pen panel: lengths in millimetres,
/// the angle guide, tidy shapes, and dimensions written next to a line.
///
/// Everything that can be is a plain function of points, so it is tested
/// without a page.
abstract class PenAssist {
  /// Millimetres per page unit. A page is 1000 units wide and is taken to
  /// be as wide as A4 paper (210 mm).
  static const mmPerUnit = 0.21;

  static double toMm(double units) => units * mmPerUnit;

  /// A length of [units] page units, written in millimetres: whole
  /// numbers from 10 mm up, one decimal below.
  static String formatLength(double units, {bool comma = true}) {
    final mm = toMm(units);
    final text = mm >= 10 ? mm.round().toString() : mm.toStringAsFixed(1);
    return '${comma ? text.replaceAll('.', ',') : text} mm';
  }

  /// The angle of the line from [a] to [b] above the horizontal, 0..360
  /// degrees, counted anticlockwise as on paper.
  static double angleDegrees(Offset a, Offset b) {
    final degrees = -math.atan2(b.dy - a.dy, b.dx - a.dx) * 180 / math.pi;
    final wrapped = degrees % 360;
    return wrapped < 0 ? wrapped + 360 : wrapped;
  }

  /// The steps of the angle guide, in degrees.
  static const angleStep = 15.0;

  /// Where a line from [start] to [end] ends when it is turned to the
  /// nearest step of the angle guide. Its length stays the same.
  static Offset snapAngle(Offset start, Offset end, {double step = angleStep}) {
    final delta = end - start;
    final length = delta.distance;
    if (length == 0) return end;
    final stepRadians = step * math.pi / 180;
    final snapped = (delta.direction / stepRadians).round() * stepRadians;
    return start + Offset(math.cos(snapped), math.sin(snapped)) * length;
  }

  // -- tidy shapes ----------------------------------------------------------

  /// How unequal the sides of a shape may be and still be made equal.
  static const _tidyTolerance = 0.15;

  /// [guess] with what was nearly regular made exactly so: nearly square
  /// rectangles become squares, nearly round ellipses circles, polygons
  /// with nearly equal sides regular, and nearly level ones level.
  static ShapeGuess regularize(ShapeGuess guess) {
    switch (guess.kind) {
      case ShapeKind.rectangle:
        final rect = guess.rect;
        final longest = math.max(rect.width, rect.height);
        if ((rect.width - rect.height).abs() > _tidyTolerance * longest) {
          return guess;
        }
        final side = (rect.width + rect.height) / 2;
        return ShapeGuess(
          kind: ShapeKind.rectangle,
          rect: Rect.fromCenter(center: rect.center, width: side, height: side),
        );
      case ShapeKind.ellipse:
        final longest = math.max(guess.radiusX, guess.radiusY);
        if ((guess.radiusX - guess.radiusY).abs() > _tidyTolerance * longest) {
          return guess;
        }
        final radius = (guess.radiusX + guess.radiusY) / 2;
        return ShapeGuess(
          kind: ShapeKind.circle,
          center: guess.center,
          radiusX: radius,
          radiusY: radius,
        );
      case ShapeKind.polygon:
        return _regularPolygon(guess);
      case ShapeKind.line:
      case ShapeKind.circle:
      case ShapeKind.curve:
        return guess;
    }
  }

  static ShapeGuess _regularPolygon(ShapeGuess guess) {
    final points = guess.points;
    final n = points.length;
    if (n < 3) return guess;

    var sum = 0.0, longest = 0.0, shortest = double.infinity;
    for (var i = 0; i < n; i++) {
      final side = (points[(i + 1) % n] - points[i]).distance;
      sum += side;
      longest = math.max(longest, side);
      shortest = math.min(shortest, side);
    }
    final mean = sum / n;
    if (mean <= 0 || longest - shortest > 2 * _tidyTolerance * mean) {
      return guess;
    }

    var centre = Offset.zero;
    for (final p in points) {
      centre += p;
    }
    centre /= n.toDouble();
    var radius = 0.0, area = 0.0;
    for (var i = 0; i < n; i++) {
      radius += (points[i] - centre).distance;
      final a = points[i], b = points[(i + 1) % n];
      area += a.dx * b.dy - b.dx * a.dy;
    }
    radius /= n;
    final turn = (area >= 0 ? 1 : -1) * 2 * math.pi / n;
    var first = (points.first - centre).direction;

    // Level the polygon if one of its sides is nearly level or upright.
    const quarter = math.pi / 2;
    final side = first + turn / 2 + (turn > 0 ? quarter : -quarter);
    var best = double.infinity;
    for (var i = 0; i < n; i++) {
      final angle = side + turn * i;
      final off = angle - (angle / quarter).round() * quarter;
      if (off.abs() < best.abs()) best = off;
    }
    if (best.abs() <= 10 * math.pi / 180) first -= best;

    return ShapeGuess(
      kind: ShapeKind.polygon,
      points: [
        for (var i = 0; i < n; i++)
          centre +
              Offset(math.cos(first + turn * i), math.sin(first + turn * i)) *
                  radius,
      ],
    );
  }

  /// Closed shapes smaller than this (the diagonal of their bounding box,
  /// in page units) are left alone by [autoShape]: letters such as "o"
  /// are writing, not circles.
  static const autoShapeMinSize = 90.0;

  /// The closed shape (circle, rectangle, triangle, ...) that [stroke] was
  /// meant to be, or [stroke] itself if it doesn't look like one.
  static Stroke autoShape(Stroke stroke, {required bool tidy}) {
    final points = stroke.pointOffsets;
    if (points.length < 4) return stroke;
    var left = points.first.dx, right = left;
    var top = points.first.dy, bottom = top;
    for (final p in points) {
      left = math.min(left, p.dx);
      right = math.max(right, p.dx);
      top = math.min(top, p.dy);
      bottom = math.max(bottom, p.dy);
    }
    final diagonal = (Offset(right, bottom) - Offset(left, top)).distance;
    if (diagonal < autoShapeMinSize) return stroke;

    var guess = ShapeAnalysis.analyze(points);
    if (guess == null) return stroke;
    if (guess.kind == ShapeKind.line || guess.kind == ShapeKind.curve) {
      return stroke;
    }
    if (tidy) guess = regularize(guess);
    return ShapeBuilder.build(stroke, guess);
  }

  // -- dimensions -----------------------------------------------------------

  /// The height of the figures written next to a dimensioned line.
  static const textHeight = 20.0;

  /// The space between a line and the figures written next to it.
  static const textGap = 8.0;

  /// The figures and letters dimensions are written with, each a few
  /// strokes in a box one unit tall (y down). Drawn as ink, so they are
  /// saved, moved and erased like any other line.
  static const Map<String, List<List<Offset>>> _glyphs = {
    '0': [
      [
        Offset(0.1, 0.18), Offset(0.3, 0), Offset(0.5, 0.18),
        Offset(0.5, 0.82), Offset(0.3, 1), Offset(0.1, 0.82),
        Offset(0.1, 0.18),
      ],
    ],
    '1': [
      [Offset(0.14, 0.22), Offset(0.36, 0), Offset(0.36, 1)],
    ],
    '2': [
      [
        Offset(0.1, 0.2), Offset(0.22, 0.02), Offset(0.4, 0.02),
        Offset(0.5, 0.2), Offset(0.48, 0.42), Offset(0.1, 1), Offset(0.52, 1),
      ],
    ],
    '3': [
      [
        Offset(0.1, 0.1), Offset(0.3, 0), Offset(0.5, 0.15),
        Offset(0.5, 0.34), Offset(0.3, 0.47), Offset(0.5, 0.62),
        Offset(0.5, 0.85), Offset(0.3, 1), Offset(0.1, 0.9),
      ],
    ],
    '4': [
      [Offset(0.42, 1), Offset(0.42, 0), Offset(0.06, 0.68), Offset(0.56, 0.68)],
    ],
    '5': [
      [
        Offset(0.5, 0), Offset(0.13, 0), Offset(0.1, 0.45),
        Offset(0.3, 0.38), Offset(0.5, 0.52), Offset(0.5, 0.84),
        Offset(0.3, 1), Offset(0.1, 0.9),
      ],
    ],
    '6': [
      [
        Offset(0.48, 0.08), Offset(0.3, 0), Offset(0.12, 0.2),
        Offset(0.1, 0.8), Offset(0.3, 1), Offset(0.5, 0.82),
        Offset(0.5, 0.6), Offset(0.3, 0.45), Offset(0.1, 0.6),
      ],
    ],
    '7': [
      [Offset(0.08, 0), Offset(0.52, 0), Offset(0.22, 1)],
    ],
    '8': [
      [
        Offset(0.3, 0.47), Offset(0.12, 0.33), Offset(0.12, 0.14),
        Offset(0.3, 0), Offset(0.48, 0.14), Offset(0.48, 0.33),
        Offset(0.3, 0.47), Offset(0.1, 0.63), Offset(0.1, 0.85),
        Offset(0.3, 1), Offset(0.5, 0.85), Offset(0.5, 0.63),
        Offset(0.3, 0.47),
      ],
    ],
    '9': [
      [
        Offset(0.5, 0.4), Offset(0.3, 0.55), Offset(0.1, 0.4),
        Offset(0.1, 0.18), Offset(0.3, 0), Offset(0.5, 0.18),
        Offset(0.5, 0.8), Offset(0.3, 1), Offset(0.12, 0.92),
      ],
    ],
    ',': [
      [Offset(0.16, 0.88), Offset(0.18, 1), Offset(0.08, 1.16)],
    ],
    'm': [
      [Offset(0.06, 1), Offset(0.06, 0.45)],
      [Offset(0.06, 0.6), Offset(0.2, 0.45), Offset(0.34, 0.6), Offset(0.34, 1)],
      [Offset(0.34, 0.6), Offset(0.48, 0.45), Offset(0.62, 0.6), Offset(0.62, 1)],
    ],
    'Ø': [
      [
        Offset(0.1, 0.18), Offset(0.3, 0), Offset(0.5, 0.18),
        Offset(0.5, 0.82), Offset(0.3, 1), Offset(0.1, 0.82),
        Offset(0.1, 0.18),
      ],
      [Offset(0.04, 1.06), Offset(0.56, -0.06)],
    ],
  };

  /// How far the pen moves on after each character, in units of height.
  static double _advance(String character) => switch (character) {
    ' ' => 0.32,
    ',' => 0.3,
    'm' => 0.78,
    _ => 0.68,
  };

  /// How wide [text] is when written [height] tall.
  static double textWidth(String text, {double height = textHeight}) {
    var width = 0.0;
    for (final character in text.split('')) {
      width += _advance(character);
    }
    return width * height;
  }

  /// [text] as lines to draw, written from [origin] along [along] (a unit
  /// vector), with the tops of the figures towards [up] (a unit vector).
  /// Characters that can't be written are left out.
  static List<List<Offset>> textLines(
    String text, {
    required Offset origin,
    required Offset along,
    required Offset up,
    double height = textHeight,
  }) {
    final lines = <List<Offset>>[];
    var cursor = 0.0;
    for (final character in text.split('')) {
      for (final line in _glyphs[character] ?? const <List<Offset>>[]) {
        lines.add([
          for (final p in line)
            origin +
                along * ((cursor + p.dx) * height) +
                up * ((1 - p.dy) * height),
        ]);
      }
      cursor += _advance(character);
    }
    return lines;
  }

  /// The lines of the dimension of a line from [a] to [b]: an arrowhead at
  /// each end and its length in millimetres above the middle, written so
  /// that it reads from the left (or from below, for an upright line).
  static List<List<Offset>> lineDimension(
    Offset a,
    Offset b, {
    double height = textHeight,
  }) {
    final length = (b - a).distance;
    if (length < 1) return const [];
    var along = (b - a) / length;
    if (along.dx < -1e-9 || (along.dx.abs() <= 1e-9 && along.dy > 0)) {
      along = -along;
    }
    final up = Offset(along.dy, -along.dx);
    final text = formatLength(length);
    final width = textWidth(text, height: height);
    final middle = (a + b) / 2;

    final head = math.min(14.0, length * 0.3);
    final (leftB, rightB) = Stroke.arrowHead(a, b, headLength: head);
    final (leftA, rightA) = Stroke.arrowHead(b, a, headLength: head);
    return [
      [leftA, a, rightA],
      [leftB, b, rightB],
      ...textLines(
        text,
        origin: middle - along * (width / 2) + up * textGap,
        along: along,
        up: up,
        height: height,
      ),
    ];
  }

  /// The lines of the dimensions of [stroke], if it is a straight line, a
  /// circle or a rectangle: see [lineDimension]; a circle gets its
  /// diameter above it, a rectangle its width above and its height beside.
  static List<List<Offset>> dimensionsOf(Stroke stroke) {
    const right = Offset(1, 0), up = Offset(0, -1);
    if (stroke is CircleStroke) {
      final text = 'Ø ${formatLength(stroke.radius * 2)}';
      return textLines(
        text,
        origin:
            stroke.center +
            Offset(-textWidth(text) / 2, -stroke.radius - textGap),
        along: right,
        up: up,
      );
    }
    if (stroke is RectangleStroke) {
      final rect = stroke.rect;
      final width = formatLength(rect.width);
      final height = formatLength(rect.height);
      return [
        ...textLines(
          width,
          origin: rect.topCenter + Offset(-textWidth(width) / 2, -textGap),
          along: right,
          up: up,
        ),
        // Read from below, like the height of a part on a drawing.
        ...textLines(
          height,
          origin:
              rect.centerRight + Offset(textGap + textHeight, textWidth(height) / 2),
          along: up,
          up: const Offset(-1, 0),
        ),
      ];
    }
    final ends = stroke.vertexHandles;
    if (ends == null || ends.length != 2) return const [];
    return lineDimension(ends[0], ends[1]);
  }

  /// [dimensionsOf] as strokes drawn like [stroke], only thinner.
  static List<Stroke> dimensionStrokes(Stroke stroke) {
    final lines = dimensionsOf(stroke);
    if (lines.isEmpty) return const [];
    final options = stroke.options.copyWith(
      size: (stroke.options.size * 0.5).clamp(1.5, 3.0),
      thinning: 0,
      smoothing: 0,
      streamline: 0,
      simulatePressure: false,
      isComplete: true,
      start: StrokeEndOptions.start(taperEnabled: false),
      end: StrokeEndOptions.end(taperEnabled: false),
    );
    return [
      for (final line in lines)
        Stroke(
          color: stroke.color,
          pressureEnabled: false,
          options: options.copyWith(),
          pageIndex: stroke.pageIndex,
          page: stroke.page,
          toolId: stroke.toolId,
        )..addPoints(line),
    ];
  }

  // -- measuring ------------------------------------------------------------

  /// What is being measured, shown over the page while the measuring tool
  /// is on; null when there is nothing to show.
  static final readout = ValueNotifier<String?>(null);

  /// Where the pen is on screen (in global coordinates), so that the
  /// readout can be shown next to it; null when that isn't known.
  static final readoutAt = ValueNotifier<Offset?>(null);

  /// Goes up by one each time a finished measurement is shown: what shows
  /// the readout takes it away again [readoutDuration] later.
  static final readoutFinished = ValueNotifier<int>(0);

  /// How long a finished measurement stays on screen.
  static const readoutDuration = Duration(seconds: 4);

  /// Shows [text] until the next measurement.
  static void showReadout(String? text) => readout.value = text;

  /// The measurement of a straight line from [a] to [b].
  static String describeLine(Offset a, Offset b) =>
      '${formatLength((b - a).distance)}  ${describeAngle(a, b)}';

  /// The angle of a straight line from [a] to [b], as it is shown.
  static String describeAngle(Offset a, Offset b) =>
      '∠ ${angleDegrees(a, b).round() % 360}°';

  /// A line shorter than this (in page units) is not yet said to be
  /// straight while it is drawn: its direction still jumps about.
  static const liveLineMinLength = 24.0;

  /// What to show while a line is being drawn from [start] to [position],
  /// [pathLength] long so far; null for nothing.
  ///
  /// As long as the line is straight, that is its length and angle (the
  /// angle it will be turned to, with the [angleGuide] on); once it bends,
  /// how long it is along its path. Lengths are only shown with [measure].
  static String? liveReadout({
    required Offset start,
    required Offset position,
    required double pathLength,
    required bool measure,
    required bool angleGuide,
  }) {
    if (!measure && !angleGuide) return null;
    final chord = (position - start).distance;
    final straight =
        chord >= liveLineMinLength && pathLength <= chord * 1.12 + 1e-9;
    if (straight) {
      final end = angleGuide ? snapAngle(start, position) : position;
      return measure ? describeLine(start, end) : describeAngle(start, end);
    }
    return measure ? formatLength(pathLength) : null;
  }

  /// Whether [stroke] was drawn as a straight line, by a rule that allows
  /// for an unsteady hand: it never strays more than a little from the
  /// line between its ends, and is long enough not to be writing.
  static bool isLine(Stroke stroke) =>
      ShapeAnalysis.analyze(stroke.pointOffsets)?.kind == ShapeKind.line;

  /// The measurement of a finished [stroke]: length and angle of a line,
  /// diameter of a circle, sides of a rectangle, otherwise how long the
  /// line is along its path.
  static String describe(Stroke stroke) {
    if (stroke is CircleStroke) {
      return 'Ø ${formatLength(stroke.radius * 2)}';
    }
    if (stroke is RectangleStroke) {
      return '${formatLength(stroke.rect.width)} × '
          '${formatLength(stroke.rect.height)}';
    }
    final ends = stroke.vertexHandles;
    if (ends != null && ends.length == 2) return describeLine(ends[0], ends[1]);
    return formatLength(stroke.pathLength);
  }

  /// Shows the measurement of a finished [stroke] for a few seconds.
  static void showResult(Stroke stroke) => showBriefly(describe(stroke));

  /// Shows [text] for a few seconds.
  static void showBriefly(String text) {
    showReadout(text);
    readoutFinished.value++;
  }

  // -- finishing a line -----------------------------------------------------

  /// Applies the helpers that are switched on to a line that was just
  /// drawn, and returns the strokes to add with it (its dimensions).
  static List<Stroke> finish(
    Stroke stroke, {
    required bool angleGuide,
    required bool dimensions,
    required bool measure,
  }) {
    var isLine = false;
    if (angleGuide) {
      final ends = stroke.vertexHandles;
      if (ends != null && ends.length == 2) {
        isLine = true;
        stroke.setVertexHandles([ends[0], snapAngle(ends[0], ends[1])]);
        stroke.markPolygonNeedsUpdating();
      }
    }
    if (measure) {
      showResult(stroke);
    } else if (angleGuide) {
      // The angle the line was turned to, or nothing for what is no line.
      final ends = stroke.vertexHandles;
      if (isLine && ends != null) {
        showBriefly(describeAngle(ends[0], ends[1]));
      } else {
        showReadout(null);
      }
    }
    return dimensions ? dimensionStrokes(stroke) : const [];
  }
}
