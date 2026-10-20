import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xml/xml.dart';

/// Renders the rect/circle/pattern subset used by the packaged paper SVGs.
/// Flutter's SVG renderer does not render these SVG pattern fills directly.
class PackagedPaperPreview extends StatelessWidget {
  const PackagedPaperPreview({
    super.key,
    required this.asset,
    required this.pageSize,
    required this.fallback,
    this.paperColor,
  });

  final String asset;
  final Size pageSize;
  final Color? paperColor;
  final Widget fallback;
  static final _cache = <String, Future<XmlDocument>>{};

  static const assets = <String, String>{
    'blank': 'blank.svg',
    'lined-narrow': 'ruledNarrow.svg',
    'lined-wide': 'ruledWide.svg',
    'grid': 'grid.svg',
    'dots': 'dottedgrid.svg',
    'legal': 'legal.svg',
  };

  @override
  Widget build(BuildContext context) => FutureBuilder<XmlDocument>(
    future: _cache.putIfAbsent(
      asset,
      () async => XmlDocument.parse(
        await rootBundle.loadString('assets/goodnotes/papers/$asset'),
      ),
    ),
    builder: (context, snapshot) {
      if (!snapshot.hasData) return fallback;
      return SizedBox.fromSize(
        size: pageSize,
        child: CustomPaint(
          painter: _PaperSvgPainter(snapshot.data!, paperColor),
        ),
      );
    },
  );
}

class _PaperSvgPainter extends CustomPainter {
  const _PaperSvgPainter(this.document, this.paperColor);
  final XmlDocument document;
  final Color? paperColor;

  double _length(String? value, double extent, [double fallback = 0]) {
    if (value == null) return fallback;
    if (value.endsWith('%')) {
      return (double.tryParse(value.substring(0, value.length - 1)) ?? 0) *
          extent /
          100;
    }
    return double.tryParse(value) ?? fallback;
  }

  Color? _color(String? value) {
    if (value == null || value == 'none') return null;
    final rgb = RegExp(r'^rgb\((\d+),(\d+),(\d+)\)$')
        .firstMatch(value.replaceAll(' ', ''));
    if (rgb != null)
      return Color.fromARGB(
        255,
        int.parse(rgb[1]!),
        int.parse(rgb[2]!),
        int.parse(rgb[3]!),
      );
    if (value.startsWith('#') && value.length == 7) {
      return Color(0xff000000 | int.parse(value.substring(1), radix: 16));
    }
    return null;
  }

  Rect _rect(XmlElement node, Size size) => Rect.fromLTWH(
    _length(node.getAttribute('x'), size.width),
    _length(node.getAttribute('y'), size.height),
    _length(node.getAttribute('width'), size.width),
    _length(node.getAttribute('height'), size.height),
  );

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final root = document.rootElement;
    final patterns = <String, XmlElement>{
      for (final p in root.findAllElements('pattern'))
        if (p.getAttribute('id') case final String id) id: p,
    };
    var background = true;
    for (final node in root.childElements) {
      if (node.name.local != 'rect') continue;
      final rect = _rect(node, size);
      final fill = node.getAttribute('fill');
      final patternId = RegExp(r'^url\(#([^)]*)\)$')
          .firstMatch(fill ?? '')
          ?.group(1);
      final pattern = patterns[patternId];
      if (pattern == null) {
        final color = background && paperColor != null
            ? paperColor
            : _color(fill);
        if (color != null) canvas.drawRect(rect, Paint()..color = color);
      } else {
        final width = _length(pattern.getAttribute('width'), size.width);
        final height = _length(pattern.getAttribute('height'), size.height);
        if (width <= 0 || height <= 0) continue;
        canvas.save();
        canvas.clipRect(rect);
        // Pattern tiles in userSpaceOnUse are anchored at the SVG origin.
        for (double y = 0; y < size.height; y += height) {
          for (double x = 0; x < size.width; x += width) {
            for (final primitive in pattern.childElements) {
              final color = _color(primitive.getAttribute('fill'));
              if (color == null) continue;
              final paint = Paint()..color = color;
              if (primitive.name.local == 'rect') {
                canvas.drawRect(
                  _rect(primitive, Size(width, height)).shift(Offset(x, y)),
                  paint,
                );
              } else if (primitive.name.local == 'circle') {
                canvas.drawCircle(
                  Offset(
                    x + _length(primitive.getAttribute('cx'), width),
                    y + _length(primitive.getAttribute('cy'), height),
                  ),
                  _length(primitive.getAttribute('r'), width),
                  paint,
                );
              }
            }
          }
        }
        canvas.restore();
      }
      background = false;
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PaperSvgPainter oldDelegate) =>
      document != oldDelegate.document || paperColor != oldDelegate.paperColor;
}
