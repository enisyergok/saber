import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:saber/data/editor/page.dart';
import 'package:saber/data/flavor_config.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/tools/pen.dart';
import 'package:saber/data/tools/pen_prediction.dart';

(Offset, Duration) _s(double x, double y, int ms) =>
    (Offset(x, y), Duration(milliseconds: ms));

/// Samples every 4 ms (a 250 Hz pen) over the 36 ms up to [endMs], of a pen
/// whose position at a time in ms is given by [at].
List<(Offset, Duration)> _run(Offset Function(int ms) at, int endMs) => [
  for (var ms = endMs - 36; ms <= endMs; ms += 4)
    (at(ms), Duration(milliseconds: ms)),
];

/// A pen going round a circle of [radius] at [speed] units per millisecond.
Offset _circle(int ms, {double radius = 10, double speed = 0.8}) {
  final angle = speed / radius * ms;
  return Offset(radius * cos(angle), radius * sin(angle));
}

double get _horizonMs => PenPrediction.horizon.inMicroseconds / 1000;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlavorConfig.setup();

  group('Pen prediction:', () {
    setUp(() {
      PenPrediction.reset();
      PenPrediction.horizon = PenPrediction.defaultHorizon;
    });

    test('a steady pen is predicted a little further along', () {
      // 1 unit per millisecond to the right.
      final tip = PenPrediction.predict(
        _run((ms) => Offset(ms.toDouble(), 0), 100),
      );
      expect(tip, isNotNull);
      expect(tip!.dx, closeTo(100 + _horizonMs, 1e-6));
      expect(tip.dy, closeTo(0, 1e-6));
    });

    test('direction is kept', () {
      final tip = PenPrediction.predict(
        _run((ms) => Offset(0, -ms.toDouble()), 100),
      );
      expect(tip!.dx, closeTo(0, 1e-6));
      expect(tip.dy, lessThan(-100));
    });

    test('a slower pen reporting less often is predicted too', () {
      // A 60 Hz pen: 16 ms between samples, 0.5 units per millisecond.
      final tip = PenPrediction.predict([
        for (var ms = 0; ms <= 48; ms += 16)
          (Offset(ms * 0.5, 0), Duration(milliseconds: ms)),
      ]);
      expect(tip, isNotNull);
      expect(tip!.dx, closeTo(24 + 0.5 * _horizonMs, 1e-6));
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

    group('in a curve', () {
      // Round letters at the speeds writing has: the guess must land much
      // nearer to where the pen then is than the line's end is, and stay on
      // the curve instead of sticking out of it.
      const letters = [
        (radius: 20.0, speed: 0.4),
        (radius: 30.0, speed: 0.5),
        (radius: 40.0, speed: 0.8),
        (radius: 60.0, speed: 1.0),
        (radius: 100.0, speed: 1.5),
      ];

      for (final (:radius, :speed) in letters) {
        test('radius $radius at $speed units/ms', () {
          var checked = 0;
          for (var ms = 60; ms < 600; ms += 4) {
            final samples = _run(
              (t) => _circle(t, radius: radius, speed: speed),
              ms,
            );
            final tip = PenPrediction.predict(samples);
            expect(tip, isNotNull, reason: 't=$ms');
            final truth = _circle(
              ms + _horizonMs.round(),
              radius: radius,
              speed: speed,
            );
            final lineEnd = samples.last.$1;
            final guessed = (tip! - truth).distance;
            final trailing = (lineEnd - truth).distance;
            expect(
              guessed,
              lessThan(trailing * 0.5),
              reason: 't=$ms: off by $guessed, the line end by $trailing',
            );
            final offPath = (tip.distance - radius).abs();
            expect(
              offPath,
              lessThan(radius * 0.12 + 0.5),
              reason: 't=$ms: stuck out by $offPath',
            );
            checked++;
          }
          expect(checked, greaterThan(100));
        });
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

    test('a pen that is stopping is never guessed to turn back', () {
      for (final stopsAt in [16, 24, 32, 40]) {
        // 1 unit per millisecond, braking evenly until it stands still
        // (half way along the first [stopsAt] ms), sampled until just
        // before that.
        double x(int ms) => ms - ms * ms / (2 * stopsAt);
        final samples = [
          for (var ms = 0; ms <= stopsAt - 4; ms += 4)
            (Offset(x(ms), 0), Duration(milliseconds: ms)),
        ];
        final tip = PenPrediction.predict(samples);
        if (tip == null) continue; // already too slow to guess at
        expect(
          tip.dx,
          greaterThanOrEqualTo(samples.last.$1.dx - 1e-9),
          reason: 'stops at $stopsAt',
        );
        if (stopsAt >= 24) {
          // With enough of the braking seen, the guess ends where it ends.
          expect(
            tip.dx,
            lessThanOrEqualTo(stopsAt / 2 + 2),
            reason: 'stops at $stopsAt',
          );
        }
      }
    });

    test('old movement is forgotten', () {
      for (var ms = 0; ms <= 40; ms += 4) {
        PenPrediction.add(Offset(ms.toDouble(), 0), Duration(milliseconds: ms));
      }
      expect(PenPrediction.tip, isNotNull);
      // Much later, the pen is somewhere else and just starting to move.
      PenPrediction.add(
        const Offset(500, 500),
        const Duration(milliseconds: 500),
      );
      expect(PenPrediction.tip, isNull);
    });

    test('the same moment twice does not upset the speed', () {
      for (var ms = 0; ms <= 40; ms += 4) {
        PenPrediction.add(Offset(ms.toDouble(), 0), Duration(milliseconds: ms));
        // The same event heard a second time
        PenPrediction.add(
          Offset(ms.toDouble(), 0),
          Duration(milliseconds: ms),
        );
      }
      expect(PenPrediction.tip!.dx, closeTo(40 + _horizonMs, 1e-6));
    });

    test('reset clears the guess', () {
      for (var ms = 0; ms <= 40; ms += 4) {
        PenPrediction.add(Offset(ms.toDouble(), 0), Duration(milliseconds: ms));
      }
      expect(PenPrediction.bend, isNotNull);
      PenPrediction.reset();
      expect(PenPrediction.tip, isNull);
      expect(PenPrediction.bend, isNull);
    });

    test('the bend is on the way from the last point to the tip', () {
      // A straight line: the curve to the tip is straight too.
      for (var ms = 0; ms <= 40; ms += 4) {
        PenPrediction.add(Offset(ms.toDouble(), 0), Duration(milliseconds: ms));
      }
      final bend = PenPrediction.bend!;
      final tip = PenPrediction.tip!;
      expect(bend.dy, closeTo(0, 1e-6));
      expect(bend.dx, inInclusiveRange(40, tip.dx));

      // A curve: the way to the tip passes along the circle, halfway to it
      // as well as at either end.
      PenPrediction.reset();
      for (var ms = 0; ms <= 40; ms += 4) {
        PenPrediction.add(
          _circle(ms, radius: 20, speed: 0.5),
          Duration(milliseconds: ms),
        );
      }
      final last = _circle(40, radius: 20, speed: 0.5);
      final halfway =
          (last + PenPrediction.bend! * 2 + PenPrediction.tip!) / 4;
      expect((halfway.distance - 20).abs(), lessThan(1.5));
    });
  });

  group('The horizon follows the screen:', () {
    tearDown(() => PenPrediction.horizon = PenPrediction.defaultHorizon);

    double tuned(double hertz) {
      PenPrediction.tuneToRefreshRate(hertz);
      return PenPrediction.horizon.inMicroseconds / 1000;
    }

    test('60 Hz is about two frames less a bit', () {
      expect(tuned(60), closeTo(1000 / 60 * PenPrediction.framesAhead, 0.01));
      expect(tuned(60), inInclusiveRange(25, 30));
    });

    test('a faster screen has less to make up', () {
      expect(tuned(120), lessThan(tuned(60)));
      expect(tuned(120), greaterThanOrEqualTo(14));
    });

    test('there are limits at either end', () {
      expect(tuned(240), 14);
      expect(tuned(30), 30);
    });

    test('an unknown rate gives the default', () {
      for (final hertz in [0.0, -1.0, double.nan, double.infinity, 5000.0]) {
        PenPrediction.horizon = const Duration(milliseconds: 5);
        expect(tuned(hertz), PenPrediction.defaultHorizon.inMilliseconds);
      }
    });
  });

  group('The pen uses the time its events happened:', () {
    late EditorPage page;

    setUp(() {
      page = EditorPage(size: const Size(1000, 1400));
      stows.pressureAuto.value = false;
      stows.shapeHoldToSnap.value = false;
      stows.penPrediction.value = true;
      stows.rulerMode.value = false;
      stows.angleGuide.value = false;
      stows.measureMode.value = false;
      PenPrediction.reset();
    });
    tearDown(() {
      stows.penPrediction.value = stows.penPrediction.defaultValue;
      stows.pressureAuto.value = stows.pressureAuto.defaultValue;
      PenPrediction.reset();
      PenPrediction.horizon = PenPrediction.defaultHorizon;
    });

    test('events handled all at once still give a speed', () {
      final pen = Pen.fountainPen();
      // All of these reach the pen in the same instant (one batch from the
      // tablet), but each says when it happened: 1 unit per ms, every 4 ms.
      pen.onDragStart(
        const Offset(100, 100),
        page,
        0,
        0.5,
        at: const Duration(seconds: 50),
      );
      for (var i = 1; i <= 10; i++) {
        pen.onDragUpdate(
          Offset(100 + i * 4.0, 100),
          0.5,
          at: Duration(seconds: 50, milliseconds: i * 4),
        );
      }
      final tip = PenPrediction.tip;
      expect(tip, isNotNull);
      expect(tip!.dx, closeTo(140 + _horizonMs, 1e-6));
      pen.onDragEnd();
      expect(PenPrediction.tip, isNull);
    });
  });
}
