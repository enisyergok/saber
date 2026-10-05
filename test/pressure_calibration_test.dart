import 'package:flutter_test/flutter_test.dart';
import 'package:saber/data/tools/pressure_calibration.dart';

void main() {
  setUp(PressureCalibration.reset);

  void learn(double lo, double hi, {int strokes = 5}) {
    for (var i = 0; i < strokes; i++) {
      PressureCalibration.addStroke(lo, hi, 20);
    }
  }

  test('nothing changes before enough strokes were seen', () {
    learn(0.8, 1.0, strokes: 2);
    expect(PressureCalibration.map(0.8), 0.8);
    expect(PressureCalibration.isFlat, isFalse);
  });

  test('a narrow range is stretched over 0..1', () {
    learn(0.5, 0.9);
    expect(PressureCalibration.map(0.5), 0);
    expect(PressureCalibration.map(0.9), 1);
    expect(PressureCalibration.map(0.7), closeTo(0.5, 1e-9));
    expect(PressureCalibration.map(1.0), 1);
    expect(PressureCalibration.map(0.1), 0);
  });

  test('a full range pen is left alone', () {
    learn(0.0, 1.0);
    expect(PressureCalibration.map(0.3), 0.3);
    learn(0.1, 0.9);
    expect(PressureCalibration.isFlat, isFalse);
  });

  test('pressure that never changes is flat', () {
    learn(0.97, 1.0);
    expect(PressureCalibration.isFlat, isTrue);
    expect(PressureCalibration.map(0.98), 0.98);
  });

  test('short strokes are ignored', () {
    for (var i = 0; i < 10; i++) {
      PressureCalibration.addStroke(0.9, 1.0, 3);
    }
    expect(PressureCalibration.isFlat, isFalse);
  });
}
