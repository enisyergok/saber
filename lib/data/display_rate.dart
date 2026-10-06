import 'dart:collection';

import 'package:flutter/services.dart';

/// What the device says about how fast its screen is drawn.
class DisplayRateInfo {
  const new({
    this.max,
    this.mode,
    this.app,
    this.sdk,
    this.maker,
    this.model,
    this.details,
  });

  /// The fastest rate the screen has at its current resolution, in Hz.
  final double? max;

  /// The rate of the screen mode that is in use.
  final double? mode;

  /// The rate the system lets this app draw at.
  final double? app;

  /// The Android version (API level).
  final int? sdk;
  final String? maker;
  final String? model;

  /// The screen's modes and what the app asked for, as text.
  final String? details;

  static double? _number(Object? value) =>
      value is num && value > 0 ? value.toDouble() : null;

  factory fromMap(Map<Object?, Object?> map) => DisplayRateInfo(
    max: _number(map['max']),
    mode: _number(map['mode']),
    app: _number(map['app']),
    sdk: map['sdk'] is int ? map['sdk'] as int : null,
    maker: map['maker'] is String ? map['maker'] as String : null,
    model: map['model'] is String ? map['model'] as String : null,
    details: map['details'] is String ? map['details'] as String : null,
  );
}

/// What the measured drawing rate means on this screen.
enum DisplayRateVerdict {
  /// Not enough is known yet.
  unknown,

  /// The screen has no faster rate than the usual 60 Hz.
  noFasterMode,

  /// The app is drawn at the screen's fastest rate.
  full,

  /// The screen can go faster, but the system draws the app slower.
  heldBack,
}

/// How fast the screen is and how fast the app is really drawn on it.
abstract class DisplayRate {
  static const channel = MethodChannel('defter/display');

  /// A screen up to this rate has no "fast" mode.
  static const usualRate = 70.0;

  /// The measured rate counts as the screen's rate from this part of it.
  /// (Measured rates are a little under the nominal one: 119.9 for 120.)
  static const fullFrom = 0.9;

  /// What the device says, or null where that isn't known (not Android).
  static Future<DisplayRateInfo?> read() async {
    try {
      final map = await channel.invokeMapMethod<Object?, Object?>(
        'refreshInfo',
      );
      return map == null ? null : DisplayRateInfo.fromMap(map);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// Opens the device's screen settings. False if that isn't possible.
  static Future<bool> openSettings() async {
    try {
      return await channel.invokeMethod<bool>('openDisplaySettings') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Compares the rate the app is really drawn at ([measured]) with the
  /// fastest rate of the screen ([max]).
  static DisplayRateVerdict verdict({
    required double? max,
    required double? measured,
  }) {
    if (max == null) return .unknown;
    if (max <= usualRate) return .noFasterMode;
    if (measured == null) return .unknown;
    return measured >= max * fullFrom ? .full : .heldBack;
  }
}

/// Works out how many frames a second are drawn from the times at which
/// frames start.
///
/// The usual time between two frames is used, not the average: a frame
/// that was late does not make the screen look slower than it is.
class FrameRateMeter {
  new({this.keep = 90, this.needed = 12})
    : assert(needed >= 2 && keep >= needed);

  /// How many of the latest gaps between frames are looked at.
  final int keep;

  /// How many gaps are needed before a rate is given.
  final int needed;

  final _gaps = ListQueue<int>();
  Duration? _last;

  /// Tells the meter that a frame started at [time] (on any clock that
  /// only moves forward).
  void add(Duration time) {
    final last = _last;
    _last = time;
    if (last == null) return;
    final gap = (time - last).inMicroseconds;
    // The clock was restarted, or two frames were reported as one.
    if (gap <= 0) return;
    _gaps.addLast(gap);
    while (_gaps.length > keep) {
      _gaps.removeFirst();
    }
  }

  /// Forgets what was measured.
  void clear() {
    _gaps.clear();
    _last = null;
  }

  /// Frames per second, or null while too few frames have been seen.
  double? get rate {
    if (_gaps.length < needed) return null;
    final sorted = _gaps.toList()..sort();
    final middle = sorted[sorted.length ~/ 2];
    return 1e6 / middle;
  }
}
