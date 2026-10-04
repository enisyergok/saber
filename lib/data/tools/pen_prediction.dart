import 'dart:ui';

/// Guesses where the pen tip will be a few milliseconds from now, so the
/// line can be drawn up to (nearly) the tip instead of trailing behind it.
///
/// The guess is only ever drawn while writing, never saved: when the pen
/// lifts, the stroke is exactly what the pen did.
class PenPrediction {
  /// How far ahead to guess. About one and a half frames at 60 Hz.
  static const horizon = Duration(milliseconds: 24);

  /// Only the last moments of movement say where the pen is heading.
  static const window = Duration(milliseconds: 40);

  /// The guess never goes further than this from the last point, in page
  /// units, so a sudden stop or turn can't leave a long stray tail.
  static const maxDistance = 48.0;

  /// A pen that is barely moving isn't predicted.
  static const minSpeed = 0.15; // page units per millisecond

  static final List<(Offset, Duration)> _samples = [];

  /// Where the line is predicted to end, or null when no guess is made.
  static Offset? tip;

  /// Forget everything, at the start and end of a stroke.
  static void reset() {
    _samples.clear();
    tip = null;
  }

  /// Notes that the pen is at [position] at time [at], and updates [tip].
  static void add(Offset position, Duration at) {
    _samples.add((position, at));
    _samples.removeWhere((s) => at - s.$2 > window);
    tip = predict(_samples);
  }

  /// The predicted tip for [samples] (oldest first), or null.
  static Offset? predict(
    List<(Offset, Duration)> samples, {
    Duration ahead = horizon,
  }) {
    if (samples.length < 2) return null;

    final (lastPosition, lastTime) = samples.last;
    final (firstPosition, firstTime) = samples.first;
    final elapsed = (lastTime - firstTime).inMicroseconds / 1000;
    if (elapsed < 4) return null; // too little time to know the speed

    final velocity = (lastPosition - firstPosition) / elapsed;
    if (velocity.distance < minSpeed) return null;

    var step = velocity * (ahead.inMicroseconds / 1000);
    if (step.distance > maxDistance) {
      step = step / step.distance * maxDistance;
    }
    return lastPosition + step;
  }
}
