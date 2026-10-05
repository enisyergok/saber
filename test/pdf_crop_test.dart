import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:saber/data/pdf/pdf_crop.dart';

void main() {
  group('PdfCrop', () {
    test('none writes nothing and reads back as none', () {
      final json = <String, dynamic>{};
      PdfCrop.none.writeTo(json);
      expect(json, isEmpty);
      expect(PdfCrop.fromJson(json), PdfCrop.none);
      expect(PdfCrop.none.isNone, isTrue);
    });

    test('survives a JSON round trip', () {
      const crop = PdfCrop(left: 0.1, top: 0.05, right: 0.2, bottom: 0.0);
      final json = <String, dynamic>{};
      crop.writeTo(json);
      expect(json.keys, unorderedEquals(['cl', 'ct', 'cr']));
      expect(PdfCrop.fromJson(json), crop);
    });

    test('integer values in JSON are read', () {
      expect(PdfCrop.fromJson({'cl': 0}), PdfCrop.none);
    });

    test('clamped keeps edges in range and leaves 20% of the page', () {
      final c = const PdfCrop(
        left: 0.9,
        top: -1,
        right: 0.9,
        bottom: double.nan,
      ).clamped();
      expect(c.left, closeTo(0.4, 1e-9));
      expect(c.right, closeTo(0.4, 1e-9));
      expect(c.top, 0);
      expect(c.bottom, 0);
      expect(1 - c.left - c.right, greaterThanOrEqualTo(0.2 - 1e-9));
    });

    test('fromJson clamps bad data from a file', () {
      final c = PdfCrop.fromJson({'cl': 5, 'cr': 5});
      expect(1 - c.left - c.right, greaterThanOrEqualTo(0.2 - 1e-9));
    });

    test('layout enlarges the kept part to fit, without stretching', () {
      const crop = PdfCrop(left: 0.1, right: 0.1);
      final l = crop.layout(const Size(600, 800), const Size(1000, 1333));
      // 480x800 kept, scale limited by height (1333/800).
      final scale = 1333 / 800;
      expect(l.visible.height, closeTo(1333, 1e-6));
      expect(l.visible.width, closeTo(480 * scale, 1e-6));
      expect(l.full.width, closeTo(600 * scale, 1e-6));
      expect(l.full.height, closeTo(800 * scale, 1e-6));
      expect(l.offset.dx, closeTo(-0.1 * 600 * scale, 1e-6));
      expect(l.offset.dy, 0);
      // aspect ratio of the kept part is unchanged
      expect(l.visible.width / l.visible.height, closeTo(480 / 800, 1e-9));
    });

    test('cropping top and bottom is limited by the page width', () {
      const crop = PdfCrop(top: 0.2, bottom: 0.2);
      final l = crop.layout(const Size(600, 800), const Size(600, 800));
      // 600x480 kept in 600x800: width limits, scale 1.
      expect(l.visible, const Size(600, 480));
      expect(l.full, const Size(600, 800));
      expect(l.offset, const Offset(0, -160));
    });

    test('no crop keeps the page as it is', () {
      final l = PdfCrop.none.layout(const Size(600, 800), const Size(600, 800));
      expect(l.visible, const Size(600, 800));
      expect(l.offset, Offset.zero);
    });
  });
}
