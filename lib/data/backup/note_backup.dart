import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:saber/data/audio/note_recordings.dart';
import 'package:saber/data/backup/zip_file.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/is_this_a_test.dart';
import 'package:saber/data/nextcloud/saber_syncer.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/search/handwriting_text.dart';
import 'package:saber/data/tools/pen_styles.dart';
import 'package:saber/data/version.dart';
import 'package:saber/data/versions/note_versions.dart';

/// Why a backup could not be made or brought back.
enum BackupFailure {
  /// The file is not a backup made by this app (or not a zip at all).
  notABackup,

  /// The backup was made by a newer version of the app.
  newerFormat,

  /// The backup file is cut short or its content was altered.
  damaged,

  /// Notes kept changing while the backup was being made.
  changedWhileReading,

  /// Reading or writing a file failed (no space left, for one).
  io,
}

class BackupException implements Exception {
  const BackupException(this.failure, [this.detail = '']);
  final BackupFailure failure;
  final String detail;

  @override
  String toString() => 'BackupException(${failure.name}): $detail';
}

/// The list of what a backup holds. It is the last file in the zip.
class BackupManifest {
  const BackupManifest({
    required this.created,
    required this.appVersion,
    required this.files,
  });

  /// The name of the manifest in the zip.
  static const entryName = 'defter-backup.json';

  /// The newest form of backup this version of the app can read.
  static const format = 1;

  final DateTime created;
  final String appVersion;

  /// Every file in the backup by its name in the zip, with its size in
  /// bytes and its SHA-256.
  final Map<String, ({int size, String sha256})> files;

  /// How many notes the backup holds.
  int get notes => files.keys.where(NoteBackupWork.isNoteFile).length;

  /// How many recordings the backup holds.
  int get recordings =>
      files.keys.where((name) => name.startsWith('recordings/')).length;

  /// How many bytes the files take when they are out of the zip.
  int get bytes => files.values.fold(0, (sum, file) => sum + file.size);

  Map<String, dynamic> toJson() => {
    'app': 'Defter',
    'format': format,
    'created': created.toUtc().toIso8601String(),
    'appVersion': appVersion,
    'notes': notes,
    'files': [
      for (final entry in files.entries)
        {
          'path': entry.key,
          'size': entry.value.size,
          'sha256': entry.value.sha256,
        },
    ],
  };

  /// Reads [toJson]'s map. Throws a [BackupException] if it isn't one this
  /// version of the app can use.
  factory BackupManifest.fromJson(Object? json) {
    if (json is! Map || json['app'] != 'Defter') {
      throw const BackupException(BackupFailure.notABackup);
    }
    final format = json['format'];
    if (format is! int) throw const BackupException(BackupFailure.notABackup);
    if (format > BackupManifest.format) {
      throw const BackupException(BackupFailure.newerFormat);
    }
    final created = DateTime.tryParse('${json['created']}');
    final list = json['files'];
    if (created == null || list is! List) {
      throw const BackupException(BackupFailure.damaged, 'manifest');
    }
    final files = <String, ({int size, String sha256})>{};
    for (final item in list) {
      if (item is! Map) continue;
      final path = item['path'], size = item['size'], hash = item['sha256'];
      if (path is! String || size is! int || hash is! String) {
        throw const BackupException(BackupFailure.damaged, 'manifest');
      }
      files[path] = (size: size, sha256: hash);
    }
    return BackupManifest(
      created: created.toLocal(),
      appVersion: '${json['appVersion'] ?? ''}',
      files: files,
    );
  }
}

/// How far making or bringing back a backup has got.
class BackupProgress {
  const BackupProgress(this.phase, this.done, this.total);

  final BackupPhase phase;

  /// Bytes dealt with so far in this phase, and how many there are.
  final int done;
  final int total;

  double get fraction => total <= 0 ? 0 : (done / total).clamp(0, 1).toDouble();
}

enum BackupPhase { writing, verifying, restoring }

/// A backup that was made and checked.
class BackupSummary {
  const BackupSummary({
    required this.path,
    required this.created,
    required this.notes,
    required this.recordings,
    required this.files,
    required this.bytes,
    required this.zipBytes,
  });

