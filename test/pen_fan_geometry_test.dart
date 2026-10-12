import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:saber/components/editor_gn/pen_fan_geometry.dart';

void main() {
  const g = PenFanGeometry(direction: 0);

  test('the middle of each cell hits that cell', () {
    for (var i = 0; i < g.toolCount; i++) {
      expect(g.hit(g.toolCenter(i)), FanTool(i));
    }
    for (var i = 0; i < g.colorCount; i++) {
      expect(g.hit(g.colorCenter(i)), FanColor(i));
    }
  });

  test('outside the fan hits nothing', () {
    expect(g.hit(Offset.zero), isNull);
    expect(g.hit(const Offset(300, 0)), isNull); // too far
    expect(g.hit(const Offset(-100, 0)), isNull); // behind the button
    expect(g.hit(const Offset(75, 0) + const Offset(0, 0.0)), isNotNull);
    // between the rings
    expect(g.hit(const Offset(134, 0)), isNull);
  });

  test('works for any direction, including across the 0/2pi seam', () {
    for (var k = 0; k < 24; k++) {
      final geo = PenFanGeometry(direction: k * math.pi / 12);
      for (var i = 0; i < geo.toolCount; i++) {
        expect(geo.hit(geo.toolCenter(i)), FanTool(i), reason: 'dir $k tool $i');
      }
      for (var i = 0; i < geo.colorCount; i++) {
        expect(geo.hit(geo.colorCenter(i)), FanColor(i), reason: 'dir $k col $i');
      }
    }
  });

  test('neighbouring colour cells are at least 24 px apart', () {
    for (var i = 1; i < g.colorCount; i++) {
      expect(
        (g.colorCenter(i) - g.colorCenter(i - 1)).distance,
        greaterThanOrEqualTo(24),
      );
    }
  });

  test('a button with room keeps its place', () {
    const screen = Size(1200, 1800);
    expect(
      PenFanGeometry.fitPosition(const Offset(600, 900), screen),
      const Offset(600, 900),
    );
  });

  test('the fan opens toward the middle of the screen', () {
    const screen = Size(1200, 1800);
    final left = PenFanGeometry.bestDirection(const Offset(100, 900), screen);
    expect(math.cos(left), greaterThan(0.5)); // to the right
    final right = PenFanGeometry.bestDirection(const Offset(1100, 900), screen);
    expect(math.cos(right), lessThan(-0.5)); // to the left
  });

  test('the whole outer arc stays on screen near corners', () {
    const screen = Size(1200, 1800);
    for (final p in [
      const Offset(40, 40),
      const Offset(1160, 40),
      const Offset(40, 1760),
      const Offset(1160, 1760),
      const Offset(600, 40),
    ]) {
      final fitted = PenFanGeometry.fitPosition(p, screen);
      final dir = PenFanGeometry.bestDirection(fitted, screen);
      final geo = PenFanGeometry(direction: dir);
      for (var k = 0; k <= 6; k++) {
        final a = geo.start + PenFanGeometry.span * k / 6;
        final q = fitted + Offset.fromDirection(a, PenFanGeometry.toolOuter);
        expect(q.dx, inInclusiveRange(0, screen.width), reason: '$p $k');
        expect(q.dy, inInclusiveRange(0, screen.height), reason: '$p $k');
      }
    }
  });

  group('rotating rings', () {
    test('wrap keeps indices in range, also going backwards', () {
      expect(FanRing.wrap(-1, 27), 26);
      expect(FanRing.wrap(27, 27), 0);
      expect(FanRing.wrap(30, 27), 3);
    });

    test('cells show a window onto the list', () {
      expect([for (var s = 0; s < 5; s++) FanRing.itemAt(0, 8, s)],
          [0, 1, 2, 3, 4]);
      expect([for (var s = 0; s < 5; s++) FanRing.itemAt(6, 8, s)],
          [6, 7, 0, 1, 2]);
      expect([for (var s = 0; s < 5; s++) FanRing.itemAt(-1, 8, s)],
          [7, 0, 1, 2, 3]);
    });

    test('slotOf finds an item that is in view and null otherwise', () {
      expect(FanRing.slotOf(0, 8, 5, 3), 3);
      expect(FanRing.slotOf(0, 8, 5, 6), isNull);
      expect(FanRing.slotOf(6, 8, 5, 1), 3);
    });

    test('reveal brings a hidden item into view', () {
      final o = FanRing.reveal(0, 27, 9, 20);
      expect(FanRing.slotOf(o, 27, 9, 20), isNotNull);
      expect(FanRing.reveal(0, 27, 9, 4), 0); // already in view
    });

    test('dragging forward turns the cells with the finger', () {
      // a drag by one cell's width moves the offset by one cell
      final cell = PenFanGeometry.span / 9;
      expect(FanRing.turnBy(cell, 9, PenFanGeometry.span), closeTo(-1, 1e-9));
      expect(FanRing.turnBy(-cell, 9, PenFanGeometry.span), closeTo(1, 1e-9));
    });

    test('angleDelta takes the short way round the seam', () {
      expect(FanRing.angleDelta(3.0, -3.0), closeTo(2 * math.pi - 6, 1e-9));
      expect(FanRing.angleDelta(-3.0, 3.0), closeTo(6 - 2 * math.pi, 1e-9));
    });

    test('the colour list is as long as the ring expects', () {
      expect(penFanColors.length, 27);
      expect(penFanColors.toSet().length, 27);
    });

    test('inside covers both rings and the gap, not the rest', () {
      expect(g.inside(g.colorCenter(4)), isTrue);
      expect(g.inside(const Offset(134, 0)), isTrue);
      expect(g.inside(const Offset(10, 0)), isFalse);
      expect(g.inside(const Offset(-100, 0)), isFalse);
    });
  });
}
