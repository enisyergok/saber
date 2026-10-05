import 'package:flutter_test/flutter_test.dart';
import 'package:saber/data/benchmark/pen_latency.dart';

/// A pen moving 1000 px/s sending an event every [eventUs], with frames every
/// [frameUs] that each cost [spanUs].
PenLatencyReport simulate({
  int eventUs = 4167,
  int frameUs = 8333,
  int spanUs = 10000,
  int seconds = 2,
  bool prediction = true,
  int slowEvery = 0,
  int clockOffsetUs = 0,
}) {
  final recorder = PenLatencyRecorder()..start(0);
  final end = seconds * 1000000;
  var nextEvent = 0;
  var x = 0.0;
  for (var frame = frameUs + 2000; frame < end; frame += frameUs) {
    while (nextEvent <= frame) {
      recorder.onPointerMove(
        eventUs: nextEvent + clockOffsetUs,
        arrivalUs: nextEvent,
        x: x,
        y: 0,
        kind: 'stylus',
      );
      x += 1000 * eventUs / 1e6;
      nextEvent += eventUs;
    }
    recorder.onFrame(frame);
    final slow = slowEvery > 0 && (frame ~/ frameUs) % slowEvery == 0;
    recorder.onFrameCost(
      spanUs: slow ? spanUs * 3 : spanUs,
      buildUs: 3000,
      rasterUs: 5000,
    );
  }
  return recorder.finish(prediction: prediction, displayHz: 120);
}

void main() {
  test('reads the pen event rate and speed', () {
    final report = simulate();
    expect(report.eventIntervalMs, closeTo(4.167, 0.01));
    expect(report.fastSpeed, closeTo(1000, 5));
    expect(report.medianSpeed, closeTo(1000, 5));
    expect(report.kinds, ['stylus']);
  });

  test('measures the display rate from the frames', () {
    final report = simulate();
    expect(report.measuredHz, closeTo(120, 1));
    expect(report.slowFrames, 0);
  });

  test('events per frame follows the pen rate', () {
    // 240 Hz pen on a 120 Hz screen: two events per frame.
    final report = simulate();
    expect(report.eventsPerFrame, closeTo(2, 1));
  });

  test('the event is at most one pen interval old when the frame starts', () {
    final report = simulate();
    expect(report.ageMs.p50, inInclusiveRange(0, 4.2));
    expect(report.ageMs.max, lessThanOrEqualTo(4.2));
  });

  test('software latency is event age plus frame cost', () {
    final report = simulate(spanUs: 10000);
    expect(report.spanMs.p50, closeTo(10, 0.01));
    expect(
      report.softwareLatencyMs,
      closeTo(report.ageMs.p50 + 10, 0.01),
    );
    expect(report.softwareLatencyMs, inInclusiveRange(10, 14.2));
  });

  test('trail follows speed times latency', () {
    final report = simulate(spanUs: 10000);
    expect(
      report.trailPx,
      closeTo(report.fastSpeed * report.totalLatencyMs / 1000, 1e-9),
    );
    expect(report.trailPx, inInclusiveRange(15, 30));
  });

  test('a slower frame cost raises the latency', () {
    final fast = simulate(spanUs: 8000);
    final slow = simulate(spanUs: 20000);
    expect(slow.softwareLatencyMs, greaterThan(fast.softwareLatencyMs + 10));
  });

  test('the worst case is above the typical case when frames are uneven', () {
    final report = simulate(slowEvery: 5);
    expect(report.softwareLatencyWorstMs, greaterThan(report.softwareLatencyMs));
    expect(report.spanMs.max, closeTo(30, 0.01));
  });

  test('the screen refresh adds one frame to the total', () {
    final report = simulate();
    expect(report.frameIntervalMs, closeTo(8.33, 0.1));
    expect(
      report.totalLatencyMs,
      closeTo(report.softwareLatencyMs + report.frameIntervalMs, 1e-9),
    );
  });

  test('different pen and frame clocks are detected and compensated', () {
    // The pen clock runs 64 hours ahead of the frame clock.
    final offset = (230386.5 * 1e6).round();
    final aligned = simulate();
    final shifted = simulate(clockOffsetUs: offset);
    expect(aligned.clocksDiffer, isFalse);
    expect(shifted.clocksDiffer, isTrue);
    expect(shifted.ageMs.p50, inInclusiveRange(0, 4.2));
    expect(shifted.softwareLatencyMs, inInclusiveRange(10, 14.2));
    expect(shifted.toText(), contains('farklı saat'));
  });

  test('the display modes are shown when known', () {
    final recorder = PenLatencyRecorder()..start(0);
    final report = recorder.finish(
      prediction: true,
      displayModes: '1: 2800x1840 @ 60 Hz, 2: 2800x1840 @ 120 Hz',
    );
    expect(report.displayModes, contains('120 Hz'));
    expect(report.hasData, isFalse);
  });

  test('no data is reported as such', () {
    final report = (PenLatencyRecorder()..start(0)).finish(prediction: false);
    expect(report.hasData, isFalse);
    expect(report.toText(), contains('Yeterli veri yok'));
  });

  test('the text shows the main numbers', () {
    final text = simulate(prediction: false).toText();
    expect(text, contains('Kalem tahmini: kapalı'));
    expect(text, contains('Yazılım gecikmesi'));
    expect(text, contains('gerisinde'));
    expect(text, contains('120 Hz'));
  });
}