  /// Where the zip file is.
  final String path;
  final DateTime created;
  final int notes;
  final int recordings;
  final int files;

  /// The size of everything in the backup, and of the zip itself.
  final int bytes;
  final int zipBytes;
}

/// What bringing back a backup did. Notes are named by their path without
/// extension, as everywhere in the library.
class RestoreOutcome {
  const RestoreOutcome({
    required this.restored,
    required this.copies,
    required this.alreadyThere,
    required this.failed,
    required this.writtenFiles,
    required this.recordings,
    required this.handwriting,
    required this.penProfiles,
  });

  /// Notes that were missing here and are back under their own name.
  final List<String> restored;

  /// Notes that differ from the one of the same name here: they were
  /// brought back next to it, under the name given here.
  final Map<String, String> copies;

  /// Notes that are here already, the same as in the backup.
  final List<String> alreadyThere;

  /// Notes that are damaged in the backup and were left out.
  final List<String> failed;

  /// The note files that were written, relative to the notes folder.
  final List<String> writtenFiles;

  /// How many recordings were brought back.
  final int recordings;

  /// Handwriting text from the backup, by the note it now belongs to.
  final Map<String, Object?> handwriting;

  /// The pen profiles in the backup, as they were saved.
  final String? penProfiles;

  bool get changedAnything =>
      restored.isNotEmpty || copies.isNotEmpty || recordings > 0;
}

class _Group {
  _Group(this.key, this.extension);
  final String key;
  final String extension;
  String? main;
  String? preview;
  final assets = <int, String>{};
}

/// Making, checking and bringing back backups, with plain files and paths
/// and blocking calls only: it is run away from the screen, in another
/// isolate (see [NoteBackup]).
///
/// A backup is an ordinary zip file:
///
///     notes/…            the notes folder as it is on the device: notes,
///                        their pictures and PDFs, and empty folders
///     recordings/…       audio recordings, a folder for each note
///     handwriting.json   the handwriting text that was read for searching
///     pen_profiles.json  the pen profiles
///     defter-backup.json the list of all of the above, with sizes and
///                        SHA-256 checksums
abstract class NoteBackupWork {
  static final _notePart = RegExp(r'^(.*)(\.sbn2?)(?:\.(\d+|p))?$');
  static final _transient = RegExp(r'\.(tmp|bak|bad|new)$');
  static final _mainFile = RegExp(r'^notes/.*\.sbn2?$');

  static const handwritingName = 'handwriting.json';
  static const penProfilesName = 'pen_profiles.json';

  /// Whether the zip entry [name] is a note (and not one of its assets).
  static bool isNoteFile(String name) => _mainFile.hasMatch(name);

  static bool _inTrash(String path) =>
      path == FileManager.trashDirectory ||
      path.startsWith('${FileManager.trashDirectory}/');

  static String _withoutTrailingSlash(String path) =>
      path.endsWith('/') && path.length > 1
      ? path.substring(0, path.length - 1)
      : path;

