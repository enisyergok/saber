import 'package:flutter_test/flutter_test.dart';
import 'package:saber/data/tools/pressure_curve.dart';

void main() {
  test('the curve goes through its points, in straight pieces', () {
    const curve = PressureCurve([0.4, 0.6, 0.9, 1]);
    expect(curve.map(0), 0);
    expect(curve.map(0.25), closeTo(0.4, 1e-9));
    expect(curve.map(0.5), closeTo(0.6, 1e-9));
    expect(curve.map(1), 1);
    expect(curve.map(0.125), closeTo(0.2, 1e-9));
    expect(curve.map(0.625), closeTo(0.75, 1e-9));
    // Out of range pressures are brought back in.
    expect(curve.map(-1), 0);
    expect(curve.map(2), 1);
  });

  test('the standard curve lifts light pressure and never goes down', () {
    var previous = -1.0;
    for (var p = 0.0; p <= 1.0001; p += 0.05) {
      final mapped = PressureCurve.standard.map(p);
      expect(mapped, greaterThanOrEqualTo(previous));
      expect(mapped, inInclusiveRange(0, 1));
      if (p > 0.01 && p < 0.99) expect(mapped, greaterThan(p));
      previous = mapped;
    }
    expect(PressureCurve.linear.map(0.37), closeTo(0.37, 1e-9));
  });

  test('a dragged point stays between its neighbours', () {
    const curve = PressureCurve([0.4, 0.6, 0.9, 1]);
    expect(curve.withPoint(2, 0.5).ys, [0.4, 0.5, 0.9, 1]);
    // not below the point before it, nor above the one after
    expect(curve.withPoint(2, 0.1).ys, [0.4, 0.4, 0.9, 1]);
    expect(curve.withPoint(2, 0.99).ys, [0.4, 0.9, 0.9, 1]);
    // the last point may come down, but not below the third
    expect(curve.withPoint(4, 0.95).ys, [0.4, 0.6, 0.9, 0.95]);
    expect(curve.withPoint(4, 0.2).ys, [0.4, 0.6, 0.9, 0.9]);
    expect(curve.withPoint(1, -3).ys, [0, 0.6, 0.9, 1]);
    // the original is untouched
    expect(curve.ys, [0.4, 0.6, 0.9, 1]);
  });

  test('the curve survives being saved and read back', () {
    const curve = PressureCurve([0.125, 0.5, 0.875, 1]);
    expect(PressureCurve.parse(curve.encode()), curve);
    expect(PressureCurve.parse(''), PressureCurve.standard);
    expect(PressureCurve.parse(null), PressureCurve.standard);
    expect(PressureCurve.parse('nonsense'), PressureCurve.standard);
    expect(PressureCurve.parse('0.5,0.4,0.9,1'), PressureCurve.standard);
    expect(PressureCurve.parse('0.1,0.2,0.3'), PressureCurve.standard);
    expect(PressureCurve.parse('0.1,0.2,0.3,7'), PressureCurve.standard);
  });
}
