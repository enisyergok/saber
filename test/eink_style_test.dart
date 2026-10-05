import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:saber/data/eink/eink_service.dart';
import 'package:saber/data/eink/eink_style.dart';

/// Applies a 4x5 colour matrix (offsets in 0-255) to an opaque colour.
Color _apply(List<double> m, Color c) {
  double row(int r) =>
      (m[r * 5] * c.r + m[r * 5 + 1] * c.g + m[r * 5 + 2] * c.b) * 255 +
      m[r * 5 + 4];
  int byte(double v) => v.round().clamp(0, 255);
  return Color.fromARGB(255, byte(row(0)), byte(row(1)), byte(row(2)));
}

int _r(Color c) => (c.r * 255).round();
int _g(Color c) => (c.g * 255).round();
int _b(Color c) => (c.b * 255).round();

/// Every combination of the two settings that decide paper and ink.
Iterable<EInkStyle> get _allStyles => [
  for (final warmth in [0.0, 0.4, 0.7, 1.0])
    for (final darkness in [0.0, 0.5, 0.8, 1.0])
      EInkStyle(paperWarmth: warmth, inkDarkness: darkness),
];

void main() {
  group('E-ink style:', () {
    test('paper goes from neutral to warm', () {
      expect(const EInkStyle(paperWarmth: 0).paper, const Color(0xFFEEEEEC));
      expect(const EInkStyle(paperWarmth: 1).paper, const Color(0xFFEBE3CE));
      // warmer paper has less blue
      expect(
        _b(const EInkStyle(paperWarmth: 0.8).paper),
        lessThan(_b(const EInkStyle(paperWarmth: 0.2).paper)),
      );
    });

    test('ink is a grey, darker with more darkness', () {
      final soft = const EInkStyle(inkDarkness: 0).ink;
      final dark = const EInkStyle(inkDarkness: 1).ink;
      expect(_r(soft), _g(soft));
      expect(_g(soft), _b(soft));
      expect(_r(dark), lessThan(_r(soft)));
      expect(_r(dark), lessThan(0x20));
    });

    test('out-of-range settings are clamped, not extrapolated', () {
      expect(
        const EInkStyle(paperWarmth: 5).paper,
        const EInkStyle(paperWarmth: 1).paper,
      );
      expect(
        const EInkStyle(inkDarkness: -3).ink,
        const EInkStyle(inkDarkness: 0).ink,
      );
    });

    test('a black pen is drawn with the ink colour', () {
      for (final style in _allStyles) {
        expect(style.mapInk(const Color(0xFF000000)), style.ink);
      }
    });

    test('pen colours become greys that keep their order', () {
      const style = EInkStyle();
      const red = Color(0xFFFF0000);
      const blue = Color(0xFF0000FF);
      const green = Color(0xFF00FF00);
      const yellow = Color(0xFFFFFF00);
      for (final color in [red, blue, green, yellow]) {
        final mapped = style.mapInk(color);
        expect(_r(mapped), _g(mapped));
        expect(_g(mapped), _b(mapped));
      }
      // by luminance: blue < red < green < yellow
      expect(_r(style.mapInk(blue)), lessThan(_r(style.mapInk(red))));
      expect(_r(style.mapInk(red)), lessThan(_r(style.mapInk(green))));
      expect(_r(style.mapInk(green)), lessThan(_r(style.mapInk(yellow))));
    });

    test('transparency of a pen colour is kept (highlighters)', () {
      const style = EInkStyle();
      final mapped = style.mapInk(const Color(0x80FFFF00));
      expect(mapped.a, closeTo(0x80 / 255, 0.01));
    });

    test('every pen stays readable on the paper', () {
      // WCAG: 4.5:1 is the bar for text; 3:1 for graphics. Writing is
      // text, so a black pen must pass 4.5:1 at every setting, and even a
      // white pen (the lightest ink there is) still shows at 3:1.
      const colors = [
        Color(0xFF000000),
        Color(0xFFFF0000),
        Color(0xFF0000FF),
        Color(0xFF00AA00),
        Color(0xFFFFFFFF),
      ];
      for (final style in _allStyles) {
        expect(
          EInkStyle.contrastRatio(style.mapInk(colors.first), style.paper),
          greaterThanOrEqualTo(4.5),
          reason:
              'black pen at warmth ${style.paperWarmth}, '
              'darkness ${style.inkDarkness}',
        );
        for (final color in colors) {
          expect(
            EInkStyle.contrastRatio(style.mapInk(color), style.paper),
            greaterThanOrEqualTo(3.0),
            reason:
                '$color at warmth ${style.paperWarmth}, '
                'darkness ${style.inkDarkness}',
          );
        }
      }
    });

    test('the default look reaches AAA contrast for black ink', () {
      const style = EInkStyle();
      expect(
        EInkStyle.contrastRatio(style.ink, style.paper),
        greaterThanOrEqualTo(7),
      );
    });

    test('the default page becomes paper, darker pages stay readable', () {
      const style = EInkStyle();
      expect(style.mapPaper(const Color(0xFFFCFCFC)), style.paper);
      expect(style.mapPaper(const Color(0xFFFFFFFF)), style.paper);
      // a mid grey page is darker paper
      final grey = style.mapPaper(const Color(0xFF808080));
      expect(_r(grey), lessThan(_r(style.paper)));
      // a black page is not allowed to hide the ink
      final black = style.mapPaper(const Color(0xFF000000));
      expect(
        EInkStyle.contrastRatio(style.ink, black),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('pictures: black becomes ink, white becomes paper', () {
      for (final style in _allStyles) {
        final matrix = style.imageMatrix;
        expect(matrix, hasLength(20));
        final black = _apply(matrix, const Color(0xFF000000));
        final white = _apply(matrix, const Color(0xFFFFFFFF));
        expect((_r(black) - _r(style.ink)).abs(), lessThanOrEqualTo(1));
        expect((_r(white) - _r(style.paper)).abs(), lessThanOrEqualTo(1));
        // a photo's white never glows brighter than the page
        expect(_r(white), lessThanOrEqualTo(_r(style.paper) + 1));
        expect(_r(white), greaterThan(_r(black)));
      }
    });

    test('pictures: colour is dropped, order of tones is kept', () {
      final matrix = const EInkStyle().imageMatrix;
      var previous = -1;
      for (var level = 0; level <= 255; level += 15) {
        final out = _apply(matrix, Color.fromARGB(255, level, level, level));
        expect(_r(out), greaterThanOrEqualTo(previous));
        previous = _r(out);
      }
      // two very different colours of the same brightness look the same
      final a = _apply(matrix, const Color(0xFF8A5A2B));
      final b = _apply(matrix, const Color(0xFF2B5A8A));
      expect((_r(a) - _r(b)).abs(), lessThanOrEqualTo(40));
      // and red, green, blue come out as the same grey family (no hue left)
      final tint = _apply(matrix, const Color(0xFFFF0000));
      expect((_r(tint) - _g(tint)).abs(), lessThan(40));
    });

    test('pictures keep their transparency', () {
      final matrix = const EInkStyle().imageMatrix;
      expect(matrix.sublist(15), [0, 0, 0, 1, 0]);
    });

    test('equal styles are equal', () {
      expect(const EInkStyle(), const EInkStyle());
      expect(const EInkStyle().hashCode, const EInkStyle().hashCode);
      expect(const EInkStyle(), isNot(const EInkStyle(texture: 0.9)));
    });

    test('texture strength maps to a cached step', () {
      expect(const EInkStyle(texture: 0).textureStep, 0);
      expect(const EInkStyle(texture: 1).textureStep, 8);
      expect(const EInkStyle(texture: 0.5).textureStep, 4);
      expect(const EInkStyle(texture: 7).textureStep, 8);
    });
  });

  group('E-ink brightness:', () {
    test('the system decides while the mode is off', () {
      for (var setting = 0; setting < 4; setting++) {
        expect(EInkService.brightnessFor(eInkOn: false, setting: setting), -1);
      }
    });

    test('settings dim the window, setting 0 leaves it alone', () {
      expect(EInkService.brightnessFor(eInkOn: true, setting: 0), -1);
      expect(EInkService.brightnessFor(eInkOn: true, setting: 1), 0.7);
      expect(EInkService.brightnessFor(eInkOn: true, setting: 3), 0.35);
    });

    test('a stored value out of range does not crash', () {
      expect(EInkService.brightnessFor(eInkOn: true, setting: 99), 0.35);
      expect(EInkService.brightnessFor(eInkOn: true, setting: -5), -1);
    });
  });
}
