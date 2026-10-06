import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:logging/logging.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/is_this_a_test.dart';
import 'package:saber/data/prefs.dart';

/// An earlier state of a note that can be brought back.
///
/// It names the content of the note file, of each of its assets (images,
/// PDF pages) and of its preview by their SHA-256 hash; the content itself
/// is kept once in the store, however many versions use it.
class NoteVersion {
  const NoteVersion({
    required this.id,
    required this.key,
    required this.time,
    required this.extension,
    required this.main,
    required this.assets,
    required this.preview,
    required this.size,
    required this.reason,
  });

  /// Names the version among those of its note; later versions sort after
  /// earlier ones.
  final String id;

  /// The note's path without its extension, as it was when this was kept.
  final String key;
  final DateTime time;

  /// The extension of the note file: ".sbn2", or ".sbn" for old notes.
  final String extension;

  /// The hash of the note file.
  final String main;

  /// The hashes of the assets, in the order the note numbers them.
  final List<String> assets;

  /// The hash of the preview picture, if the note had one.
  final String? preview;

  /// How many bytes the note file and its assets take together.
  final int size;

  /// Why this was kept: one of the constants below.
  final String reason;

  /// The note as it was found when it was opened.
  static const reasonOpen = 'open';

  /// A state reached while writing, kept every few minutes.
  static const reasonAuto = 'auto';

  /// The note as it was left when it was closed.
  static const reasonClose = 'close';

  /// The note as it was just before an older version was brought back.
  static const reasonRestore = 'restore';

  /// Every hash this version needs in the store.
  Iterable<String> get hashes sync* {
    yield main;
    yield* assets;
    if (preview != null) yield preview!;
  }

  Map<String, dynamic> toJson() => {
    'format': 1,
    'id': id,
    'key': key,
    'time': time.toUtc().toIso8601String(),
    'extension': extension,
    'main': main,
    'assets': assets,
    'preview': preview,
    'size': size,
    'reason': reason,
  };

  static final _hash = RegExp(r'^[0-9a-f]{64}$');

  /// Reads [toJson]'s map; null if it isn't a version that can be used.
  ///
  /// [id] and [key], when given, are used in place of those in the map:
  /// where the version is found says more than what it was first called
  /// (a note's versions follow it when it is renamed).
  static NoteVersion? fromJson(Object? json, {String? id, String? key}) {
    if (json is! Map) return null;
    id ??= json['id'] is String ? json['id'] as String : null;
    key ??= json['key'] is String ? json['key'] as String : null;
    final main = json['main'];
    final time = DateTime.tryParse('${json['time']}');
    final assets = json['assets'], preview = json['preview'];
    final extension = json['extension'];
    if (id == null || key == null || time == null) return null;
    if (main is! String || !_hash.hasMatch(main)) return null;
    if (assets is! List) return null;
    if (extension != '.sbn2' && extension != '.sbn') return null;
    final hashes = <String>[];
    for (final asset in assets) {
      if (asset is! String || !_hash.hasMatch(asset)) return null;
      hashes.add(asset);
    }
    if (preview != null && (preview is! String || !_hash.hasMatch(preview))) {
      return null;
    }
    final size = json['size'];
    return NoteVersion(
      id: id,
      key: key,
      time: time.toLocal(),
      extension: extension as String,
      main: main,
      assets: hashes,
      preview: preview as String?,
      size: size is int ? size : 0,
      reason: '${json['reason'] ?? reasonAuto}',
    );
  }
}

class _DigestSink implements Sink<Digest> {
  Digest? value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}

/// Where versions are kept on disk, and everything that is done to them.
///
/// It only uses plain files and paths, with blocking calls: it is meant to
/// be run away from the screen, in another isolate (see [NoteVersions]).
///
/// On disk: `objects/ab/<hash>` holds the content named by a hash, and
/// `notes/<folder>/<id>.json` the versions of one note, where the folder is
/// named after the hash of the note's path (paths can be too long, or have
/// characters a file name can't).
class NoteVersionStore {
  const NoteVersionStore(this.rootPath);

  final String rootPath;

  /// Objects younger than this are never collected as garbage: the version
  /// that will name them may still be being written.
  static const garbageGrace = Duration(minutes: 10);

  static String hashOfText(String text) =>
      sha256.convert(utf8.encode(text)).toString();

