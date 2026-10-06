import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfect_freehand/perfect_freehand.dart';
import 'package:saber/components/canvas/_circle_stroke.dart';
import 'package:saber/components/canvas/_rectangle_stroke.dart';
import 'package:saber/components/canvas/_stroke.dart';
import 'package:saber/data/tools/ink_eraser.dart';
import 'package:sbn/has_size.dart';
import 'package:sbn/tool_id.dart';

const _page = HasSize(Size(1000, 1400));

/// A stroke as the fountain pen makes it: steadied, as wide as the pen was
/// pressed, with pointed ends.
Stroke _pen({
  double size = 4,
  double thinning = 0.6,
  double streamline = 0.5,
  bool pointed = true,
  ToolId toolId = ToolId.fountainPen,
}) => Stroke(
  color: Colors.black,
  pressureEnabled: true,
  options: StrokeOptions(
    size: size,
    thinning: thinning,
    streamline: streamline,
    simulatePressure: false,
    isComplete: true,
    // (a taper length given turns the taper on, whatever else is said)
    start: pointed
        ? StrokeEndOptions.start(taperEnabled: true, customTaper: 20)
        : StrokeEndOptions.start(taperEnabled: false),
    end: pointed
        ? StrokeEndOptions.end(taperEnabled: true, customTaper: 20)
        : StrokeEndOptions.end(taperEnabled: false),
  ),
  pageIndex: 0,
  page: _page,
  toolId: toolId,
);

/// A line written from left to right, wavering and pressed unevenly.
Stroke _written({double y = 300, double from = 100, double to = 500}) {
  final stroke = _pen();
  for (var x = from; x <= to; x += 4) {
    stroke.addPoint(
      Offset(x, y + math.sin(x / 30) * 12),
      0.3 + 0.5 * (0.5 + 0.5 * math.sin(x / 47)),
    );
  }
  return stroke;
}

double _distanceToSegment(Offset p, Offset a, Offset b) {
  final d = b - a;
  final length2 = d.dx * d.dx + d.dy * d.dy;
  if (length2 == 0) return (p - a).distance;
  final t = (((p - a).dx * d.dx + (p - a).dy * d.dy) / length2).clamp(0.0, 1.0);
  return (p - (a + d * t)).distance;
}

/// How far [p] is from [line], and how wide the ink of [line] is there.
({double distance, double radius}) _on(List<InkPoint> line, Offset p) {
  var best = double.infinity, radius = 0.0;
  for (var i = 0; i + 1 < line.length; i++) {
    final a = line[i], b = line[i + 1];
    final distance = _distanceToSegment(p, a.at, b.at);
    if (distance < best) {
      best = distance;
      final length = (b.at - a.at).distance;
      final t = length == 0 ? 0.0 : ((p - a.at).distance / length).clamp(0, 1);
      radius = a.radius + (b.radius - a.radius) * t;
    }
  }
  return (distance: best, radius: radius);
}

double _lengthOf(List<InkPoint> line) {
  var total = 0.0;
  for (var i = 1; i < line.length; i++) {
    total += (line[i].at - line[i - 1].at).distance;
  }
  return total;
}

/// Checks that [piece] is ink of [original]: it lies on the line the
/// original was drawn along and is as wide there as the original was.
void _expectSameInk(Stroke piece, List<InkPoint> original) {
  final line = piece.inkLine();
  expect(line.length, greaterThanOrEqualTo(2));
  for (final point in line) {
    final there = _on(original, point.at);
    expect(there.distance, lessThan(1e-6), reason: 'the ink did not move');
    expect(
      point.radius,
      closeTo(there.radius, 1e-6),
      reason: 'the ink is as wide as it was',
    );
  }
}

