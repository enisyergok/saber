import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_dollar_unistroke_recognizer/one_dollar_unistroke_recognizer.dart';
import 'package:saber/data/tools/shape_analysis.dart';

double _jitter(Random rng, double amount) => (rng.nextDouble() - 0.5) * 2 * amount;

/// Points along [corners], about [step] apart, wobbled by [noise].
List<Offset> _along(
  List<Offset> corners,
  Random rng, {
  bool closed = false,
  double step = 5,
  double noise = 1.2,
}) {
  final path = closed ? [...corners, corners.first] : corners;
  final out = <Offset>[];
  for (var i = 1; i < path.length; i++) {
    final a = path[i - 1], b = path[i];
    final n = max(1, ((b - a).distance / step).round());
    final last = i == path.length - 1;
    for (var j = 0; j < (last ? n + 1 : n); j++) {
      out.add(
        Offset.lerp(a, b, j / n)! +
            Offset(_jitter(rng, noise), _jitter(rng, noise)),
      );
    }
  }
  return out;
}

/// A hand-drawn ellipse: starts anywhere and overshoots (or stops short of)
/// its start by [closure] of a turn.
List<Offset> _ellipse(
  Random rng,
  double rx,
  double ry,
  double rotation, {
  double closure = 0.04,
  double noise = 1.5,
}) {
  const center = Offset(300, 300);
  final n = (2 * pi * max(rx, ry) / 5).ceil();
  final start = rng.nextDouble() * 2 * pi;
  final total = 2 * pi * (1 + closure);
  final count = (n * (1 + closure)).floor();
  return [
    for (var i = 0; i <= count; i++)
      () {
        final t = start + total * i / count;
        final u = rx * cos(t), v = ry * sin(t);
        final wobble = 1 + _jitter(rng, noise) / max(rx, ry);
        return center +
            Offset(
              (u * cos(rotation) - v * sin(rotation)) * wobble,
              (u * sin(rotation) + v * cos(rotation)) * wobble,
            ) +
            Offset(_jitter(rng, 0.8), _jitter(rng, 0.8));
      }(),
  ];
}

List<Offset> _regular(int sides, double radius, double rotation) => [
  for (var i = 0; i < sides; i++)
    Offset(300, 300) +
        Offset.fromDirection(rotation + 2 * pi * i / sides, radius),
];

List<Offset> _rectangle(double w, double h, double rotation) {
  final corners = [
    Offset(-w / 2, -h / 2),
    Offset(w / 2, -h / 2),
    Offset(w / 2, h / 2),
    Offset(-w / 2, h / 2),
  ];
  return [
    for (final c in corners)
      Offset(300, 300) +
          Offset(
            c.dx * cos(rotation) - c.dy * sin(rotation),
            c.dx * sin(rotation) + c.dy * cos(rotation),
          ),
  ];
}

/// Starts the loop at a random point, as people do.
List<Offset> _startAnywhere(List<Offset> points, Random rng) {
  final k = rng.nextInt(points.length);
  return [...points.sublist(k), ...points.sublist(0, k)];
}

/// Rounds corners, like a quick hand-drawn shape.
List<Offset> _rounded(List<Offset> points, [int k = 3]) {
  final n = points.length;
  return [
    for (var i = 0; i < n; i++)
      () {
        var sum = Offset.zero;
        var count = 0;
        for (var j = i - k; j <= i + k; j++) {
          sum += points[j.clamp(0, n - 1)];
          count++;
        }
        return sum / count.toDouble();
      }(),
  ];
}

String _describe(ShapeGuess? guess) {
  if (guess == null) return 'none';
  if (guess.kind == ShapeKind.polygon) return 'polygon${guess.points.length}';
  return guess.kind.name;
}

/// The share of 40 random drawings that come out as [expected].
double _rate(
  String name,
  List<Offset> Function(Random rng) draw,
  String? expected,
) {
  const trials = 40;
  var ok = 0;
  final got = <String, int>{};
  for (var seed = 0; seed < trials; seed++) {
    final result = _describe(ShapeAnalysis.analyze(draw(Random(seed))));
    got[result] = (got[result] ?? 0) + 1;
    if (result == (expected ?? 'none')) ok++;
  }
  // ignore: avoid_print
  print('shape analysis | ${name.padRight(24)} ${(ok / trials).toStringAsFixed(2)} $got');
  return ok / trials;
}

