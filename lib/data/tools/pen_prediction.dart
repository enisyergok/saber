import 'dart:math' as math;
import 'dart:ui';

/// Guesses where the pen tip will be a few milliseconds from now, so the
/// line can be drawn up to (nearly) the tip instead of trailing behind it.
///
/// From the pen touching the glass to the screen showing it takes two or
/// three frames: the frame that draws it, the one the screen is still
/// showing while that is made, and the panel's own time. The ink is
/// always that far behind the pen. A fast stroke at 500 units a second
/// trails by 15 to 20 units, many pen widths.
///
/// The guess is a smooth curve fitted to the last few samples (position,
/// speed and how the speed is changing), carried a little way forward.
/// Handwriting is almost all curves, so a guess that only holds on straight
/// lines (as the first version of this was) hardly ever helped.
///
/// The guess is only ever drawn while writing, never saved: when the pen
/// lifts, the stroke is exactly what the pen did.
class PenPrediction {
  /// How far ahead to guess, when nothing is known of the screen: a bit
  /// less than the two frames at 60 Hz that the line is behind by.
  static const defaultHorizon = Duration(milliseconds: 28);

  /// How far ahead to guess now (see [tuneToRefreshRate]).
  static Duration horizon = defaultHorizon;

  /// The guess reaches this many frames of the screen ahead: about as far
  /// as the line is behind, a little less so that a pen that turns or stops
  /// never leaves much of a stray end.
  static const framesAhead = 1.7;

  /// The furthest ahead the guess goes, however fast the screen is.
  static const minHorizon = Duration(milliseconds: 14);
  static const maxHorizon = Duration(milliseconds: 30);

  /// Sets [horizon] for a screen that refreshes [hertz] times a second: a
  /// faster screen shows the line sooner, so there is less to make up.
  static void tuneToRefreshRate(double hertz) {
    if (!hertz.isFinite || hertz < 30 || hertz > 400) {
      horizon = defaultHorizon;
      return;
    }
    final ms = (1000 / hertz * framesAhead).clamp(
      minHorizon.inMicroseconds / 1000,
      maxHorizon.inMicroseconds / 1000,
    );
    horizon = Duration(microseconds: (ms * 1000).round());
  }

  /// Only the last moments of movement say where the pen is heading.
  static const window = Duration(milliseconds: 40);

  /// The fit uses at most this many of the newest samples (a pen that
  /// reports every 4 ms gives 10 in [window]; more only adds work).
  static const maxSamples = 8;

  /// The newest samples count the most: a weight falls by a factor of e for
  /// every this much older a sample is.
  static const _weightFalloff = 0.02; // seconds

  /// How much of the change of speed (curvature, a stop) is believed. Less
  /// than all of it, because it is the noisiest part of the fit and its
  /// error grows with the square of the time ahead.
  static const accelerationTrust = 0.8;

  /// The guess never goes further than this from the last point, in page
  /// units, so a sudden stop or turn can't leave a long stray tail.
  static const maxDistance = 48.0;

  /// ... nor further than this many times what the pen would cover at its
  /// present speed.
  static const _maxReachOfSpeed = 1.6;

  /// A pen that is barely moving isn't predicted (page units per
  /// millisecond).
  static const minSpeed = 0.15;

  static final List<(Offset, Duration)> _samples = [];

  /// Where the line is predicted to end, or null when no guess is made.
  static Offset? tip;

  /// The point that bends the way from the last point to [tip] into the
  /// curve the pen is following: draw `quadraticBezierTo(bend, tip)` from
  /// the last point. Null when there is no guess.
  static Offset? bend;

  /// Forget everything, at the start and end of a stroke.
  static void reset() {
    _samples.clear();
    tip = null;
    bend = null;
  }

  /// Notes that the pen is at [position] at time [at], and updates [tip].
  ///
  /// [at] must be the time the pen was there (the time stamp of its event),
  /// not the time the app got to hear of it: events come in batches, and
  /// one batch is handled all at once.
  static void add(Offset position, Duration at) {
    // The same moment twice (or going back) tells nothing about speed.
    if (_samples.isNotEmpty && at <= _samples.last.$2) return;
    _samples.add((position, at));
    _samples.removeWhere((s) => at - s.$2 > window);
    final guess = _predictBoth(_samples, horizon);
    tip = guess?.$1;
    bend = guess?.$2;
  }

  /// The predicted tip for [samples] (oldest first), or null.
  static Offset? predict(
    List<(Offset, Duration)> samples, {
    Duration? ahead,
  }) => _predictBoth(samples, ahead ?? horizon)?.$1;

