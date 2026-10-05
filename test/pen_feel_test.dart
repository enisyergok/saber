import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:perfect_freehand/perfect_freehand.dart';
import 'package:saber/data/tools/pen_feel.dart';
import 'package:saber/data/tools/pressure_curve.dart';

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
  setUp(() => PenFeel.curve = PressureCurve.standard);

  test('pressure follows the curve in use', () {
    expect(PenFeel.pressure(0), 0);
    expect(PenFeel.pressure(1), 1);
    // Ordinary writing pressure lands near the middle of the range.
    expect(PenFeel.pressure(0.29), inInclusiveRange(0.4, 0.5));

    PenFeel.curve = PressureCurve.linear;
    expect(PenFeel.pressure(0.29), closeTo(0.29, 1e-9));
  });

  test('the calligraphy nib is thin along its edge and thick across it', () {
    // Up to the right: along the nib.
    expect(PenFeel.nibPressure(const Offset(1, -1).direction), closeTo(0, 1e-9));
    // Down to the right: across it.
    expect(PenFeel.nibPressure(const Offset(1, 1).direction), closeTo(1, 1e-9));
    // The same line drawn the other way is as thick.
    expect(
      PenFeel.nibPressure(const Offset(-1, -1).direction),
      closeTo(1, 1e-9),
    );
    expect(
      PenFeel.nibPressure(const Offset(1, 0).direction),
      closeTo(0.7071, 1e-3),
    );
    expect(PenFeel.hasSharpness(PenKind.calligraphy), isFalse);
    expect(PenFeel.hasSharpness(PenKind.fountain), isTrue);
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
