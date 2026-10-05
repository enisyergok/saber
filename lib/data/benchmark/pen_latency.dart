import 'dart:math' as math;

/// Collects what happens between the pen touching the screen and the frame
/// that shows it, and turns it into a [PenLatencyReport].
///
/// All times are in microseconds. Pointer event times and frame (vsync)
/// times come from the same clock, so `frame - event` is how old an input
/// was when the frame that draws it started.
class PenLatencyRecorder {
  final _eventUs = <int>[];
  final _arrivalUs = <int>[];
  final _xs = <double>[];
  final _ys = <double>[];
  final _kinds = <String>{};

  final _frameUs = <int>[];
  final _ageUs = <int>[];
  final _batchSizes = <int>[];
  final _spanUs = <int>[];
  final _buildUs = <int>[];
  final _rasterUs = <int>[];

  int _pending = 0;
  int _newestPendingEventUs = 0;
  int _startedAtUs = 0;
  int _endedAtUs = 0;

  /// The recording started at [nowUs] (any clock, only the span is used).
  void start(int nowUs) {
    _startedAtUs = nowUs;
    _endedAtUs = nowUs;
  }

  /// A pen move event: [eventUs] is its own time stamp, [arrivalUs] when the
  /// app saw it.
  void onPointerMove({
    required int eventUs,
    required int arrivalUs,
    required double x,
    required double y,
    required String kind,
  }) {
    _eventUs.add(eventUs);
    _arrivalUs.add(arrivalUs);
    _xs.add(x);
    _ys.add(y);
    _kinds.add(kind);
    _pending++;
    _newestPendingEventUs = math.max(_newestPendingEventUs, eventUs);
    _endedAtUs = math.max(_endedAtUs, arrivalUs);
  }

  /// A frame started at [frameUs] (its vsync time).
  void onFrame(int frameUs) {
    _frameUs.add(frameUs);
    if (_pending > 0) {
      _ageUs.add(frameUs - _newestPendingEventUs);
      _batchSizes.add(_pending);
      _pending = 0;
    }
  }

  /// How long a finished frame took: [spanUs] from vsync to the end of
  /// rasterising, split into [buildUs] and [rasterUs].
  void onFrameCost({
    required int spanUs,
    required int buildUs,
    required int rasterUs,
  }) {
    _spanUs.add(spanUs);
    _buildUs.add(buildUs);
    _rasterUs.add(rasterUs);
  }

  PenLatencyReport finish({
    required bool prediction,
    double? displayHz,
    String? displayModes,
  }) {
    // Time between consecutive pen events (ignoring pauses between strokes).
    final intervals = <double>[];
    final speeds = <double>[];
    for (var i = 1; i < _eventUs.length; i++) {
      final dt = _eventUs[i] - _eventUs[i - 1];
      if (dt <= 0 || dt > 100000) continue;
      intervals.add(dt.toDouble());
      final dist = math.sqrt(
        math.pow(_xs[i] - _xs[i - 1], 2) + math.pow(_ys[i] - _ys[i - 1], 2),
      );
      speeds.add(dist / (dt / 1e6));
    }

    final frameIntervals = <double>[];
    for (var i = 1; i < _frameUs.length; i++) {
      final dt = _frameUs[i] - _frameUs[i - 1];
      // pauses with nothing to draw are not slow frames
      if (dt > 0 && dt < 100000) frameIntervals.add(dt.toDouble());
    }
    final frameMedian = _percentile(frameIntervals, 50);
    final slowFrames = frameMedian == 0
        ? 0
        : frameIntervals.where((dt) => dt > frameMedian * 1.5).length;

    // Some devices stamp pen events with a different clock than the one the
    // frames use (the two can be days apart). The offset is constant, so the
    // ages are then measured from the newest one that was seen right before
    // a frame, which cannot be negative in reality.
    final rawAgesMs = _ageUs.map((e) => e / 1000).toList();
    final medianAge = _percentile(rawAgesMs, 50);
    final clocksDiffer = rawAgesMs.isNotEmpty &&
        (medianAge < -50 || medianAge > 1000);
    final shiftMs = clocksDiffer ? rawAgesMs.reduce(math.min) : 0.0;
    final agesMs = rawAgesMs.map((e) => e - shiftMs);

    return PenLatencyReport(
      clocksDiffer: clocksDiffer,
      displayModes: displayModes,
      seconds: (_endedAtUs - _startedAtUs) / 1e6,
      events: _eventUs.length,
      kinds: _kinds.toList()..sort(),
      prediction: prediction,
      displayHz: displayHz,
      eventIntervalMs: _percentile(intervals, 50) / 1000,
      frames: _frameUs.length,
      measuredHz: frameMedian == 0 ? 0 : 1e6 / frameMedian,
      slowFrames: slowFrames,
      slowFrameShare: frameIntervals.isEmpty
          ? 0
          : slowFrames / frameIntervals.length,
      eventsPerFrame: _percentile(_batchSizes.map((e) => e.toDouble()), 50),
      ageMs: LatencyStat.of(agesMs),
      spanMs: LatencyStat.of(_spanUs.map((e) => e / 1000)),
      buildMs: LatencyStat.of(_buildUs.map((e) => e / 1000)),
      rasterMs: LatencyStat.of(_rasterUs.map((e) => e / 1000)),
      medianSpeed: _percentile(speeds, 50),
      fastSpeed: _percentile(speeds, 90),
    );
  }

