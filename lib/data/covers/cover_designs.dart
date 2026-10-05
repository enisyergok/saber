import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:saber/data/defter_strings.dart';

/// A notebook cover, drawn in code (so there is nothing to download and
/// every design is original). Covers are drawn at the size of a page and
/// become the first page of a notebook.
class CoverDesign {
  const CoverDesign({
    required this.id,
    required this.group,
    required this.nameTr,
    required this.nameEn,
    required this.paint,
    this.titleColor = const Color(0xFF222222),
  });

  final String id;

  /// 'minimal', 'gradient', 'pattern', 'classic' or 'scene'.
  final String group;
  final String nameTr, nameEn;
  final void Function(Canvas canvas, Size size) paint;

  /// The colour the notebook's title is written in.
  final Color titleColor;

  String get name => (DefterStrings.isTr) ? nameTr : nameEn;

  /// Draws the whole cover, with the [title] (if any) on a label.
  void draw(Canvas canvas, Size size, {String? title}) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    paint(canvas, size);
    final spine = Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(size.width * 0.06, 0),
        [const Color(0x33000000), const Color(0x00000000)],
      );
    canvas.drawRect(Offset.zero & size, spine);
    if (title != null && title.trim().isNotEmpty) {
      final painter = TextPainter(
        text: TextSpan(
          text: title.trim(),
          style: TextStyle(
            color: titleColor,
            fontSize: size.width * 0.075,
            fontWeight: FontWeight.w600,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        maxLines: 3,
        ellipsis: '…',
      )..layout(maxWidth: size.width * 0.7);
      final label = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(size.width / 2, size.height * 0.42),
          width: size.width * 0.78,
          height: painter.height + size.width * 0.12,
        ),
        Radius.circular(size.width * 0.02),
      );
      canvas.drawRRect(label, Paint()..color = const Color(0xCCFFFFFF));
      painter.paint(
        canvas,
        Offset(
          (size.width - painter.width) / 2,
          label.center.dy - painter.height / 2,
        ),
      );
      painter.dispose();
    }
    canvas.restore();
  }

  /// A PNG of the cover at [size].
  Future<Uint8List> renderPng(Size size, {String? title}) async {
    final recorder = ui.PictureRecorder();
    draw(Canvas(recorder), size, title: title);
    final image = await recorder.endRecording().toImage(
      size.width.round(),
      size.height.round(),
    );
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data!.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }
}

/// A repeatable pseudo-random number in 0..1, so a cover always looks the
/// same.
double _noise(int i) {
  final x = math.sin(i * 12.9898 + 78.233) * 43758.5453;
  return x - x.floorToDouble();
}

CoverDesign _solid(String id, String tr, String en, Color color) {
  return CoverDesign(
    id: id,
    group: 'minimal',
    nameTr: tr,
    nameEn: en,
    titleColor: color.computeLuminance() < 0.3
        ? const Color(0xFF222222)
        : const Color(0xFF222222),
    paint: (c, s) {
      c.drawRect(Offset.zero & s, Paint()..color = color);
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(s.width * 0.1, s.height * 0.07, s.width * 0.8, s.height * 0.86),
          Radius.circular(s.width * 0.02),
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s.width * 0.004
          ..color = (color.computeLuminance() < 0.3 ? Colors.white : Colors.black)
              .withValues(alpha: 0.18),
      );
    },
  );
}

CoverDesign _gradient(
  String id,
  String tr,
  String en,
  List<Color> colors,
) {
  return CoverDesign(
    id: id,
    group: 'gradient',
    nameTr: tr,
    nameEn: en,
    paint: (c, s) {
      c.drawRect(
        Offset.zero & s,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(s.width * 0.2, 0),
            Offset(s.width * 0.8, s.height),
            colors,
          ),
      );
    },
  );
}

