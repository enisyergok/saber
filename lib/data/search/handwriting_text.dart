import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:logging/logging.dart';
import 'package:saber/components/canvas/_stroke.dart';
import 'package:saber/data/audio/note_recordings.dart';
import 'package:saber/data/editor/editor_core_info.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/ocr/handwriting_recognizer.dart';

/// The text read from a note's handwriting, page by page.
class NoteHandwriting {
  const NoteHandwriting({required this.recognizedMs, required this.pages});

  /// When the handwriting was read (milliseconds since the epoch). A note
  /// that was saved after this has changed since.
  final int recognizedMs;

  /// One text per page of the note; empty if the page had no handwriting.
  final List<String> pages;

  bool get hasText => pages.any((text) => text.trim().isNotEmpty);

  Map<String, dynamic> toJson() => {'m': recognizedMs, 'p': pages};

  factory NoteHandwriting.fromJson(Map<String, dynamic> json) =>
      NoteHandwriting(
        recognizedMs: json['m'] as int,
        pages: [for (final page in json['p'] as List<dynamic>) page as String],
      );
}

/// Handwriting text kept for search ("Add to search").
///
/// It is kept in a file of its own next to (not inside) the notes folder, so
/// the notes are never touched and the text is not synced. Like audio
/// recordings, it follows a note that is renamed, moved or trashed and goes
/// when the note is deleted.
abstract class HandwritingTexts {
  static final log = Logger('HandwritingTexts');

  /// Tests point this somewhere else.
  static File? fileOverride;

  static File get file =>
      fileOverride ??
      File(
        '${Directory(FileManager.documentsDirectory).parent.path}'
        '/note_handwriting_text.json',
      );

  static final Map<String, NoteHandwriting> _texts = {};
  static bool _loaded = false;

  /// For tests: forget everything held in memory.
  static void resetForTesting() {
    _texts.clear();
    _loaded = false;
  }

  static String _key(String notePath) => NoteRecordings.keyOf(notePath);

  static Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final f = file;
      if (!f.existsSync()) return;
      final json = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      for (final entry in json.entries) {
        _texts[entry.key] = NoteHandwriting.fromJson(
          entry.value as Map<String, dynamic>,
        );
      }
    } catch (e, st) {
      // A damaged file only means notes have to be added to the search again.
      log.warning('Ignoring unreadable handwriting text file: $e', e, st);
      _texts.clear();
    }
  }

  /// Written to a temporary file first, so a crash never leaves half a file.
  static Future<void> _save() async {
    final f = file;
    await f.parent.create(recursive: true);
    final temp = File('${f.path}.tmp');
    await temp.writeAsString(
      jsonEncode({for (final e in _texts.entries) e.key: e.value.toJson()}),
      flush: true,
    );
    await temp.rename(f.path);
  }

  static NoteHandwriting? of(String notePath) => _texts[_key(notePath)];

  /// Notes that have handwriting text, by path without extension.
  static Map<String, NoteHandwriting> get all => Map.unmodifiable(_texts);

  static Future<void> put(String notePath, NoteHandwriting text) async {
    await load();
    _texts[_key(notePath)] = text;
    await _save();
  }

  static Future<void> remove(String notePath) async {
    await load();
    if (_texts.remove(_key(notePath)) != null) await _save();
  }

  /// A note was renamed or moved.
  static Future<void> move(String fromPath, String toPath) async {
    await load();
    final text = _texts.remove(_key(fromPath));
    if (text == null) return;
    _texts[_key(toPath)] = text;
    await _save();
  }
}

/// Splits items that sit on a page into groups that each cover a band of the
/// page, top to bottom, so every picture sent to the recognizer shows a few
/// lines at a readable size (the whole page in one picture would be shrunk
/// too far to read).
List<List<T>> bandChunks<T>(
  List<T> items,
  Rect Function(T) bounds, {
  double bandHeight = 600,
}) {
  if (items.isEmpty) return const [];
  final sorted = [...items]
    ..sort((a, b) => bounds(a).center.dy.compareTo(bounds(b).center.dy));
  final result = <List<T>>[];
  var current = <T>[];
  var bandTop = bounds(sorted.first).top;
  for (final item in sorted) {
    final rect = bounds(item);
    if (current.isNotEmpty && rect.center.dy - bandTop > bandHeight) {
      result.add(current);
      current = <T>[];
      bandTop = rect.top;
    }
    current.add(item);
  }
  result.add(current);
  return result;
}

class HandwritingIndexProgress {
  const HandwritingIndexProgress(this.done, this.total);
  final int done;
  final int total;
}

class HandwritingIndexCancelled implements Exception {
  const HandwritingIndexCancelled();
}

/// Reads all the handwriting of a note and keeps the text for search.
abstract class HandwritingIndexer {
  /// The most pictures sent for one note; a note beyond this is read only up
  /// to here (and says so), so one tap can never cost a surprising amount.
  static const maxChunks = 60;

  /// Strokes that carry writing (not highlighter marks, which would cover it).
  static bool isWriting(Stroke stroke) =>
      stroke.toolId != .highlighter && !stroke.isEmpty;

  /// How many pictures reading [note] takes.
  static int countChunks(EditorCoreInfo note) {
    var total = 0;
    for (final page in note.pages) {
      total += bandChunks<Stroke>(
        page.strokes.where(isWriting).toList(),
        (s) => s.bounds,
      ).length;
    }
    return total;
  }

  /// Reads [note]'s handwriting with [recognize] (given a PNG, returns its
  /// text) and stores the result. Calls [onProgress] after each picture and
  /// stops with [HandwritingIndexCancelled] when [isCancelled] says so.
  static Future<NoteHandwriting> index(
    EditorCoreInfo note, {
    required Future<String> Function(Uint8List png) recognize,
    void Function(HandwritingIndexProgress progress)? onProgress,
    bool Function()? isCancelled,
    int Function()? nowMs,
    int maxChunks = HandwritingIndexer.maxChunks,
  }) async {
    final chunksPerPage = [
      for (final page in note.pages)
        bandChunks<Stroke>(
          page.strokes.where(isWriting).toList(),
          (s) => s.bounds,
        ),
    ];
    final total = chunksPerPage
        .fold<int>(0, (sum, chunks) => sum + chunks.length)
        .clamp(0, maxChunks);

    var done = 0;
    final pages = <String>[];
    for (final chunks in chunksPerPage) {
      final lines = <String>[];
      for (final chunk in chunks) {
        if (done >= maxChunks) break;
        if (isCancelled?.call() ?? false) {
          throw const HandwritingIndexCancelled();
        }
        final png = await HandwritingRecognizer.renderStrokes(chunk);
        if (png != null) {
          final text = (await recognize(png)).trim();
          if (text.isNotEmpty) lines.add(text);
        }
        onProgress?.call(HandwritingIndexProgress(++done, total));
      }
      pages.add(lines.join('\n'));
    }

    final result = NoteHandwriting(
      recognizedMs: nowMs?.call() ?? DateTime.now().millisecondsSinceEpoch,
      pages: pages,
    );
    await HandwritingTexts.put(note.filePath, result);
    return result;
  }

  /// Whether the note was saved after its handwriting was read.
  static bool isOutdated(NoteHandwriting text, int noteModifiedMs) =>
      noteModifiedMs > text.recognizedMs;
}
