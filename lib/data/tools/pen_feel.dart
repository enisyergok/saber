import 'dart:math' as math;

import 'package:perfect_freehand/perfect_freehand.dart';
import 'package:saber/data/tools/stylus_profile.dart';
import 'package:saber/data/tools/pressure_curve.dart';

/// The writing pens whose line follows the settings of the pen panel.
enum PenKind { fountain, ballpoint, brush, calligraphy, creative }

/// How the pen panel's settings (pressure sensitivity, tip sharpness, the
/// pressure curve) and the stylus' pressure become the shape of a line.
abstract class PenFeel {
  /// The pressure curve in use. Set from the settings when a line is begun
  /// and by the pen panel while it is being edited.
  static PressureCurve curve = PressureCurve.standard;

  /// Spreads a raw stylus pressure (0..1) over the whole width range.
  static double pressure(double raw) => curve.map(raw);

  /// Removes the tiny pressure jumps produced by some EMR pens without
  /// making a deliberate pressure change feel delayed. Notewise's ink
  /// resources use a similarly quiet pressure-to-width transition: the
  /// stroke should widen continuously, not in visible steps.
  static double smoothPressure(
    double current,
    double? previous, {
    bool creative = false,
  }) {
    if (previous == null) return current.clamp(0.0, 1.0);
    final response = creative ? 0.58 : StylusProfile.pressureResponse;
    return (previous + (current - previous) * response).clamp(0.0, 1.0);
  }

  /// The angle the calligraphy pen's flat nib is held at: 45 degrees, so
  /// lines going up to the right are thin and those going down to the
  /// right are thick.
  static const nibAngle = -math.pi / 4;

  /// How thick (0..1) the calligraphy pen draws when moving in
  /// [direction] (radians, as [Offset.direction] gives it).
  static double nibPressure(double direction) =>
      math.sin(direction - nibAngle).abs();

  /// How strongly the width follows pressure, for a [sensitivity] of 0..1
  /// as set in the pen panel. 0 always gives a line of even width.
  static double thinning(PenKind kind, double sensitivity) {
    final s = sensitivity.clamp(0.0, 1.0);
    return switch (kind) {
      // Half way already gives a lively line; the end of the scale goes
      // from a hairline to the full width.
      PenKind.fountain => 1 - (1 - s) * (1 - s),
      // A ballpoint only swells a little.
      PenKind.ballpoint => 0.45 * s,
      // A brush is never even, unless turned off.
      PenKind.brush => s == 0 ? 0 : 0.6 + 0.4 * s,
      // Here it is the contrast between thin and thick strokes.
      PenKind.calligraphy => s == 0 ? 0 : 0.5 + 0.5 * s,
      PenKind.creative => s == 0 ? 0 : 0.72 + 0.28 * s,
    };
  }

  /// The lengths of the pointed start and end of a line, for a tip
  /// [sharpness] of 0..1. Zero means a blunt end.
  static (double start, double end) tapers(
    PenKind kind,
    double sharpness,
    double size,
  ) {
    final s = sharpness.clamp(0.0, 1.0);
    return switch (kind) {
      PenKind.fountain => (size * 3 * s, size * 7 * s),
      PenKind.ballpoint => (0, 0),
      PenKind.brush => (size * 3 * s, size * 6 * s),
      PenKind.calligraphy => (0, 0),
      PenKind.creative => (size * 2 * s, size * 5 * s),
    };
  }

  /// Whether the pen panel offers tip sharpness for [kind].
  static bool hasSharpness(PenKind kind) =>
      kind == PenKind.fountain || kind == PenKind.brush;

  /// The longest a taper may be on a finished line of [length], so that
  /// short lines (dots, small letters) do not turn into hairlines.
  static double maxTaper(double length) => length * 0.3;

  /// The options a line is really drawn with: [options] as edited in the
  /// pen panel, where thinning holds the pressure sensitivity.
  static StrokeOptions apply(
    PenKind kind,
    StrokeOptions options, {
    required double sharpness,
  }) {
    final (start, end) = tapers(kind, sharpness, options.size);
    return options.copyWith(
      thinning: thinning(kind, options.thinning),
      start: StrokeEndOptions.start(
        taperEnabled: start > 0,
        customTaper: start > 0 ? start : null,
      ),
      end: StrokeEndOptions.end(
        taperEnabled: end > 0,
        customTaper: end > 0 ? end : null,
      ),
    );
  }
}
