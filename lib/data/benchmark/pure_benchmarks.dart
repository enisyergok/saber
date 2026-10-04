import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' show Offset;

import 'package:saber/data/benchmark/synthetic_notes.dart';
import 'package:saber/data/editor/editor_core_info.dart';
import 'package:saber/data/editor/page.dart';

/// Measurements that need no screen, so they run both on a device
/// (from the benchmark page) and in CI (to catch regressions).
abstract class PureBenchmarks {
  /// The time to rebuild a stroke's outline after each of [points] points,
  /// which is what happens on every pen move while drawing.
  static Duration outlineWhileDrawing(int points) {
    final page = EditorPage();
    final stroke = SyntheticNotes.emptyStroke(page: page);
    final random = Random(7);
    final width = points * 0.8;
    final phase = random.nextDouble() * pi;

    final stopwatch = Stopwatch()..start();
    for (var i = 0; i < points; i++) {
      final (position, pressure) = SyntheticNotes.letterPoint(
        origin: const Offset(40, 300),
        i: i,
        points: points,
        width: width,
        height: 60,
        phase: phase,
      );
      stroke.addPoint(position, pressure);
      // The painter asks for the current stroke's path on every frame.
      stroke.highQualityPath.getBounds();
    }
    stopwatch.stop();
    page.dispose();
    return stopwatch.elapsed;
  }

  /// Serializes [note] the way a save does (on the calling isolate).
  static ({Duration elapsed, Uint8List bytes}) serialize(EditorCoreInfo note) {
    final stopwatch = Stopwatch()..start();
    final (bytes, _) = note.saveToBinary(currentPageIndex: 0);
    stopwatch.stop();
    return (elapsed: stopwatch.elapsed, bytes: bytes);
  }

  /// Parses [bytes] the way opening a note does, including the hop to
  /// another isolate that large files take.
  static Future<Duration> parse(Uint8List bytes) async {
    final stopwatch = Stopwatch()..start();
    // ignore: invalid_use_of_visible_for_testing_member
    final loaded = await EditorCoreInfo.loadFromFileContents(
      bsonBytes: bytes,
      path: '/_benchmark_parse',
      onlyFirstPage: false,
    );
    stopwatch.stop();
    loaded.dispose();
    return stopwatch.elapsed;
  }
}

/// The given percentile (0–100) of [values], which need not be sorted.
double percentile(List<double> values, double p) {
  if (values.isEmpty) return double.nan;
  final sorted = [...values]..sort();
  final rank = (p / 100) * (sorted.length - 1);
  final lower = rank.floor();
  final upper = rank.ceil();
  if (lower == upper) return sorted[lower];
  return sorted[lower] + (sorted[upper] - sorted[lower]) * (rank - lower);
}
