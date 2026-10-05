import 'package:flutter_test/flutter_test.dart';
import 'package:saber/data/eink/eink_texture.dart';

void main() {
  group('E-ink paper texture:', () {
    test('is exactly the same every time (nothing shimmers)', () {
      final a = EInkTexture.pixels(maxAlpha: 0.07);
      final b = EInkTexture.pixels(maxAlpha: 0.07);
      expect(a, b);
    });

    test('has the size of one tile, 4 bytes a pixel', () {
      expect(
        EInkTexture.pixels(maxAlpha: 0.07),
        hasLength(EInkTexture.tileSize * EInkTexture.tileSize * 4),
      );
    });

    test('is black grain: colour channels are zero, only opacity varies', () {
      final data = EInkTexture.pixels(maxAlpha: 0.07);
      for (var i = 0; i < data.length; i += 4) {
        expect(data[i], 0);
        expect(data[i + 1], 0);
        expect(data[i + 2], 0);
      }
    });

    test('never gets darker than the strength allows', () {
      for (final maxAlpha in [0.02, 0.07]) {
        final data = EInkTexture.pixels(maxAlpha: maxAlpha);
        var peak = 0;
        for (var i = 3; i < data.length; i += 4) {
          if (data[i] > peak) peak = data[i];
        }
        expect(peak, lessThanOrEqualTo((maxAlpha * 255).ceil()));
        // and it does use most of the range, so the grain is visible
        expect(peak, greaterThanOrEqualTo((maxAlpha * 255 * 0.8).floor()));
      }
    });

    test('is faint on average, so small text stays sharp', () {
      final data = EInkTexture.pixels(maxAlpha: 0.07);
      var sum = 0;
      for (var i = 3; i < data.length; i += 4) {
        sum += data[i];
      }
      final mean = sum / (data.length / 4);
      // average opacity of the grain: well under 3% black
      expect(mean / 255, lessThan(0.03));
    });

    test('no strength means no grain', () {
      final data = EInkTexture.pixels(maxAlpha: 0);
      expect(data.every((byte) => byte == 0), isTrue);
    });

    test('is not just one repeated value', () {
      final data = EInkTexture.pixels(maxAlpha: 0.07);
      final values = <int>{
        for (var i = 3; i < data.length; i += 4) data[i],
      };
      expect(values.length, greaterThan(8));
    });
  });
}
