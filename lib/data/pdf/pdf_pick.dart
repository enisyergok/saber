import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

/// What was chosen in the window that shows a PDF before any of it is put
/// into the note.
sealed class PdfPick {
  const new();
}

/// Whole pages, to become pages of the note.
class PdfPickPages extends PdfPick {
  const new(this.pages);

  /// The pages of the PDF (the first is 0), in the order of the PDF.
  final List<int> pages;
}

/// A piece of a page, as a picture.
class PdfPickImage extends PdfPick {
  const new({
    required this.png,
    required this.pixelSize,
    required this.fractionOfPage,
  });

  final Uint8List png;
  final Size pixelSize;

  /// How much of the PDF page's width and height the piece takes (0 to 1),
  /// so that it can be shown as large as it was on its page.
  final Size fractionOfPage;
}

/// The text of a piece of a page.
class PdfPickText extends PdfPick {
  const new(this.text);

  final String text;
}

/// A part of a page that was marked with the pen: a rectangle, or the
/// inside of a line drawn freely. Everything is in fractions of the page
/// (0 to 1 from the top left), so it does not depend on how large the page
/// is shown.
class PdfRegion {
  /// A rectangle between two corners, in any order.
  factory rectangle(Offset a, Offset b) {
    final rect = _clamp(Rect.fromPoints(a, b));
    return PdfRegion._(rect, null);
  }

  /// The inside of the line through [points]; its ends are joined.
  factory lasso(List<Offset> points) {
    final inside = [
      for (final point in points)
        Offset(point.dx.clamp(0.0, 1.0), point.dy.clamp(0.0, 1.0)),
    ];
    if (inside.isEmpty) return PdfRegion._(Rect.zero, const []);
    var left = inside.first.dx, right = left;
    var top = inside.first.dy, bottom = top;
    for (final point in inside) {
      left = math.min(left, point.dx);
      right = math.max(right, point.dx);
      top = math.min(top, point.dy);
      bottom = math.max(bottom, point.dy);
    }
    return PdfRegion._(
      Rect.fromLTRB(left, top, right, bottom),
      List.unmodifiable(inside),
    );
  }

  const PdfRegion._(this.bounds, this.outline);

  /// The smallest rectangle around the region.
  final Rect bounds;

  /// The line that was drawn, or null for a rectangle.
  final List<Offset>? outline;

  bool get isRectangle => outline == null;

  static Rect _clamp(Rect rect) => Rect.fromLTRB(
    rect.left.clamp(0.0, 1.0),
    rect.top.clamp(0.0, 1.0),
    rect.right.clamp(0.0, 1.0),
    rect.bottom.clamp(0.0, 1.0),
  );

  /// Whether the region is large enough to mean something when the page
  /// is shown [shownSize] large: a tap or a slip of the pen is not a
  /// selection.
  bool isLargeEnough(Size shownSize, {double minSide = 12}) =>
      bounds.width * shownSize.width >= minSide &&
      bounds.height * shownSize.height >= minSide &&
      (outline == null || outline!.length >= 3);

  /// Whether [point] (in fractions of the page) is inside the region.
  bool contains(Offset point) {
    final inBounds =
        point.dx >= bounds.left &&
        point.dx <= bounds.right &&
        point.dy >= bounds.top &&
        point.dy <= bounds.bottom;
    final line = outline;
    if (line == null || !inBounds) return inBounds;
    // Count how often a line going right from the point crosses the outline.
    var inside = false;
    for (var i = 0, j = line.length - 1; i < line.length; j = i++) {
      final a = line[i], b = line[j];
      if ((a.dy > point.dy) == (b.dy > point.dy)) continue;
      final crossing = a.dx + (point.dy - a.dy) / (b.dy - a.dy) * (b.dx - a.dx);
      if (point.dx < crossing) inside = !inside;
    }
    return inside;
  }

