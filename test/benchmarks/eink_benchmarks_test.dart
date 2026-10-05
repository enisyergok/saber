// What e-ink mode costs, next to the normal look, on the same notes.
// The numbers come from a shared CI runner (software drawing, no GPU), so
// only the "normal" and "eink" lines of one run are comparable, never a
// device. Run with `--tags benchmark`.
@Tags(['benchmark'])
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saber/components/canvas/_canvas_background_painter.dart';
import 'package:saber/components/canvas/_canvas_painter.dart';
import 'package:saber/data/benchmark/synthetic_notes.dart';
import 'package:saber/data/eink/eink_style.dart';
import 'package:saber/data/eink/eink_texture.dart';
import 'package:saber/data/flavor_config.dart';
import 'package:saber/data/tools/stroke_properties.dart';

String _ms(Duration duration) =>
    (duration.inMicroseconds / 1000).toStringAsFixed(2);

Duration _best(int runs, Duration Function() run) =>
    [for (var i = 0; i < runs; i++) run()].reduce((a, b) => a < b ? a : b);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlavorConfig.setup();
  StrokeOptionsExtension.setDefaults();

  const style = EInkStyle();

  test('BENCH colour mapping', () {
    final elapsed = _best(3, () {
      final stopwatch = Stopwatch()..start();
      var sink = 0.0;
      for (var i = 0; i < 100000; i++) {
        sink += style.mapInk(Color(0xFF000000 | (i * 2654435761 & 0xFFFFFF))).a;
      }
      stopwatch.stop();
      expect(sink, greaterThan(0));
      return stopwatch.elapsed;
    });
    // ignore: avoid_print
    print('BENCH eink_mapInk_100000_calls_ms=${_ms(elapsed)}');
  });

  for (final strokes in [1000, 5000]) {
    test('BENCH finished strokes layer, $strokes strokes', () {
      final note = SyntheticNotes.note(strokes: strokes);
      addTearDown(note.dispose);
      final page = note.pages.first;

      Duration record(EInkStyle? eInk) {
        final stopwatch = Stopwatch()..start();
        final recorder = ui.PictureRecorder();
        CanvasPainter(
          layer: InkLayer.dry,
          eInk: eInk,
          strokes: page.strokes,
          laserStrokes: const [],
          currentStroke: null,
          currentSelection: null,
          primaryColor: Colors.blue,
          page: page,
          showPageIndicator: true,
          pageIndex: 0,
          totalPages: 1,
          currentScale: 1,
          defaultTextStyle: const TextStyle(),
        ).paint(Canvas(recorder), page.size);
        recorder.endRecording().dispose();
        stopwatch.stop();
        return stopwatch.elapsed;
      }

      record(null); // outlines are built on first use
      final normal = _best(5, () => record(null));
      final eInk = _best(5, () => record(style));
      // ignore: avoid_print
      print(
        'BENCH dry_layer_${strokes}_strokes_ms normal=${_ms(normal)} '
        'eink=${_ms(eInk)}',
      );
    });
  }

  test('BENCH live layer while writing, 2000 points', () {
    final note = SyntheticNotes.note(strokes: 10);
    addTearDown(note.dispose);
    final page = note.pages.first;
    final stroke = SyntheticNotes.emptyStroke(page: page);
    for (var i = 0; i < 2000; i++) {
      final (position, pressure) = SyntheticNotes.letterPoint(
        origin: const Offset(40, 300),
        i: i,
        points: 2000,
        width: 1600,
        height: 60,
        phase: 0.3,
      );
      stroke.addPoint(position, pressure);
    }

    Duration frames(EInkStyle? eInk, int count) {
      final painter = CanvasPainter(
        layer: InkLayer.live,
        eInk: eInk,
        strokes: page.strokes,
        laserStrokes: const [],
        currentStroke: stroke,
        currentSelection: null,
        primaryColor: Colors.blue,
        page: page,
        showPageIndicator: false,
        pageIndex: 0,
        totalPages: 1,
        currentScale: 1,
        defaultTextStyle: const TextStyle(),
      );
      final stopwatch = Stopwatch()..start();
      for (var i = 0; i < count; i++) {
        final recorder = ui.PictureRecorder();
        painter.paint(Canvas(recorder), page.size);
        recorder.endRecording().dispose();
      }
      stopwatch.stop();
      return stopwatch.elapsed;
    }

    frames(null, 5);
    final normal = _best(5, () => frames(null, 60));
    final eInk = _best(5, () => frames(style, 60));
    // ignore: avoid_print
    print(
      'BENCH live_layer_per_frame_ms normal=${_ms(normal ~/ 60)} '
      'eink=${_ms(eInk ~/ 60)}',
    );
  });

  test('BENCH page background drawn to pixels', () async {
    final size = const Size(1000, 1400);

    Future<Duration> raster(EInkStyle? eInk, ui.Image? grain) async {
      final recorder = ui.PictureRecorder();
      CanvasBackgroundPainter(
        invert: false,
        backgroundColor: eInk?.paper ?? Colors.white,
        backgroundPattern: .grid,
        lineHeight: 40,
        lineThickness: 3,
        eInk: eInk != null,
        grain: grain,
      ).paint(Canvas(recorder), size);
      final picture = recorder.endRecording();
      final stopwatch = Stopwatch()..start();
      final image = await picture.toImage(
        size.width.toInt(),
        size.height.toInt(),
      );
      stopwatch.stop();
      image.dispose();
      picture.dispose();
      return stopwatch.elapsed;
    }

    final grain = await EInkTexture.load(
      style.textureStep,
      maxAlpha: EInkStyle.maxGrainAlpha,
    );
    await raster(null, null);
    var normal = const Duration(days: 1);
    var eInk = const Duration(days: 1);
    for (var i = 0; i < 5; i++) {
      final a = await raster(null, null);
      final b = await raster(style, grain);
      if (a < normal) normal = a;
      if (b < eInk) eInk = b;
    }
    // ignore: avoid_print
    print(
      'BENCH page_background_raster_1000x1400_ms normal=${_ms(normal)} '
      'eink_with_grain=${_ms(eInk)}',
    );
  });
}
