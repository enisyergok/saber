import 'dart:math' show acos;
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

  /// A turn sharper than this (radians, between the first and second half of
  /// the recent movement) is not predicted at all. Smaller turns shorten the
  /// guess in proportion, so the tip never sticks out of a curve.
  static const fullTurn = 0.6;

  /// The predicted tip for [samples] (oldest first), or null.
  ///
  /// The guess follows the latest speed and direction, but is shortened when
  /// the pen is turning or slowing down. On a straight stroke it reaches the
  /// full [horizon]; in a letter's curve it shrinks towards nothing instead of
  /// poking out of the line and snapping back.
  static Offset? predict(
    List<(Offset, Duration)> samples, {
    Duration ahead = horizon,
  }) {
    if (samples.length < 3) return null;

    final first = samples.first;
    final middle = samples[samples.length ~/ 2];
    final last = samples.last;
    final firstMs = (middle.$2 - first.$2).inMicroseconds / 1000;
    final secondMs = (last.$2 - middle.$2).inMicroseconds / 1000;
    if (firstMs < 2 || secondMs < 2) return null; // too little time

    final earlier = (middle.$1 - first.$1) / firstMs;
    final latest = (last.$1 - middle.$1) / secondMs;
    final earlierSpeed = earlier.distance;
    final latestSpeed = latest.distance;
    if (latestSpeed < minSpeed || earlierSpeed < minSpeed) return null;

    final cosTurn =
        ((earlier.dx * latest.dx + earlier.dy * latest.dy) /
                (earlierSpeed * latestSpeed))
            .clamp(-1.0, 1.0);
    final turn = acos(cosTurn);
    final straightness = (1 - turn / fullTurn).clamp(0.0, 1.0);
    final steadiness = (latestSpeed / earlierSpeed).clamp(0.0, 1.0);
    final trust = straightness * steadiness;
    if (trust <= 0) return null;

    var step = latest * (ahead.inMicroseconds / 1000 * trust);
    if (step.distance > maxDistance) {
      step = step / step.distance * maxDistance;
    }
    return last.$1 + step;
  }
}
