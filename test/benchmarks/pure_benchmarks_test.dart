// Screen-independent benchmarks, run in CI to catch regressions.
// The numbers come from a shared CI runner, so compare them only with other
// CI runs, never with a device. Run with `--tags benchmark`.
@Tags(['benchmark'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:saber/data/benchmark/pure_benchmarks.dart';
import 'package:saber/data/benchmark/synthetic_notes.dart';
import 'package:saber/data/flavor_config.dart';
import 'package:saber/data/tools/stroke_properties.dart';

String _ms(Duration duration) =>
    (duration.inMicroseconds / 1000).toStringAsFixed(1);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlavorConfig.setup();
  StrokeOptionsExtension.setDefaults();

  test('synthetic notes are deterministic', () {
    final a = SyntheticNotes.note(strokes: 50);
    final b = SyntheticNotes.note(strokes: 50);
    addTearDown(a.dispose);
    addTearDown(b.dispose);

    expect(a.pages.single.strokes, hasLength(50));
    expect(
      PureBenchmarks.serialize(a).bytes,
      PureBenchmarks.serialize(b).bytes,
    );
  });

  test('synthetic notes spread strokes over pages', () {
    final note = SyntheticNotes.note(strokes: 1000, pages: 7);
    addTearDown(note.dispose);

    expect(note.pages, hasLength(7));
    final total = note.pages.fold<int>(
      0,
      (sum, page) => sum + page.strokes.length,
    );
    expect(total, 1000);
  });

  test('percentile', () {
    expect(percentile([1, 2, 3, 4, 5], 50), 3);
    expect(percentile([5, 1, 4, 2, 3], 100), 5);
    expect(percentile([1, 2], 50), 1.5);
    expect(percentile([], 50).isNaN, isTrue);
  });

  test('BENCH stroke outline while drawing', () {
    for (final points in [100, 500, 2000]) {
      // Best of three, to reduce noise from the shared runner.
      final best = [
        for (var i = 0; i < 3; i++) PureBenchmarks.outlineWhileDrawing(points),
      ].reduce((a, b) => a < b ? a : b);
      // ignore: avoid_print
      print('BENCH outline_${points}_points_ms=${_ms(best)}');
    }
  });

  test('BENCH eraser sweep', () {
    for (final strokes in [1000, 10000, 50000]) {
      final note = SyntheticNotes.note(strokes: strokes);
      final best = [
        for (var i = 0; i < 3; i++) PureBenchmarks.eraserSweep(note),
      ].reduce((a, b) => a < b ? a : b);
      note.dispose();
      // ignore: avoid_print
      print('BENCH eraser_sweep_200_moves_${strokes}_strokes_ms=${_ms(best)}');
    }
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('BENCH serialize', () {
    for (final (strokes, pages) in [(1000, 1), (10000, 1), (30000, 100)]) {
      final note = SyntheticNotes.note(strokes: strokes, pages: pages);
      final best = [
        for (var i = 0; i < 3; i++) PureBenchmarks.serialize(note),
      ].reduce((a, b) => a.elapsed < b.elapsed ? a : b);
      note.dispose();
      // ignore: avoid_print
      print(
        'BENCH serialize_${strokes}_strokes_${pages}_pages_ms=${_ms(best.elapsed)} '
        'bytes=${best.bytes.length}',
      );
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}