  /// Makes a backup at [zipPath] and checks it by reading it back.
  ///
  /// Throws a [BackupException], and leaves no file behind, if that can't
  /// be done.
  static BackupSummary create({
    required String documentsPath,
    required String recordingsPath,
    required String handwritingPath,
    required String penProfiles,
    required String zipPath,
    required DateTime created,
    required String appVersion,
    void Function(BackupProgress progress)? report,
  }) {
    final writer = ZipWriter(zipPath, modified: created);
    try {
      final root = Directory(_withoutTrailingSlash(documentsPath));
      final folders = <String>[];
      final sources = <({String name, File file})>[];

      if (root.existsSync()) {
        for (final entity in root.listSync(
          recursive: true,
          followLinks: false,
        )) {
          final path = entity.path
              .substring(root.path.length)
              .replaceAll('\\', '/');
          if (_inTrash(path)) continue;
          if (entity is Directory) {
            folders.add('notes$path/');
          } else if (entity is File) {
            if (_transient.hasMatch(path) || !_notePart.hasMatch(path)) continue;
            sources.add((name: 'notes$path', file: entity));
          }
        }
      }

      final recordings = Directory(recordingsPath);
      if (recordings.existsSync()) {
        for (final folder in recordings.listSync(followLinks: false)) {
          if (folder is! Directory) continue;
          // The folder is named after the note, with its slashes encoded.
          final folderName = _baseName(folder.path);
          final key = _decode(folderName);
          if (key == null || _inTrash(key)) continue;
          for (final file in folder.listSync(followLinks: false)) {
            if (file is! File) continue;
            sources.add((
              name: 'recordings/$folderName/${_baseName(file.path)}',
              file: file,
            ));
          }
        }
      }

      folders.sort();
      sources.sort((a, b) => a.name.compareTo(b.name));

      final total = sources.fold<int>(
        0,
        (sum, source) => sum + source.file.lengthSync(),
      );
      var done = 0;
      var reported = -1;
      void advance(BackupPhase phase, int bytes) {
        done += bytes;
        // About two hundred steps are plenty for a progress bar.
        final step = total <= 0 ? 0 : done * 200 ~/ total;
        if (step == reported) return;
        reported = step;
        report?.call(BackupProgress(phase, done, total));
      }

      for (final folder in folders) {
        writer.addDirectory(folder);
      }

      final files = <String, ({int size, String sha256})>{};
      for (final source in sources) {
        final before = done;
        ZipAdded? added;
        // A file that is being written right now is read again.
        for (var attempt = 0; added == null; attempt++) {
          try {
            added = writer.addFile(
              source.name,
              source.file,
              compress: isNoteFile(source.name),
              onBytes: (bytes) => advance(BackupPhase.writing, bytes),
            );
          } on ZipSourceChangedException {
            done = before;
            if (attempt >= 2) {
              throw BackupException(
                BackupFailure.changedWhileReading,
                source.name,
              );
            }
          }
        }
        files[source.name] = (size: added.size, sha256: added.sha256);
      }

      final handwriting = File(handwritingPath);
      if (handwriting.existsSync()) {
        final added = writer.addBytes(
          handwritingName,
          handwriting.readAsBytesSync(),
        );
        files[handwritingName] = (size: added.size, sha256: added.sha256);
      }
      if (penProfiles.isNotEmpty) {
        final added = writer.addBytes(penProfilesName, utf8.encode(penProfiles));
        files[penProfilesName] = (size: added.size, sha256: added.sha256);
      }

      final manifest = BackupManifest(
        created: created,
        appVersion: appVersion,
        files: files,
      );
      writer.addBytes(
        BackupManifest.entryName,
        utf8.encode(const JsonEncoder.withIndent(' ').convert(manifest)),
      );
      writer.close();

      // A backup is only worth something if it can be read back.
      verify(zipPath, report: report);

      return BackupSummary(
        path: zipPath,
        created: created,
        notes: manifest.notes,
        recordings: manifest.recordings,
        files: files.length,
        bytes: manifest.bytes,
        zipBytes: File(zipPath).lengthSync(),
      );
    } on BackupException {
      writer.abort();
      rethrow;
    } on FileSystemException catch (e) {
      writer.abort();
      throw BackupException(BackupFailure.io, e.message);
    } on Object {
      writer.abort();
      rethrow;
    }
  }

  /// The last part of [path], whichever way its slashes lean.
  static String _baseName(String path) {
    final clean = _withoutTrailingSlash(path.replaceAll('\\', '/'));
    return clean.substring(clean.lastIndexOf('/') + 1);
  }

  static String? _decode(String component) {
    try {
      return Uri.decodeComponent(component);
    } on ArgumentError {
      return null;
    } on FormatException {
      return null;
    }
  }

  static BackupManifest _readManifest(ZipReader reader) {
    final entry = reader.find(BackupManifest.entryName);
    if (entry == null) throw const BackupException(BackupFailure.notABackup);
    final Object? json;
    try {
      json = jsonDecode(utf8.decode(reader.readBytes(entry)));
    } on FormatException {
      throw const BackupException(BackupFailure.damaged, 'manifest');
    } on ZipFormatException {
      throw const BackupException(BackupFailure.damaged, 'manifest');
    }
    return BackupManifest.fromJson(json);
  }

  static ZipReader _open(String zipPath) {
    try {
      return ZipReader.open(zipPath);
    } on ZipFormatException catch (e) {
      throw BackupException(BackupFailure.notABackup, e.message);
    } on FileSystemException catch (e) {
      throw BackupException(BackupFailure.io, e.message);
    }
  }

