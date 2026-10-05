import 'dart:math' as math;

/// Makes a stylus whose pressure values are squeezed into a narrow band
/// (for example always 0.9 to 1.0) still draw lines that get thicker and
/// thinner.
///
/// It learns from the last few strokes how far the pen's pressure really
/// ranges and stretches that to 0..1. When the pressure hardly changes at
/// all, [isFlat] is true and the pen should fall back to speed based width.
/// A pen that already uses the whole range is left untouched.
abstract class PressureCalibration {
  /// How many finished strokes are remembered.
  static const historyLength = 30;

  /// Strokes needed before anything is changed.
  static const minStrokes = 3;

  /// Points needed in a stroke before it counts as a sample.
  static const minPoints = 8;

  /// Below this range the pressure carries no information.
  static const flatRange = 0.12;

  /// At or above this range the pen is left alone.
  static const healthyRange = 0.7;

  static final List<double> _lows = [];
  static final List<double> _highs = [];

  static void reset() {
    _lows.clear();
    _highs.clear();
  }

  static double _median(List<double> values) {
    final sorted = [...values]..sort();
    final mid = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[mid]
        : (sorted[mid - 1] + sorted[mid]) / 2;
  }

  static bool get _learned => _lows.length >= minStrokes;

  static double get low => _learned ? _median(_lows) : 0;
  static double get high => _learned ? _median(_highs) : 1;

  /// True when this pen's pressure has been the same in recent strokes.
  static bool get isFlat => _learned && high - low < flatRange;

  /// Stretches a raw pressure (0..1) over the range this pen really uses.
  static double map(double raw) {
    if (!_learned) return raw;
    final lo = low;
    final range = high - lo;
    if (range >= healthyRange || range < flatRange) return raw;
    return ((raw - lo) / range).clamp(0.0, 1.0);
  }

  /// Records a finished stroke's lowest and highest raw pressure.
  static void addStroke(double lowest, double highest, int points) {
    if (points < minPoints) return;
    _lows.add(lowest);
    _highs.add(highest);
    if (_lows.length > historyLength) {
      _lows.removeAt(0);
      _highs.removeAt(0);
    }
  }

  /// Shared with tests.
  static double spread(Iterable<double> values) {
    if (values.isEmpty) return 0;
    return values.reduce(math.max) - values.reduce(math.min);
  }
}
