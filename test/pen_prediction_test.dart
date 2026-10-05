import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:saber/data/tools/pen_prediction.dart';

(Offset, Duration) _s(double x, double y, int ms) =>
    (Offset(x, y), Duration(milliseconds: ms));

/// Samples every 4 ms (a 250 Hz pen) of a pen moving at [speed] units per
/// millisecond along [at], which maps a time in ms to a position.
List<(Offset, Duration)> _run(Offset Function(int ms) at, int endMs) => [
  for (var ms = endMs - 36; ms <= endMs; ms += 4) (at(ms), Duration(milliseconds: ms)),
];

Offset _circle(int ms, {double radius = 10, double speed = 0.8}) {
  final angle = speed / radius * ms;
  return Offset(radius * cos(angle), radius * sin(angle));
}

void main() {
  group('Pen prediction:', () {
    setUp(PenPrediction.reset);

    test('a steady pen is predicted a little further along', () {
      // 1 unit per millisecond to the right.
      final tip = PenPrediction.predict(_run((ms) => Offset(ms.toDouble(), 0), 100));
      expect(tip, isNotNull);
      expect(tip!.dx, closeTo(100 + 24, 1e-6));
      expect(tip.dy, closeTo(0, 1e-6));
    });

    test('direction is kept', () {
      final tip = PenPrediction.predict(_run((ms) => Offset(0, -ms.toDouble()), 100));
      expect(tip!.dx, closeTo(0, 1e-6));
      expect(tip.dy, lessThan(-100));
    });

    test('one sample, two samples or a motionless pen have no prediction', () {
      expect(PenPrediction.predict([_s(5, 5, 0)]), isNull);
      expect(PenPrediction.predict([_s(0, 0, 0), _s(10, 0, 10)]), isNull);
      expect(
        PenPrediction.predict([_s(5, 5, 0), _s(5, 5, 10), _s(5, 5, 20)]),
        isNull,
      );
    });

    test('a very slow pen is not predicted', () {
      expect(
        PenPrediction.predict([_s(0, 0, 0), _s(1, 0, 10), _s(2, 0, 20)]),
        isNull,
      );
    });

    test('too little time between samples gives no prediction', () {
      expect(
        PenPrediction.predict([_s(0, 0, 0), _s(15, 0, 1), _s(30, 0, 2)]),
        isNull,
      );
    });

    test('the guess is never far from the last point', () {
      final tip = PenPrediction.predict([
        _s(0, 0, 0),
        _s(100, 0, 5),
        _s(200, 0, 10),
      ]);
      expect(
        (tip! - const Offset(200, 0)).distance,
        lessThanOrEqualTo(PenPrediction.maxDistance + 1e-9),
      );
    });

    test('a curve does not make the tip stick out of the line', () {
      // Writing a small round letter at normal speed: the guess may help a
      // little but must stay on the curve (within a pen width or so).
      for (final radius in [6.0, 10.0, 20.0]) {
        for (final speed in [0.4, 0.8, 1.5]) {
          for (var ms = 60; ms < 400; ms += 4) {
            final tip = PenPrediction.predict(
              _run((t) => _circle(t, radius: radius, speed: speed), ms),
            );
            if (tip == null) continue;
            final offPath = (tip.distance - radius).abs();
            expect(
              offPath,
              lessThan(2.5),
              reason: 'r=$radius v=$speed t=$ms stuck out by $offPath',
            );
          }
        }
      }
    });

    test('a pen that is stopping gets a shorter guess', () {
      final steady = PenPrediction.predict(
        _run((ms) => Offset(ms.toDouble(), 0), 100),
      )!;
      // Same pen, but it slows down to a third of the speed.
      final slowing = PenPrediction.predict([
        for (var i = 0; i < 10; i++)
          (
            Offset(i < 5 ? i * 4.0 : 16 + (i - 4) * 1.4, 0),
            Duration(milliseconds: i * 4),
          ),
      ])!;
      final last = 16 + 5 * 1.4;
      expect(slowing.dx - last, lessThan((steady.dx - 100) / 2));
    });

    test('old movement is forgotten', () {
      for (var ms = 0; ms <= 40; ms += 4) {
        PenPrediction.add(Offset(ms.toDouble(), 0), Duration(milliseconds: ms));
      }
      expect(PenPrediction.tip, isNotNull);
      // Much later, the pen is somewhere else and just starting to move.
      PenPrediction.add(const Offset(500, 500), const Duration(milliseconds: 500));
      expect(PenPrediction.tip, isNull);
    });

    test('reset clears the guess', () {
      for (var ms = 0; ms <= 40; ms += 4) {
        PenPrediction.add(Offset(ms.toDouble(), 0), Duration(milliseconds: ms));
      }
      PenPrediction.reset();
      expect(PenPrediction.tip, isNull);
    });
  });
}
