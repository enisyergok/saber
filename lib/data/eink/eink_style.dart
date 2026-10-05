import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:saber/data/eink/eink_texture.dart';

/// How the "e-ink mode" looks: a viewing preference only. Notes keep their
/// own colours; everything here is applied while drawing.
///
/// This imitates an e-ink screen on an ordinary LCD/OLED panel. It cannot
/// reproduce what makes real e-ink special (reflective, holds an image with
/// no power, physical refresh).
@immutable
class EInkStyle {
  const new({
    this.paperWarmth = 0.4,
    this.inkDarkness = 0.8,
    this.texture = 0.3,
    this.refreshEffect = true,
  });

  /// 0 = neutral grey-white paper, 1 = warm cream paper.
  final double paperWarmth;

  /// 0 = soft dark grey ink, 1 = near-black ink.
  final double inkDarkness;

  /// Strength of the paper grain, 0 (none) to 1.
  final double texture;

  /// Whether page turns and "refresh page" show the short e-ink refresh.
  final bool refreshEffect;

  static const _paperNeutral = Color(0xFFEEEEEC);
  static const _paperWarm = Color(0xFFEBE3CE);

  /// The luminance (0-1) of the default page colour; pages this light or
  /// lighter become [paper].
  static const _whitePage = 0.988;

  /// Grey level (0-255) of a white pen. Colour pens land between [ink] and
  /// this, so every pen keeps at least 3:1 contrast against the paper.
  static const _lightestInk = 128.0;

  /// The darkest page a note may have in this mode (as a share of [paper]):
  /// dark pages would hide the ink.
  static const _darkestPage = 0.72;

  /// The most opaque a speck of paper grain gets at full [texture].
  static const maxGrainAlpha = 0.07;

  Color get paper =>
      Color.lerp(_paperNeutral, _paperWarm, paperWarmth.clamp(0.0, 1.0))!;

  /// The darkest ink: what a black pen is drawn with.
  Color get ink => Color.fromARGB(255, _inkLevel, _inkLevel, _inkLevel);

  int get _inkLevel =>
      lerpDouble(0x4A, 0x10, inkDarkness.clamp(0.0, 1.0))!.round();

  /// Opacity (0-1) of the darkest grain speck.
  double get grainAlpha => texture.clamp(0.0, 1.0) * maxGrainAlpha;

  /// Which cached grain tile (0 = none) shows this [texture] strength.
  int get textureStep =>
      (texture.clamp(0.0, 1.0) * EInkTexture.steps).round();

  /// A pen colour as it shows on screen: grey, dark for dark colours.
  /// Transparency is kept (highlighters stay see-through).
  Color mapInk(Color color) {
    final level = _inkLevel + (_lightestInk - _inkLevel) * luma(color);
    return Color.from(
      alpha: color.a,
      red: level / 255,
      green: level / 255,
      blue: level / 255,
    );
  }

  /// A page colour as it shows on screen: the default (near-white) page
  /// becomes [paper], other colours become darker or lighter paper.
  Color mapPaper(Color page) {
    final lum = luma(page);
    if (lum >= _whitePage - 0.01) return paper;
    final k = (lum / _whitePage).clamp(_darkestPage, 1.0);
    final base = paper;
    return Color.from(
      alpha: 1,
      red: base.r * k,
      green: base.g * k,
      blue: base.b * k,
    );
  }

  /// A 4x5 colour matrix (the `ColorFilter.matrix` format) that turns any
  /// picture into the ink/paper range: black becomes [ink], white becomes
  /// [paper] (never lighter, so a photo's white doesn't glow against the
  /// page) and colours become the grey of the same brightness.
  List<double> get imageMatrix {
    final inkColor = ink;
    final paperColor = paper;
    List<double> row(double inkC, double paperC) {
      final range = paperC - inkC;
      return [
        range * _lumaR,
        range * _lumaG,
        range * _lumaB,
        0,
        inkC * 255,
      ];
    }

    return [
      ...row(inkColor.r, paperColor.r),
      ...row(inkColor.g, paperColor.g),
      ...row(inkColor.b, paperColor.b),
      0, 0, 0, 1, 0, //
    ];
  }

  /// Rec. 709 luma, 0-1.
  static double luma(Color c) => _lumaR * c.r + _lumaG * c.g + _lumaB * c.b;

  static const _lumaR = 0.2126;
  static const _lumaG = 0.7152;
  static const _lumaB = 0.0722;

  /// WCAG contrast ratio between two opaque colours, 1 to 21.
  static double contrastRatio(Color a, Color b) {
    final la = _relativeLuminance(a);
    final lb = _relativeLuminance(b);
    final hi = la > lb ? la : lb;
    final lo = la > lb ? lb : la;
    return (hi + 0.05) / (lo + 0.05);
  }

  static double _relativeLuminance(Color c) {
    double channel(double v) =>
        v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    return _lumaR * channel(c.r) +
        _lumaG * channel(c.g) +
        _lumaB * channel(c.b);
  }

  EInkStyle copyWith({
    double? paperWarmth,
    double? inkDarkness,
    double? texture,
    bool? refreshEffect,
  }) => EInkStyle(
    paperWarmth: paperWarmth ?? this.paperWarmth,
    inkDarkness: inkDarkness ?? this.inkDarkness,
    texture: texture ?? this.texture,
    refreshEffect: refreshEffect ?? this.refreshEffect,
  );

  @override
  bool operator ==(Object other) =>
      other is EInkStyle &&
      other.paperWarmth == paperWarmth &&
      other.inkDarkness == inkDarkness &&
      other.texture == texture &&
      other.refreshEffect == refreshEffect;

  @override
  int get hashCode =>
      Object.hash(paperWarmth, inkDarkness, texture, refreshEffect);
}
