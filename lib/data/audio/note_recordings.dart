import 'dart:io';

import 'package:saber/data/file_manager/file_manager.dart';

/// One audio recording that belongs to a note.
class NoteRecording {
  const new({required this.file, required this.startedAt, required this.size});

  final File file;
  final DateTime startedAt;
  final int size;
}

/// Audio recordings attached to notes.
///
/// They are kept in their own folder next to (not inside) the notes folder,
/// one subfolder per note, so they never confuse the note library. They
/// follow a note when it is renamed, moved or put in the trash, and are
/// deleted with it. They are not synced.
abstract class NoteRecordings {
  static const extension = '.m4a';

  /// Where recordings are kept. Tests point this somewhere else.
  static Directory? rootOverride;

  static Directory get root =>
      rootOverride ??
      Directory(
        '${Directory(FileManager.documentsDirectory).parent.path}'
        '/note_recordings',
      );

  /// A note's path without its file extension, which is how recordings
  /// identify it.
  static String keyOf(String notePath) {
    for (final ext in ['.sbn2', '.sbn']) {
      if (notePath.endsWith(ext)) {
        return notePath.substring(0, notePath.length - ext.length);
      }
    }
    return notePath;
  }

  static Directory directoryFor(String notePath) =>
      Directory('${root.path}/${Uri.encodeComponent(keyOf(notePath))}');

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String _fileName(DateTime t) =>
      '${t.year}${_two(t.month)}${_two(t.day)}_'
      '${_two(t.hour)}${_two(t.minute)}${_two(t.second)}$extension';

  /// A new, empty path to record into.
  static Future<File> newRecordingFile(
    String notePath, {
    DateTime? now,
  }) async {
    final directory = directoryFor(notePath);
    await directory.create(recursive: true);
    return File('${directory.path}/${_fileName(now ?? DateTime.now())}');
  }

  /// A note's recordings, newest first.
  static Future<List<NoteRecording>> list(String notePath) async {
    final directory = directoryFor(notePath);
    if (!directory.existsSync()) return const [];

    final result = <NoteRecording>[];
    await for (final entity in directory.list()) {
      if (entity is! File || !entity.path.endsWith(extension)) continue;
      final stat = await entity.stat();
      result.add(
        NoteRecording(
          file: entity,
          startedAt: _parseName(entity.path) ?? stat.modified,
          size: stat.size,
        ),
      );
    }
    result.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return result;
  }

  static DateTime? _parseName(String path) {
    final name = path.substring(path.lastIndexOf('/') + 1);
    final match = RegExp(
      r'^(\d{4})(\d{2})(\d{2})_(\d{2})(\d{2})(\d{2})\.m4a$',
    ).firstMatch(name);
    if (match == null) return null;
    final v = [for (var i = 1; i <= 6; i++) int.parse(match.group(i)!)];
    return DateTime(v[0], v[1], v[2], v[3], v[4], v[5]);
  }

  static Future<bool> hasAny(String notePath) async =>
      (await list(notePath)).isNotEmpty;

  /// Deletes one recording.
  static Future<void> delete(NoteRecording recording) async {
    if (recording.file.existsSync()) await recording.file.delete();
  }

  /// Moves a note's recordings when the note is renamed or moved.
  static Future<void> move(String fromNotePath, String toNotePath) async {
    final from = directoryFor(fromNotePath);
    final to = directoryFor(toNotePath);
    if (from.path == to.path || !from.existsSync()) return;

    await to.parent.create(recursive: true);
    if (to.existsSync()) {
      // Another note's recordings are already there: keep both.
      await for (final entity in from.list()) {
        if (entity is! File) continue;
        var target = File('${to.path}/${entity.uri.pathSegments.last}');
        var n = 1;
        while (target.existsSync()) {
          final name = entity.uri.pathSegments.last;
          target = File(
            '${to.path}/${name.substring(0, name.length - extension.length)}'
            '_${n++}$extension',
          );
        }
        await entity.rename(target.path);
      }
      await from.delete(recursive: true);
    } else {
      await from.rename(to.path);
    }
  }

  /// Deletes all of a note's recordings.
  static Future<void> deleteAll(String notePath) async {
    final directory = directoryFor(notePath);
    if (directory.existsSync()) await directory.delete(recursive: true);
  }
}