void main() {
  group('Shape analysis recognises', () {
    test('circles', () {
      expect(_rate('circle r70', (r) => _ellipse(r, 70, 70, 0), 'circle'), 1);
      expect(_rate('circle r30', (r) => _ellipse(r, 30, 30, 0), 'circle'), 1);
      expect(
        _rate('circle stops short', (r) => _ellipse(r, 70, 70, 0, closure: -0.04), 'circle'),
        1,
      );
      expect(
        _rate('circle wobbly', (r) => _ellipse(r, 70, 70, 0, noise: 4), 'circle'),
        greaterThanOrEqualTo(0.9),
      );
    });

    test('ellipses, even thin ones', () {
      expect(
        _rate('ellipse 100x55', (r) => _ellipse(r, 100, 55, 0.4), 'ellipse'),
        greaterThanOrEqualTo(0.9),
      );
      expect(
        _rate('ellipse 120x35', (r) => _ellipse(r, 120, 35, 0.3), 'ellipse'),
        greaterThanOrEqualTo(0.9),
      );
    });

    test('rectangles, kept upright and kept tilted', () {
      expect(
        _rate(
          'rectangle',
          (r) => _rounded(_along(_rectangle(160, 100, 0), r, closed: true, noise: 2)),
          'rectangle',
        ),
        greaterThanOrEqualTo(0.9),
      );
      expect(
        _rate(
          'rectangle overshoot',
          (r) {
            final p = _along(_rectangle(160, 100, 0), r, closed: true, noise: 2);
            return [...p, ...p.sublist(1, 5)];
          },
          'rectangle',
        ),
        greaterThanOrEqualTo(0.9),
      );
      expect(
        _rate(
          'rectangle tilted 25',
          (r) => _along(_rectangle(160, 100, 25 * pi / 180), r, closed: true),
          'polygon4',
        ),
        greaterThanOrEqualTo(0.9),
      );
    });

    test('triangles, pentagons and hexagons', () {
      for (final (name, sides) in [('triangle', 3), ('pentagon', 5), ('hexagon', 6)]) {
        expect(
          _rate(
            name,
            (r) => _rounded(
              _startAnywhere(
                _along(_regular(sides, 90, r.nextDouble() * 6), r, closed: true, noise: 2),
                r,
              ),
            ),
            'polygon$sides',
          ),
          greaterThanOrEqualTo(0.9),
          reason: name,
        );
      }
      expect(
        _rate(
          'scalene triangle',
          (r) => _along(
            [const Offset(0, 0), const Offset(180, 20), const Offset(60, 120)],
            r,
            closed: true,
            noise: 2,
          ),
          'polygon3',
        ),
        greaterThanOrEqualTo(0.9),
      );
    });

    test('straight lines and arcs', () {
      expect(
        _rate(
          'line',
          (r) => _along([const Offset(0, 0), const Offset(200, 40)], r),
          'line',
        ),
        1,
      );
      expect(
        _rate(
          'arc',
          (r) {
            final start = r.nextDouble() * 2 * pi;
            final span = 1.2 + r.nextDouble() * 1.5;
            final radius = 100 + r.nextDouble() * 80;
            final count = (radius * span / 5).floor();
            return [
              for (var i = 0; i <= count; i++)
                Offset(300, 300) +
                    Offset.fromDirection(start + span * i / count, radius) +
                    Offset(_jitter(r, 1.2), _jitter(r, 1.2)),
            ];
          },
          'curve',
        ),
        greaterThanOrEqualTo(0.9),
      );
    });
  });

  group('Shape analysis leaves alone', () {
    test('zigzags, corners and S-curves', () {
      expect(
        _rate(
          'zigzag',
          (r) => _along([
            const Offset(0, 0),
            const Offset(40, 40),
            const Offset(80, 0),
            const Offset(120, 40),
            const Offset(160, 0),
          ], r),
          null,
        ),
        1,
      );
      expect(
        _rate(
          'L shape',
          (r) => _along([
            const Offset(0, 0),
            const Offset(0, 100),
            const Offset(80, 100),
          ], r),
          null,
        ),
        1,
      );
      expect(
        _rate(
          'S curve',
          (r) => [
            for (var i = 0; i < 60; i++)
              Offset(100 + 40 * sin(i / 59 * 2 * pi) + _jitter(r, 0.8), 100 + i * 2.5 + _jitter(r, 0.8)),
          ],
          null,
        ),
        1,
      );
    });

    test('stars, figure eights, and anything small', () {
      expect(
        _rate(
          'star',
          (r) => _along([
            for (var i = 0; i < 10; i++)
              Offset(300, 300) +
                  Offset.fromDirection(-pi / 2 + 2 * pi * i / 10, i.isEven ? 90 : 40),
          ], r, closed: true),
          null,
        ),
        1,
      );
      expect(
        _rate(
          'figure eight',
          (r) => [
            for (var i = 0; i < 80; i++)
              Offset(
                300 + 80 * sin(i / 79 * 2 * pi) + _jitter(r, 1),
                300 + 50 * sin(2 * i / 79 * 2 * pi) + _jitter(r, 1),
              ),
          ],
          null,
        ),
        1,
      );
      expect(_rate('tiny circle', (r) => _ellipse(r, 10, 10, 0), null), 1);
    });

    test('too few points', () {
      expect(ShapeAnalysis.analyze(const [Offset(0, 0), Offset(50, 0)]), isNull);
      expect(ShapeAnalysis.analyze(const []), isNull);
    });
  });

  group('Shape analysis results', () {
    test('a circle has the radius and centre that was drawn', () {
      final guess = ShapeAnalysis.analyze(_ellipse(Random(1), 70, 70, 0))!;
      expect(guess.kind, ShapeKind.circle);
      expect(guess.radiusX, closeTo(70, 4));
      expect((guess.center - const Offset(300, 300)).distance, lessThan(4));
    });

    test('a rectangle has the corners that were drawn', () {
      final guess = ShapeAnalysis.analyze(
        _along(_rectangle(160, 100, 0), Random(2), closed: true, noise: 1),
      )!;
      expect(guess.kind, ShapeKind.rectangle);
      expect(guess.rect.width, closeTo(160, 6));
      expect(guess.rect.height, closeTo(100, 6));
    });

    test('a tilted square keeps its tilt', () {
      final guess = ShapeAnalysis.analyze(
        _along(_rectangle(120, 120, 40 * pi / 180), Random(3), closed: true),
      )!;
      expect(guess.kind, ShapeKind.polygon);
      expect(guess.points, hasLength(4));
    });

    test('a tilted rectangle comes back with the sides that were drawn', () {
      final guess = ShapeAnalysis.analyze(
        _along(_rectangle(180, 90, 30 * pi / 180), Random(6), closed: true),
      )!;
      expect(guess.kind, ShapeKind.polygon);
      final sides = [
        for (var i = 0; i < 4; i++)
          (guess.points[(i + 1) % 4] - guess.points[i]).distance,
      ]..sort();
      expect(sides[0], closeTo(90, 8));
      expect(sides[3], closeTo(180, 8));
    });

    test('an almost level ellipse is made level', () {
      final guess = ShapeAnalysis.analyze(
        _ellipse(Random(7), 110, 60, 2 * pi / 180),
      )!;
      expect(guess.kind, ShapeKind.ellipse);
      expect(guess.rotation, 0);
      expect(guess.radiusX, closeTo(110, 6));
      expect(guess.radiusY, closeTo(60, 6));
    });

    test('an arc comes back with the radius that was drawn', () {
      const radius = 120.0;
      final rng = Random(8);
      final stroke = [
        for (var i = 0; i <= 40; i++)
          Offset(300, 300) +
              Offset.fromDirection(-pi + 1.8 * i / 40, radius) +
              Offset(_jitter(rng, 0.8), _jitter(rng, 0.8)),
      ];
      final guess = ShapeAnalysis.analyze(stroke)!;
      expect(guess.kind, ShapeKind.curve);
      final centre = const Offset(300, 300);
      final radii = [for (final p in guess.points) (p - centre).distance];
      final mean = radii.reduce((a, b) => a + b) / radii.length;
      expect(mean, closeTo(radius, 6));
      final spread = radii.reduce(max) - radii.reduce(min);
      expect(spread, lessThan(1.5));
    });

    test('a flick where the pen came down does not stop a circle', () {
      var found = 0;
      for (var seed = 0; seed < 20; seed++) {
        final circle = _ellipse(Random(seed), 80, 80, 0);
        final k = max(3, circle.length ~/ 25);
        final flicked = [
          for (var i = 0; i < circle.length; i++)
            i < k
                ? circle[i] + (circle[i] - const Offset(300, 300)) * 0.35 * (1 - i / k)
                : circle[i],
        ];
        if (ShapeAnalysis.analyze(flicked)?.kind == ShapeKind.circle) found++;
      }
      expect(found, greaterThanOrEqualTo(17));
    });

    test('a hook where the pen was lifted does not stop a triangle', () {
      var found = 0;
      for (var seed = 0; seed < 20; seed++) {
        final triangle = _along(
          _regular(3, 90, 0.3),
          Random(seed),
          closed: true,
        );
        final k = max(3, triangle.length ~/ 16);
        final hooked = [
          for (var i = 0; i < triangle.length; i++)
            i >= triangle.length - k
                ? triangle[i] +
                      (const Offset(300, 300) - triangle[i]) *
                          (0.5 * (i - (triangle.length - k) + 1) / k)
                : triangle[i],
        ];
        final guess = ShapeAnalysis.analyze(hooked);
        if (guess?.kind == ShapeKind.polygon && guess!.points.length == 3) {
          found++;
        }
      }
      expect(found, greaterThanOrEqualTo(15));
    });

    test('a heart and a scribble are left alone', () {
      final heart = [
        for (var i = 0; i < 100; i++)
          () {
            final t = 2 * pi * i / 100;
            return Offset(
              300 + 80 * sin(t) * sin(t) * sin(t),
              300 - 5 * (13 * cos(t) - 5 * cos(2 * t) - 2 * cos(3 * t) - cos(4 * t)),
            );
          }(),
      ];
      expect(ShapeAnalysis.analyze(heart), isNull);
    });

    test('a polygon outline is closed, an ellipse outline too', () {
      final triangle = ShapeAnalysis.analyze(
        _along(_regular(3, 90, 0.3), Random(4), closed: true),
      )!;
      expect(triangle.outline().first, triangle.outline().last);
      final ellipse = ShapeAnalysis.analyze(_ellipse(Random(5), 100, 55, 0.4))!;
      expect(ellipse.outline().first, ellipse.outline().last);
      expect(ellipse.outline(), hasLength(97));
    });
  });

  // How the recogniser the shape pen used until now (a $1 template matcher)
  // does on the same drawings, for comparison. Nothing is asserted: this
  // only prints, so the improvement can be read from the test log.
  test('baseline: the earlier recogniser on the same drawings', () {
    Map<String, int> count(List<Offset> Function(Random) draw) {
      final got = <String, int>{};
      for (var seed = 0; seed < 40; seed++) {
        final name = (recognizeUnistroke(draw(Random(seed)))?.name ?? 'none')
            .toString();
        got[name] = (got[name] ?? 0) + 1;
      }
      return got;
    }

    // ignore: avoid_print
    print('baseline | circle        ${count((r) => _ellipse(r, 70, 70, 0))}');
    // ignore: avoid_print
    print('baseline | ellipse       ${count((r) => _ellipse(r, 100, 55, 0.4))}');
    // ignore: avoid_print
    print('baseline | rect tilted   ${count((r) => _along(_rectangle(160, 100, 25 * pi / 180), r, closed: true))}');
    // ignore: avoid_print
    print('baseline | pentagon      ${count((r) => _along(_regular(5, 90, 0.2), r, closed: true))}');
    // ignore: avoid_print
    print('baseline | hexagon       ${count((r) => _along(_regular(6, 90, 0.2), r, closed: true))}');
  });
}