  /// The region as a path on a page shown [size] large.
  Path pathIn(Size size) {
    final line = outline;
    if (line == null) {
      return Path()..addRect(
        Rect.fromLTRB(
          bounds.left * size.width,
          bounds.top * size.height,
          bounds.right * size.width,
          bounds.bottom * size.height,
        ),
      );
    }
    final path = Path();
    for (var i = 0; i < line.length; i++) {
      final x = line[i].dx * size.width, y = line[i].dy * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    return path..close();
  }
}

/// Reading the text of a marked part of a page.
abstract class PdfTextPicker {
  /// The text of the characters whose middle is inside the marked part.
  ///
  /// [fullText] is the text of the whole page in reading order and
  /// [charRects] the place of each of its characters in fractions of the
  /// page (null or empty for a character that has none, as line breaks
  /// do). Words and lines stay apart as they are on the page.
  static String textIn({
    required String fullText,
    required List<Rect?> charRects,
    required bool Function(Offset point) contains,
  }) {
    final out = StringBuffer();
    var brokeLine = false;
    var brokeWord = false;
    final count = math.min(fullText.length, charRects.length);
    for (var i = 0; i < count; i++) {
      final char = fullText[i];
      final isBreak = char == '\n' || char == '\r';
      final isSpace = !isBreak && char.trim().isEmpty;
      final rect = charRects[i];
      final chosen =
          !isBreak &&
          !isSpace &&
          rect != null &&
          !rect.isEmpty &&
          contains(rect.center);
      if (!chosen) {
        if (isBreak) {
          brokeLine = true;
        } else {
          // A space, or a letter that was left out: either way what comes
          // next is another word.
          brokeWord = true;
        }
        continue;
      }
      if (out.isNotEmpty) {
        if (brokeLine) {
          out.write('\n');
        } else if (brokeWord) {
          out.write(' ');
        }
      }
      brokeLine = false;
      brokeWord = false;
      out.write(char);
    }
    return out.toString();
  }
}

/// How large a marked part of a page is drawn when it becomes a picture.
abstract class PdfClip {
  /// Pixels for each point of the PDF (72 points are an inch): 216 dpi,
  /// sharp enough to zoom into on the note.
  static const pixelsPerPoint = 3.0;

  /// The longest side a picture may have, in pixels.
  static const maxSide = 3000;

  /// The pixels for a part that is [widthPoints] by [heightPoints] large,
  /// and the scale they are drawn at.
  static ({int width, int height, double scale}) pixelsFor(
    double widthPoints,
    double heightPoints,
  ) {
    final longest = math.max(widthPoints, heightPoints);
    var scale = pixelsPerPoint;
    if (longest * scale > maxSide) scale = maxSide / longest;
    return (
      width: math.max(1, (widthPoints * scale).round()),
      height: math.max(1, (heightPoints * scale).round()),
      scale: scale,
    );
  }

  /// Where a piece that took [fractionOfPage] of its PDF page goes on a
  /// note page of [pageSize]: as wide as it was on its own page, smaller
  /// if it would not fit, in the middle, with its top at [top] if there is
  /// room.
  static Rect placeOn({
    required Size pageSize,
    required Size fractionOfPage,
    required Size pixelSize,
    required double top,
    double margin = 0.04,
  }) {
    final aspect = pixelSize.height / math.max(1.0, pixelSize.width);
    final roomWidth = pageSize.width * (1 - 2 * margin);
    final roomHeight = pageSize.height * (1 - 2 * margin);
    var width = math.min(fractionOfPage.width * pageSize.width, roomWidth);
    width = math.max(width, math.min(roomWidth, 40));
    var height = width * aspect;
    if (height > roomHeight) {
      height = roomHeight;
      width = height / aspect;
    }
    final left = (pageSize.width - width) / 2;
    final lowest = pageSize.height - height - pageSize.height * margin;
    final highest = pageSize.height * margin;
    final y = top.clamp(highest, math.max(highest, lowest)).toDouble();
    return Rect.fromLTWH(left, y, width, height);
  }
}
