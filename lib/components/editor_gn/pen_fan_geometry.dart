import 'dart:math' as math;
import 'dart:ui';

/// What a point on the pen fan lands on.
sealed class FanHit {
  const FanHit();
}

class FanTool extends FanHit {
  const FanTool(this.index);
  final int index;
  @override
  bool operator ==(Object other) => other is FanTool && other.index == index;
  @override
  int get hashCode => index.hashCode;
}

class FanColor extends FanHit {
  const FanColor(this.index);
  final int index;
  @override
  bool operator ==(Object other) => other is FanColor && other.index == index;
  @override
  int get hashCode => Object.hash('color', index);
}

/// The shape of the pen fan: two rings of cells around the round button,
/// the inner ring for colours and the outer for tools, both spread over
/// the same angle. Pure geometry, so it can be tested without a screen.
class PenFanGeometry {
  const PenFanGeometry({
    required this.direction,
    this.toolCount = 5,
    this.colorCount = 9,
  });

  /// The angle (radians, as on screen: 0 = right, pi/2 = down) the middle
  /// of the fan points to.
  final double direction;
  final int toolCount;
  final int colorCount;

  static const buttonRadius = 28.0;
  static const colorInner = 52.0;
  static const colorOuter = 132.0;
  static const toolInner = 136.0;
  static const toolOuter = 214.0;

  /// How wide the fan is.
  static const span = 140 * math.pi / 180;

  double get start => direction - span / 2;

  /// The angle of the middle of cell [i] of [count] cells.
  double cellAngle(int i, int count) => start + span * (i + 0.5) / count;

  Offset toolCenter(int i) => Offset.fromDirection(
    cellAngle(i, toolCount),
    (toolInner + toolOuter) / 2,
  );

  Offset colorCenter(int i) => Offset.fromDirection(
    cellAngle(i, colorCount),
    (colorInner + colorOuter) / 2,
  );

  /// What [p] (relative to the button's centre) lands on, or null.
  FanHit? hit(Offset p) {
    final r = p.distance;
    var a = p.direction - start;
    // bring into 0..2pi
    while (a < 0) {
      a += 2 * math.pi;
    }
    while (a >= 2 * math.pi) {
      a -= 2 * math.pi;
    }
    if (a > span) return null;
    if (r >= toolInner && r <= toolOuter) {
      return FanTool((a / span * toolCount).floor().clamp(0, toolCount - 1));
    }
    if (r >= colorInner && r <= colorOuter) {
      return FanColor((a / span * colorCount).floor().clamp(0, colorCount - 1));
    }
    return null;
  }

  /// The direction that opens the fan toward the middle of the screen
  /// while keeping all of it on screen where possible.
  static double bestDirection(Offset button, Size screen, {double margin = 8}) {
    final inward = (Offset(screen.width / 2, screen.height / 2) - button)
        .direction;
    final candidates = <double>[
      for (var k = 0; k < 24; k++) k * math.pi / 12,
    ]..sort(
        (a, b) => _angleGap(a, inward).compareTo(_angleGap(b, inward)),
      );
    final bounds = Rect.fromLTWH(
      margin,
      margin,
      screen.width - 2 * margin,
      screen.height - 2 * margin,
    );
    for (final dir in candidates) {
      if (_fits(PenFanGeometry(direction: dir), button, bounds)) return dir;
    }
    return inward;
  }

  static bool _fits(PenFanGeometry g, Offset button, Rect bounds) {
    for (var k = 0; k <= 6; k++) {
      final a = g.start + span * k / 6;
      if (!bounds.contains(button + Offset.fromDirection(a, toolOuter))) {
        return false;
      }
    }
    return true;
  }

  static double _angleGap(double a, double b) {
    var d = (a - b) % (2 * math.pi);
    if (d < 0) d += 2 * math.pi;
    return d > math.pi ? 2 * math.pi - d : d;
  }
}
