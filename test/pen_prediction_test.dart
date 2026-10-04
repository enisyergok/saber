import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:saber/data/tools/pen_prediction.dart';

(Offset, Duration) _s(double x, double y, int ms) =>
    (Offset(x, y), Duration(milliseconds: ms));

void main() {
  group('Pen prediction:', () {
    setUp(PenPrediction.reset);

    test('a steady pen is predicted a little further along', () {
      // 1 unit per millisecond to the right.
      final tip = PenPrediction.predict([_s(0, 0, 0), _s(10, 0, 10)]);
      expect(tip, isNotNull);
      expect(tip!.dx, closeTo(10 + 24, 1e-6));
      expect(tip.dy, closeTo(0, 1e-6));
    });

    test('direction is kept', () {
      final tip = PenPrediction.predict([_s(0, 0, 0), _s(0, -20, 10)]);
      expect(tip!.dx, closeTo(0, 1e-6));
      expect(tip.dy, lessThan(-20));
    });

    test('one sample or a motionless pen has no prediction', () {
      expect(PenPrediction.predict([_s(5, 5, 0)]), isNull);
      expect(PenPrediction.predict([_s(5, 5, 0), _s(5, 5, 20)]), isNull);
    });

    test('a very slow pen is not predicted', () {
      expect(PenPrediction.predict([_s(0, 0, 0), _s(1, 0, 20)]), isNull);
    });

    test('too little time between samples gives no prediction', () {
      expect(PenPrediction.predict([_s(0, 0, 0), _s(30, 0, 2)]), isNull);
    });

    test('the guess is never far from the last point', () {
      final tip = PenPrediction.predict([_s(0, 0, 0), _s(200, 0, 10)]);
      expect((tip! - const Offset(200, 0)).distance,
          lessThanOrEqualTo(PenPrediction.maxDistance + 1e-9));
    });

    test('old movement is forgotten', () {
      PenPrediction.add(const Offset(0, 0), const Duration(milliseconds: 0));
      PenPrediction.add(const Offset(10, 0), const Duration(milliseconds: 10));
      expect(PenPrediction.tip, isNotNull);
      // Much later, the pen is somewhere else and just starting to move.
      PenPrediction.add(const Offset(500, 500), const Duration(milliseconds: 500));
      expect(PenPrediction.tip, isNull);
    });

    test('reset clears the guess', () {
      PenPrediction.add(const Offset(0, 0), Duration.zero);
      PenPrediction.add(const Offset(10, 0), const Duration(milliseconds: 10));
      PenPrediction.reset();
      expect(PenPrediction.tip, isNull);
    });
  });
}
