import 'dart:ui';

/// How much of the edges of an imported PDF page is cut away, as fractions
/// (0 to [max]) of the page's width and height.
///
/// The cropped part is shown as large as the note page allows, without
/// stretching. Strokes keep their positions, so crop before writing.
class PdfCrop {
  const new({this.left = 0, this.top = 0, this.right = 0, this.bottom = 0});

  static const none = PdfCrop();

  /// The most that can be cut from one edge.
  static const max = 0.4;

  final double left;
  final double top;
  final double right;
  final double bottom;

  bool get isNone => left == 0 && top == 0 && right == 0 && bottom == 0;

  /// Keeps every edge in 0 to [max] and leaves at least 20% of the page.
  PdfCrop clamped() {
    double edge(double v) => v.isNaN ? 0 : v.clamp(0.0, max);
    var l = edge(left), t = edge(top), r = edge(right), b = edge(bottom);
    if (l + r > 0.8) {
      final k = 0.8 / (l + r);
      l *= k;
      r *= k;
    }
    if (t + b > 0.8) {
      final k = 0.8 / (t + b);
      t *= k;
      b *= k;
    }
    return PdfCrop(left: l, top: t, right: r, bottom: b);
  }

  PdfCrop copyWith({
    double? left,
    double? top,
    double? right,
    double? bottom,
  }) => PdfCrop(
    left: left ?? this.left,
    top: top ?? this.top,
    right: right ?? this.right,
    bottom: bottom ?? this.bottom,
  );

  /// Where the page goes when [natural] (the whole PDF page) is cropped and
  /// shown inside [available].
  PdfCropLayout layout(Size natural, Size available) {
    final region = Size(
      natural.width * (1 - left - right),
      natural.height * (1 - top - bottom),
    );
    final scale = _min(
      available.width / region.width,
      available.height / region.height,
    );
    final full = Size(natural.width * scale, natural.height * scale);
    return PdfCropLayout(
      visible: Size(region.width * scale, region.height * scale),
      full: full,
      offset: Offset(-left * full.width, -top * full.height),
    );
  }

  static double _min(double a, double b) => a < b ? a : b;

  /// Adds the non-zero edges to [json].
  void writeTo(Map<String, dynamic> json) {
    if (left != 0) json['cl'] = left;
    if (top != 0) json['ct'] = top;
    if (right != 0) json['cr'] = right;
    if (bottom != 0) json['cb'] = bottom;
  }

  static PdfCrop fromJson(Map<String, dynamic> json) {
    double read(String key) => (json[key] as num?)?.toDouble() ?? 0;
    return PdfCrop(
      left: read('cl'),
      top: read('ct'),
      right: read('cr'),
      bottom: read('cb'),
    ).clamped();
  }

  @override
  bool operator ==(Object other) =>
      other is PdfCrop &&
      other.left == left &&
      other.top == top &&
      other.right == right &&
      other.bottom == bottom;

  @override
  int get hashCode => Object.hash(left, top, right, bottom);

  @override
  String toString() => 'PdfCrop($left, $top, $right, $bottom)';
}

/// The result of [PdfCrop.layout].
class PdfCropLayout {
  const new({required this.visible, required this.full, required this.offset});

  /// The size of the part of the page that stays visible.
  final Size visible;

  /// The size the whole PDF page is drawn at, before cutting.
  final Size full;

  /// Where the whole page's top left corner sits inside the visible part.
  final Offset offset;
}
