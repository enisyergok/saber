/// How hard the pen is pressed (0..1 across) against how thick the line
/// gets (0..1 up): the curve drawn in the pen settings.
///
/// It is made of straight pieces through five points. The first is fixed
/// at nothing; the other four ([ys]) can be dragged up and down, and never
/// go below the point before them.
class PressureCurve {
  const PressureCurve(this.ys) : assert(ys.length == 4);

  /// The heights at a pressure of a quarter, a half, three quarters and
  /// full.
  final List<double> ys;

  /// The pressures the points of the curve sit at.
  static const xs = <double>[0, 0.25, 0.5, 0.75, 1];

  /// Tuned on the tablet: ordinary writing presses at about 0.1 to 0.5 of
  /// the pen's range, so light pressure is lifted.
  static const standard = PressureCurve([0.40, 0.67, 0.91, 1]);

  /// Pressure used exactly as the pen reports it.
  static const linear = PressureCurve([0.25, 0.5, 0.75, 1]);

  /// The height of point [index] (0..4), the fixed first one included.
  double y(int index) => index == 0 ? 0 : ys[index - 1];

  /// The line thickness (0..1) for a raw pressure of [raw] (0..1).
  double map(double raw) {
    final x = raw.clamp(0.0, 1.0);
    for (var i = 1; i < xs.length; i++) {
      if (x <= xs[i]) {
        final t = (x - xs[i - 1]) / (xs[i] - xs[i - 1]);
        return y(i - 1) + (y(i) - y(i - 1)) * t;
      }
    }
    return y(4);
  }

  /// This curve with point [index] (1..4) moved to a height of [value].
  /// The point stays between its neighbours, so the curve never goes down.
  PressureCurve withPoint(int index, double value) {
    assert(index >= 1 && index <= 4);
    final low = y(index - 1);
    final high = index == 4 ? 1.0 : y(index + 1);
    final next = [...ys];
    next[index - 1] = value.clamp(low, high);
    return PressureCurve(next);
  }

  /// How the curve is kept in the settings.
  String encode() => ys.map((y) => y.toStringAsFixed(3)).join(',');

  /// Reads [encode]'s text; anything else gives [standard].
  static PressureCurve parse(String? text) {
    if (text == null || text.isEmpty) return standard;
    final parts = text.split(',');
    if (parts.length != 4) return standard;
    final values = <double>[];
    var previous = 0.0;
    for (final part in parts) {
      final value = double.tryParse(part.trim());
      if (value == null || value.isNaN || value < previous || value > 1) {
        return standard;
      }
      values.add(value);
      previous = value;
    }
    return PressureCurve(values);
  }

  @override
  bool operator ==(Object other) =>
      other is PressureCurve && other.encode() == encode();

  @override
  int get hashCode => encode().hashCode;
}