  static double _percentile(Iterable<num> values, double p) {
    final sorted = values.map((e) => e.toDouble()).toList()..sort();
    if (sorted.isEmpty) return 0;
    final rank = (p / 100) * (sorted.length - 1);
    final low = rank.floor();
    final high = rank.ceil();
    return sorted[low] + (sorted[high] - sorted[low]) * (rank - low);
  }
}

/// Median, 95th percentile and largest of a set of measurements.
class LatencyStat {
  const LatencyStat(this.p50, this.p95, this.max, this.count);

  factory LatencyStat.of(Iterable<double> values) {
    final list = values.toList();
    if (list.isEmpty) return const LatencyStat(0, 0, 0, 0);
    return LatencyStat(
      PenLatencyRecorder._percentile(list, 50),
      PenLatencyRecorder._percentile(list, 95),
      list.reduce(math.max),
      list.length,
    );
  }

  final double p50;
  final double p95;
  final double max;
  final int count;
}

/// The result of a pen latency recording.
class PenLatencyReport {
  const PenLatencyReport({
    required this.clocksDiffer,
    required this.displayModes,
    required this.seconds,
    required this.events,
    required this.kinds,
    required this.prediction,
    required this.displayHz,
    required this.eventIntervalMs,
    required this.frames,
    required this.measuredHz,
    required this.slowFrames,
    required this.slowFrameShare,
    required this.eventsPerFrame,
    required this.ageMs,
    required this.spanMs,
    required this.buildMs,
    required this.rasterMs,
    required this.medianSpeed,
    required this.fastSpeed,
  });

  /// Pen events and frames use different clocks on this device, so the
  /// event ages are relative to the freshest event seen.
  final bool clocksDiffer;

  /// The display modes the device offers and the one in use, if known.
  final String? displayModes;

  final double seconds;
  final int events;
  final List<String> kinds;
  final bool prediction;
  final double? displayHz;

  /// Median time between two pen events.
  final double eventIntervalMs;
  final int frames;
  final double measuredHz;
  final int slowFrames;
  final double slowFrameShare;

  /// Median number of pen events that arrive for one frame.
  final double eventsPerFrame;
  final LatencyStat ageMs;
  final LatencyStat spanMs;
  final LatencyStat buildMs;
  final LatencyStat rasterMs;

  /// Median and fast (90th percentile) pen speed, in logical pixels per
  /// second.
  final double medianSpeed;
  final double fastSpeed;

  /// Whether there is enough data to say anything.
  bool get hasData => events >= 20 && ageMs.count >= 10;

  /// How old the newest pen position is when a frame starts, plus how long
  /// the frame takes to reach the screen buffer: the software part of the
  /// delay between pen and ink, in milliseconds. The screen's own delay is
  /// not included.
  double get softwareLatencyMs => ageMs.p50 + spanMs.p50;

  /// Same, for the slower frames (95th percentile of each part).
  double get softwareLatencyWorstMs => ageMs.p95 + spanMs.p95;