void main() {
  group('The part of a line near a point', () {
    test('is found exactly', () {
      final covered = InkEraser.within(
        const Offset(0, 0),
        const Offset(100, 0),
        const Offset(50, 0),
        10,
      )!;
      expect(covered.$1, closeTo(0.4, 1e-9));
      expect(covered.$2, closeTo(0.6, 1e-9));
    });

    test('is cut off at the ends of the line', () {
      final start = InkEraser.within(
        const Offset(0, 0),
        const Offset(100, 0),
        const Offset(0, 0),
        10,
      )!;
      expect(start.$1, 0);
      expect(start.$2, closeTo(0.1, 1e-9));
      final all = InkEraser.within(
        const Offset(0, 0),
        const Offset(10, 0),
        const Offset(5, 0),
        50,
      )!;
      expect(all, (0.0, 1.0));
    });

    test('is nothing when the point is too far, or only just touches', () {
      const a = Offset(0, 0), b = Offset(100, 0);
      expect(InkEraser.within(a, b, const Offset(50, 11), 10), isNull);
      expect(InkEraser.within(a, b, const Offset(50, 10), 10), isNull);
      expect(InkEraser.within(a, b, const Offset(150, 0), 10), isNull);
      expect(InkEraser.within(a, b, const Offset(-20, 0), 10), isNull);
      // a line of no length
      expect(InkEraser.within(a, a, const Offset(3, 0), 10), (0.0, 1.0));
      expect(InkEraser.within(a, a, const Offset(30, 0), 10), isNull);
    });
  });

  group('The line a stroke is drawn along', () {
    test('has the width the pressure gives, and pointed ends', () {
      final stroke = _written();
      final line = stroke.inkLine();
      expect(line.length, greaterThan(50));
      // pointed where it begins and ends
      expect(line.first.radius, lessThan(0.1));
      expect(line.last.radius, lessThan(0.1));
      // and in between as wide as the pen was pressed: with a size of 4
      // and a thinning of 0.6, between 0.8 and 3.2 either side
      final middle = line.sublist(line.length ~/ 4, line.length * 3 ~/ 4);
      for (final point in middle) {
        expect(point.radius, inInclusiveRange(1.0, 3.2));
      }
      expect(
        middle.map((p) => p.radius).reduce(math.max) -
            middle.map((p) => p.radius).reduce(math.min),
        greaterThan(0.5),
        reason: 'the pressure shows',
      );
    });

    test('a stroke made from it is drawn along the same line, as wide', () {
      final stroke = _written();
      final line = stroke.inkLine();
      final copy = Stroke.fromInkLine(stroke, line);
      _expectSameInk(copy, line);
      expect(copy.color, stroke.color);
      expect(copy.toolId, stroke.toolId);
      expect(copy.options.size, stroke.options.size);
      // point for point, from end to end
      final again = copy.inkLine();
      expect(again.length, line.length);
      for (var i = 0; i < line.length; i++) {
        expect(again[i].at, line[i].at, reason: 'point $i');
        expect(again[i].radius, closeTo(line[i].radius, 1e-9));
      }
    });

    test('a stroke made from part of it starts and ends where the part does', () {
      // also when the part begins with points close together, which the
      // drawing would otherwise take for the pen settling and leave out
      final stroke = _written();
      final line = stroke.inkLine();
      final part = [
        (
          at: Offset.lerp(line[20].at, line[21].at, 0.8)!,
          radius: line[20].radius,
        ),
        ...line.sublist(21, 60),
      ];
      final piece = Stroke.fromInkLine(stroke, part, flatStart: true);
      final again = piece.inkLine();
      expect(again.length, part.length);
      for (var i = 0; i < part.length; i++) {
        expect(again[i].at, part[i].at, reason: 'point $i');
        expect(again[i].radius, closeTo(part[i].radius, 1e-9));
      }
      // and saying it again changes nothing
      final twice = Stroke.fromInkLine(piece, again, flatStart: true).inkLine();
      expect(twice.length, part.length);
    });

    test('of a circle and of a rectangle goes round them once', () {
      final circle = CircleStroke(
        color: Colors.black,
        pressureEnabled: false,
        options: StrokeOptions(size: 4),
        pageIndex: 0,
        page: _page,
        toolId: ToolId.fountainPen,
        center: const Offset(300, 300),
        radius: 100,
      );
      final round = circle.inkLine();
      expect(circle.inkLineIsClosed, isTrue);
      expect(round.first.at, round.last.at);
      for (final point in round) {
        expect((point.at - circle.center).distance, closeTo(100, 1e-9));
        expect(point.radius, 2);
      }
      expect(_lengthOf(round), closeTo(2 * math.pi * 100, 1));

      final rectangle = RectangleStroke(
        color: Colors.black,
        pressureEnabled: false,
        options: StrokeOptions(size: 4),
        pageIndex: 0,
        page: _page,
        toolId: ToolId.fountainPen,
        rect: const Rect.fromLTWH(100, 100, 300, 200),
      );
      final sides = rectangle.inkLine();
      expect(rectangle.inkLineIsClosed, isTrue);
      expect(sides.first.at, sides.last.at);
      expect(_lengthOf(sides), closeTo(1000, 1e-9));
      for (final corner in [
        const Offset(400, 100),
        const Offset(400, 300),
        const Offset(100, 300),
      ]) {
        expect(sides.any((p) => p.at == corner), isTrue, reason: '$corner');
      }
      // no step so long that a corner would be rounded far along a side
      for (var i = 1; i < sides.length; i++) {
        expect((sides[i].at - sides[i - 1].at).distance, lessThanOrEqualTo(2.4 + 1e-9));
      }
    });
  });

  group('Rubbing out part of a stroke', () {
    test('leaves the rest exactly where and as wide as it was', () {
      final stroke = _written();
      final original = stroke.inkLine();
      const centre = Offset(300, 300 - 6.5);
      const radius = 10.0;

      final pieces = InkEraser().cut(stroke, centre, radius)!;
      expect(pieces, hasLength(2));
      for (final piece in pieces) {
        _expectSameInk(piece, original);
      }

      // The left piece keeps the pointed start and is cut square where
      // the eraser went; the right piece the other way round.
      final left = pieces[0], right = pieces[1];
      expect(left.options.start.cap, isTrue);
      expect(left.options.end.cap, isFalse);
      expect(right.options.start.cap, isFalse);
      expect(right.options.end.cap, isTrue);
      expect(left.inkLine().first.at, original.first.at);
      expect(right.inkLine().last.at, original.last.at);
      expect(left.inkLine().first.radius, closeTo(original.first.radius, 1e-9));

      // The cut is at the edge of the eraser (and half the ink's width).
      for (final end in [left.inkLine().last, right.inkLine().first]) {
        expect(
          (end.at - centre).distance,
          closeTo(InkEraser.reachOf(radius, end.radius), 0.2),
        );
      }
      // Nothing is left under the eraser.
      for (final piece in pieces) {
        for (final point in piece.inkLine()) {
          expect((point.at - centre).distance, greaterThan(radius - 1e-6));
        }
      }
      // And only what was under it is gone.
      final lengthLeft = pieces.fold<double>(
        0,
        (sum, piece) => sum + _lengthOf(piece.inkLine()),
      );
      expect(_lengthOf(original) - lengthLeft, inInclusiveRange(20, 26));
    });

    test('at an end leaves one shorter stroke', () {
      final stroke = _written();
      final original = stroke.inkLine();
      final pieces = InkEraser().cut(stroke, original.first.at, 10)!;
      expect(pieces, hasLength(1));
      _expectSameInk(pieces.single, original);
      expect(pieces.single.options.start.cap, isFalse, reason: 'cut here');
      expect(pieces.single.inkLine().last.at, original.last.at);
      expect(
        _lengthOf(pieces.single.inkLine()),
        lessThan(_lengthOf(original) - 8),
      );
    });

    test('an end the eraser made stays square when the piece is cut again', () {
      final stroke = _written();
      final strokes = <Stroke>[stroke];
      final eraser = InkEraser()..begin(strokes);
      eraser.eraseAt(const Offset(200, 300 + 4.5), 8, strokes);
      expect(strokes, hasLength(2));
      eraser.eraseAt(const Offset(400, 300 + 8.4), 8, strokes);
      expect(strokes, hasLength(3));
      final middle = strokes[1];
      expect(middle.options.start.cap, isFalse, reason: 'cut by the first');
      expect(middle.options.end.cap, isFalse, reason: 'cut by the second');
      expect(strokes[0].options.start.cap, isTrue);
      expect(strokes[2].options.end.cap, isTrue);

      // and in a later drag, too
      final later = InkEraser()..begin(strokes);
      final at = middle.inkLine()[middle.inkLine().length ~/ 2].at;
      later.eraseAt(at, 6, strokes);
      expect(strokes, hasLength(4));
      expect(strokes[1].options.start.cap, isFalse);
      expect(strokes[2].options.end.cap, isFalse);
    });

    test('leaves a stroke it does not reach alone', () {
      final stroke = _written();
      final eraser = InkEraser();
      expect(eraser.cut(stroke, const Offset(300, 340), 10), isNull);
      expect(eraser.cut(stroke, const Offset(50, 300), 10), isNull);
      expect(eraser.cut(stroke, const Offset(900, 900), 50), isNull);
    });

    test('takes all of a stroke it covers', () {
      final dot = _pen(pointed: false)..addPoint(const Offset(200, 200), 0.5);
      expect(InkEraser().cut(dot, const Offset(203, 200), 10), isEmpty);
      expect(InkEraser().cut(dot, const Offset(230, 200), 10), isNull);

      final short = _written(from: 100, to: 112);
      expect(InkEraser().cut(short, const Offset(106, 300), 25), isEmpty);
    });

    test('drops crumbs too small to be of use', () {
      // a line of 26: the eraser leaves less than one unit at either end
      final stroke = _pen(pointed: false, streamline: 0);
      for (var x = 100.0; x <= 126; x += 2) {
        stroke.addPoint(Offset(x, 300), 0.5);
      }
      final pieces = InkEraser().cut(stroke, const Offset(113, 300), 11.8)!;
      expect(pieces, isEmpty);
    });

    test('broad ink is rubbed out when the eraser gets near its middle', () {
      // a highlighter line, 50 wide
      final broad = _pen(
        size: 50,
        thinning: 0,
        pointed: false,
        toolId: ToolId.highlighter,
      );
      for (var x = 100.0; x <= 500; x += 5) {
        broad.addPoint(Offset(x, 300), 0.5);
      }
      // the eraser's edge 15 into ink that is 25 to either side: not yet
      expect(InkEraser().cut(broad, const Offset(300, 280), 10), isNull);
      // its edge at the middle of the ink, and a little: rubbed out
      final pieces = InkEraser().cut(broad, const Offset(300, 289), 10)!;
      expect(pieces, hasLength(2));
      for (final piece in pieces) {
        expect(piece.toolId, ToolId.highlighter);
        expect(piece.inkLine().first.radius, 25);
      }
      // What goes is about as wide as the eraser, not as the ink: an
      // eraser 20 across, drawn through the middle, takes 25.
      final through = InkEraser().cut(broad, const Offset(300, 300), 10)!;
      final gap =
          through[1].inkLine().first.at.dx - through[0].inkLine().last.at.dx;
      expect(gap, closeTo(25, 0.01));
      expect(InkEraser.reachOf(10, 25), 12.5);
      expect(InkEraser.reachOf(10, 1), 10.5);
    });

    test('what is left can be saved and read back the same', () {
      final stroke = _written();
      final pieces = InkEraser().cut(stroke, const Offset(300, 293), 10)!;
      for (final piece in pieces) {
        final back = Stroke.fromJson(
          piece.toJson(),
          fileVersion: 19,
          pageIndex: 0,
          page: _page,
        );
        expect(back.options.start.cap, piece.options.start.cap);
        expect(back.options.end.cap, piece.options.end.cap);
        expect(back.options.thinning, 1);
        expect(back.options.streamline, 0);
        expect(back.options.simulatePressure, isFalse);
        final a = piece.inkLine(), b = back.inkLine();
        expect(b.length, a.length);
        for (var i = 0; i < a.length; i++) {
          // points are kept as 32 bit numbers in the file
          expect((a[i].at - b[i].at).distance, lessThan(1e-3));
          expect(b[i].radius, closeTo(a[i].radius, 1e-3));
        }
      }
    });
  });

  group('Rubbing out part of a shape', () {
    CircleStroke circle() => CircleStroke(
      color: Colors.black,
      pressureEnabled: false,
      options: StrokeOptions(size: 4, smoothing: 0, streamline: 0),
      pageIndex: 0,
      page: _page,
      toolId: ToolId.fountainPen,
      center: const Offset(300, 300),
      radius: 100,
    );

    test('a circle with a bite out of it is one arc', () {
      // at the very top, well away from where the circle begins and ends
      final pieces = InkEraser().cut(circle(), const Offset(300, 200), 20)!;
      expect(pieces, hasLength(1));
      final arc = pieces.single;
      expect(arc, isNot(isA<CircleStroke>()));
      expect(arc.options.start.cap, isFalse);
      expect(arc.options.end.cap, isFalse);
      final line = arc.inkLine();
      for (final point in line) {
        expect((point.at - const Offset(300, 300)).distance, closeTo(100, 0.05));
        expect((point.at - const Offset(300, 200)).distance, greaterThan(20));
      }
      // the bite is about 42 long (an eraser 40 across, and a little more)
      expect(2 * math.pi * 100 - _lengthOf(line), inInclusiveRange(40, 46));
    });

    test('a bite where the circle begins and ends is one arc too', () {
      final pieces = InkEraser().cut(circle(), const Offset(400, 300), 20)!;
      expect(pieces, hasLength(1));
      expect(pieces.single.options.start.cap, isFalse);
      expect(pieces.single.options.end.cap, isFalse);
    });

    test('two bites make two arcs', () {
      final eraser = InkEraser();
      final strokes = <Stroke>[circle()];
      eraser.begin(strokes);
      eraser.eraseAt(const Offset(300, 200), 20, strokes);
      eraser.eraseAt(const Offset(300, 400), 20, strokes);
      expect(strokes, hasLength(2));
    });

    test('a rectangle cut through one side stays in one piece', () {
      final rectangle = RectangleStroke(
        color: Colors.black,
        pressureEnabled: false,
        options: StrokeOptions(size: 4, smoothing: 0, streamline: 0),
        pageIndex: 0,
        page: _page,
        toolId: ToolId.fountainPen,
        rect: const Rect.fromLTWH(100, 100, 300, 200),
      );
      // the middle of the bottom side
      final pieces = InkEraser().cut(rectangle, const Offset(250, 300), 15)!;
      expect(pieces, hasLength(1));
      final line = pieces.single.inkLine();
      expect(_lengthOf(line), closeTo(1000 - 32, 1));
      // every corner is still there
      for (final corner in const [
        Offset(100, 100),
        Offset(400, 100),
        Offset(400, 300),
        Offset(100, 300),
      ]) {
        expect(_on(line, corner).distance, lessThan(1e-6), reason: '$corner');
      }
    });

    test('what is left of a straight line is straight lines', () {
      final line = _pen(pointed: false)
        ..setVertexHandles(const [Offset(100, 500), Offset(500, 500)]);
      final pieces = InkEraser().cut(line, const Offset(300, 500), 20)!;
      expect(pieces, hasLength(2));
      final left = pieces[0].vertexHandles!, right = pieces[1].vertexHandles!;
      expect(left, hasLength(2), reason: 'its ends can still be moved');
      expect(left[0], const Offset(100, 500));
      expect(left[1].dx, closeTo(279, 0.2));
      expect(left[1].dy, 500);
      expect(right[0].dx, closeTo(321, 0.2));
      expect(right[1], const Offset(500, 500));
      expect(pieces[0].options.end.cap, isFalse);
      expect(pieces[1].options.start.cap, isFalse);
      expect(pieces[0].options.size, line.options.size);
      // the pieces don't share their ends' settings with the line
      expect(line.options.start.cap, isTrue);
      expect(line.options.end.cap, isTrue);
    });

    test('a triangle loses a corner and keeps its sides', () {
      final triangle = _pen(pointed: false, streamline: 0)
        ..setVertexHandles(const [
          Offset(300, 100),
          Offset(500, 400),
          Offset(100, 400),
        ]);
      final original = triangle.inkLine();
      final pieces = InkEraser().cut(triangle, const Offset(500, 400), 30)!;
      expect(pieces, hasLength(1));
      _expectSameInk(pieces.single, original);
      final line = pieces.single.inkLine();
      expect(_on(line, const Offset(300, 100)).distance, lessThan(1e-6));
      expect(_on(line, const Offset(100, 400)).distance, lessThan(1e-6));
      expect(_on(line, const Offset(500, 400)).distance, greaterThan(25));
    });
  });

  group('A drag of the eraser', () {
    test('rubs out everything on its way, and nothing else', () {
      // ten lines one under the other, the eraser drawn straight down
      // through the middle of them
      final strokes = <Stroke>[
        for (var i = 0; i < 10; i++) _written(y: 200 + i * 40.0),
      ];
      final originals = [for (final stroke in strokes) stroke.inkLine()];
      final eraser = InkEraser()..begin(strokes);
      const radius = 10.0;
      expect(eraser.moveTo(const Offset(300, 150), radius, strokes), isFalse);
      // in a few long moves, as a fast hand makes them
      expect(eraser.moveTo(const Offset(300, 330), radius, strokes), isTrue);
      eraser.moveTo(const Offset(300, 620), radius, strokes);

      expect(strokes, hasLength(20));
      for (final (i, stroke) in strokes.indexed) {
        _expectSameInk(stroke, originals[i ~/ 2]);
        for (final point in stroke.inkLine()) {
          // nothing left in the strip the eraser was drawn along (bar
          // the hollows between one circle and the next, a hair deep)
          expect((point.at.dx - 300).abs(), greaterThan(radius * 0.95));
        }
      }

      final changes = eraser.finish();
      expect(changes, hasLength(10));
      for (final (i, change) in changes.indexed) {
        expect(change.after, [strokes[2 * i], strokes[2 * i + 1]]);
        expect(change.before.inkLine().length, originals[i].length);
      }
      // each knows the stroke that came after it
      expect(identical(changes[0].next, changes[1].before), isTrue);
      expect(changes.last.next, isNull);
    });

    test('keeps strokes in their place among the others', () {
      final under = _written(y: 300);
      final middle = _written(y: 310);
      final over = _written(y: 320);
      final far = _written(y: 900);
      final strokes = <Stroke>[under, middle, over, far];
      final eraser = InkEraser()..begin(strokes);
      // a small eraser, right on where the middle one starts
      eraser.moveTo(middle.inkLine().first.at, 3, strokes);
      // only the middle one was reached
      expect(strokes, hasLength(4));
      expect(identical(strokes[0], under), isTrue);
      expect(identical(strokes[2], over), isTrue);
      expect(identical(strokes[3], far), isTrue);
      expect(identical(strokes[1], middle), isFalse);

      final change = eraser.finish().single;
      expect(identical(change.before, middle), isTrue);
      expect(change.after, [strokes[1]]);
      expect(identical(change.next, over), isTrue);
    });

    test('going over the same stroke again and again is one change', () {
      final stroke = _written();
      final strokes = <Stroke>[stroke];
      final eraser = InkEraser()..begin(strokes);
      for (final x in [200.0, 300.0, 400.0]) {
        eraser.eraseAt(Offset(x, 300 + math.sin(x / 30) * 12), 8, strokes);
      }
      expect(strokes, hasLength(4));
      final change = eraser.finish().single;
      expect(identical(change.before, stroke), isTrue);
      expect(change.after, strokes);

      // and then rubbing all of it out leaves nothing of it
      final again = InkEraser()..begin(strokes);
      again.moveTo(const Offset(90, 300), 30, strokes);
      again.moveTo(const Offset(510, 300), 30, strokes);
      expect(strokes, isEmpty);
      final gone = again.finish();
      expect(gone, hasLength(4));
      expect(gone.every((change) => change.after.isEmpty), isTrue);
    });

    test('that touches nothing changes nothing', () {
      final strokes = <Stroke>[_written()];
      final eraser = InkEraser()..begin(strokes);
      expect(eraser.moveTo(const Offset(100, 900), 10, strokes), isFalse);
      expect(eraser.moveTo(const Offset(500, 900), 10, strokes), isFalse);
      expect(eraser.finish(), isEmpty);
      expect(strokes, hasLength(1));
    });
  });
}
