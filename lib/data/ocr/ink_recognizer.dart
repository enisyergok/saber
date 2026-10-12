import 'dart:ui';

import 'package:google_mlkit_digital_ink_recognition/google_mlkit_digital_ink_recognition.dart'
    as mlkit;
import 'package:saber/components/canvas/_stroke.dart';
import 'package:saber/data/crash_log.dart';
import 'package:saber/data/defter_strings.dart';
import 'package:saber/data/ocr/handwriting_recognizer.dart';

/// Groups [items] (strokes) into lines of writing, top to bottom. Items
/// keep the order they were given in within a line, because the order the
/// strokes were drawn in helps the recognizer.
List<List<T>> groupLines<T>(List<T> items, Rect Function(T) bounds) {
  if (items.isEmpty) return const [];
  final order = List<int>.generate(items.length, (i) => i)
    ..sort(
      (a, b) =>
          bounds(items[a]).center.dy.compareTo(bounds(items[b]).center.dy),
    );
  final lines = <List<int>>[];
  var current = <int>[];
  var sum = 0.0;
  var heights = <double>[];
  for (final i in order) {
    final rect = bounds(items[i]);
    if (current.isNotEmpty) {
      final mean = sum / current.length;
      final sorted = [...heights]..sort();
      final typical = sorted[sorted.length ~/ 2].clamp(12.0, 400.0);
      if ((rect.center.dy - mean).abs() > typical * 0.8) {
        lines.add(current);
        current = <int>[];
        sum = 0;
        heights = <double>[];
      }
    }
    current.add(i);
    sum += rect.center.dy;
    heights.add(rect.height);
  }
  lines.add(current);
  return [
    for (final line in lines) [for (final i in (line..sort())) items[i]],
  ];
}

/// The time-stamped points of [strokes] in the form the recognizer wants.
/// The notes do not keep when each point was drawn, so a steady pace is
/// made up: 8 ms between points, 150 ms between strokes.
List<List<({double x, double y, int t})>> inkPoints(
  List<List<Offset>> strokes,
) {
  var t = 0;
  final result = <List<({double x, double y, int t})>>[];
  for (final stroke in strokes) {
    final points = <({double x, double y, int t})>[];
    for (final p in stroke) {
      t += 8;
      points.add((x: p.dx, y: p.dy, t: t));
    }
    result.add(points);
    t += 150;
  }
  return result;
}

/// Reads handwriting on the device with Google ML Kit's digital ink
/// recognition: it works from the pen strokes themselves and needs the
/// internet only to download the language model once.
abstract class InkRecognizer {
  static const languages = <String, String>{
    'tr': 'Türkçe',
    'en-US': 'English',
  };

  static Future<bool> isModelReady(String language) async {
    try {
      return await mlkit.DigitalInkRecognizerModelManager().isModelDownloaded(
        language,
      );
    } catch (_) {
      return false;
    }
  }

  /// Makes sure the model for [language] is on the device.
  static Future<void> ensureModel(String language) async {
    try {
      await CrashLog.mark('dil modeli: kontrol basliyor ($language)');
      final manager = mlkit.DigitalInkRecognizerModelManager();
      if (await manager.isModelDownloaded(language)) {
        await CrashLog.mark('dil modeli: zaten indirilmis');
        return;
      }
      await CrashLog.mark('dil modeli: indirme basliyor');
      final ok = await manager.downloadModel(language);
      await CrashLog.mark('dil modeli: indirme bitti ($ok)');
      if (!ok) {
        throw HandwritingException(DefterStrings.inkModelFailed('?'));
      }
    } on HandwritingException {
      rethrow;
    } catch (e) {
      throw HandwritingException(DefterStrings.inkModelFailed('$e'));
    }
  }

  /// The text of [strokes], one line of text per line of writing.
  static Future<String> recognize(
    List<Stroke> strokes, {
    required String language,
  }) async {
    if (strokes.isEmpty) {
      throw HandwritingException(DefterStrings.recognizeNoStrokes);
    }
    await ensureModel(language);
    await CrashLog.mark('okuma basliyor ($language, ${strokes.length} cizgi)');
    final recognizer = mlkit.DigitalInkRecognizer(languageCode: language);
    try {
      final lines = <String>[];
      for (final line in groupLines<Stroke>(strokes, (s) => s.bounds)) {
        final ink = mlkit.Ink();
        final points = inkPoints([
          for (final s in line) [for (final p in s.points) Offset(p.x, p.y)],
        ]);
        ink.strokes = [
          for (final stroke in points)
            if (stroke.isNotEmpty)
              mlkit.Stroke()
                ..points = [
                  for (final p in stroke)
                    mlkit.StrokePoint(x: p.x, y: p.y, t: p.t),
                ],
        ];
        if (ink.strokes.isEmpty) continue;
        final candidates = await recognizer.recognize(ink);
        if (candidates.isNotEmpty) {
          final text = candidates.first.text.trim();
          if (text.isNotEmpty) lines.add(text);
        }
      }
      await CrashLog.mark('okuma bitti');
      return lines.join('\n');
    } on HandwritingException {
      rethrow;
    } catch (e) {
      throw HandwritingException('$e');
    } finally {
      await recognizer.close();
    }
  }
}