  /// What the backup at [zipPath] says it holds, without checking that it
  /// really does (see [verify]).
  static BackupManifest inspect(String zipPath) {
    final reader = _open(zipPath);
    try {
      return _readManifest(reader);
    } finally {
      reader.close();
    }
  }

  /// Reads every file of the backup at [zipPath] and checks it against the
  /// list: throws a [BackupException] if one is missing or altered.
  static BackupManifest verify(
    String zipPath, {
    void Function(BackupProgress progress)? report,
  }) {
    final reader = _open(zipPath);
    try {
      final manifest = _readManifest(reader);
      final total = manifest.bytes;
      var done = 0;
      var reported = -1;
      for (final MapEntry(key: name, value: expected) in manifest.files.entries) {
        final entry = reader.find(name);
        if (entry == null || entry.size != expected.size) {
          throw BackupException(BackupFailure.damaged, name);
        }
        final String hash;
        try {
          hash = reader.read(entry, (data) {
            done += data.length;
            final step = total <= 0 ? 0 : done * 200 ~/ total;
            if (step == reported) return;
            reported = step;
            report?.call(BackupProgress(BackupPhase.verifying, done, total));
          });
        } on ZipFormatException {
          throw BackupException(BackupFailure.damaged, name);
        }
        if (hash != expected.sha256) {
          throw BackupException(BackupFailure.damaged, name);
        }
      }
      return manifest;
    } on FileSystemException catch (e) {
      throw BackupException(BackupFailure.io, e.message);
    } finally {
      reader.close();
    }
  }

  /// Whether [path] (starting with a slash) stays inside the folder it is
  /// meant for when it is added to that folder's path.
  static bool isSafePath(String path) {
    if (!path.startsWith('/') || path.contains('\\') || path.contains('\x00')) {
      return false;
    }
    final segments = path.substring(1).split('/');
    return segments.every(
      (segment) => segment.isNotEmpty && segment != '.' && segment != '..',
    );
  }

  static bool _noteExists(String documentsPath, String key) =>
      File('$documentsPath$key.sbn2').existsSync() ||
      File('$documentsPath$key.sbn').existsSync();

  /// Whether the note [key] on the device is the one [group] holds: its
  /// note file is the same byte for byte and it has as many assets, each
  /// of the same size.
  static bool _sameNote(
    String documentsPath,
    String key,
    _Group group,
    BackupManifest manifest,
  ) {
    final local = File('$documentsPath$key${group.extension}');
    if (!local.existsSync()) return false;
    final main = manifest.files[group.main]!;
    if (local.lengthSync() != main.size) return false;
    for (final MapEntry(key: index, value: name) in group.assets.entries) {
      final asset = File('${local.path}.$index');
      if (!asset.existsSync()) return false;
      if (asset.lengthSync() != manifest.files[name]!.size) return false;
    }
    if (File('${local.path}.${group.assets.length}').existsSync()) return false;
    return NoteVersionStore.hashOfFile(local) == main.sha256;
  }