  /// The time one frame takes at the measured rate, in milliseconds. A
  /// finished frame waits for the next screen refresh, so roughly this much
  /// comes on top of [softwareLatencyMs].
  double get frameIntervalMs => measuredHz <= 0 ? 0 : 1000 / measuredHz;

  /// [softwareLatencyMs] plus one frame interval for the screen refresh.
  double get totalLatencyMs => softwareLatencyMs + frameIntervalMs;

  /// How far (logical pixels) the ink end trails the pen tip during a fast
  /// stroke because of [totalLatencyMs].
  double get trailPx => fastSpeed * totalLatencyMs / 1000;

  /// How many frames at the measured rate [softwareLatencyMs] is.
  double get latencyInFrames =>
      measuredHz <= 0 ? 0 : softwareLatencyMs / (1000 / measuredHz);

  String toText() {
    String ms(double v) => v.toStringAsFixed(1);
    final b = StringBuffer();
    if (!hasData) {
      b.writeln('Yeterli veri yok.');
      b.writeln(
        'Kayıt sırasında kalemle en az birkaç saniye, yavaş ve hızlı '
        'çizgiler çizin ($events kalem olayı, ${ageMs.count} kare toplandı).',
      );
      return b.toString().trimRight();
    }
    b.writeln('Süre: ${ms(seconds)} sn, kalem: ${kinds.join(', ')}');
    b.writeln('Kalem tahmini: ${prediction ? 'açık' : 'kapalı'}');
    b.writeln(
      'Ekran: ${displayHz == null ? '?' : displayHz!.toStringAsFixed(0)} Hz '
      'bildirildi, ${measuredHz.toStringAsFixed(0)} Hz ölçüldü',
    );
    if (displayModes != null && displayModes!.isNotEmpty) {
      b.writeln('Ekran modları: $displayModes');
    }
    b.writeln('');
    b.writeln(
      'Kalem olay aralığı: ${ms(eventIntervalMs)} ms '
      '(${eventIntervalMs <= 0 ? '?' : (1000 / eventIntervalMs).toStringAsFixed(0)} Hz), '
      'kare başına ${eventsPerFrame.toStringAsFixed(0)} olay',
    );
    if (clocksDiffer) {
      b.writeln(
        'Bu cihazda kalem olayları ile kareler farklı saat kullanıyor; '
        'olay yaşları en taze olaya göre ölçüldü (gerçek değer biraz '
        'daha yüksek olabilir).',
      );
    }
    b.writeln(
      'Olay yaşı (karenin başlangıcında): ortanca ${ms(ageMs.p50)} ms, '
      '%95 ${ms(ageMs.p95)} ms, en çok ${ms(ageMs.max)} ms',
    );
    b.writeln(
      'Kare maliyeti (vsync→ekran belleği): ortanca ${ms(spanMs.p50)} ms, '
      '%95 ${ms(spanMs.p95)} ms, en çok ${ms(spanMs.max)} ms',
    );
    b.writeln(
      '  çizim hazırlığı: ortanca ${ms(buildMs.p50)} ms, %95 ${ms(buildMs.p95)} ms',
    );
    b.writeln(
      '  rasterleştirme: ortanca ${ms(rasterMs.p50)} ms, %95 ${ms(rasterMs.p95)} ms',
    );
    b.writeln(
      'Yavaş kare: $slowFrames / $frames '
      '(%${(slowFrameShare * 100).toStringAsFixed(0)})',
    );
    b.writeln('');
    b.writeln(
      'Yazılım gecikmesi (olay yaşı + kare): ${ms(softwareLatencyMs)} ms '
      '(${latencyInFrames.toStringAsFixed(1)} kare), kötü anda '
      '${ms(softwareLatencyWorstMs)} ms',
    );
    b.writeln(
      'Ekrana yansıma dahil tahmin (+1 kare = ${ms(frameIntervalMs)} ms): '
      '${ms(totalLatencyMs)} ms',
    );
    b.writeln(
      'Hızlı çizgide kalem hızı ${fastSpeed.toStringAsFixed(0)} px/sn → '
      'çizgi ucu kalemin yaklaşık ${trailPx.toStringAsFixed(0)} px gerisinde',
    );
    b.write(
      'Not: ekran panelinin ve sistem katmanının kendi gecikmesi bu '
      'sayıya dahil değildir.',
    );
    return b.toString();
  }
}
