import 'dart:io';

import 'package:flutter/services.dart';
import 'package:saber/data/prefs.dart';

/// Device-aware tuning for EMR pens. Huawei's stack tends to report a
/// narrower, noisier pressure range than the generic Android path.
abstract final class StylusProfile {
  static const _channel = MethodChannel('defter/device');
  static var manufacturer = '';
  static var model = '';

  static Future<void> init() async {
    if (!Platform.isAndroid) return;
    try {
      final value = await _channel.invokeMethod<Map<Object?, Object?>>('info');
      manufacturer = '${value?['manufacturer'] ?? ''}'.toLowerCase();
      model = '${value?['model'] ?? ''}'.toLowerCase();
    } on MissingPluginException {
      // Device information is an optional tuning hint.
    } on PlatformException {
      // Older builds use the generic profile.
    }
  }

  static bool get isHuaweiLike =>
      manufacturer.contains('huawei') ||
      manufacturer.contains('honor') ||
      model.contains('matepad') ||
      model.contains('huawei');

  static bool get enabled => isHuaweiLike || stows.huaweiPenMode.value;

  static double get pressureResponse => enabled ? 0.62 : 0.72;

  /// Huawei's shipped wrapper exposes prediction as an independent switch.
  /// Keep it scoped to Huawei devices so generic pen behaviour is unchanged.
  static bool get vendorPredictionEnabled =>
      !enabled || stows.huaweiPenPrediction.value;

  /// Point budget used by the fast preview only; saved strokes are untouched.
  static int get predictionPointLimit =>
      enabled ? stows.huaweiPenPointLimit.value.clamp(0, 10000).toInt() : 0;
}