  /// Brings the notes of the backup at [zipPath] back into
  /// [documentsPath], and their recordings into [recordingsPath].
  ///
  /// Nothing on the device is replaced or removed: a note that is here
  /// already and the same is left alone, and one that differs from the
  /// note of the same name is put next to it under a numbered name. Notes
  /// that are damaged in the backup are left out, and the others are still
  /// brought back.
  static RestoreOutcome restore({
    required String zipPath,
    required String documentsPath,
    required String recordingsPath,
    void Function(BackupProgress progress)? report,
  }) {
    documentsPath = _withoutTrailingSlash(documentsPath);
    final reader = _open(zipPath);
    final pending = <File>[];
    try {
      final manifest = _readManifest(reader);

      final groups = <String, _Group>{};
      for (final name in manifest.files.keys) {
        if (!name.startsWith('notes/')) continue;
        final path = name.substring('notes'.length);
        if (!isSafePath(path) || _inTrash(path)) continue;
        final match = _notePart.firstMatch(path);
        if (match == null) continue;
        final key = match.group(1)!, extension = match.group(2)!;
        final part = match.group(3);
        final group = groups.putIfAbsent(
          '$key$extension',
          () => _Group(key, extension),
        );
        if (part == null) {
          group.main = name;
        } else if (part == 'p') {
          group.preview = name;
        } else {
          group.assets[int.parse(part)] = name;
        }
      }

      final recordingsByKey = <String, List<String>>{};
      for (final name in manifest.files.keys) {
        if (!name.startsWith('recordings/')) continue;
        final parts = name.split('/');
        if (parts.length != 3 || parts[2].isEmpty) continue;
        if (!isSafePath('/${parts[2]}')) continue;
        final key = _decode(parts[1]);
        if (key == null || !isSafePath(key)) continue;
        recordingsByKey.putIfAbsent(key, () => []).add(name);
      }

      Map<String, Object?> handwritingByKey = const {};
      final handwritingEntry = reader.find(handwritingName);
      if (handwritingEntry != null) {
        try {
          final json = jsonDecode(
            utf8.decode(reader.readBytes(handwritingEntry)),
          );
          if (json is Map<String, dynamic>) handwritingByKey = json;
        } on FormatException {
          // The notes are what matters: they are brought back without it.
        } on ZipFormatException {
          // As above.
        }
      }

      String? penProfiles;
      final penProfilesEntry = reader.find(penProfilesName);
      if (penProfilesEntry != null) {
        try {
          penProfiles = utf8.decode(reader.readBytes(penProfilesEntry));
        } on FormatException {
          penProfiles = null;
        } on ZipFormatException {
          penProfiles = null;
        }
      }

      // Folders first, so that empty ones come back too.
      for (final entry in reader.entries) {
        if (!entry.isDirectory || !entry.name.startsWith('notes/')) continue;
        final path = _withoutTrailingSlash(
          entry.name.substring('notes'.length),
        );
        if (!isSafePath(path) || _inTrash(path)) continue;
        Directory('$documentsPath$path').createSync(recursive: true);
      }

      final total = manifest.bytes;
      var done = 0;
      var reported = -1;
      void advance(int bytes) {
        done += bytes;
        final step = total <= 0 ? 0 : done * 200 ~/ total;
        if (step == reported) return;
        reported = step;
        report?.call(BackupProgress(BackupPhase.restoring, done, total));
      }

      /// Takes [name] out of the zip to [target].tmp and checks it.
      File extract(String name, String target) {
        final entry = reader.find(name);
        final expected = manifest.files[name]!;
        if (entry == null) throw ZipFormatException('$name is missing');
        final temp = File('$target.tmp');
        pending.add(temp);
        temp.parent.createSync(recursive: true);
        final out = temp.openSync(mode: FileMode.write);
        final String hash;
        try {
          hash = reader.read(entry, (data) {
            out.writeFromSync(data);
            advance(data.length);
          });
          out.flushSync();
        } finally {
          out.closeSync();
        }
        if (hash != expected.sha256) throw ZipFormatException('$name is damaged');
        return temp;
      }

      void discardPending() {
        for (final file in pending) {
          if (file.existsSync()) file.deleteSync();
        }
        pending.clear();
      }

      final restored = <String>[];
      final copies = <String, String>{};
      final alreadyThere = <String>[];
      final failed = <String>[];
      final written = <String>[];
      final handwriting = <String, Object?>{};
      var recordingCount = 0;

      final ordered = groups.values.toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      for (final group in ordered) {
        final groupBytes = [
          group.main,
          group.preview,
          ...group.assets.values,
        ].nonNulls.fold<int>(0, (sum, name) => sum + manifest.files[name]!.size);
        final doneBefore = done;

        // Assets are numbered from zero without gaps, or the note is not
        // whole.
        final assetCount = group.assets.length;
        final whole =
            group.main != null &&
            [for (var i = 0; i < assetCount; i++) i].every(
              group.assets.containsKey,
            );
        if (!whole) {
          failed.add(group.key);
          advance(doneBefore + groupBytes - done);
          continue;
        }

        // Where it goes: its own place if that is free, else the first
        // numbered name that is free (unless the note is there already).
        var target = group.key;
        var same = false;
        for (var n = 2; _noteExists(documentsPath, target); n++) {
          if (_sameNote(documentsPath, target, group, manifest)) {
            same = true;
            break;
          }
          target = '${group.key} ($n)';
        }

        if (same) {
          alreadyThere.add(group.key);
        } else {
          final mainPath = '$documentsPath$target${group.extension}';
          try {
            final moves = <(File, String)>[
              for (var i = 0; i < assetCount; i++)
                (extract(group.assets[i]!, '$mainPath.$i'), '$mainPath.$i'),
              if (group.preview != null)
                (extract(group.preview!, '$mainPath.p'), '$mainPath.p'),
              // The note itself last: it only shows up once it is whole.
              (extract(group.main!, mainPath), mainPath),
            ];
            for (final (temp, path) in moves) {
              temp.renameSync(path);
              written.add(path.substring(documentsPath.length));
            }
            pending.clear();
          } on ZipFormatException {
            discardPending();
            failed.add(group.key);
            advance(doneBefore + groupBytes - done);
            continue;
          }
          if (target == group.key) {
            restored.add(group.key);
          } else {
            copies[group.key] = target;
          }
        }
        advance(doneBefore + groupBytes - done);

        // What belongs to the note goes where the note went.
        for (final name in recordingsByKey[group.key] ?? const <String>[]) {
          final expected = manifest.files[name]!;
          final fileName = name.split('/').last;
          final folder = '$recordingsPath/${Uri.encodeComponent(target)}';
          var file = File('$folder/$fileName');
          if (file.existsSync() && file.lengthSync() == expected.size) {
            advance(expected.size);
            continue; // it is here already
          }
          final dot = fileName.lastIndexOf('.');
          final base = dot < 0 ? fileName : fileName.substring(0, dot);
          final ending = dot < 0 ? '' : fileName.substring(dot);
          for (var n = 1; file.existsSync(); n++) {
            file = File('$folder/${base}_$n$ending');
          }
          final doneHere = done;
          try {
            extract(name, file.path).renameSync(file.path);
            pending.clear();
            recordingCount++;
          } on ZipFormatException {
            discardPending();
          }
          advance(doneHere + expected.size - done);
        }
        if (handwritingByKey[group.key] case final text?) {
          handwriting[target] = text;
        }
      }

      report?.call(BackupProgress(BackupPhase.restoring, total, total));
      return RestoreOutcome(
        restored: restored,
        copies: copies,
        alreadyThere: alreadyThere,
        failed: failed,
        writtenFiles: written,
        recordings: recordingCount,
        handwriting: handwriting,
        penProfiles: penProfiles,
      );
    } on FileSystemException catch (e) {
      for (final file in pending) {
        try {
          if (file.existsSync()) file.deleteSync();
        } on FileSystemException {
          // Left behind: it is a .tmp file, which is never shown as a note.
        }
      }
      throw BackupException(BackupFailure.io, e.message);
    } finally {
      reader.close();
    }
  }
}

