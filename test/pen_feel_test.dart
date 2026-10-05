import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:perfect_freehand/perfect_freehand.dart';
import 'package:saber/data/tools/pen_feel.dart';

/// The thickness of a straight line drawn with one raw [pressure].
double _thickness(PenKind kind, double sensitivity, double pressure) {
  final options = PenFeel.apply(
    kind,
    StrokeOptions(size: 10, thinning: sensitivity, streamline: 0),
    sharpness: 0,
  ).copyWith(isComplete: true, simulatePressure: false);
  final polygon = getStroke([
    for (var x = 0.0; x <= 300; x += 5)
      PointVector(x, 100, PenFeel.pressure(pressure)),
  ], options: options);
  final middle = polygon.where((p) => p.dx > 100 && p.dx < 200);
  final ys = middle.map((p) => p.dy);
  return ys.reduce(math.max) - ys.reduce(math.min);
}

void main() {
  test('pressure is spread out and never leaves 0..1', () {
    expect(PenFeel.pressure(0), 0);
    expect(PenFeel.pressure(PenFeel.knee), 1);
    expect(PenFeel.pressure(1), 1);
    var previous = -1.0;
    for (var p = 0.0; p <= 1; p += 0.05) {
      final mapped = PenFeel.pressure(p);
      expect(mapped, greaterThanOrEqualTo(previous));
      expect(mapped, inInclusiveRange(0, 1));
      previous = mapped;
    }
    // Ordinary writing pressure lands near the middle of the range.
    expect(PenFeel.pressure(0.29), inInclusiveRange(0.4, 0.5));
  });

  test('sensitivity 0 gives an even line for every pen', () {
    for (final kind in PenKind.values) {
      expect(PenFeel.thinning(kind, 0), 0, reason: '$kind');
      expect(
        _thickness(kind, 0, 0.1),
        closeTo(_thickness(kind, 0, 0.94), 0.01),
        reason: '$kind',
      );
    }
  });

  test('the fountain pen thickens clearly with the measured pressures', () {
    // Measured on the tablet: light writing about 0.1 to 0.45, firm 0.94.
    final light = _thickness(PenKind.fountain, 0.5, 0.1);
    final normal = _thickness(PenKind.fountain, 0.5, 0.29);
    final firm = _thickness(PenKind.fountain, 0.5, 0.94);
    expect(normal, greaterThan(light * 1.4));
    expect(firm, greaterThan(light * 2.5));
    expect(firm, greaterThan(normal * 1.5));
    // More sensitivity, more difference.
    final lightMax = _thickness(PenKind.fountain, 1, 0.1);
    final firmMax = _thickness(PenKind.fountain, 1, 0.94);
    expect(firmMax / lightMax, greaterThan(firm / light));
  });

  test('the ballpoint only swells a little', () {
    final light = _thickness(PenKind.ballpoint, 1, 0.1);
    final firm = _thickness(PenKind.ballpoint, 1, 0.94);
    expect(firm, greaterThan(light * 1.2));
    expect(firm, lessThan(light * 2.5));
  });

  test('tip sharpness sets the tapers and leaves the pen options alone', () {
    final options = StrokeOptions(size: 10, thinning: 0.5);
    final blunt = PenFeel.apply(PenKind.fountain, options, sharpness: 0);
    expect(blunt.start.taperEnabled, isFalse);
    expect(blunt.end.taperEnabled, isFalse);

    final sharp = PenFeel.apply(PenKind.fountain, options, sharpness: 1);
    expect(sharp.end.taperEnabled, isTrue);
    expect(sharp.end.customTaper, 70);
    expect(sharp.start.customTaper, 30);

    final ballpoint = PenFeel.apply(PenKind.ballpoint, options, sharpness: 1);
    expect(ballpoint.end.taperEnabled, isFalse);

    expect(options.thinning, 0.5);
    expect(options.end.taperEnabled, isFalse);
    expect(PenFeel.maxTaper(100), 30);
  });
}