  /// The SHA-256 of [file], read in pieces so that a large PDF never has to
  /// fit in memory.
  static String hashOfFile(File file) {
    final sink = _DigestSink();
    final input = sha256.startChunkedConversion(sink);
    final handle = file.openSync();
    try {
      final buffer = Uint8List(1 << 16);
      while (true) {
        final read = handle.readIntoSync(buffer);
        if (read <= 0) break;
        input.add(Uint8List.sublistView(buffer, 0, read));
      }
    } finally {
      handle.closeSync();
    }
    input.close();
    return sink.value!.toString();
  }

  Directory directoryOf(String key) =>
      Directory('$rootPath/notes/${hashOfText(key).substring(0, 32)}');

  File objectFile(String hash) =>
      File('$rootPath/objects/${hash.substring(0, 2)}/$hash');

  /// The versions of the note [key], newest first. Version files that
  /// can't be read are left out.
  List<NoteVersion> list(String key) {
    final directory = directoryOf(key);
    if (!directory.existsSync()) return const [];
    final versions = <NoteVersion>[];
    for (final entity in directory.listSync()) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      final name = entity.uri.pathSegments.last;
      final version = _read(
        entity,
        id: name.substring(0, name.length - '.json'.length),
        key: key,
      );
      if (version != null) versions.add(version);
    }
    versions.sort((a, b) {
      final byTime = b.time.compareTo(a.time);
      return byTime != 0 ? byTime : b.id.compareTo(a.id);
    });
    return versions;
  }

  static NoteVersion? _read(File file, {String? id, String? key}) {
    try {
      return NoteVersion.fromJson(
        jsonDecode(file.readAsStringSync()),
        id: id,
        key: key,
      );
    } on FormatException {
      return null;
    } on FileSystemException {
      return null;
    }
  }

  /// Puts the content of [source] in the store (unless it is there
  /// already) and returns its hash.
  String _store(File source) {
    final hash = hashOfFile(source);
    final target = objectFile(hash);
    if (target.existsSync() && target.lengthSync() == source.lengthSync()) {
      return hash;
    }
    // Copied first and named after what the copy holds: the file may have
    // been replaced since it was hashed, and content must never be found
    // under a hash that is not its own (nor half written).
    final temp = File('$rootPath/objects/incoming-$pid.tmp');
    temp.parent.createSync(recursive: true);
    source.copySync(temp.path);
    final copied = hashOfFile(temp);
    final place = objectFile(copied);
    place.parent.createSync(recursive: true);
    temp.renameSync(place.path);
    return copied;
  }

  static void _writeAtomically(File file, String text) {
    file.parent.createSync(recursive: true);
    final temp = File('${file.path}.tmp');
    final handle = temp.openSync(mode: FileMode.write);
    try {
      handle.writeStringSync(text);
      handle.flushSync();
    } finally {
      handle.closeSync();
    }
    temp.renameSync(file.path);
  }

  /// Whether the note file at [mainFilePath] and its assets are what
  /// [version] holds, judged without reading the assets again: the note
  /// file must be the same byte for byte, and there must be as many assets,
  /// each as large as the one that was kept.
  bool _looksLike(NoteVersion version, String mainFilePath, String mainHash) {
    if (version.main != mainHash) return false;
    for (var i = 0; i < version.assets.length; i++) {
      final asset = File('$mainFilePath.$i');
      final kept = objectFile(version.assets[i]);
      if (!asset.existsSync() || !kept.existsSync()) return false;
      if (asset.lengthSync() != kept.lengthSync()) return false;
    }
    return !File('$mainFilePath.${version.assets.length}').existsSync();
  }

  /// Whether nothing would be lost if the note file at [mainFilePath] were
  /// replaced now: there is no note there, or a version of [key] holds it
  /// as it is.
  bool isKept(String key, String mainFilePath) {
    final mainFile = File(mainFilePath);
    if (!mainFile.existsSync() || mainFile.lengthSync() == 0) return true;
    final versions = list(key);
    if (versions.isEmpty) return false;
    final hash = hashOfFile(mainFile);
    return versions.any((version) => _looksLike(version, mainFilePath, hash));
  }

  /// Keeps the note whose file is at [mainFilePath] (a full path on disk,
  /// extension included) as a version of [key].
  ///
  /// Returns null without keeping anything when there is no such note, when
  /// the newest version already holds it, when the newest version is
  /// younger than [minInterval], or when the note was being written while
  /// it was read.
  NoteVersion? snapshot({
    required String key,
    required String mainFilePath,
    required DateTime now,
    required String reason,
    Duration minInterval = Duration.zero,
    int keepRecent = NoteVersions.keepRecent,
    int keepDaily = NoteVersions.keepDaily,
  }) {
    final mainFile = File(mainFilePath);
    if (!mainFile.existsSync() || mainFile.lengthSync() == 0) return null;
    final extension = mainFilePath.endsWith('.sbn2') ? '.sbn2' : '.sbn';

    final existing = list(key);
    if (existing.isNotEmpty &&
        now.difference(existing.first.time).abs() < minInterval) {
      return null;
    }
    final mainHashBefore = hashOfFile(mainFile);
    if (existing.isNotEmpty &&
        _looksLike(existing.first, mainFilePath, mainHashBefore)) {
      return null;
    }

    final main = _store(mainFile);
    var size = mainFile.lengthSync();
    final assets = <String>[];
    final assetStats = <(int, DateTime)>[];
    for (var i = 0; true; i++) {
      final asset = File('$mainFilePath.$i');
      if (!asset.existsSync()) break;
      final stat = asset.statSync();
      assetStats.add((stat.size, stat.modified));
      assets.add(_store(asset));
      size += stat.size;
    }
    final previewFile = File('$mainFilePath.p');
    final preview = previewFile.existsSync() && previewFile.lengthSync() > 0
        ? _store(previewFile)
        : null;

    // The note was saved again while it was being read: what was gathered
    // may be half one state and half the next. Leave it for the next time.
    if (main != mainHashBefore) return null;
    if (!mainFile.existsSync() || hashOfFile(mainFile) != main) return null;
    if (File('$mainFilePath.${assets.length}').existsSync()) return null;
    for (var i = 0; i < assets.length; i++) {
      final asset = File('$mainFilePath.$i');
      if (!asset.existsSync()) return null;
      final stat = asset.statSync();
      if ((stat.size, stat.modified) != assetStats[i]) return null;
    }

    final stamp = now.toUtc().millisecondsSinceEpoch.toString().padLeft(15, '0');
    var id = 'v$stamp';
    final directory = directoryOf(key);
    for (var n = 1; File('${directory.path}/$id.json').existsSync(); n++) {
      id = 'v$stamp-$n';
    }
    final version = NoteVersion(
      id: id,
      key: key,
      time: now,
      extension: extension,
      main: main,
      assets: assets,
      preview: preview,
      size: size,
      reason: reason,
    );
    _writeAtomically(
      File('${directory.path}/$id.json'),
      jsonEncode(version.toJson()),
    );
    if (prune(key, keepRecent: keepRecent, keepDaily: keepDaily) > 0) {
      collectGarbage(now: now);
    }
    return version;
  }

  /// Which of [newestFirst] stay when the history is thinned: the newest
  /// [keepRecent], and of the older ones the last of each day (a day that
  /// already has a version among those kept needs no other) for up to
  /// [keepDaily] days.
  static Set<String> idsToKeep(
    List<NoteVersion> newestFirst, {
    required int keepRecent,
    required int keepDaily,
  }) {
    String dayOf(DateTime t) => '${t.year}-${t.month}-${t.day}';
    final keep = <String>{};
    final days = <String>{};
    var daily = 0;
    for (final (index, version) in newestFirst.indexed) {
      final day = dayOf(version.time);
      if (index < keepRecent) {
        keep.add(version.id);
        days.add(day);
      } else if (daily < keepDaily && days.add(day)) {
        keep.add(version.id);
        daily++;
      }
    }
    return keep;
  }

  /// Thins the history of [key] (see [idsToKeep]); returns how many
  /// versions were removed.
  int prune(String key, {required int keepRecent, required int keepDaily}) {
    final versions = list(key);
    final keep = idsToKeep(
      versions,
      keepRecent: keepRecent,
      keepDaily: keepDaily,
    );
    var removed = 0;
    for (final version in versions) {
      if (keep.contains(version.id)) continue;
      if (remove(key, version.id)) removed++;
    }
    return removed;
  }

  /// Forgets one version; returns whether it was there.
  bool remove(String key, String id) {
    final file = File('${directoryOf(key).path}/$id.json');
    if (!file.existsSync()) return false;
    file.deleteSync();
    return true;
  }

  /// The hashes [version] needs that are missing from the store or have
  /// the wrong content there. Empty when the version can be brought back.
  List<String> damaged(NoteVersion version) => [
    for (final hash in version.hashes.toSet())
      if (!objectFile(hash).existsSync() ||
          hashOfFile(objectFile(hash)) != hash)
        hash,
  ];

  /// Gives the versions of [fromKey] to [toKey], when a note is renamed or
  /// moved. If [toKey] has versions already, both sets are kept.
  void move(String fromKey, String toKey) {
    final from = directoryOf(fromKey), to = directoryOf(toKey);
    if (from.path == to.path || !from.existsSync()) return;
    to.createSync(recursive: true);
    for (final entity in from.listSync()) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      final name = entity.uri.pathSegments.last;
      var target = File('${to.path}/$name');
      for (var n = 1; target.existsSync(); n++) {
        target = File(
          '${to.path}/${name.substring(0, name.length - '.json'.length)}'
          '-m$n.json',
        );
      }
      entity.renameSync(target.path);
    }
    from.deleteSync(recursive: true);
  }

  /// Forgets every version of [key].
  void deleteAll(String key) {
    final directory = directoryOf(key);
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  }

  /// Forgets every version of every note.
  void clear() {
    final root = Directory(rootPath);
    if (root.existsSync()) root.deleteSync(recursive: true);
  }

  /// Deletes the content no version names any more; returns how many
  /// bytes that freed.
  int collectGarbage({required DateTime now}) {
    final objects = Directory('$rootPath/objects');
    if (!objects.existsSync()) return 0;

    final used = <String>{};
    final notes = Directory('$rootPath/notes');
    if (notes.existsSync()) {
      for (final entity in notes.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.json')) continue;
        final String text;
        try {
          text = entity.readAsStringSync();
        } on FileSystemException {
          // A version that can't be read right now might name anything:
          // nothing is thrown away this time.
          return 0;
        }
        final NoteVersion? version;
        try {
          version = NoteVersion.fromJson(jsonDecode(text));
        } on FormatException {
          // Damaged for good: it can never be brought back, so it holds on
          // to nothing.
          continue;
        }
        if (version != null) used.addAll(version.hashes);
      }
    }

    var freed = 0;
    for (final entity in objects.listSync(recursive: true)) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.last;
      if (used.contains(name)) continue;
      final stat = entity.statSync();
      if (now.difference(stat.modified) < garbageGrace) continue;
      freed += stat.size;
      entity.deleteSync();
    }
    return freed;
  }

  /// How many bytes the store takes on disk.
  int totalSize() {
    final root = Directory(rootPath);
    if (!root.existsSync()) return 0;
    var total = 0;
    for (final entity in root.listSync(recursive: true)) {
      if (entity is File) total += entity.lengthSync();
    }
    return total;
  }
}

