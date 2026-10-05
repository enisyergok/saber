import 'dart:math' as math;

import 'package:perfect_freehand/perfect_freehand.dart';

/// The writing pens whose line follows the settings of the pen panel.
enum PenKind { fountain, ballpoint, brush }

/// How the pen panel's settings (pressure sensitivity, tip sharpness) and
/// the stylus' pressure become the shape of a line.
///
/// The numbers come from measurements on the tablet: ordinary writing
/// presses at about 0.1 to 0.5 of the pen's range and a firm press reaches
/// 0.95. Used as they are, such values barely change the width of a line,
/// so they are spread out first.
abstract class PenFeel {
  /// Raw pressure at and above which the line is at its thickest.
  static const knee = 0.85;

  /// Below 1 this lifts light pressure, where most writing happens.
  static const gamma = 0.75;

  /// Spreads a raw stylus pressure (0..1) over the whole width range.
  static double pressure(double raw) =>
      math.pow((raw / knee).clamp(0.0, 1.0), gamma).toDouble();

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
    };
  }

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