  /// (tip, bend) for [samples], see [tip] and [bend].
  static (Offset, Offset)? _predictBoth(
    List<(Offset, Duration)> samples,
    Duration ahead,
  ) {
    if (samples.length < 3) return null;

    // The newest samples within the window, oldest first.
    final last = samples.last;
    var from = samples.length - 1;
    while (from > 0 &&
        samples.length - from < maxSamples &&
        last.$2 - samples[from - 1].$2 <= window) {
      from--;
    }
    final count = samples.length - from;
    if (count < 3) return null;

    final span = (last.$2 - samples[from].$2).inMicroseconds / 1e6;
    if (span < 0.008) return null; // too little time to tell a speed

    final times = List<double>.filled(count, 0);
    final weights = List<double>.filled(count, 0);
    for (var i = 0; i < count; i++) {
      final t = (samples[from + i].$2 - last.$2).inMicroseconds / 1e6;
      times[i] = t;
      weights[i] = math.exp(t / _weightFalloff);
    }

    // How the speed changes can only be told from enough samples that
    // cover enough time.
    final quadratic = count >= 4 && span >= 0.016;
    final fitX = _fit(times, weights, [
      for (var i = 0; i < count; i++) samples[from + i].$1.dx,
    ], quadratic);
    final fitY = _fit(times, weights, [
      for (var i = 0; i < count; i++) samples[from + i].$1.dy,
    ], quadratic);
    if (fitX == null || fitY == null) return null;

    final speed = math.sqrt(fitX.speed * fitX.speed + fitY.speed * fitY.speed);
    if (speed < minSpeed * 1000) return null; // per second

    final h = ahead.inMicroseconds / 1e6;
    // A pen that is slowing down comes to a stop, it does not turn back (as
    // the curve of the fit would, if followed for long enough).
    final alongTrack =
        (fitX.acceleration * fitX.speed + fitY.acceleration * fitY.speed) /
        speed *
        accelerationTrust;
    final stopsIn = alongTrack < 0 ? speed / -alongTrack : double.infinity;

    Offset after(double seconds) {
      final s = math.min(seconds, stopsIn);
      final lean = 0.5 * accelerationTrust * s * s;
      return Offset(
        fitX.position + fitX.speed * s + fitX.acceleration * lean,
        fitY.position + fitY.speed * s + fitY.acceleration * lean,
      );
    }

    final lastAt = last.$1;
    final reach = math.min(maxDistance, speed * h * _maxReachOfSpeed);
    Offset limited(Offset point) {
      final step = point - lastAt;
      final distance = step.distance;
      return distance > reach ? lastAt + step / distance * reach : point;
    }

    final end = limited(after(h));
    final middle = limited(after(h / 2));
    // The curve from the last point that passes through [middle] halfway
    // along: its control point.
    final control = middle * 2 - (lastAt + end) / 2;
    return (end, control);
  }

  /// A least-squares fit (newest samples weigh most) of
  /// `p + v t + a t² / 2` to [values] taken at [times] (seconds, the newest
  /// at 0), or of `p + v t` if not [quadratic].
  static ({double position, double speed, double acceleration})? _fit(
    List<double> times,
    List<double> weights,
    List<double> values,
    bool quadratic,
  ) {
    final n = quadratic ? 3 : 2;
    // Normal equations: (AᵀWA) c = AᵀW values, with A's columns
    // 1, t and t²/2.
    final m = List.generate(n, (_) => List<double>.filled(n + 1, 0));
    for (var i = 0; i < times.length; i++) {
      final t = times[i];
      final row = [1.0, t, 0.5 * t * t];
      for (var r = 0; r < n; r++) {
        for (var c = 0; c < n; c++) {
          m[r][c] += weights[i] * row[r] * row[c];
        }
        m[r][n] += weights[i] * row[r] * values[i];
      }
    }
    // Gaussian elimination with partial pivoting: it is a 3 by 3.
    for (var col = 0; col < n; col++) {
      var pivot = col;
      for (var r = col + 1; r < n; r++) {
        if (m[r][col].abs() > m[pivot][col].abs()) pivot = r;
      }
      if (m[pivot][col].abs() < 1e-18) return null;
      final swap = m[col];
      m[col] = m[pivot];
      m[pivot] = swap;
      for (var r = col + 1; r < n; r++) {
        final factor = m[r][col] / m[col][col];
        for (var c = col; c <= n; c++) {
          m[r][c] -= factor * m[col][c];
        }
      }
    }
    final c = List<double>.filled(n, 0);
    for (var r = n - 1; r >= 0; r--) {
      var sum = m[r][n];
      for (var k = r + 1; k < n; k++) {
        sum -= m[r][k] * c[k];
      }
      c[r] = sum / m[r][r];
    }
    if (c.any((v) => !v.isFinite)) return null;
    return (position: c[0], speed: c[1], acceleration: quadratic ? c[2] : 0);
  }
}
