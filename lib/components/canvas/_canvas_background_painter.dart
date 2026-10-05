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

      if (element.label != null) {
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
  });
}
