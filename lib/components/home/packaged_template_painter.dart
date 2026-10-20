import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:xml/xml.dart';

import '../../data/notebooks/recovered_template.dart';

/// The package's rect/circle/gradient subset, shared by paper and cover previews.
class PackagedTemplatePainter extends CustomPainter {
  PackagedTemplatePainter(this.resource, this.pageSize, {this.paperColor})
    : document = XmlDocument.parse(
        RecoveredTemplates.render(
          resource,
          pageSize.width,
          pageSize.height,
          paperColor: paperColor?.toARGB32(),
        ),
      );
  final String resource;
  final Size pageSize;
  final Color? paperColor;
  final XmlDocument document;

  static Color _color(String text) {
    if (text.startsWith('#'))
      return Color(0xff000000 | int.parse(text.substring(1), radix: 16));
    final rgb = RegExp(r'\d+')
        .allMatches(text)
        .map((m) => int.parse(m[0]!))
        .toList();
    if (text.startsWith('rgb') && rgb.length == 3)
      return Color.fromARGB(255, rgb[0], rgb[1], rgb[2]);
    return switch (text) {
      'white' => Colors.white,
      'transparent' => Colors.transparent,
      _ => Colors.black,
    };
  }

  static double _number(String? text, [double fallback = 0]) =>
      double.tryParse(text ?? '') ?? fallback;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / pageSize.width, size.height / pageSize.height);
    canvas.clipRect(Offset.zero & pageSize);
    final gradients = {
      for (final g in document.rootElement.findAllElements('linearGradient'))
        g.getAttribute('id'): g,
    };
    void draw(XmlElement node, String inheritedFill, double inheritedOpacity) {
      final kind = node.name.local;
      if (kind == 'defs') return;
      final fill = node.getAttribute('fill') ?? inheritedFill;
      final opacity =
          inheritedOpacity * _number(node.getAttribute('fill-opacity'), 1);
      final rect = Rect.fromLTWH(
        _number(node.getAttribute('x')),
        _number(node.getAttribute('y')),
        _number(node.getAttribute('width')),
        _number(node.getAttribute('height')),
      );
      if (['rect', 'circle'].contains(kind) && fill != 'none') {
        final paint = Paint();
        final gradientId = RegExp(r'^url\(#([^)]*)\)$')
            .firstMatch(fill)
            ?.group(1);
        final gradient = gradients[gradientId];
        if (gradient != null) {
          final colors = <Color>[], stops = <double>[];
          for (final stop in gradient.childElements.where(
            (e) => e.name.local == 'stop',
          )) {
            final styles = <String, String>{};
            for (final item in (stop.getAttribute('style') ?? '').split(';')) {
              final pair = item.split(':');
              if (pair.length == 2) styles[pair[0].trim()] = pair[1].trim();
            }
            colors.add(
              _color(
                stop.getAttribute('stop-color') ??
                    styles['stop-color'] ??
                    'black',
              ).withValues(
                alpha:
                    _number(
                      stop.getAttribute('stop-opacity') ??
                          styles['stop-opacity'],
                      1,
                    ) *
                    opacity,
              ),
            );
            final offset = stop.getAttribute('offset') ?? '0';
            stops.add(
              offset.endsWith('%')
                  ? double.parse(offset.substring(0, offset.length - 1)) / 100
                  : double.parse(offset),
            );
          }
          double fraction(String key, String fallback) {
            final text = gradient.getAttribute(key) ?? fallback;
            return text.endsWith('%')
                ? double.parse(text.substring(0, text.length - 1)) / 100
                : double.parse(text);
          }

          paint.shader = ui.Gradient.linear(
            rect.topLeft +
                Offset(
                  rect.width * fraction('x1', '0'),
                  rect.height * fraction('y1', '0'),
                ),
            rect.topLeft +
                Offset(
                  rect.width * fraction('x2', '1'),
                  rect.height * fraction('y2', '0'),
                ),
            colors,
            stops,
          );
        } else {
          paint.color = _color(fill).withValues(alpha: opacity);
        }
        if (kind == 'circle') {
          canvas.drawCircle(
            Offset(
              _number(node.getAttribute('cx')),
              _number(node.getAttribute('cy')),
            ),
            _number(node.getAttribute('r')),
            paint,
          );
        } else {
          canvas.drawRect(rect, paint);
        }
      }
      for (final child in node.childElements) {
        draw(child, fill, opacity);
      }
    }

    draw(document.rootElement, 'black', 1);
    canvas.restore();
  }

  @override
  bool shouldRepaint(PackagedTemplatePainter old) =>
      resource != old.resource ||
      pageSize != old.pageSize ||
      paperColor != old.paperColor;
}
