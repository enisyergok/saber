import 'dart:ui' show FrameTiming;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:saber/data/benchmark/pen_latency.dart';
import 'package:saber/data/prefs.dart';

/// Records how the real editor handles pen input, for [PenLatencyReport].
///
/// While [recording] is false, the only cost is one flag check per pointer
/// event.
class PenLatencyProbe {
  PenLatencyProbe._();

  static final instance = PenLatencyProbe._();

  /// Whether a recording is running.
  final recording = ValueNotifier<bool>(false);

  final _clock = Stopwatch()..start();
  PenLatencyRecorder? _recorder;
  bool _frameHooked = false;

  /// Starts a recording.
  void start() {
    if (recording.value) return;
    _recorder = PenLatencyRecorder()..start(_clock.elapsedMicroseconds);
    if (!_frameHooked) {
      // Persistent callbacks can't be removed: this one does nothing
      // while there is no recording.
      SchedulerBinding.instance.addPersistentFrameCallback(_onFrame);
      _frameHooked = true;
    }
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    recording.value = true;
  }

  /// Stops the recording and returns what it found.
  PenLatencyReport? stop() {
    if (!recording.value) return null;
    recording.value = false;
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    final recorder = _recorder;
    _recorder = null;
    if (recorder == null) return null;
    return recorder.finish(
      prediction: stows.penPrediction.value,
      displayHz: _displayHz(),
    );
  }

  double? _displayHz() {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty) return null;
    final rate = views.first.display.refreshRate;
    return rate > 0 ? rate : null;
  }

  /// Called with every pointer event the editor sees.
  void onPointer(PointerEvent event) {
    final recorder = _recorder;
    if (recorder == null || event is! PointerMoveEvent) return;
    // Touch moves are pans and zooms, not writing.
    if (event.kind == PointerDeviceKind.touch) return;
    recorder.onPointerMove(
      eventUs: event.timeStamp.inMicroseconds,
      arrivalUs: _clock.elapsedMicroseconds,
      x: event.position.dx,
      y: event.position.dy,
      kind: event.kind.name,
    );
  }

  void _onFrame(Duration frameTime) {
    _recorder?.onFrame(frameTime.inMicroseconds);
  }

  void _onTimings(List<FrameTiming> timings) {
    final recorder = _recorder;
    if (recorder == null) return;
    for (final timing in timings) {
      recorder.onFrameCost(
        spanUs: timing.totalSpan.inMicroseconds,
        buildUs: timing.buildDuration.inMicroseconds,
        rasterUs: timing.rasterDuration.inMicroseconds,
      );
    }
  }
}