/// The version history of notes: earlier states are kept as a note is
/// written, and any of them can be brought back.
///
/// Versions live in their own folder next to (not inside) the notes
/// folder, so they are neither listed in the library nor synced. They
/// follow a note when it is renamed, moved or put in the trash, and go
/// when it is deleted for good.
///
/// A version is read from the note's files on disk, away from the pen in
/// another isolate. So that it never holds half of one save and half of
/// the next, a save and the reading of a version wait for each other (see
/// [beginSave]), and a version that was read while the note was written
/// all the same is thrown away.
abstract class NoteVersions {
  static final log = Logger('NoteVersions');

  /// The newest versions of a note, all of which are kept.
  static const keepRecent = 10;

  /// Of the versions older than those, one a day is kept for this many
  /// days.
  static const keepDaily = 20;

  /// While a note is being written, a version is kept at most this often.
  static const minInterval = Duration(minutes: 10);

  /// Where versions are kept. Tests point this somewhere else.
  static Directory? rootOverride;

  static Directory get root =>
      rootOverride ??
      Directory(
        '${Directory(FileManager.documentsDirectory).parent.path}'
        '/note_versions',
      );

  static NoteVersionStore get store => NoteVersionStore(root.path);

  /// Whether the hashing and copying is done in another isolate. Tests
  /// run it in place, unless they are about the isolate.
  static var useIsolate = !isThisATest;