/// A full backup of the library in one file, and bringing one back.
///
/// The work is done by [NoteBackupWork] in another isolate; this is what
/// the app calls.
abstract class NoteBackup {
  static final log = Logger('NoteBackup');

  /// Tests run the work in place, unless they are about the isolate.
  static var useIsolate = !isThisATest;

  /// Where backups are made before they are handed to the user. Tests point
  /// this somewhere else.
  static Directory? folderOverride;

  static Future<Directory> folder() async =>
      folderOverride ??
      Directory('${(await getTemporaryDirectory()).path}/defter_backup');

  static String _two(int n) => n.toString().padLeft(2, '0');

  /// The name a backup made at [time] is given.
  static String fileName(DateTime time) =>
      'Marj-yedek-${time.year}-${_two(time.month)}-${_two(time.day)}'
      '-${_two(time.hour)}${_two(time.minute)}.zip';

  static File get _handwritingFile => HandwritingTexts.file;

  static Future<T> _spawn<T>(
    T Function(void Function(BackupProgress progress) report) work,
    SendPort port,
  ) => Isolate.run(
    () => work(
      (progress) =>
          port.send([progress.phase.index, progress.done, progress.total]),
    ),
  );

  /// Runs [work] away from the screen, passing on what it reports.
  static Future<T> _run<T>(
    T Function(void Function(BackupProgress progress) report) work,
    void Function(BackupProgress progress)? onProgress,
  ) async {
    if (!useIsolate) return work((progress) => onProgress?.call(progress));

    final port = ReceivePort();
    final subscription = port.listen((message) {
      if (message is! List || message.length != 3) return;
      onProgress?.call(
        BackupProgress(
          BackupPhase.values[message[0] as int],
          message[1] as int,
          message[2] as int,
        ),
      );
    });
    try {
      return await _spawn(work, port.sendPort);
    } finally {
      await subscription.cancel();
      port.close();
    }
  }

