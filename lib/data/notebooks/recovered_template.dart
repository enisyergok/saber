import 'dart:math' as math;

import 'package:xml/xml.dart';

import 'recovered_sources.dart';

/// Known package resources only: no JavaScript or external URLs are executed.
abstract class RecoveredTemplates {
  static const papers = <String>[
    'blank.svg',
    'ruledNarrow.svg',
    'ruledWide.svg',
    'grid.svg',
    'dottedgrid.svg',
    'legal.svg',
    'cornell.svg',
    'singleColumn.svg',
    'singleColumnMix.svg',
    'twoColumn.svg',
    'twoColumnLeft.svg',
    'twoColumnRight.svg',
    'threeColumn.svg',
  ];
  static final covers = List<String>.unmodifiable(
    recoveredTemplateSources.keys.where((name) => !papers.contains(name)),
  );
  static const paperAssets = <String, String>{
    'blank': 'blank.svg',
    'lined-narrow': 'ruledNarrow.svg',
    'lined-wide': 'ruledWide.svg',
    'grid': 'grid.svg',
    'dots': 'dottedgrid.svg',
    'legal': 'legal.svg',
    'pkg-cornell': 'cornell.svg',
    'pkg-single': 'singleColumn.svg',
    'pkg-single-mix': 'singleColumnMix.svg',
    'pkg-two': 'twoColumn.svg',
    'pkg-two-left': 'twoColumnLeft.svg',
    'pkg-two-right': 'twoColumnRight.svg',
    'pkg-three': 'threeColumn.svg',
  };
  static bool contains(String resource) =>
      recoveredTemplateSources.containsKey(resource);
  static const _titles = <String, (String, String)>{
    'cornell.svg': ('Cornell', 'Cornell'),
    'singleColumn.svg': ('Tek sütun', 'Single column'),
    'singleColumnMix.svg': ('Tek sütun karma', 'Mixed single column'),
    'twoColumn.svg': ('İki sütun', 'Two columns'),
    'twoColumnLeft.svg': ('Sol geniş sütun', 'Wide left column'),
    'twoColumnRight.svg': ('Sağ geniş sütun', 'Wide right column'),
    'threeColumn.svg': ('Üç sütun', 'Three columns'),
  };
  static String title(String resource, {required bool turkish}) {
    final title = _titles[resource];
    if (title != null) return turkish ? title.$1 : title.$2;
    if (resource.startsWith('enclosed')) {
      return '${turkish ? 'Çerçeveli' : 'Enclosed'} ${resource.replaceAll(RegExp(r'[^0-9]'), '')}';
    }
    if (turkish) {
      const colors = {
        'Beige': 'Bej',
        'Darkgrey': 'Koyu gri',
        'Green': 'Yeşil',
        'Grey': 'Gri',
        'White': 'Beyaz',
        'Allblack': 'Tam siyah',
        'Black': 'Siyah',
        'Blue': 'Mavi',
        'Pink': 'Pembe',
        'Red': 'Kırmızı',
        'Yellow': 'Sarı',
        'Babyblue': 'Bebek mavisi',
        'Teal': 'Turkuaz',
      };
      for (final prefix in ['plain', 'simple', 'solid']) {
        if (resource.startsWith(prefix)) {
          final color = resource
              .substring(prefix.length)
              .replaceAll('.svg', '');
          final style = {
            'plain': 'Katmanlı',
            'simple': 'Klasik',
            'solid': 'Düz',
          }[prefix];
          return '$style ${colors[color] ?? color}';
        }
      }
    }
    return resource
        .replaceAll('.svg', '')
        .replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}');
  }

  static final _cache = <String, String>{};

  /// Materialize a self-contained SVG with the package's dimension formulas.
  /// Bounds protect the UI from accidental pathological page/pattern sizes.
  static String render(
    String resource,
    double width,
    double height, {
    int? paperColor,
  }) {
    if (!width.isFinite ||
        !height.isFinite ||
        width < 100 ||
        height < 120 ||
        width > 8192 ||
        height > 8192) {
      throw ArgumentError('Unsupported template dimensions: $width x $height');
    }
    final source = recoveredTemplateSources[resource];
    if (source == null) throw ArgumentError.value(resource, 'resource');
    final key = '$resource|$width|$height|$paperColor';
    final cached = _cache[key];
    if (cached != null) return cached;
    final doc = XmlDocument.parse(source);
    final root = doc.rootElement;
    root.setAttribute('width', '$width');
    root.setAttribute('height', '$height');
    root.setAttribute('viewBox', '0 0 $width $height');
    root.setAttribute('data-noteva-template', resource);
    XmlElement byId(String id) =>
        root.descendantElements.firstWhere((e) => e.getAttribute('id') == id);
    double value(String id, String attribute) =>
        double.parse(byId(id).getAttribute(attribute)!);
    void set(String id, String attribute, double number) =>
        byId(id).setAttribute(attribute, '$number');

    if ([
      'ruledNarrow.svg',
      'ruledWide.svg',
      'legal.svg',
      'singleColumn.svg',
      'dottedgrid.svg',
      'cornell.svg',
    ].contains(resource)) {
      set('patternRect', 'height', height - value('patternRect', 'y') * 2);
      if (resource == 'singleColumn.svg' || resource == 'dottedgrid.svg') {
        set('patternRect', 'width', width - value('patternRect', 'x') * 2);
      }
      if (resource == 'cornell.svg') {
        final repeat = value('pattern', 'height');
        final rows = (value('patternRect', 'height') / repeat).round();
        final dividerHeight = math.max(0.0, (rows - 6) * repeat);
        set('verticalLine', 'height', dividerHeight);
        set('bottomLine', 'y', value('verticalLine', 'y') + dividerHeight);
      }
    } else if (resource == 'grid.svg') {
      set('horizontalLinesRect', 'width', width);
      set('verticalLinesRect', 'height', height);
    } else if (resource == 'singleColumnMix.svg') {
      final contentWidth = width - value('topLine', 'x') * 2;
      set('topLine', 'width', contentWidth);
      set('patternRect', 'width', contentWidth);
      set('patternRect', 'height', height * .5 - value('topLine', 'y'));
    } else if (resource == 'twoColumn.svg' || resource == 'threeColumn.svg') {
      final count = resource == 'twoColumn.svg' ? 2 : 3;
      final x = value('column1', 'x');
      final columnWidth = (width - x * 2 - (count - 1) * 10) / count;
      final columnHeight = height - value('column1', 'y') * 2;
      for (var i = 0; i < count; i++) {
        set('column${i + 1}', 'width', columnWidth);
        set('column${i + 1}', 'height', columnHeight);
        set('column${i + 1}', 'x', x + i * (columnWidth + 10));
      }
    } else if (resource == 'twoColumnLeft.svg' ||
        resource == 'twoColumnRight.svg') {
      final x = value('leftLines', 'x');
      final unit = (width - x * 2 - 10) / 3;
      final leftWidth = unit * (resource == 'twoColumnLeft.svg' ? 2 : 1);
      set('leftLines', 'width', leftWidth);
      set(
        'rightLines',
        'width',
        unit * (resource == 'twoColumnLeft.svg' ? 1 : 2),
      );
      set('rightLines', 'x', x + leftWidth + 10);
      final contentHeight = height - value('leftLines', 'y') * 2;
      set('leftLines', 'height', contentHeight);
      set('rightLines', 'height', contentHeight);
    } else if (resource.startsWith('simple')) {
      final leftWidth = value('leftLine', 'width');
      final remaining = width - leftWidth;
      final lineWidth = remaining * .8;
      final lineX = leftWidth + (remaining - lineWidth) / 2;
      set('midLine', 'width', lineWidth);
      set('midLine', 'x', lineX);
      for (var i = 1; i <= 4; i++) {
        set('line$i', 'x', lineX + lineWidth * .75);
        set('line$i', 'width', lineWidth * .25);
        set('line$i', 'y', height * .9 - 30 * (4 - i));
      }
    }

    double absolute(String? text, double extent) {
      if (text == null) return 0;
      return text.endsWith('%')
          ? double.parse(text.substring(0, text.length - 1)) * extent / 100
          : double.parse(text);
    }

    if (paperColor != null && papers.contains(resource)) {
      final background = root.childElements.firstWhere(
        (e) => e.name.local == 'rect',
      );
      background.setAttribute(
        'fill',
        '#${(paperColor & 0xffffff).toRadixString(16).padLeft(6, '0')}',
      );
      background.setAttribute(
        'fill-opacity',
        '${((paperColor >> 24) & 255) / 255}',
      );
    }
    final patterns = {
      for (final p in root.findAllElements('pattern')) p.getAttribute('id'): p,
    };
    var emitted = 0;
    for (final target
        in root.descendantElements
            .where((e) => e.name.local == 'rect')
            .toList()) {
      final id = RegExp(r'^url\(#([^)]*)\)$')
          .firstMatch(target.getAttribute('fill') ?? '')
          ?.group(1);
      final pattern = patterns[id];
      if (pattern == null) continue;
      final x = absolute(target.getAttribute('x'), width);
      final y = absolute(target.getAttribute('y'), height);
      final w = absolute(target.getAttribute('width'), width);
      final h = absolute(target.getAttribute('height'), height);
      final tileW = absolute(pattern.getAttribute('width'), w);
      final tileH = absolute(pattern.getAttribute('height'), h);
      if (tileW <= 0 || tileH <= 0 || w <= 0 || h <= 0)
        throw StateError('Invalid pattern rectangle');
      final rows = (h / tileH).ceil(), columns = (w / tileW).ceil();
      if ((emitted += rows * columns * pattern.childElements.length) > 100000) {
        throw ArgumentError('Template exceeds drawing budget');
      }
      final group = XmlElement(XmlName('g'));
      if (target.getAttribute('id') case final String groupId)
        group.setAttribute('id', groupId);
      for (final primitive in pattern.childElements) {
        for (var row = 0; row < rows; row++) {
          for (var column = 0; column < columns; column++) {
            final copy = primitive.copy()..removeAttribute('id');
            final circle = primitive.name.local == 'circle';
            // Matches the packaged flattener's x/y-derived tile origin.
            copy.setAttribute(
              circle ? 'cx' : 'x',
              '${x + column * tileW + absolute(primitive.getAttribute('x'), tileW)}',
            );
            copy.setAttribute(
              circle ? 'cy' : 'y',
              '${y + row * tileH + absolute(primitive.getAttribute('y'), tileH)}',
            );
            for (final (attribute, extent) in [
              ('width', tileW),
              ('height', tileH),
            ]) {
              if (primitive.getAttribute(attribute)
                  case final String dimension) {
                copy.setAttribute(attribute, '${absolute(dimension, extent)}');
              }
            }
            group.children.add(copy);
          }
        }
      }
      final parent = target.parent!;
      final index = parent.children.indexOf(target);
      parent.children[index] = group;
    }
    // Materialize relative rect geometry, including inherited-fill groups.
    for (final node in root.descendantElements) {
      if (!['rect', 'circle'].contains(node.name.local) ||
          node.ancestors.whereType<XmlElement>().any(
            (e) => e.name.local == 'defs',
          ))
        continue;
      for (final name in ['x', 'y', 'width', 'height', 'cx', 'cy', 'r']) {
        if (node.getAttribute(name) case final String text) {
          node.setAttribute(
            name,
            '${absolute(text, ['y', 'height', 'cy'].contains(name) ? height : width)}',
          );
        }
      }
    }
    for (final pattern in patterns.values) {
      pattern.parent?.children.remove(pattern);
    }
    final result = doc.toXmlString();
    if (_cache.length >= 48) _cache.remove(_cache.keys.first);
    _cache[key] = result;
    return result;
  }
}