  /// Whether versions are kept as notes are written. Versions that were
  /// kept earlier can be looked at and brought back either way.
  static bool get enabled => stows.versionHistory.value;

  static final _notePart = RegExp(r'\.sbn2?(\.[\dp]+)?(\.(tmp|bak|bad))?$');

  /// A note's path without its file extension, which is how versions
  /// identify it. The paths of a note's assets give the note's key too.
  static String keyOf(String notePath) => notePath.replaceFirst(_notePart, '');

  /// The note file of [notePath] on disk: the current format if it is
  /// there, else the old one.
  static File _mainFile(String notePath) {
    final key = keyOf(notePath);
    final current = FileManager.getFile('$key.sbn2');
    if (current.existsSync()) return current;
    final old = FileManager.getFile('$key.sbn');
    return old.existsSync() ? old : current;
  }

  static Future<T> _run<T>(T Function() work) =>
      useIsolate ? Isolate.run(work) : Future.sync(work);

  /// The notes a version is being read from right now.
  static final _reading = <String, Future<void>>{};

  /// The notes that are being saved right now.
  static final _saving = <String, Future<void>>{};

  /// How many times each note was written since the app started.
  static final _writes = <String, int>{};

  /// Says that a file of a note is about to be written.
  static void noteWritten(String filePath) {
    final key = keyOf(filePath);
    _writes[key] = (_writes[key] ?? 0) + 1;
  }

