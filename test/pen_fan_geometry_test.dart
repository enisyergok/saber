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
    expect(g.hit(const Offset(100, 0)), isNull);
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
      final dir = PenFanGeometry.bestDirection(p, screen);
      final geo = PenFanGeometry(direction: dir);
      for (var k = 0; k <= 6; k++) {
        final a = geo.start + PenFanGeometry.span * k / 6;
        final q = p + Offset.fromDirection(a, PenFanGeometry.toolOuter);
        expect(q.dx, inInclusiveRange(0, screen.width), reason: '$p $k');
        expect(q.dy, inInclusiveRange(0, screen.height), reason: '$p $k');
      }
    }
  });
}