CoverDesign _leather(String id, String tr, String en, Color color) {
  return CoverDesign(
    id: id,
    group: 'classic',
    nameTr: tr,
    nameEn: en,
    paint: (c, s) {
      c.drawRect(Offset.zero & s, Paint()..color = color);
      // grain
      final grain = Paint();
      for (var i = 0; i < 2600; i++) {
        final x = _noise(i * 2) * s.width;
        final y = _noise(i * 2 + 1) * s.height;
        grain.color = (i.isEven ? Colors.white : Colors.black).withValues(
          alpha: 0.04 + _noise(i + 9000) * 0.05,
        );
        c.drawCircle(Offset(x, y), 1.5 + _noise(i + 4000) * 2.5, grain);
      }
      final inset = s.width * 0.07;
      final frame = Rect.fromLTWH(inset * 1.4, inset, s.width - inset * 2.4, s.height - inset * 2);
      final stitch = Paint()
        ..color = Colors.white.withValues(alpha: 0.45)
        ..strokeWidth = s.width * 0.004;
      // stitched border
      const dash = 14.0;
      for (var x = frame.left; x < frame.right; x += dash * 2) {
        c.drawLine(Offset(x, frame.top), Offset(math.min(x + dash, frame.right), frame.top), stitch);
        c.drawLine(Offset(x, frame.bottom), Offset(math.min(x + dash, frame.right), frame.bottom), stitch);
      }
      for (var y = frame.top; y < frame.bottom; y += dash * 2) {
        c.drawLine(Offset(frame.left, y), Offset(frame.left, math.min(y + dash, frame.bottom)), stitch);
        c.drawLine(Offset(frame.right, y), Offset(frame.right, math.min(y + dash, frame.bottom)), stitch);
      }
      // embossed label
      final label = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(s.width / 2 + inset * 0.3, s.height * 0.42),
          width: s.width * 0.5,
          height: s.height * 0.16,
        ),
        Radius.circular(s.width * 0.012),
      );
      c.drawRRect(
        label,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s.width * 0.006
          ..color = Colors.black.withValues(alpha: 0.25),
      );
      c.drawRRect(label.deflate(s.width * 0.012), Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s.width * 0.003
        ..color = Colors.white.withValues(alpha: 0.3));
    },
  );
}

void _stars(Canvas c, Size s, int count, {double top = 0, double? bottom}) {
  final p = Paint();
  final limit = bottom ?? s.height;
  for (var i = 0; i < count; i++) {
    p.color = Colors.white.withValues(alpha: 0.3 + _noise(i + 100) * 0.7);
    c.drawCircle(
      Offset(_noise(i) * s.width, top + _noise(i + 50) * (limit - top)),
      0.8 + _noise(i + 200) * 2.6,
      p,
    );
  }
}

void _mountains(Canvas c, Size s, double baseY, double peak, Color color, int seed) {
  final path = Path()..moveTo(0, s.height);
  path.lineTo(0, baseY);
  var x = 0.0;
  var i = 0;
  while (x < s.width) {
    final step = s.width * (0.12 + _noise(seed + i) * 0.14);
    final top = baseY - peak * (0.35 + _noise(seed + i + 40) * 0.65);
    path.lineTo(x + step / 2, top);
    x += step;
    path.lineTo(math.min(x, s.width), baseY - peak * 0.1 * _noise(seed + i + 80));
    i++;
  }
  path.lineTo(s.width, s.height);
  path.close();
  c.drawPath(path, Paint()..color = color);
}