  /// Call before writing the files of the note at [notePath], and call
  /// what it returns once they are all written.
  ///
  /// Waits for a version that is being read from the note, but only for a
  /// few seconds: saving is never held up for long (a version that was not
  /// finished by then is thrown away instead).
  static Future<void Function()> beginSave(String notePath) async {
    final key = keyOf(notePath);
    final reading = _reading[key];
    if (reading != null) {
      await reading.timeout(const Duration(seconds: 3), onTimeout: () {});
    }
    final completer = Completer<void>();
    _saving[key] = completer.future;
    noteWritten(key);
    return () {
      if (identical(_saving[key], completer.future)) _saving.remove(key);
      if (!completer.isCompleted) completer.complete();
    };
  }

  /// Completes once no note is in the middle of being saved.
  static Future<void> whenIdle() async {
    if (_saving.isEmpty) return;
    await Future.wait(_saving.values.toList()).timeout(
      const Duration(seconds: 30),
      onTimeout: () => const [],
    );
  }

  /// Keeps the note at [notePath] as it is on disk now, unless the newest
  /// version is younger than [minInterval]. See [NoteVersionStore.snapshot]
  /// for when else nothing is kept.
  ///
  /// With [always], a version is kept even if keeping versions is turned
  /// off (it is used before a version is brought back).
  static Future<NoteVersion?> snapshot(
    String notePath, {
    required String reason,
    Duration minInterval = Duration.zero,
    bool always = false,
    DateTime? now,
  }) async {
    if (!enabled && !always) return null;
    final key = keyOf(notePath);
    // A note that has no place yet has nothing on disk to keep.
    if (!key.startsWith('/')) return null;
    try {
      // One thing at a time for each note. (No time limit here: a save
      // always ends, and a version must not be read in the middle of one.)
      while (true) {
        final pending = _saving[key] ?? _reading[key];
        if (pending == null) break;
        await pending;
      }

      final mainPath = _mainFile(notePath).path;
      final store = NoteVersions.store;
      final time = now ?? DateTime.now();
      final writes = _writes[key] ?? 0;
      final work = _run(
        () => store.snapshot(
          key: key,
          mainFilePath: mainPath,
          now: time,
          reason: reason,
          minInterval: minInterval,
        ),
      );
      final done = work.then<void>((_) {}, onError: (Object _) {});
      _reading[key] = done;
      try {
        final version = await work;
        if (version != null && (_writes[key] ?? 0) != writes) {
          // The note was written while it was read.
          final id = version.id;
          await _run(() => store.remove(key, id));
          return null;
        }
        return version;
      } finally {
        if (identical(_reading[key], done)) _reading.remove(key);
      }
    } on Object catch (e, st) {
      // Keeping versions must never get in the way of writing.
      log.severe('Could not keep a version of $notePath', e, st);
      return null;
    }
  }