  /// Makes a backup of every note (those in the trash aside), with their
  /// pictures, PDFs, recordings and handwriting text, and the pen
  /// profiles, and checks it by reading it back.
  ///
  /// The file is made in [folder], where only the newest backup is kept:
  /// it is for the user to save somewhere safe. Throws a
  /// [BackupException] if it can't be made.
  static Future<BackupSummary> create({
    void Function(BackupProgress progress)? onProgress,
    DateTime? now,
  }) async {
    // Whatever is being saved right now is in the backup whole.
    await NoteVersions.whenIdle();

    final created = now ?? DateTime.now();
    final directory = await folder();
    if (directory.existsSync()) {
      for (final entity in directory.listSync()) {
        if (entity is File) entity.deleteSync();
      }
    }
    directory.createSync(recursive: true);

    final documentsPath = FileManager.documentsDirectory;
    final recordingsPath = NoteRecordings.root.path;
    final handwritingPath = _handwritingFile.path;
    final penProfiles = stows.penProfiles.value;
    final zipPath = '${directory.path}/${fileName(created)}';
    return _run(
      (report) => NoteBackupWork.create(
        documentsPath: documentsPath,
        recordingsPath: recordingsPath,
        handwritingPath: handwritingPath,
        penProfiles: penProfiles,
        zipPath: zipPath,
        created: created,
        appVersion: buildName,
        report: report,
      ),
      onProgress,
    );
  }

  /// The backup that was last made on this device, if its file is still in
  /// [folder].
  static Future<File?> latest() async {
    final directory = await folder();
    if (!directory.existsSync()) return null;
    final files =
        directory
            .listSync()
            .whereType<File>()
            .where((file) => file.path.endsWith('.zip'))
            .toList()
          ..sort((a, b) => b.path.compareTo(a.path));
    return files.firstOrNull;
  }

  /// What the backup at [zipPath] says it holds. Throws a
  /// [BackupException] if it isn't a backup.
  static Future<BackupManifest> inspect(String zipPath) =>
      _run((_) => NoteBackupWork.inspect(zipPath), null);

  /// Brings the backup at [zipPath] back (see [NoteBackupWork.restore]:
  /// nothing here is replaced or removed).
  static Future<RestoreOutcome> restore(
    String zipPath, {
    void Function(BackupProgress progress)? onProgress,
  }) async {
    await NoteVersions.whenIdle();
    final documentsPath = FileManager.documentsDirectory;
    final recordingsPath = NoteRecordings.root.path;
    final outcome = await _run(
      (report) => NoteBackupWork.restore(
        zipPath: zipPath,
        documentsPath: documentsPath,
        recordingsPath: recordingsPath,
        report: report,
      ),
      onProgress,
    );

    // Handwriting text for notes that have none here.
    await HandwritingTexts.load();
    for (final MapEntry(key: path, value: json) in outcome.handwriting.entries) {
      if (HandwritingTexts.of(path) != null) continue;
      try {
        await HandwritingTexts.put(
          path,
          NoteHandwriting.fromJson(json as Map<String, dynamic>),
        );
      } on Object catch (e) {
        log.warning('Left out unreadable handwriting text for $path: $e');
      }
    }

    // Pen profiles that are not here yet.
    final theirs = PenProfiles.decode(outcome.penProfiles ?? '');
    if (theirs != null) {
      final mine = PenProfiles.load();
      final missing = [
        for (final profile in theirs)
          if (!mine.any((other) => other.id == profile.id)) profile,
      ];
      if (missing.isNotEmpty) PenProfiles.save([...mine, ...missing]);
    }

    for (final path in outcome.writtenFiles) {
      unawaited(syncer.uploader.enqueueRel(path));
    }
    return outcome;
  }
}
