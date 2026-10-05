import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:saber/data/defter_strings.dart';
import 'package:saber/data/extensions/color_extensions.dart';
import 'package:sbn/canvas_background_pattern.dart';

class CanvasBackgroundPainter extends CustomPainter {
  const new({
    required this.invert,
    required this.backgroundColor,
    this.backgroundPattern = .none,
    required this.lineHeight,
    required this.lineThickness,
    this.primaryColor = Colors.blue,
    this.secondaryColor = Colors.red,
    this.preview = false,
    this.eInk = false,
    this.grain,
  });

  final bool invert;
  final Color backgroundColor;

  /// The pattern to use for the background. See [CanvasBackgroundPatterns].
  final CanvasBackgroundPattern backgroundPattern;

  /// The height between each line in the background pattern
  final int lineHeight;
  final int lineThickness;
  final Color primaryColor, secondaryColor;

  /// Whether to draw the background pattern in a preview mode (more opaque).
  final bool preview;

  /// Whether e-ink mode is on: [backgroundColor] is already the paper
  /// colour, and the pattern is drawn a little stronger to stay sharp.
  final bool eInk;

  /// The tile of paper grain drawn over the paper, if any. Fixed noise, so
  /// the grain never moves.
  final ui.Image? grain;

  @override
  void paint(Canvas canvas, Size size) {
    final canvasRect = Offset.zero & size;
    final paint = Paint();

    paint.color = backgroundColor.withInversion(invert);
    canvas.drawRect(canvasRect, paint);

    final grain = this.grain;
    if (grain != null) {
      canvas.drawRect(
        canvasRect,
        Paint()
          ..shader = ui.ImageShader(
            grain,
            TileMode.repeated,
            TileMode.repeated,
            Matrix4.identity().storage,
            filterQuality: FilterQuality.low,
          ),
      );
    }

    paint.strokeWidth = lineThickness.toDouble();

    if (backgroundPattern.requiresClipping) {
      canvas.save();
      canvas.clipRect(canvasRect);
    }

    final lineAlpha = preview ? 0.5 : (eInk ? 0.38 : 0.2);
    // On dark paper the guide lines are light, or they would not be seen.
    // (When the page is inverted for dark mode the usual colours stay.)
    final dark = !invert && backgroundColor.computeLuminance() < 0.25;
    final primaryColor = dark ? Colors.white : this.primaryColor;
    final secondaryColor = dark ? Colors.white70 : this.secondaryColor;
    for (final element in getPatternElements(
      pattern: backgroundPattern,
      size: size,
      lineHeight: lineHeight,
    )) {
      if (element.secondaryColor) {
        paint.color = secondaryColor.withValues(alpha: lineAlpha);
      } else {
        paint.color = primaryColor.withValues(alpha: lineAlpha);
      }

      if (element.radius != null) {
        final stroke = Paint()
          ..color = paint.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = paint.strokeWidth;
        canvas.drawOval(
          Rect.fromCenter(
            center: element.start,
            width: element.radius! * 2,
            height: (element.radiusY ?? element.radius!) * 2,
          ),
          stroke,
        );
      } else if (element.label != null) {
        final painter = TextPainter(
          text: TextSpan(
            text: element.label,
            style: TextStyle(
              color: primaryColor.withValues(alpha: lineAlpha * 2.2),
              fontSize: lineHeight * 0.55,
              fontWeight: FontWeight.w500,
            ),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 1,
          ellipsis: '…',
        )..layout(maxWidth: element.labelWidth ?? size.width);
        painter.paint(canvas, element.start);
        painter.dispose();
      } else if (element.isLine) {
        canvas.drawLine(element.start, element.end, paint);
      } else {
        canvas.drawCircle(element.start, paint.strokeWidth * 4 / 3, paint);
      }
    }

    if (backgroundPattern.requiresClipping) {
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(CanvasBackgroundPainter oldDelegate) =>
      kDebugMode ||
      oldDelegate.invert != invert ||
      oldDelegate.backgroundColor != backgroundColor ||
      oldDelegate.backgroundPattern != backgroundPattern ||
      oldDelegate.lineHeight != lineHeight ||
      oldDelegate.primaryColor != primaryColor ||
      oldDelegate.secondaryColor != secondaryColor ||
      oldDelegate.eInk != eInk ||
      oldDelegate.grain != grain;

  static Iterable<PatternElement> getPatternElements({
    required CanvasBackgroundPattern pattern,
    required Size size,
    required int lineHeight,
  }) sync* {
    switch (pattern) {
      case .none:
        return;
      case .collegeLtr:
      case .collegeRtl:
      case .lined:
        // horizontal lines
        for (double y = lineHeight * 2; y < size.height; y += lineHeight) {
          yield PatternElement(
            Offset(0, y),
            Offset(size.width, y),
            isLine: true,
          );
        }

        // vertical line
        if (pattern == .collegeLtr) {
          yield PatternElement(
            Offset(lineHeight * 2, 0),
            Offset(lineHeight * 2, size.height),
            isLine: true,
            secondaryColor: true,
          );
        } else if (pattern == .collegeRtl) {
          yield PatternElement(
            Offset(size.width - lineHeight * 2, 0),
            Offset(size.width - lineHeight * 2, size.height),
            isLine: true,
            secondaryColor: true,
          );
        }
      case .grid:
        for (double y = lineHeight * 2; y < size.height; y += lineHeight) {
          yield PatternElement(
            Offset(0, y),
            Offset(size.width, y),
            isLine: true,
          );
        }
        for (double x = 0; x < size.width; x += lineHeight) {
          yield PatternElement(
            Offset(x, lineHeight * 2),
            Offset(x, size.height),
            isLine: true,
          );
        }
      case .dots:
        for (double y = lineHeight * 2; y <= size.height; y += lineHeight) {
          for (double x = 0; x <= size.width; x += lineHeight) {
            yield PatternElement(Offset(x, y), Offset(x, y), isLine: false);
          }
        }
      case .staffs:
      case .tablature:
        final staffSpaces = pattern == .staffs ? 4 : 5;
        final staffHeight = lineHeight * staffSpaces;
        final staffSpacing = lineHeight * 3;

        for (
          double topOfStaff = staffSpacing.toDouble() - lineHeight;
          topOfStaff + staffHeight < size.height;
          topOfStaff += staffHeight + staffSpacing
        ) {
          // horizontal lines
          for (int line = 0; line < staffSpaces + 1; line++) {
            yield PatternElement(
              Offset(lineHeight.toDouble(), topOfStaff + lineHeight * line),
              Offset(size.width - lineHeight, topOfStaff + lineHeight * line),
              isLine: true,
            );
          }

          // vertical lines on either side
          yield PatternElement(
            Offset(lineHeight.toDouble(), topOfStaff),
            Offset(lineHeight.toDouble(), topOfStaff + staffHeight),
            isLine: true,
          );
          yield PatternElement(
            Offset(size.width - lineHeight, topOfStaff),
            Offset(size.width - lineHeight, topOfStaff + staffHeight),
            isLine: true,
          );
        }
      case .isometric:
      case .engineering:
      case .writing:
      case .todo:
      case .weekly:
      case .daily:
      case .monthly:
      case .meeting:
      case .storyboard:
      case .table:
      case .twoColumns:
      case .threeColumns:
      case .fourColumns:
      case .sideSplit:
      case .topBottom:
      case .verticalSplit:
      case .squareSplit:
      case .titled:
      case .bullets:
      case .numbered:
      case .legal:
      case .hexagon:
      case .diamond:
      case .yearly:
      case .classSchedule:
      case .habits:
      case .budget:
      case .meals:
      case .travel:
      case .project:
      case .water:
      case .reading:
      case .shopping:
      case .mindMap:
      case .conceptMap:
      case .flowchart:
      case .decisionTree:
      case .venn:
      case .cycle:
      case .pyramid:
      case .fishbone:
      case .swot:
      case .timeline:
      case .rings:
      case .wheel:
      case .wireframe:
      case .math:
      case .recipe:
      case .millimetre:
      case .circuit:
      case .pcb:
      case .blockDiagram:
      case .gantt:
      case .measureTable:
      case .orgChart:
      case .arrowDiagram:
      case .relationDiagram:
      case .academicPlanner:
      case .goalPlanner:
      case .financePlanner:
      case .moodTracker:
      case .studentPlanner:
      case .ledger:
        yield* _templateElements(pattern, size, lineHeight.toDouble());
      case .cornell:
        // half-width line for name field
        yield PatternElement(
          Offset(lineHeight.toDouble(), lineHeight * 2),
          Offset(size.width / 2 - lineHeight / 2, lineHeight * 2),
          isLine: true,
        );
        // half-width line for date field
        yield PatternElement(
          Offset(size.width / 2 + lineHeight / 2, lineHeight * 2),
          Offset(size.width - lineHeight, lineHeight * 2),
          isLine: true,
        );
        // full-width line for title field
        yield PatternElement(
          Offset(lineHeight.toDouble(), lineHeight * 3),
          Offset(size.width - lineHeight, lineHeight * 3),
          isLine: true,
        );

        // lines for main notes
        final left = size.width * 0.35; // 35% width reserved for cues column
        final bottom = size.height * 0.7; // 30% height reserved for summary
        for (double y = lineHeight * 5; y < bottom; y += lineHeight) {
          yield PatternElement(
            Offset(left, y),
            Offset(size.width - lineHeight, y),
            isLine: true,
          );
        }
    }
  }
}


/// Elements of the structured templates (planners, forms, special papers).
/// Everything stays inside [size] and leaves two line heights at the top.
Iterable<PatternElement> _templateElements(
  CanvasBackgroundPattern pattern,
  Size size,
  double l,
) sync* {
  final w = size.width;
  final h = size.height;
  final left = l;
  final right = w - l;
  final top = l * 2;
  final bottom = h - l;

  PatternElement hLine(double x1, double x2, double y, {bool strong = false}) =>
      PatternElement(Offset(x1, y), Offset(x2, y), secondaryColor: strong);
  PatternElement vLine(double x, double y1, double y2, {bool strong = false}) =>
      PatternElement(Offset(x, y1), Offset(x, y2), secondaryColor: strong);
  PatternElement text(String label, double x, double y, {double? width}) =>
      PatternElement(
        Offset(x, y),
        Offset(x, y),
        isLine: false,
        label: label,
        labelWidth: width,
      );
  Iterable<PatternElement> box(double x1, double y1, double x2, double y2) sync* {
    yield hLine(x1, x2, y1);
    yield hLine(x1, x2, y2);
    yield vLine(x1, y1, y2);
    yield vLine(x2, y1, y2);
  }

  switch (pattern) {
    case .isometric:
      {
      final dy = l * 0.866;
      var row = 0;
      for (var y = top; y <= h; y += dy, row++) {
        final shift = row.isOdd ? l / 2 : 0.0;
        for (var x = shift; x <= w; x += l) {
          yield PatternElement(Offset(x, y), Offset(x, y), isLine: false);
        }
      }
      }
    case .engineering:
      {
      var i = 0;
      for (var y = top; y <= h; y += l, i++) {
        yield hLine(0, w, y, strong: i % 5 == 0);
      }
      i = 0;
      for (var x = 0.0; x <= w; x += l, i++) {
        yield vLine(x, top, h, strong: i % 5 == 0);
      }
      }
    case .writing:
      {
      // three guide lines per group: top, middle (stronger), base
      for (var y = top; y + 2 * l < bottom; y += 4 * l) {
        yield hLine(left, right, y);
        yield hLine(left, right, y + l, strong: true);
        yield hLine(left, right, y + 2 * l);
      }
      }
    case .todo:
      {
      yield text(DefterStrings.labelTodo, left, top - l * 0.9, width: w / 2);
      yield hLine(left, right, top);
      final pitch = l * 1.5;
      final side = l * 0.8;
      for (var y = top + pitch; y <= bottom; y += pitch) {
        yield* box(left, y - side - l * 0.1, left + side, y - l * 0.1);
        yield hLine(left + side + l * 0.5, right, y);
      }
      }
    case .weekly:
      {
      final days = DefterStrings.weekDays;
      final midX = w / 2;
      final rows = 4;
      final cellH = (bottom - top) / rows;
      for (var r = 0; r <= rows; r++) {
        yield hLine(left, right, top + r * cellH);
      }
      yield vLine(left, top, bottom);
      yield vLine(midX, top, bottom);
      yield vLine(right, top, bottom);
      for (var i = 0; i < 8; i++) {
        final col = i < 4 ? 0 : 1;
        final r = i % 4;
        final x = col == 0 ? left : midX;
        final y = top + r * cellH;
        final label = i < 7 ? days[i] : DefterStrings.labelNotes;
        yield text(label, x + l * 0.4, y + l * 0.3, width: midX - left - l);
        // writing lines inside the cell
        for (var ly = y + l * 2; ly < y + cellH - l * 0.4; ly += l) {
          yield hLine(x + l * 0.4, (col == 0 ? midX : right) - l * 0.4, ly);
        }
      }
      }
    case .daily:
      {
      yield text(DefterStrings.labelDate, left, top - l * 1.1, width: w / 2);
      yield hLine(left, right, top);
      final mid = w * 0.58;
      const hours = 17; // 06:00 to 22:00
      final rowH = (bottom - top - l) / hours;
      yield text(DefterStrings.labelSchedule, left, top + l * 0.2, width: mid);
      yield text(DefterStrings.labelTodo, mid + l, top + l * 0.2, width: right - mid);
      final start = top + l * 1.5;
      for (var i = 0; i < hours; i++) {
        final y = start + i * rowH;
        yield text('${(6 + i).toString().padLeft(2, '0')}:00', left, y + rowH * 0.15, width: l * 3);
        yield hLine(left, mid, y + rowH);
      }
      yield vLine(mid + l * 0.5, top, bottom);
      final side = l * 0.7;
      for (var y = start + l; y < bottom - l; y += l * 1.6) {
        yield* box(mid + l, y, mid + l + side, y + side);
        yield hLine(mid + l * 2.2, right, y + side);
      }
      }
    case .monthly:
      {
      yield text(DefterStrings.labelMonth, left, top - l * 1.1, width: w / 2);
      yield hLine(left * 3, right, top - l * 0.2);
      final gridTop = top + l * 1.2;
      final cellW = (right - left) / 7;
      final cellH = (bottom - gridTop) / 6;
      final short = DefterStrings.weekDaysShort;
      for (var c = 0; c < 7; c++) {
        yield text(short[c], left + c * cellW + l * 0.3, top + l * 0.3, width: cellW);
      }
      for (var r = 0; r <= 6; r++) {
        yield hLine(left, right, gridTop + r * cellH);
      }
      for (var c = 0; c <= 7; c++) {
        yield vLine(left + c * cellW, gridTop, gridTop + 6 * cellH);
      }
      }
    case .meeting:
      {
      yield text(DefterStrings.labelTitle, left, top - l * 0.9, width: w / 2);
      yield hLine(left, right, top);
      yield text(DefterStrings.labelDate, left, top + l * 0.4, width: w / 2);
      yield hLine(left, w * 0.5 - l / 2, top + l * 2);
      yield text(DefterStrings.labelAttendees, w * 0.5 + l / 2, top + l * 0.4, width: w / 2);
      yield hLine(w * 0.5 + l / 2, right, top + l * 2);
      yield hLine(w * 0.5 + l / 2, right, top + l * 3);
      var y = top + l * 4.5;
      yield text(DefterStrings.labelAgenda, left, y, width: w / 2);
      for (var i = 1; i <= 4; i++) {
        yield hLine(left, right, y + l * 1.6 * i);
      }
      y = y + l * 8;
      yield text(DefterStrings.labelNotes, left, y, width: w / 2);
      final notesEnd = h * 0.78;
      for (var ly = y + l * 2; ly < notesEnd; ly += l) {
        yield hLine(left, right, ly);
      }
      yield text(DefterStrings.labelActions, left, notesEnd + l * 0.5, width: w / 2);
      final side = l * 0.7;
      for (var ay = notesEnd + l * 2.4; ay < bottom; ay += l * 1.5) {
        yield* box(left, ay - side, left + side, ay);
        yield hLine(left + side + l * 0.5, right, ay);
      }
      }
    case .storyboard:
      {
      final gap = l;
      final frameW = (right - left - gap) / 2;
      final rows = 3;
      final blockH = (bottom - top - gap * (rows - 1)) / rows;
      final frameH = blockH - l * 2.6;
      for (var r = 0; r < rows; r++) {
        for (var c = 0; c < 2; c++) {
          final x = left + c * (frameW + gap);
          final y = top + r * (blockH + gap);
          yield* box(x, y, x + frameW, y + frameH);
          yield hLine(x, x + frameW, y + frameH + l * 1.2);
          yield hLine(x, x + frameW, y + frameH + l * 2.2);
        }
      }
      }
    case .table:
      {
        const cols = 4;
        final rowH = l * 2;
        final colW = (right - left) / cols;
        final rowsEnd = top + ((bottom - top) / rowH).floor() * rowH;
        for (var y = top; y <= rowsEnd; y += rowH) {
          yield hLine(left, right, y, strong: y == top || y == top + rowH);
        }
        for (var c = 0; c <= cols; c++) {
          yield vLine(left + c * colW, top, rowsEnd);
        }
      }
    case .twoColumns:
    case .threeColumns:
    case .fourColumns:
      {
        final n = pattern == .twoColumns ? 2 : (pattern == .threeColumns ? 3 : 4);
        final colW = (right - left) / n;
        for (var c = 0; c < n; c++) {
          final x1 = left + c * colW + (c == 0 ? 0 : l * 0.3);
          final x2 = left + (c + 1) * colW - (c == n - 1 ? 0 : l * 0.3);
          for (var y = top; y <= bottom; y += l) {
            yield hLine(x1, x2, y);
          }
        }
        for (var c = 1; c < n; c++) {
          yield vLine(left + c * colW, top, bottom, strong: true);
        }
      }
    case .sideSplit:
      {
        final x = w * 0.3;
        yield vLine(x, top, bottom, strong: true);
        for (var y = top; y <= bottom; y += l) {
          yield hLine(x + l * 0.5, right, y);
        }
      }
    case .topBottom:
      {
        final mid = (top + bottom) / 2;
        yield* box(left, top, right, mid - l * 0.5);
        yield* box(left, mid + l * 0.5, right, bottom);
      }
    case .verticalSplit:
      {
        final mid = w / 2;
        for (var y = top; y <= bottom; y += l) {
          yield hLine(left, mid - l * 0.4, y);
          yield hLine(mid + l * 0.4, right, y);
        }
        yield vLine(mid, top, bottom, strong: true);
      }
    case .squareSplit:
      {
        final gap = l * 0.8;
        final mx = w / 2;
        final my = (top + bottom) / 2;
        yield* box(left, top, mx - gap / 2, my - gap / 2);
        yield* box(mx + gap / 2, top, right, my - gap / 2);
        yield* box(left, my + gap / 2, mx - gap / 2, bottom);
        yield* box(mx + gap / 2, my + gap / 2, right, bottom);
      }
    case .titled:
      {
        yield* box(left, top, right, top + l * 2.5);
        for (var y = top + l * 4.5; y <= bottom; y += l) {
          yield hLine(left, right, y);
        }
      }
    case .bullets:
      {
        for (var y = top + l; y <= bottom; y += l * 1.8) {
          yield PatternElement(
            Offset(left + l * 0.5, y - l * 0.35),
            Offset(left + l * 0.5, y - l * 0.35),
            isLine: false,
          );
          yield hLine(left + l * 1.2, right, y);
        }
      }
    case .numbered:
      {
        var n = 1;
        for (var y = top + l; y <= bottom; y += l * 1.8, n++) {
          yield text('$n.', left, y - l * 0.95, width: l * 2);
          yield hLine(left + l * 2, right, y);
        }
      }
    case .legal:
      {
        for (var y = top; y <= bottom; y += l) {
          yield hLine(0, w, y);
        }
        yield vLine(l * 3, 0, h, strong: true);
        yield vLine(l * 3.25, 0, h, strong: true);
      }
    case .hexagon:
      {
        final s = l * 0.9;
        final dx = s * 0.8660254;
        var j = 0;
        for (var y = top; y + 1.5 * s <= h; y += 1.5 * s, j++) {
          final phase = j % 2;
          final n = (w / dx).floor();
          for (var i = 0; i < n; i++) {
            final y1 = y + ((i + phase) % 2 == 0 ? 0 : s / 2);
            final y2 = y + ((i + 1 + phase) % 2 == 0 ? 0 : s / 2);
            yield PatternElement(Offset(i * dx, y1), Offset((i + 1) * dx, y2));
          }
          for (var i = 0; i <= n; i++) {
            if ((i + phase) % 2 == 1) {
              yield vLine(i * dx, y + s / 2, y + 1.5 * s);
            }
          }
        }
      }
    case .diamond:
      {
        final pitch = l * 1.4;
        // lines going down to the right: y = top + (x - c)
        for (var c = -(h - top); c <= w; c += pitch) {
          final x1 = math.max(0.0, c);
          final x2 = math.min(w, c + (h - top));
          if (x2 <= x1) continue;
          yield PatternElement(
            Offset(x1, top + (x1 - c)),
            Offset(x2, top + (x2 - c)),
          );
        }
        // lines going up to the right: y = h - (x - c)
        for (var c = -(h - top); c <= w; c += pitch) {
          final x1 = math.max(0.0, c);
          final x2 = math.min(w, c + (h - top));
          if (x2 <= x1) continue;
          yield PatternElement(
            Offset(x1, h - (x1 - c)),
            Offset(x2, h - (x2 - c)),
          );
        }
      }
    case .yearly:
      {
        yield text(DefterStrings.labelYear, left, top - l * 0.9, width: w / 2);
        yield hLine(left, right, top);
        final months = DefterStrings.months;
        const cols = 3;
        const rows = 4;
        final gap = l * 0.6;
        final cw = (right - left - gap * (cols - 1)) / cols;
        final ch = (bottom - top - l - gap * (rows - 1)) / rows;
        for (var i = 0; i < 12; i++) {
          final x = left + (i % cols) * (cw + gap);
          final y = top + l + (i ~/ cols) * (ch + gap);
          yield* box(x, y, x + cw, y + ch);
          yield text(months[i], x + l * 0.3, y + l * 0.2, width: cw - l * 0.6);
          yield hLine(x, x + cw, y + l * 1.4);
        }
      }
    case .classSchedule:
      {
        final days = DefterStrings.weekDaysShort.sublist(0, 5);
        final firstW = l * 2.5;
        final colW = (right - left - firstW) / 5;
        final rowH = (bottom - top) / 11;
        for (var r = 0; r <= 11; r++) {
          yield hLine(left, right, top + r * rowH, strong: r == 1);
        }
        yield vLine(left, top, bottom);
        yield vLine(left + firstW, top, bottom, strong: true);
        for (var c = 1; c <= 5; c++) {
          yield vLine(left + firstW + c * colW, top, bottom);
        }
        for (var c = 0; c < 5; c++) {
          yield text(days[c], left + firstW + c * colW + l * 0.3, top + rowH * 0.2, width: colW);
        }
      }
    case .habits:
      {
        yield text(DefterStrings.labelHabit, left, top - l * 0.9, width: w / 3);
        final nameW = (right - left) * 0.3;
        final dayW = (right - left - nameW) / 31;
        const rows = 14;
        final rowH = (bottom - top - l * 1.4) / rows;
        yield hLine(left, right, top);
        for (var d = 1; d <= 31; d++) {
          if (d == 1 || d % 5 == 0) {
            yield text('$d', left + nameW + (d - 1) * dayW, top - l * 0.9, width: dayW * 2);
          }
        }
        for (var r = 0; r < rows; r++) {
          final y = top + l * 0.6 + r * rowH;
          yield hLine(left, left + nameW - l * 0.3, y + rowH * 0.8);
          for (var d = 0; d < 31; d++) {
            yield PatternElement(
              Offset(left + nameW + d * dayW + dayW / 2, y + rowH * 0.45),
              Offset(left + nameW + d * dayW + dayW / 2, y + rowH * 0.45),
              isLine: false,
              radius: dayW * 0.32,
            );
          }
        }
      }
    case .budget:
      {
        final amountX = right - (right - left) * 0.25;
        yield text(DefterStrings.labelDate, left, top - l * 0.9, width: w / 3);
        yield hLine(left, right, top);
        var y = top + l * 0.8;
        yield text(DefterStrings.labelIncome, left, y, width: w / 3);
        yield text(DefterStrings.labelAmount, amountX + l * 0.3, y, width: w / 4);
        for (var i = 1; i <= 5; i++) {
          yield hLine(left, right, y + l * 1.6 * i);
        }
        yield vLine(amountX, y + l * 0.2, y + l * 8);
        y = y + l * 10;
        yield text(DefterStrings.labelExpenses, left, y, width: w / 3);
        yield text(DefterStrings.labelAmount, amountX + l * 0.3, y, width: w / 4);
        var n = 1;
        for (; y + l * 1.6 * n < bottom - l * 3; n++) {
          yield hLine(left, right, y + l * 1.6 * n);
        }
        yield vLine(amountX, y + l * 0.2, y + l * 1.6 * (n - 1));
        final totalY = bottom - l * 1.2;
        yield text(DefterStrings.labelTotal, left, totalY - l * 1.1, width: w / 3);
        yield hLine(left, right, totalY, strong: true);
      }
    case .meals:
      {
        final names = DefterStrings.meals3;
        final days = DefterStrings.weekDays;
        final firstW = l * 4.5;
        final colW = (right - left - firstW) / 3;
        final rowH = (bottom - top) / 8;
        for (var r = 0; r <= 8; r++) {
          yield hLine(left, right, top + r * rowH, strong: r == 1);
        }
        yield vLine(left, top, bottom);
        yield vLine(left + firstW, top, bottom, strong: true);
        for (var c = 1; c <= 3; c++) {
          yield vLine(left + firstW + c * colW, top, bottom);
        }
        for (var c = 0; c < 3; c++) {
          yield text(names[c], left + firstW + c * colW + l * 0.3, top + rowH * 0.25, width: colW - l * 0.4);
        }
        for (var r = 0; r < 7; r++) {
          yield text(days[r], left + l * 0.3, top + rowH * (r + 1) + rowH * 0.25, width: firstW - l * 0.4);
        }
      }
    case .travel:
      {
        final fields = [
          DefterStrings.labelDestination,
          DefterStrings.labelDates,
          DefterStrings.labelStay,
          DefterStrings.labelTransport,
        ];
        final mid = w * 0.55;
        var y = top;
        for (final f in fields) {
          yield text(f, left, y, width: mid - left);
          yield hLine(left, mid - l, y + l * 2.2);
          y += l * 3.2;
        }
        yield vLine(mid, top, y, strong: true);
        yield text(DefterStrings.labelPacking, mid + l, top, width: right - mid - l);
        final side = l * 0.7;
        for (var cy = top + l * 2.2; cy < y; cy += l * 1.5) {
          yield* box(mid + l, cy - side, mid + l + side, cy);
          yield hLine(mid + l * 2.2, right, cy);
        }
        yield text(DefterStrings.labelNotes, left, y + l * 0.2, width: w / 2);
        for (var ly = y + l * 2.6; ly < bottom; ly += l * 1.2) {
          yield hLine(left, right, ly);
        }
      }
    case .project:
      {
        yield text(DefterStrings.labelGoal, left, top - l * 0.9, width: w / 2);
        yield hLine(left, right, top);
        yield hLine(left, right, top + l * 1.6);
        final heads = [
          DefterStrings.labelTask,
          DefterStrings.labelOwner,
          DefterStrings.labelDue,
          DefterStrings.labelStatus,
        ];
        final xs = [left, left + (right - left) * 0.5, left + (right - left) * 0.7, left + (right - left) * 0.85, right];
        final tableTop = top + l * 3;
        final rowH = l * 1.8;
        final rowsEnd = tableTop + ((bottom - tableTop) / rowH).floor() * rowH;
        for (var c = 0; c < 4; c++) {
          yield text(heads[c], xs[c] + l * 0.3, tableTop + rowH * 0.2, width: xs[c + 1] - xs[c]);
        }
        for (var y = tableTop; y <= rowsEnd; y += rowH) {
          yield hLine(left, right, y, strong: y == tableTop || y == tableTop + rowH);
        }
        for (final x in xs) {
          yield vLine(x, tableTop, rowsEnd);
        }
      }
    case .water:
      {
        yield text(DefterStrings.labelWater, left, top - l * 0.9, width: w / 2);
        yield hLine(left, right, top);
        final days = DefterStrings.weekDays;
        final rowH = (bottom - top) / 7;
        final nameW = l * 6;
        const glasses = 8;
        final gw = (right - left - nameW) / glasses;
        for (var r = 0; r < 7; r++) {
          final y = top + r * rowH;
          yield text(days[r], left, y + rowH * 0.3, width: nameW);
          for (var g = 0; g < glasses; g++) {
            yield PatternElement(
              Offset(left + nameW + g * gw + gw / 2, y + rowH * 0.5),
              Offset(left + nameW + g * gw + gw / 2, y + rowH * 0.5),
              isLine: false,
              radius: math.min(gw, rowH) * 0.3,
            );
          }
          yield hLine(left, right, y + rowH);
        }
      }
    case .reading:
      {
        yield text(DefterStrings.labelBook, left, top - l * 0.9, width: w / 2);
        yield hLine(left, right, top);
        yield text(DefterStrings.labelAuthor, left, top + l * 0.3, width: w / 2);
        yield hLine(left, right, top + l * 2.4);
        yield text(DefterStrings.labelDates, left, top + l * 2.7, width: w / 2);
        yield hLine(left, w / 2 - l, top + l * 4.8);
        yield text(DefterStrings.labelRating, w / 2 + l, top + l * 2.7, width: w / 4);
        for (var i = 0; i < 5; i++) {
          yield PatternElement(
            Offset(w / 2 + l * 1.6 + i * l * 1.6, top + l * 4.2),
            Offset(w / 2 + l * 1.6 + i * l * 1.6, top + l * 4.2),
            isLine: false,
            radius: l * 0.5,
          );
        }
        var y = top + l * 6;
        yield text(DefterStrings.labelSummary, left, y, width: w / 2);
        for (var i = 1; i <= 6; i++) {
          yield hLine(left, right, y + l * 1.4 * i);
        }
        y = y + l * 10;
        yield text(DefterStrings.labelQuotes, left, y, width: w / 2);
        for (var ly = y + l * 2.4; ly < bottom; ly += l * 1.4) {
          yield hLine(left, right, ly);
        }
      }
    case .shopping:
      {
        yield text(DefterStrings.labelShopping, left, top - l * 0.9, width: w / 2);
        yield hLine(left, right, top);
        final mid = w / 2;
        final side = l * 0.7;
        for (final x0 in [left, mid + l * 0.3]) {
          final x1 = x0 == left ? mid - l * 0.3 : right;
          for (var y = top + l * 1.5; y < bottom; y += l * 1.5) {
            yield* box(x0, y - side, x0 + side, y);
            yield hLine(x0 + side + l * 0.4, x1, y);
          }
        }
        yield vLine(mid, top + l * 0.4, bottom, strong: true);
      }
    case .mindMap:
      {
        final c = Offset(w / 2, h / 2);
        final rx = w * 0.17;
        final ry = h * 0.07;
        yield PatternElement(c, c, isLine: false, radius: rx, radiusY: ry);
        for (var i = 0; i < 6; i++) {
          final a = -math.pi / 2 + i * math.pi / 3;
          final sx = c.dx + math.cos(a) * w * 0.34;
          final sy = c.dy + math.sin(a) * h * 0.3;
          final s2 = Offset(sx, sy);
          yield PatternElement(s2, s2, isLine: false, radius: w * 0.11, radiusY: h * 0.05);
          final d = s2 - c;
          yield PatternElement(c + d * 0.42, c + d * 0.7);
        }
      }
    case .conceptMap:
      {
        final pts = [
          Offset(w * 0.5, h * 0.12),
          Offset(w * 0.22, h * 0.34),
          Offset(w * 0.78, h * 0.34),
          Offset(w * 0.3, h * 0.62),
          Offset(w * 0.7, h * 0.62),
          Offset(w * 0.5, h * 0.84),
        ];
        for (final p in pts) {
          yield PatternElement(p, p, isLine: false, radius: w * 0.13, radiusY: h * 0.045);
        }
        const links = [[0, 1], [0, 2], [1, 3], [2, 4], [3, 5], [4, 5], [1, 2]];
        for (final k in links) {
          final a = pts[k[0]];
          final b = pts[k[1]];
          final d = b - a;
          final len = d.distance;
          final dir = d / len;
          final start = a + dir * (w * 0.1);
          final end = b - dir * (w * 0.1);
          yield PatternElement(start, end);
        }
      }
    case .flowchart:
      {
        final cx = w / 2;
        final bw = w * 0.3;
        final bh = h * 0.06;
        final ys = [h * 0.1, h * 0.26, h * 0.42, h * 0.62, h * 0.84];
        yield* box(cx - bw / 2, ys[0], cx + bw / 2, ys[0] + bh);
        yield* box(cx - bw / 2, ys[1], cx + bw / 2, ys[1] + bh);
        // decision diamond
        final dm = Offset(cx, ys[2] + bh);
        yield PatternElement(Offset(cx, ys[2] - bh * 0.6), Offset(cx + bw * 0.7, dm.dy));
        yield PatternElement(Offset(cx + bw * 0.7, dm.dy), Offset(cx, ys[2] + bh * 2.6));
        yield PatternElement(Offset(cx, ys[2] + bh * 2.6), Offset(cx - bw * 0.7, dm.dy));
        yield PatternElement(Offset(cx - bw * 0.7, dm.dy), Offset(cx, ys[2] - bh * 0.6));
        yield* box(cx - bw / 2, ys[4], cx + bw / 2, ys[4] + bh);
        yield* box(w * 0.74, ys[3], w * 0.96, ys[3] + bh);
        yield* box(w * 0.04, ys[3], w * 0.26, ys[3] + bh);
        // arrows
        yield PatternElement(Offset(cx, ys[0] + bh), Offset(cx, ys[1]));
        yield PatternElement(Offset(cx, ys[1] + bh), Offset(cx, ys[2] - bh * 0.6));
        yield PatternElement(Offset(cx, ys[2] + bh * 2.6), Offset(cx, ys[4]));
        yield PatternElement(Offset(cx + bw * 0.7, dm.dy), Offset(w * 0.85, dm.dy));
        yield PatternElement(Offset(w * 0.85, dm.dy), Offset(w * 0.85, ys[3]));
        yield PatternElement(Offset(cx - bw * 0.7, dm.dy), Offset(w * 0.15, dm.dy));
        yield PatternElement(Offset(w * 0.15, dm.dy), Offset(w * 0.15, ys[3]));
      }
    case .decisionTree:
      {
        final bw = w * 0.2;
        final bh = h * 0.045;
        Iterable<PatternElement> node(double cx, double y) => box(cx - bw / 2, y, cx + bw / 2, y + bh);
        yield* node(w * 0.5, h * 0.1);
        for (final x in [w * 0.25, w * 0.75]) {
          yield* node(x, h * 0.35);
          yield PatternElement(Offset(w * 0.5, h * 0.1 + bh), Offset(x, h * 0.35));
          for (final dx in [-w * 0.12, w * 0.12]) {
            yield* node(x + dx, h * 0.62);
            yield PatternElement(Offset(x, h * 0.35 + bh), Offset(x + dx, h * 0.62));
            for (final dx2 in [-w * 0.055, w * 0.055]) {
              yield PatternElement(
                Offset(x + dx, h * 0.62 + bh),
                Offset(x + dx + dx2, h * 0.84),
              );
            }
          }
        }
      }
    case .venn:
      {
        final r = w * 0.24;
        final c = Offset(w / 2, h / 2);
        for (final o in [
          Offset(-r * 0.6, -r * 0.45),
          Offset(r * 0.6, -r * 0.45),
          Offset(0, r * 0.65),
        ]) {
          yield PatternElement(c + o, c + o, isLine: false, radius: r);
        }
      }
    case .cycle:
      {
        final c = Offset(w / 2, h / 2);
        final rr = w * 0.3;
        const n = 5;
        final pts = [
          for (var i = 0; i < n; i++)
            c + Offset(math.cos(-math.pi / 2 + i * 2 * math.pi / n), math.sin(-math.pi / 2 + i * 2 * math.pi / n)) * rr,
        ];
        for (var i = 0; i < n; i++) {
          yield PatternElement(pts[i], pts[i], isLine: false, radius: w * 0.09);
          final a = pts[i];
          final b = pts[(i + 1) % n];
          final d = (b - a) / (b - a).distance;
          yield PatternElement(a + d * (w * 0.1), b - d * (w * 0.1));
        }
        yield PatternElement(c, c, isLine: false, radius: w * 0.1);
      }
    case .pyramid:
      {
        final topP = Offset(w / 2, h * 0.14);
        final bl = Offset(w * 0.12, h * 0.8);
        final br = Offset(w * 0.88, h * 0.8);
        yield PatternElement(topP, bl);
        yield PatternElement(topP, br);
        yield hLine(bl.dx, br.dx, bl.dy);
        for (var i = 1; i < 5; i++) {
          final t = i / 5;
          final y = topP.dy + (bl.dy - topP.dy) * t;
          final half = (w / 2 - bl.dx) * t;
          yield hLine(w / 2 - half, w / 2 + half, y);
        }
      }
    case .fishbone:
      {
        final y = h / 2;
        yield hLine(w * 0.06, w * 0.8, y, strong: true);
        yield* box(w * 0.8, y - h * 0.04, w * 0.96, y + h * 0.04);
        for (final x in [w * 0.25, w * 0.45, w * 0.65]) {
          yield PatternElement(Offset(x - w * 0.1, y - h * 0.22), Offset(x, y));
          yield PatternElement(Offset(x - w * 0.1, y + h * 0.22), Offset(x, y));
          yield hLine(x - w * 0.2, x - w * 0.1, y - h * 0.22);
          yield hLine(x - w * 0.2, x - w * 0.1, y + h * 0.22);
        }
      }
    case .swot:
      {
        final names = DefterStrings.swotNames;
        final gap = l * 0.8;
        final mx = w / 2;
        final my = (top + bottom) / 2;
        final boxes = [
          [left, top, mx - gap / 2, my - gap / 2],
          [mx + gap / 2, top, right, my - gap / 2],
          [left, my + gap / 2, mx - gap / 2, bottom],
          [mx + gap / 2, my + gap / 2, right, bottom],
        ];
        for (var i = 0; i < 4; i++) {
          final b = boxes[i];
          yield* box(b[0], b[1], b[2], b[3]);
          yield text(names[i], b[0] + l * 0.4, b[1] + l * 0.3, width: b[2] - b[0] - l * 0.8);
          yield hLine(b[0], b[2], b[1] + l * 1.5);
        }
      }
    case .timeline:
      {
        final y = h / 2;
        yield hLine(left, right, y, strong: true);
        const n = 6;
        final step = (right - left) / n;
        for (var i = 0; i < n; i++) {
          final x = left + step * (i + 0.5);
          final up = i.isEven;
          final by = up ? y - h * 0.2 : y + h * 0.1;
          yield PatternElement(Offset(x, y), Offset(x, up ? by + h * 0.1 : by));
          yield* box(x - step * 0.4, by, x + step * 0.4, by + h * 0.1);
          yield PatternElement(Offset(x, y), Offset(x, y), isLine: false, radius: l * 0.3);
        }
      }
    case .rings:
      {
        final c = Offset(w / 2, h / 2);
        for (var i = 1; i <= 4; i++) {
          yield PatternElement(c, c, isLine: false, radius: w * 0.1 * i);
        }
      }
    case .wheel:
      {
        final c = Offset(w / 2, h / 2);
        final r = w * 0.42;
        yield PatternElement(c, c, isLine: false, radius: r);
        yield PatternElement(c, c, isLine: false, radius: r * 0.25);
        for (var i = 0; i < 8; i++) {
          final a = i * math.pi / 4;
          final d = Offset(math.cos(a), math.sin(a));
          yield PatternElement(c + d * (r * 0.25), c + d * r);
        }
      }
    case .wireframe:
      {
        final fw = w * 0.26;
        final fh = h * 0.42;
        for (var r = 0; r < 2; r++) {
          for (var c = 0; c < 3; c++) {
            final x = left + c * ((right - left - fw) / 2);
            final y = top + r * (fh + h * 0.06);
            yield* box(x, y, x + fw, y + fh);
            yield hLine(x, x + fw, y + fh * 0.07);
            yield hLine(x, x + fw, y + fh * 0.93);
          }
        }
      }
    case .math:
      {
        for (var y = top; y <= bottom; y += l) {
          yield hLine(left, right, y);
        }
        for (var x = left; x <= right; x += l) {
          yield vLine(x, top, bottom);
        }
        final cx = left + ((right - left) / 2 / l).round() * l;
        final cy = top + ((bottom - top) / 2 / l).round() * l;
        yield vLine(cx, top, bottom, strong: true);
        yield hLine(left, right, cy, strong: true);
      }
    case .recipe:
      {
        yield text(DefterStrings.labelRecipe, left, top - l * 0.9, width: w / 2);
        yield hLine(left, right, top);
        yield text(DefterStrings.labelTime, left, top + l * 0.4, width: w / 3);
        yield hLine(left, w / 2 - l, top + l * 2.4);
        yield text(DefterStrings.labelServings, w / 2 + l, top + l * 0.4, width: w / 3);
        yield hLine(w / 2 + l, right, top + l * 2.4);
        final mid = w * 0.38;
        final y0 = top + l * 4;
        yield text(DefterStrings.labelIngredients, left, y0, width: mid - left);
        yield text(DefterStrings.labelSteps, mid + l, y0, width: right - mid - l);
        yield vLine(mid, y0, bottom, strong: true);
        for (var y = y0 + l * 2; y < bottom; y += l * 1.6) {
          yield PatternElement(
            Offset(left + l * 0.4, y - l * 0.35),
            Offset(left + l * 0.4, y - l * 0.35),
            isLine: false,
          );
          yield hLine(left + l, mid - l * 0.4, y);
          yield hLine(mid + l, right, y);
        }
      }
    case .millimetre:
      {
        // 2 mm squares (a page unit is 0.21 mm), every fifth line stronger.
        const step = 2 / 0.21;
        var i = 0;
        for (var y = 0.0; y <= h; y += step, i++) {
          yield hLine(0, w, y, strong: i % 5 == 0);
        }
        i = 0;
        for (var x = 0.0; x <= w; x += step, i++) {
          yield vLine(x, 0, h, strong: i % 5 == 0);
        }
      }
    case .circuit:
      {
        // never so fine that the page turns grey
        final step = math.max(l / 2, 12.0);
        final blockW = l * 9, blockH = l * 3;
        final bx = right - blockW, by = bottom - blockH;
        for (var y = top; y <= bottom; y += step) {
          for (var x = left; x <= right; x += step) {
            // keep the title block clear
            if (x > bx - 1 && y > by - 1) continue;
            yield PatternElement(Offset(x, y), Offset(x, y), isLine: false);
          }
        }
        yield* box(left, top, right, bottom);
        yield* box(bx, by, right, bottom);
        yield hLine(bx, right, by + l);
        yield hLine(bx, right, by + 2 * l);
        yield vLine(bx + blockW / 2, by + l, bottom);
        yield text(DefterStrings.labelTitle, bx + l * 0.2, by + l * 0.2, width: blockW - l);
        yield text(DefterStrings.labelDrawnBy, bx + l * 0.2, by + l * 1.2, width: blockW / 2 - l * 0.4);
        yield text(DefterStrings.labelDate, bx + blockW / 2 + l * 0.2, by + l * 1.2, width: blockW / 2 - l * 0.4);
        yield text(DefterStrings.labelNo, bx + l * 0.2, by + l * 2.2, width: blockW / 2 - l * 0.4);
        yield text(DefterStrings.labelSheet, bx + blockW / 2 + l * 0.2, by + l * 2.2, width: blockW / 2 - l * 0.4);
      }
    case .pcb:
      {
        // Pads 5.08 mm apart (twice the 2.54 mm pitch), ruler ticks on
        // the frame every fifth pad.
        const step = 5.08 / 0.21;
        // room for the frame and its ticks, whatever the line height
        final m = math.max(l, 30.0) + step / 2;
        final cols = ((w - 2 * m) / step).floor();
        final rows = ((h - 2 * m) / step).floor();
        final x0 = (w - cols * step) / 2;
        final y0 = (h - rows * step) / 2;
        for (var r = 0; r <= rows; r++) {
          for (var c = 0; c <= cols; c++) {
            final o = Offset(x0 + c * step, y0 + r * step);
            yield PatternElement(o, o, isLine: false);
          }
        }
        final fx1 = x0 - step / 2, fy1 = y0 - step / 2;
        final fx2 = x0 + cols * step + step / 2;
        final fy2 = y0 + rows * step + step / 2;
        yield* box(fx1, fy1, fx2, fy2);
        for (var c = 0; c <= cols; c += 5) {
          yield vLine(x0 + c * step, fy1 - 10, fy1, strong: true);
        }
        for (var r = 0; r <= rows; r += 5) {
          yield hLine(fx1 - 10, fx1, y0 + r * step, strong: true);
        }
      }
    case .blockDiagram:
      {
        const cols = 3, rows = 4;
        final bw = (right - left) * 0.24;
        final bh = (bottom - top) * 0.12;
        final gapX = ((right - left) - cols * bw) / (cols - 1);
        final gapY = ((bottom - top) - rows * bh) / (rows - 1);
        for (var r = 0; r < rows; r++) {
          final y = top + r * (bh + gapY);
          for (var c = 0; c < cols; c++) {
            final x = left + c * (bw + gapX);
            yield* box(x, y, x + bw, y + bh);
            if (c < cols - 1) {
              final ax = x + bw + gapX, ay = y + bh / 2;
              yield hLine(x + bw, ax, ay);
              yield PatternElement(Offset(ax, ay), Offset(ax - l * 0.35, ay - l * 0.2));
              yield PatternElement(Offset(ax, ay), Offset(ax - l * 0.35, ay + l * 0.2));
            }
          }
          // each row feeds the next one, from its last block down
          if (r < rows - 1) {
            final x = left + (cols - 1) * (bw + gapX) + bw / 2;
            yield vLine(x, y + bh, y + bh + gapY / 2);
            yield hLine(left + bw / 2, x, y + bh + gapY / 2);
            yield vLine(left + bw / 2, y + bh + gapY / 2, y + bh + gapY);
          }
        }
      }
    case .gantt:
      {
        final rowH = l * 1.5;
        final taskW = (right - left) * 0.3;
        const periods = 12;
        final colW = (right - left - taskW) / periods;
        yield text(DefterStrings.labelTask, left + l * 0.3, top + l * 0.35, width: taskW - l * 0.6);
        for (var i = 0; i < periods; i++) {
          yield text('${i + 1}', left + taskW + i * colW + colW * 0.3, top + l * 0.35, width: colW * 0.6);
        }
        var y = top;
        var first = true;
        while (y <= bottom + 0.01) {
          yield hLine(left, right, y, strong: first || y == top + rowH);
          first = false;
          y += rowH;
        }
        final last = y - rowH;
        yield vLine(left, top, last);
        yield vLine(left + taskW, top, last, strong: true);
        for (var i = 1; i <= periods; i++) {
          yield vLine(left + taskW + i * colW, top, last);
        }
      }
    case .measureTable:
      {
        // Part, drawing and instrument above; then the readings.
        final headH = l * 1.5;
        final half = (right - left) / 2;
        yield text(DefterStrings.labelPart, left, top - l * 0.9, width: half - l * 3);
        yield hLine(left + l * 2.2, left + half - l * 0.5, top - l * 0.2);
        yield text(DefterStrings.labelDate, left + half, top - l * 0.9, width: l * 2);
        yield hLine(left + half + l * 2.2, right, top - l * 0.2);
        yield text(DefterStrings.labelInstrument, left, top + l * 0.2, width: l * 4);
        yield hLine(left + l * 4.2, right, top + l * 0.9);

        final tableTop = top + l * 1.6;
        const widths = [0.08, 0.32, 0.15, 0.15, 0.15, 0.15];
        final labels = [
          DefterStrings.labelNo,
          DefterStrings.labelFeature,
          DefterStrings.labelNominal,
          DefterStrings.labelTolerance,
          DefterStrings.labelMeasured,
          DefterStrings.labelResult,
        ];
        var x = left;
        for (var i = 0; i < widths.length; i++) {
          final cw = (right - left) * widths[i];
          yield text(labels[i], x + l * 0.2, tableTop + l * 0.4, width: cw - l * 0.4);
          yield vLine(x, tableTop, bottom, strong: i == 0);
          x += cw;
        }
        yield vLine(right, tableTop, bottom, strong: true);
        yield hLine(left, right, tableTop, strong: true);
        yield hLine(left, right, tableTop + headH, strong: true);
        for (var y = tableTop + headH + l * 1.25; y < bottom - 1; y += l * 1.25) {
          yield hLine(left, right, y);
        }
        yield hLine(left, right, bottom, strong: true);
      }
    case .orgChart:
      {
        final bw = w * 0.2, bh = h * 0.07;
        final topY = top + l;
        final cx = w / 2;
        yield* box(cx - bw / 2, topY, cx + bw / 2, topY + bh);
        final midY = topY + bh + h * 0.1;
        final lowY = midY + bh + h * 0.1;
        final busY = topY + bh + h * 0.05;
        yield vLine(cx, topY + bh, busY);
        final mids = [w * 0.2, w * 0.5, w * 0.8];
        yield hLine(mids.first, mids.last, busY);
        for (final mx in mids) {
          yield vLine(mx, busY, midY);
          yield* box(mx - bw / 2, midY, mx + bw / 2, midY + bh);
          // two below each
          final bus2 = midY + bh + h * 0.05;
          yield vLine(mx, midY + bh, bus2);
          final lw = bw * 0.62;
          final offs = [-lw * 0.6, lw * 0.6];
          yield hLine(mx + offs.first, mx + offs.last, bus2);
          for (final o in offs) {
            yield vLine(mx + o, bus2, lowY);
            yield* box(mx + o - lw / 2, lowY, mx + o + lw / 2, lowY + bh);
          }
        }
        for (var y = lowY + bh + l * 2; y <= bottom; y += l) {
          yield hLine(left, right, y);
        }
      }
    case .arrowDiagram:
      {
        const steps = 4, rows = 3;
        final bw = (right - left) * 0.19;
        final gap = ((right - left) - steps * bw) / (steps - 1);
        final bh = l * 2.5;
        final rowH = (bottom - top) / rows;
        for (var r = 0; r < rows; r++) {
          final y = top + r * rowH + l * 0.5;
          for (var i = 0; i < steps; i++) {
            final x = left + i * (bw + gap);
            yield* box(x, y, x + bw, y + bh);
            if (i < steps - 1) {
              final ax = x + bw + gap, ay = y + bh / 2;
              yield hLine(x + bw, ax, ay, strong: true);
              yield PatternElement(Offset(ax, ay), Offset(ax - l * 0.4, ay - l * 0.25), secondaryColor: true);
              yield PatternElement(Offset(ax, ay), Offset(ax - l * 0.4, ay + l * 0.25), secondaryColor: true);
            }
          }
          for (var ly = y + bh + l; ly < top + (r + 1) * rowH - l * 0.2; ly += l) {
            yield hLine(left, right, ly);
          }
        }
      }
    case .relationDiagram:
      {
        final c = Offset(w / 2, top + (bottom - top) * 0.42);
        final ring = math.min(w, h) * 0.3;
        final r0 = w * 0.1;
        yield PatternElement(c, c, isLine: false, radius: r0);
        final nodes = <Offset>[
          for (var i = 0; i < 6; i++)
            c + Offset(
              math.cos(-math.pi / 2 + i * math.pi / 3),
              math.sin(-math.pi / 2 + i * math.pi / 3),
            ) * ring,
        ];
        final rn = w * 0.075;
        for (var i = 0; i < nodes.length; i++) {
          final n = nodes[i];
          yield PatternElement(n, n, isLine: false, radius: rn);
          // to the centre
          final d = (n - c) / ring;
          yield PatternElement(c + d * r0, n - d * rn);
          // to the next one round the ring
          final m = nodes[(i + 1) % nodes.length];
          final e = (m - n) / (m - n).distance;
          yield PatternElement(n + e * rn, m - e * rn);
        }
        for (var y = c.dy + ring + rn + l * 1.5; y <= bottom; y += l) {
          yield hLine(left, right, y);
        }
      }
    case .academicPlanner:
      {
        yield text(DefterStrings.labelTerm, left, top - l * 0.9, width: l * 3);
        yield hLine(left + l * 2.2, w * 0.45, top - l * 0.2);
        yield text(DefterStrings.labelWeek, w * 0.55, top - l * 0.9, width: l * 3);
        yield hLine(w * 0.55 + l * 2.2, right, top - l * 0.2);

        final days = DefterStrings.weekDaysShort;
        final rowLabels = [
          DefterStrings.labelLessons,
          DefterStrings.labelHomework,
          DefterStrings.labelExams,
          DefterStrings.labelNotes,
        ];
        final labelW = l * 3.2;
        final gridTop = top + l * 0.8;
        final headH = l * 1.2;
        final colW = (right - left - labelW) / 5;
        final rowH = (bottom - gridTop - headH) / rowLabels.length;
        for (var d = 0; d < 5; d++) {
          yield text(days[d], left + labelW + d * colW + l * 0.25, gridTop + l * 0.25, width: colW - l * 0.5);
        }
        yield hLine(left, right, gridTop, strong: true);
        yield hLine(left, right, gridTop + headH, strong: true);
        for (var r = 0; r < rowLabels.length; r++) {
          final y = gridTop + headH + r * rowH;
          yield text(rowLabels[r], left + l * 0.2, y + l * 0.3, width: labelW - l * 0.4);
          yield hLine(left, right, y + rowH, strong: r == rowLabels.length - 1);
        }
        yield vLine(left, gridTop, bottom, strong: true);
        yield vLine(left + labelW, gridTop, bottom, strong: true);
        for (var d = 1; d <= 5; d++) {
          yield vLine(left + labelW + d * colW, gridTop, bottom, strong: d == 5);
        }
      }
    case .goalPlanner:
      {
        yield text(DefterStrings.labelGoal, left, top - l * 0.9, width: l * 3);
        yield hLine(left, right, top + l * 0.6, strong: true);
        yield text(DefterStrings.labelWhy, left, top + l * 1.2, width: w / 2);
        final whyTop = top + l * 2.1;
        yield* box(left, whyTop, right, whyTop + l * 3.5);

        var y = whyTop + l * 4.4;
        yield text(DefterStrings.labelPlanSteps, left, y, width: w / 2);
        y += l * 1.6;
        final side = l * 0.8;
        for (var i = 0; i < 6; i++, y += l * 1.5) {
          yield* box(left, y - side, left + side, y);
          yield hLine(left + side + l * 0.5, right - l * 4.5, y);
          yield hLine(right - l * 4, right, y);
        }
        yield text(DefterStrings.labelDeadline, left, y, width: l * 5);
        yield hLine(left + l * 4.5, w * 0.6, y + l * 0.7);
        y += l * 1.8;
        yield text(DefterStrings.labelProgress, left, y, width: l * 5);
        y += l;
        final cell = (right - left) / 10;
        yield* box(left, y, right, y + l * 1.2);
        for (var i = 1; i < 10; i++) {
          yield vLine(left + i * cell, y, y + l * 1.2);
        }
        for (var ly = y + l * 2.6; ly <= bottom; ly += l) {
          yield hLine(left, right, ly);
        }
      }
    case .financePlanner:
      {
        yield text(DefterStrings.labelYear, left, top - l * 0.9, width: l * 2);
        yield hLine(left + l * 1.6, left + l * 6, top - l * 0.2);
        final months = DefterStrings.months;
        final labels = [
          DefterStrings.labelMonth,
          DefterStrings.labelIncome,
          DefterStrings.labelExpenses,
          DefterStrings.labelSavings,
          DefterStrings.labelNotes,
        ];
        const widths = [0.2, 0.18, 0.18, 0.18, 0.26];
        final tableTop = top + l * 0.6;
        final rowH = (bottom - tableTop) / 14;
        var x = left;
        for (var i = 0; i < widths.length; i++) {
          final cw = (right - left) * widths[i];
          yield text(labels[i], x + l * 0.2, tableTop + rowH * 0.25, width: cw - l * 0.4);
          yield vLine(x, tableTop, bottom, strong: i == 0);
          x += cw;
        }
        yield vLine(right, tableTop, bottom, strong: true);
        for (var r = 0; r <= 14; r++) {
          yield hLine(left, right, tableTop + r * rowH, strong: r <= 1 || r >= 13);
        }
        for (var m = 0; m < 12; m++) {
          yield text(months[m], left + l * 0.2, tableTop + (m + 1) * rowH + rowH * 0.25, width: (right - left) * widths[0] - l * 0.4);
        }
        yield text(DefterStrings.labelTotal, left + l * 0.2, tableTop + 13 * rowH + rowH * 0.25, width: (right - left) * widths[0] - l * 0.4);
      }
    case .moodTracker:
      {
        yield text(DefterStrings.labelMonth, left, top - l * 0.9, width: l * 2);
        yield hLine(left + l * 1.6, left + l * 8, top - l * 0.2);
        // A row per day, a column per mood from 1 to 5, and a note.
        final headH = l * 1.2;
        final dayW = l * 2;
        final moodW = l * 1.4;
        final rowH = (bottom - top - headH) / 31;
        yield text(DefterStrings.labelDay, left + l * 0.2, top + l * 0.25, width: dayW - l * 0.3);
        for (var m = 0; m < 5; m++) {
          yield text('${m + 1}', left + dayW + m * moodW + moodW * 0.35, top + l * 0.25, width: moodW * 0.6);
        }
        final noteX = left + dayW + 5 * moodW;
        yield text(DefterStrings.labelNotes, noteX + l * 0.2, top + l * 0.25, width: right - noteX - l * 0.4);
        yield hLine(left, right, top, strong: true);
        yield hLine(left, right, top + headH, strong: true);
        for (var d = 1; d <= 31; d++) {
          final y = top + headH + d * rowH;
          yield hLine(left, right, y, strong: d == 31);
          if (rowH >= l * 0.7) {
            yield text('$d', left + l * 0.3, y - rowH + rowH * 0.12, width: dayW - l * 0.4);
          }
          for (var m = 0; m < 5; m++) {
            final o = Offset(left + dayW + m * moodW + moodW / 2, y - rowH / 2);
            yield PatternElement(o, o, isLine: false, radius: math.min(rowH, moodW) * 0.3);
          }
        }
        yield vLine(left, top, bottom, strong: true);
        yield vLine(left + dayW, top, bottom);
        yield vLine(noteX, top, bottom);
        yield vLine(right, top, bottom, strong: true);
      }
    case .studentPlanner:
      {
        final mid = w / 2;
        final split = top + (bottom - top) * 0.6;
        // classes on the left
        yield text(DefterStrings.labelLessons, left, top - l * 0.9, width: mid - left - l);
        yield hLine(left, mid - l * 0.5, top, strong: true);
        for (var y = top + l * 1.25; y < split - l * 0.5; y += l * 1.25) {
          yield hLine(left, mid - l * 0.5, y);
        }
        // homework to tick off on the right
        yield text(DefterStrings.labelHomework, mid + l * 0.5, top - l * 0.9, width: right - mid - l);
        yield hLine(mid + l * 0.5, right, top, strong: true);
        final side = l * 0.7;
        for (var y = top + l * 1.25; y < split - l * 0.5; y += l * 1.25) {
          yield* box(mid + l * 0.5, y - side, mid + l * 0.5 + side, y);
          yield hLine(mid + l * 0.5 + side + l * 0.4, right, y);
        }
        // exams below
        yield text(DefterStrings.labelExams, left, split, width: w / 2);
        final tableTop = split + l * 1.1;
        final labels = [
          DefterStrings.labelLesson,
          DefterStrings.labelDate,
          DefterStrings.labelTopic,
          DefterStrings.labelGrade,
        ];
        const widths = [0.3, 0.2, 0.35, 0.15];
        var x = left;
        for (var i = 0; i < widths.length; i++) {
          final cw = (right - left) * widths[i];
          yield text(labels[i], x + l * 0.2, tableTop + l * 0.3, width: cw - l * 0.4);
          yield vLine(x, tableTop, bottom, strong: i == 0);
          x += cw;
        }
        yield vLine(right, tableTop, bottom, strong: true);
        yield hLine(left, right, tableTop, strong: true);
        yield hLine(left, right, tableTop + l * 1.3, strong: true);
        for (var y = tableTop + l * 2.55; y < bottom - 1; y += l * 1.25) {
          yield hLine(left, right, y);
        }
        yield hLine(left, right, bottom, strong: true);
      }
    case .ledger:
      {
        final labels = [
          DefterStrings.labelDate,
          DefterStrings.labelDescription,
          DefterStrings.labelDebit,
          DefterStrings.labelCredit,
          DefterStrings.labelBalance,
        ];
        const widths = [0.15, 0.4, 0.15, 0.15, 0.15];
        var x = left;
        for (var i = 0; i < widths.length; i++) {
          final cw = (right - left) * widths[i];
          yield text(labels[i], x + l * 0.2, top + l * 0.3, width: cw - l * 0.4);
          yield vLine(x, top, bottom, strong: i == 0 || i >= 2);
          x += cw;
        }
        yield vLine(right, top, bottom, strong: true);
        yield hLine(left, right, top, strong: true);
        yield hLine(left, right, top + l * 1.3, strong: true);
        for (var y = top + l * 2.3; y < bottom - 1; y += l) {
          yield hLine(left, right, y);
        }
        yield hLine(left, right, bottom, strong: true);
      }
    default:
      return;
  }
}

class PatternElement {
  final Offset start, end;

  /// Whether this is a line or a dot
  final bool isLine;

  /// Whether this should use a secondary color
  final bool secondaryColor;

  /// A circle (or ellipse, with [radiusY]) outline centred on [start].
  final double? radius;
  final double? radiusY;

  /// Text to draw at [start] instead of a line or a dot (templates only).
  final String? label;

  /// The widest the [label] may be before it is cut.
  final double? labelWidth;

  const new(
    this.start,
    this.end, {
    this.isLine = true,
    this.secondaryColor = false,
    this.label,
    this.labelWidth,
    this.radius,
    this.radiusY,
  });
}
