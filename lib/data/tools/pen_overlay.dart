import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

/// Has Android draw the pen's line straight to the screen while it is being
/// written (see InkOverlay.kt), so the ink is not held up by the app's own
/// drawing.
///
/// The Android side draws the pen's real points as they arrive, in the
/// colour and width this class tells it the pen has. When the stroke is
/// done the app draws it itself, as always, and this clears the overlay.
/// Nothing is predicted. Where the overlay can't be made, nothing changes.
class PenOverlay {
  PenOverlay._();

  static const _channel = MethodChannel('defter/ink');

  static String? _last;

  /// How many raw pressures the pressure table holds.
  static const pressureSteps = 17;

  /// Whether the overlay is available (Android only).
  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Tells Android how the next stroke is drawn, or [config] null to turn
  /// the overlay off. Does nothing when [config] is the same as before.
  static void sync(Map<String, Object?>? config) {
    if (!isSupported) return;
    final key = config?.toString();
    if (key == _last) return;
    _last = key;
    unawaited(_send('config', config));
  }

  /// Forgets what was sent, so the next [sync] sends it again.
  static void reset() => _last = null;

  /// Clears the overlay once the app has drawn the stroke itself: two frames
  /// from now, so that the stroke is on the screen first.
  static void clearSoon() {
    if (!isSupported || _last == null || _last == 'null') return;
    final binding = SchedulerBinding.instance;
    binding.addPostFrameCallback((_) {
      binding.addPostFrameCallback((_) => unawaited(_send('clear', null)));
      binding.scheduleFrame();
    });
    binding.scheduleFrame();
  }

  static Future<void> _send(String method, Object? arguments) async {
    try {
      await _channel.invokeMethod<Object?>(method, arguments);
    } on Object {
      // Only an aid: without it the app draws as before.
    }
  }
}