  /// Keeps a version if the newest one is older than [minInterval] (or
  /// there is none yet). This is what is done after a save.
  static Future<NoteVersion?> snapshotIfDue(String notePath, {DateTime? now}) =>
      snapshot(
        notePath,
        reason: NoteVersion.reasonAuto,
        minInterval: minInterval,
        now: now,
      );

  /// The versions of the note at [notePath], newest first.
  static Future<List<NoteVersion>> list(String notePath) async {
    final key = keyOf(notePath);
    final store = NoteVersions.store;
    try {
      return await _run(() => store.list(key));
    } on Object catch (e, st) {
      log.severe('Could not list the versions of $notePath', e, st);
      return const [];
    }
  }

  /// The preview picture of [version], if it has one that is still there.
  static File? previewOf(NoteVersion version) {
    final hash = version.preview;
    if (hash == null) return null;
    final file = store.objectFile(hash);
    return file.existsSync() ? file : null;
  }

  /// Brings [version] back as the note at [notePath].
  ///
  /// The note as it is now is kept as a version first, so bringing a
  /// version back can itself be undone. Throws a [StateError] and leaves
  /// the note alone if part of the version is missing or damaged, or if
  /// the note as it is now could not be kept.
  static Future<void> restore(String notePath, NoteVersion version) async {
    final key = keyOf(notePath);
    final store = NoteVersions.store;

    final damaged = await _run(() => store.damaged(version));
    if (damaged.isNotEmpty) {
      throw StateError(
        'Version ${version.id} of $notePath is missing '
        '${damaged.length} of its files',
      );
    }

    await snapshot(notePath, reason: NoteVersion.reasonRestore, always: true);
    final currentPath = _mainFile(notePath).path;
    if (!await _run(() => store.isKept(key, currentPath))) {
      throw StateError('Could not keep $notePath as it is before restoring');
    }

    final target = '$key${version.extension}';
    Future<void> write(String path, String hash) async {
      final objectPath = store.objectFile(hash).path;
      final bytes = await _run(() => File(objectPath).readAsBytesSync());
      await FileManager.writeFile(path, bytes, awaitWrite: true);
    }

    final endSave = await beginSave(notePath);
    try {
      // Assets first: the note file is what names them.
      for (var i = 0; i < version.assets.length; i++) {
        await write('$target.$i', version.assets[i]);
      }
      await FileManager.removeUnusedAssets(
        target,
        numAssets: version.assets.length,
      );
      await write(target, version.main);
      if (version.preview != null) {
        await write('$target.p', version.preview!);
      } else {
        // Better no picture in the library than that of another state.
        await FileManager.deleteFile('$target.p', alsoDeleteAssets: false);
      }
      if (version.extension == '.sbn') {
        // The old format is only read when there is no note in the new one.
        await FileManager.deleteFile('$key.sbn2', keepAttachments: true);
      }
    } finally {
      endSave();
    }
  }

  /// Gives a note's versions to its new path when it is renamed or moved.
  static Future<void> move(String fromNotePath, String toNotePath) async {
    final from = keyOf(fromNotePath), to = keyOf(toNotePath);
    final store = NoteVersions.store;
    try {
      // Most notes that are moved have no versions: no need to go far.
      if (!store.directoryOf(from).existsSync()) return;
      await _run(() => store.move(from, to));
    } on Object catch (e, st) {
      log.severe('Could not move the versions of $fromNotePath', e, st);
    }
  }

  /// Forgets every version of a note that was deleted for good.
  static Future<void> deleteAll(String notePath) async {
    final key = keyOf(notePath);
    final store = NoteVersions.store;
    try {
      if (!store.directoryOf(key).existsSync()) return;
      await _run(() => store.deleteAll(key));
    } on Object catch (e, st) {
      log.severe('Could not delete the versions of $notePath', e, st);
    }
  }

  /// Forgets every version of every note.
  static Future<void> clear() {
    final store = NoteVersions.store;
    return _run(store.clear);
  }

  /// Deletes what no version needs any more; returns the bytes freed.
  static Future<int> collectGarbage() {
    final store = NoteVersions.store;
    final now = DateTime.now();
    return _run(() => store.collectGarbage(now: now));
  }

  /// How many bytes all versions take on disk.
  static Future<int> totalSize() {
    final store = NoteVersions.store;
    return _run(store.totalSize);
  }
}
