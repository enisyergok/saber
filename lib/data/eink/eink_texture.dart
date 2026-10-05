import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

/// The paper grain: a small tile of fixed, repeating noise.
///
/// The noise is made from a fixed seed, so it is the same on every launch
/// and every frame: nothing moves or shimmers while writing or scrolling.
/// It is drawn only with the finished page (never with the live pen layer).
abstract class EInkTexture {
  static const tileSize = 128;
  static const _seed = 0xE1AC5EED;

  /// How many different grain strengths are cached.
  static const steps = 8;

  /// The tile's pixels (RGBA, black with varying opacity). The brightest
  /// speck has opacity [maxAlpha] (0-1); most pixels are much fainter.
  static Uint8List pixels({required double maxAlpha}) {
    final data = Uint8List(tileSize * tileSize * 4);
    var state = _seed;
    for (var i = 0; i < tileSize * tileSize; i++) {
      // xorshift32
      state ^= (state << 13) & 0xFFFFFFFF;
      state ^= state >> 17;
      state ^= (state << 5) & 0xFFFFFFFF;
      final v = (state & 0xFFFF) / 0xFFFF; // 0..1
      // Squared, so there are a few dark specks among many faint ones.
      final alpha = (v * v * maxAlpha * 255).round().clamp(0, 255);
      final o = i * 4;
      data[o] = 0;
      data[o + 1] = 0;
      data[o + 2] = 0;
      data[o + 3] = alpha;
    }
    return data;
  }

  /// The strength step (0 to [steps]) for a grain opacity of 0-1 of
  /// [maxPossible].
  static int stepFor(double alpha, double maxPossible) {
    if (alpha <= 0 || maxPossible <= 0) return 0;
    return (alpha / maxPossible * steps).round().clamp(0, steps);
  }

  static final _cache = <int, Future<ui.Image>>{};
  static final _ready = <int, ui.Image>{};

  /// The tile for [step] if it has been made already, otherwise null (and
  /// [load] it first).
  static ui.Image? readyImage(int step) => _ready[step];

  /// Makes (once) and returns the tile for [step] (1 to [steps]).
  static Future<ui.Image> load(int step, {required double maxAlpha}) {
    return _cache.putIfAbsent(step, () async {
      final completer = Completer<ui.Image>();
      ui.decodeImageFromPixels(
        pixels(maxAlpha: maxAlpha * step / steps),
        tileSize,
        tileSize,
        ui.PixelFormat.rgba8888,
        completer.complete,
      );
      final image = await completer.future;
      _ready[step] = image;
      return image;
    });
  }
}
