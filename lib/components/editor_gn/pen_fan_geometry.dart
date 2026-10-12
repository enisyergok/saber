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

  /// The centre of a tool cell at the (possibly fractional) cell position
  /// [slot], so rings can be drawn part-way through a turn.
  Offset toolAt(double slot) => Offset.fromDirection(
    start + span * (slot + 0.5) / toolCount,
    (toolInner + toolOuter) / 2,
  );

  Offset colorAt(double slot) => Offset.fromDirection(
    start + span * (slot + 0.5) / colorCount,
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

  /// Whether [p] (relative to the button's centre) is on the fan at all,
  /// rings and the thin gap between them.
  bool inside(Offset p) {
    final r = p.distance;
    if (r < colorInner || r > toolOuter) return false;
    return FanRing.angleDelta(start + span / 2, p.direction).abs() <=
        span / 2;
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

  /// Whether the fan opening toward [dir] from [button] stays inside
  /// [screen] (less [margin]).
  static bool fitsOnScreen(
    Offset button,
    Size screen,
    double dir, {
    double margin = 8,
  }) => _fits(
    PenFanGeometry(direction: dir),
    button,
    Rect.fromLTWH(margin, margin, screen.width - 2 * margin,
        screen.height - 2 * margin),
  );

  /// Where the button has to be for the whole fan to fit: [button] itself
  /// when it already fits, otherwise the nearest point on the way to the
  /// middle of the screen that does.
  static Offset fitPosition(Offset button, Size screen, {double margin = 8}) {
    final middle = Offset(screen.width / 2, screen.height / 2);
    for (var i = 0; i <= 40; i++) {
      final p = Offset.lerp(button, middle, i / 40)!;
      final dir = bestDirection(p, screen, margin: margin);
      if (fitsOnScreen(p, screen, dir, margin: margin)) return p;
    }
    return middle;
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

/// The rotating rings: [count] cells show a window onto a longer list of
/// [n] things that goes round and round.
abstract class FanRing {
  /// [i] wrapped into 0 to n-1.
  static int wrap(int i, int n) => ((i % n) + n) % n;

  /// Which item the cell [slot] shows when the ring is turned by [offset]
  /// (rounded to a whole cell).
  static int itemAt(double offset, int n, int slot) =>
      wrap(offset.round() + slot, n);

  /// The cell (0 to count-1) that shows item [index], or null when it is
  /// out of view.
  static int? slotOf(double offset, int n, int count, int index) {
    final slot = wrap(index - offset.round(), n);
    return slot < count ? slot : null;
  }

  /// [offset] turned, if needed, so item [index] is in view (in the middle
  /// where there is room).
  static double reveal(double offset, int n, int count, int index) {
    if (slotOf(offset, n, count, index) != null) return offset;
    return (index - count ~/ 2).toDouble();
  }

  /// How far a drag of [radians] along a ring of [count] cells spread over
  /// [span] turns it, in cells. Dragging forward moves the cells with the
  /// finger, so the offset goes down.
  static double turnBy(double radians, int count, double span) =>
      -radians / (span / count);

  /// The smallest turn (-pi to pi) from angle [a] to angle [b].
  static double angleDelta(double a, double b) {
    var d = (b - a) % (2 * math.pi);
    if (d > math.pi) d -= 2 * math.pi;
    if (d < -math.pi) d += 2 * math.pi;
    return d;
  }
}

/// The colours the colour ring goes through: greys first, then each hue in
/// a dark, a pure and a light shade, so neighbours look alike.
const penFanColors = <Color>[
  Color(0xFF111827),
  Color(0xFF6B7280),
  Color(0xFF9CA3AF),
  Color(0xFF7F1D1D),
  Color(0xFFDC2626),
  Color(0xFFF87171),
  Color(0xFFC2410C),
  Color(0xFFF97316),
  Color(0xFFFDBA74),
  Color(0xFFA16207),
  Color(0xFFFBBF24),
  Color(0xFFFDE047),
  Color(0xFF4D7C0F),
  Color(0xFF16A34A),
  Color(0xFF86EFAC),
  Color(0xFF0F766E),
  Color(0xFF14B8A6),
  Color(0xFF0369A1),
  Color(0xFF2563EB),
  Color(0xFF93C5FD),
  Color(0xFF4338CA),
  Color(0xFF8B5CF6),
  Color(0xFFC4B5FD),
  Color(0xFF9D174D),
  Color(0xFFEC4899),
  Color(0xFFF9A8D4),
  Color(0xFF78350F),
];
