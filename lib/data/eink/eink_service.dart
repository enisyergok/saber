import 'package:flutter/services.dart';
import 'package:saber/data/eink/eink_style.dart';
import 'package:saber/data/eink/eink_texture.dart';
import 'package:saber/data/prefs.dart';

/// The parts of e-ink mode that aren't drawing: the window brightness and
/// making the paper grain ready.
abstract class EInkService {
  static const _channel = MethodChannel('defter/display');

  /// Window brightness for each [Stows.eInkBrightness] setting; -1 leaves
  /// the brightness to the system.
  static const brightnessLevels = <double>[-1, 0.7, 0.5, 0.35];

  /// The window brightness to ask for (-1 = the system's).
  static double brightnessFor({required bool eInkOn, required int setting}) {
    if (!eInkOn) return -1;
    return brightnessLevels[setting.clamp(0, brightnessLevels.length - 1)];
  }

  static var _started = false;

  /// Starts following the settings. Safe to call more than once.
  static void init() {
    if (_started) return;
    _started = true;
    stows.eInkMode.addListener(_apply);
    stows.eInkBrightness.addListener(_apply);
    stows.eInkTexture.addListener(_apply);
    _apply();
  }

  static void _apply() {
    if (stows.eInkMode.value) {
      final step = EInkStyle(texture: stows.eInkTexture.value).textureStep;
      if (step > 0) {
        EInkTexture.load(step, maxAlpha: EInkStyle.maxGrainAlpha);
      }
    }
    _setBrightness(
      brightnessFor(
        eInkOn: stows.eInkMode.value,
        setting: stows.eInkBrightness.value,
      ),
    );
  }

  static Future<void> _setBrightness(double value) async {
    try {
      await _channel.invokeMethod<void>('setBrightness', {'value': value});
    } on MissingPluginException {
      // not on Android (or in a test): nothing to dim
    } catch (_) {
      // keep the system brightness
    }
  }
}
