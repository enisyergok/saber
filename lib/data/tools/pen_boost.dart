import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

/// While a pen stroke is being drawn, asks Android to keep the processor
/// and graphics chip fast enough for the drawing (a performance hint).
///
/// Between short bursts of work they idle down, and the first frames after
/// that come late. Telling the system how long each frame took, against a
/// target of a few milliseconds, has it keep the speed up for the length of
/// the stroke. Only a request: where it isn't supported, nothing changes.
class PenBoost {
  PenBoost._();

  static const _channel = MethodChannel('defter/boost');

  static bool _on = false;

  /// Whether the pen's stroke is being boosted right now.
  static bool get isOn => _on;

  /// The pen touched down.
  static Future<void> start() async {
    if (_on || kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    _on = true;
    try {
      final granted = await _channel.invokeMethod<bool>('start') ?? false;
      if (!_on) {
        // The stroke ended while this was being asked.
        if (granted) unawaited(_channel.invokeMethod<void>('stop'));
        return;
      }
      if (granted) {
        SchedulerBinding.instance.addTimingsCallback(_onTimings);
      } else {
        _on = false;
      }
    } on Object {
      _on = false;
    }
  }

  /// The pen lifted.
  static Future<void> stop() async {
    if (!_on) return;
    _on = false;
    try {
      SchedulerBinding.instance.removeTimingsCallback(_onTimings);
      await _channel.invokeMethod<void>('stop');
    } on Object {
      // Nothing to undo.
    }
  }

  static void _onTimings(List<FrameTiming> timings) {
    if (!_on) return;
    for (final t in timings) {
      final micros = t.buildDuration.inMicroseconds +
          t.rasterDuration.inMicroseconds;
      unawaited(
        _channel
            .invokeMethod<void>('report', {'micros': micros})
            .catchError((Object _) {}),
      );
    }
  }
}