final List<CoverDesign> _designs = [
  // Minimal
  _solid('white', 'Beyaz', 'White', const Color(0xFFFFFFFF)),
  _solid('black', 'Siyah', 'Black', const Color(0xFF1F1F23)),
  _solid('grey', 'Gri', 'Grey', const Color(0xFFB8B8BD)),
  _solid('beige', 'Bej', 'Beige', const Color(0xFFE6D5BE)),
  _solid('cream', 'Krem', 'Cream', const Color(0xFFF5EBD9)),
  _solid('pink', 'Pembe', 'Pink', const Color(0xFFF7BFD0)),
  _solid('blue', 'Mavi', 'Blue', const Color(0xFF9CD0F0)),
  _solid('green', 'Yeşil', 'Green', const Color(0xFF9ED9C4)),
  _solid('lilac', 'Lila', 'Lilac', const Color(0xFFC9B6F0)),
  _solid('yellow', 'Sarı', 'Yellow', const Color(0xFFF8E8A6)),
  _solid('peach', 'Şeftali', 'Peach', const Color(0xFFF9C9A8)),
  _solid('mint', 'Mint', 'Mint', const Color(0xFFA6EBD7)),
  // Gradients
  _gradient('g-sunset', 'Gün batımı', 'Sunset', const [Color(0xFFFFB88C), Color(0xFFDE6262)]),
  _gradient('g-ocean', 'Okyanus', 'Ocean', const [Color(0xFF7FDBFF), Color(0xFF1B6CA8)]),
  _gradient('g-aurora', 'Aurora', 'Aurora', const [Color(0xFF9D50BB), Color(0xFF3FD2B0)]),
  _gradient('g-candy', 'Şeker', 'Candy', const [Color(0xFFFBC2EB), Color(0xFFA6C1EE)]),
  _gradient('g-slate', 'Arduvaz', 'Slate', const [Color(0xFF485563), Color(0xFF29323C)]),
  _gradient('g-lime', 'Çimen', 'Meadow', const [Color(0xFFD4FC79), Color(0xFF96E6A1)]),
  // Patterns
  CoverDesign(
    id: 'p-stripes',
    group: 'pattern',
    nameTr: 'Çizgiler',
    nameEn: 'Stripes',
    paint: (c, s) {
      c.drawRect(Offset.zero & s, Paint()..color = const Color(0xFF2F4B7C));
      final p = Paint()..color = const Color(0xFFF2C14E);
      c.save();
      c.rotate(-0.35);
      for (var x = -s.height; x < s.width * 1.6; x += s.width * 0.14) {
        c.drawRect(Rect.fromLTWH(x, -s.height * 0.3, s.width * 0.05, s.height * 1.8), p);
      }
      c.restore();
    },
  ),
  CoverDesign(
    id: 'p-triangles',
    group: 'pattern',
    nameTr: 'Üçgenler',
    nameEn: 'Triangles',
    paint: (c, s) {
      c.drawRect(Offset.zero & s, Paint()..color = const Color(0xFFF4EFE6));
      const colors = [Color(0xFF264653), Color(0xFF2A9D8F), Color(0xFFE9C46A), Color(0xFFF4A261), Color(0xFFE76F51)];
      final step = s.width / 5;
      var i = 0;
      for (var y = 0.0; y < s.height; y += step) {
        for (var x = 0.0; x < s.width; x += step) {
          final p = Paint()..color = colors[(i * 7 + (y ~/ step) * 3) % colors.length].withValues(alpha: 0.9);
          c.drawPath(
            Path()
              ..moveTo(x, y + step)
              ..lineTo(x + step, y + step)
              ..lineTo(x + (i.isEven ? 0 : step), y)
              ..close(),
            p,
          );
          i++;
        }
      }
    },
  ),
  CoverDesign(
    id: 'p-circles',
    group: 'pattern',
    nameTr: 'Daireler',
    nameEn: 'Circles',
    paint: (c, s) {
      c.drawRect(Offset.zero & s, Paint()..color = const Color(0xFFFFF1E6));
      const colors = [Color(0xFFFF8FA3), Color(0xFFFFB703), Color(0xFF8ECAE6), Color(0xFF219EBC), Color(0xFFB5E48C)];
      for (var i = 0; i < 46; i++) {
        final r = s.width * (0.05 + _noise(i) * 0.11);
        c.drawCircle(
          Offset(_noise(i + 300) * s.width, _noise(i + 600) * s.height),
          r,
          Paint()..color = colors[i % colors.length].withValues(alpha: 0.75),
        );
      }
    },
  ),
  CoverDesign(
    id: 'p-waves',
    group: 'pattern',
    nameTr: 'Dalgalar',
    nameEn: 'Waves',
    paint: (c, s) {
      c.drawRect(Offset.zero & s, Paint()..color = const Color(0xFFE8F4F8));
      const colors = [Color(0xFF90CAF9), Color(0xFF64B5F6), Color(0xFF42A5F5), Color(0xFF1E88E5), Color(0xFF1565C0)];
      for (var i = 0; i < colors.length; i++) {
        final base = s.height * (0.45 + i * 0.12);
        final path = Path()..moveTo(0, s.height);
        path.lineTo(0, base);
        for (var x = 0.0; x <= s.width; x += 10) {
          path.lineTo(x, base + math.sin(x / s.width * 2 * math.pi * 2 + i) * s.height * 0.03);
        }
        path.lineTo(s.width, s.height);
        path.close();
        c.drawPath(path, Paint()..color = colors[i]);
      }
    },
  ),
  CoverDesign(
    id: 'p-dots',
    group: 'pattern',
    nameTr: 'Noktalar',
    nameEn: 'Polka dots',
    paint: (c, s) {
      c.drawRect(Offset.zero & s, Paint()..color = const Color(0xFFD94F5C));
      final p = Paint()..color = Colors.white.withValues(alpha: 0.85);
      final step = s.width / 8;
      var row = 0;
      for (var y = step / 2; y < s.height; y += step * 0.9, row++) {
        for (var x = (row.isEven ? step / 2 : step); x < s.width; x += step) {
          c.drawCircle(Offset(x, y), step * 0.18, p);
        }
      }
    },
  ),
  CoverDesign(
    id: 'p-chevron',
    group: 'pattern',
    nameTr: 'Zikzak',
    nameEn: 'Chevrons',
    paint: (c, s) {
      c.drawRect(Offset.zero & s, Paint()..color = const Color(0xFFEFEFEF));
      final p = Paint()
        ..color = const Color(0xFF3D5A80)
        ..style = PaintingStyle.stroke
        ..strokeWidth = s.width * 0.03;
      for (var y = 0.0; y < s.height + s.width * 0.2; y += s.width * 0.14) {
        final path = Path()..moveTo(0, y);
        for (var x = 0.0; x < s.width; x += s.width / 6) {
          path.relativeLineTo(s.width / 12, -s.width * 0.06);
          path.relativeLineTo(s.width / 12, s.width * 0.06);
        }
        c.drawPath(path, p);
      }
    },
  ),
  CoverDesign(
    id: 'p-ripples',
    group: 'pattern',
    nameTr: 'Dalga halkaları',
    nameEn: 'Ripples',
    paint: (c, s) {
      c.drawRect(Offset.zero & s, Paint()..color = const Color(0xFF14213D));
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s.width * 0.006;
      for (var k = 0; k < 3; k++) {
        final center = Offset(s.width * (0.3 + k * 0.25), s.height * (0.3 + k * 0.2));
        for (var i = 1; i < 14; i++) {
          p.color = const Color(0xFFFCA311).withValues(alpha: 0.7 - i * 0.045);
          c.drawCircle(center, s.width * 0.05 * i, p);
        }
      }
    },
  ),
  // Classic
  _leather('c-brown', 'Deri - Kahverengi', 'Leather - Brown', const Color(0xFF6B4226)),
  _leather('c-black', 'Deri - Siyah', 'Leather - Black', const Color(0xFF232323)),
  _leather('c-navy', 'Deri - Lacivert', 'Leather - Navy', const Color(0xFF1F3560)),
  _leather('c-green', 'Deri - Yeşil', 'Leather - Green', const Color(0xFF234B35)),
  _leather('c-red', 'Deri - Kırmızı', 'Leather - Red', const Color(0xFF7A1F27)),
  // Scenes
  CoverDesign(
    id: 's-mountains',
    group: 'scene',
    nameTr: 'Dağlar',
    nameEn: 'Mountains',
    paint: (c, s) {
      c.drawRect(
        Offset.zero & s,
        Paint()
          ..shader = ui.Gradient.linear(Offset.zero, Offset(0, s.height), const [Color(0xFFBFE3F5), Color(0xFFF7E8D0)]),
      );
      c.drawCircle(Offset(s.width * 0.7, s.height * 0.24), s.width * 0.09, Paint()..color = const Color(0xFFFFF4D6));
      _mountains(c, s, s.height * 0.72, s.height * 0.3, const Color(0xFF9DB7C9), 11);
      _mountains(c, s, s.height * 0.8, s.height * 0.26, const Color(0xFF5F8296), 31);
      _mountains(c, s, s.height * 0.9, s.height * 0.22, const Color(0xFF2F4F5F), 51);
    },
  ),
  CoverDesign(
    id: 's-sunset-sea',
    group: 'scene',
    nameTr: 'Deniz ve gün batımı',
    nameEn: 'Sea at sunset',
    paint: (c, s) {
      c.drawRect(
        Offset.zero & s,
        Paint()
          ..shader = ui.Gradient.linear(Offset.zero, Offset(0, s.height * 0.62), const [Color(0xFF3A1C71), Color(0xFFD76D77), Color(0xFFFFAF7B)]),
      );
      final horizon = s.height * 0.62;
      c.drawCircle(Offset(s.width * 0.5, horizon - s.width * 0.02), s.width * 0.16, Paint()..color = const Color(0xFFFFE29A));
      c.drawRect(
        Rect.fromLTWH(0, horizon, s.width, s.height - horizon),
        Paint()
          ..shader = ui.Gradient.linear(Offset(0, horizon), Offset(0, s.height), const [Color(0xFF2B4C7E), Color(0xFF0B1F3A)]),
      );
      final glint = Paint()..color = const Color(0xFFFFE29A).withValues(alpha: 0.7);
      for (var i = 0; i < 16; i++) {
        final y = horizon + s.height * 0.015 + i * s.height * 0.022;
        final w = s.width * (0.28 - i * 0.012) * (0.6 + _noise(i) * 0.5);
        c.drawRRect(
          RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(s.width / 2, y), width: math.max(w, 20), height: 6), const Radius.circular(3)),
          glint,
        );
      }
    },
  ),
  CoverDesign(
    id: 's-forest',
    group: 'scene',
    nameTr: 'Orman',
    nameEn: 'Forest',
    paint: (c, s) {
      c.drawRect(
        Offset.zero & s,
        Paint()
          ..shader = ui.Gradient.linear(Offset.zero, Offset(0, s.height), const [Color(0xFFDDEFD8), Color(0xFFA8D5BA)]),
      );
      const greens = [Color(0xFF3F7D58), Color(0xFF2D6A4F), Color(0xFF1B4332)];
      for (var layer = 0; layer < 3; layer++) {
        final base = s.height * (0.6 + layer * 0.15);
        for (var i = 0; i < 9; i++) {
          final x = (i + _noise(i + layer * 20) * 0.6) / 8.5 * s.width;
          final h = s.height * (0.18 + _noise(i + layer * 33) * 0.1) * (1 + layer * 0.25);
          final w = h * 0.5;
          final p = Paint()..color = greens[layer];
          for (var t = 0; t < 3; t++) {
            final ty = base - h + t * h * 0.28;
            c.drawPath(
              Path()
                ..moveTo(x, ty)
                ..lineTo(x + w * (0.5 + t * 0.25), ty + h * 0.45)
                ..lineTo(x - w * (0.5 + t * 0.25), ty + h * 0.45)
                ..close(),
              p,
            );
          }
          c.drawRect(Rect.fromLTWH(x - w * 0.06, base + h * 0.1, w * 0.12, h * 0.15), Paint()..color = const Color(0xFF3B2A1A));
        }
        c.drawRect(Rect.fromLTWH(0, base + s.height * 0.1, s.width, s.height), p0(greens[layer]));
      }
    },
  ),
  CoverDesign(
    id: 's-galaxy',
    group: 'scene',
    nameTr: 'Galaksi',
    nameEn: 'Galaxy',
    paint: (c, s) {
      c.drawRect(
        Offset.zero & s,
        Paint()
          ..shader = ui.Gradient.radial(Offset(s.width * 0.6, s.height * 0.4), s.height * 0.7, const [Color(0xFF3B1E6E), Color(0xFF0B0B2B)]),
      );
      _stars(c, s, 220);
      c.drawCircle(
        Offset(s.width * 0.62, s.height * 0.38),
        s.width * 0.14,
        Paint()
          ..shader = ui.Gradient.radial(Offset(s.width * 0.62, s.height * 0.38), s.width * 0.14, const [Color(0xFFFFE9A8), Color(0x00FFE9A8)]),
      );
    },
    titleColor: const Color(0xFF222222),
  ),
  CoverDesign(
    id: 's-night-lake',
    group: 'scene',
    nameTr: 'Gece gölü',
    nameEn: 'Night lake',
    paint: (c, s) {
      c.drawRect(
        Offset.zero & s,
        Paint()
          ..shader = ui.Gradient.linear(Offset.zero, Offset(0, s.height), const [Color(0xFF0F2027), Color(0xFF2C5364)]),
      );
      _stars(c, s, 120, bottom: s.height * 0.6);
      c.drawCircle(Offset(s.width * 0.72, s.height * 0.2), s.width * 0.07, Paint()..color = const Color(0xFFF4F1DE));
      _mountains(c, s, s.height * 0.62, s.height * 0.22, const Color(0xFF14323F), 71);
      c.drawRect(
        Rect.fromLTWH(0, s.height * 0.62, s.width, s.height * 0.38),
        Paint()
          ..shader = ui.Gradient.linear(Offset(0, s.height * 0.62), Offset(0, s.height), const [Color(0xFF1C3B4A), Color(0xFF0A1A22)]),
      );
    },
  ),
];

Paint p0(Color color) => Paint()..color = color;

/// All the covers, in the order they are offered.
abstract class CoverDesigns {
  static List<CoverDesign> get all => _designs;

  static CoverDesign? byId(String? id) {
    for (final design in _designs) {
      if (design.id == id) return design;
    }
    return null;
  }

  static List<CoverDesign> inGroup(String group) =>
      [for (final d in _designs) if (d.group == group) d];

  static const groups = ['minimal', 'gradient', 'pattern', 'classic', 'scene'];
}
