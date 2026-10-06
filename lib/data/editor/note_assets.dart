import 'dart:io';
import 'dart:isolate';

import 'package:flutter/painting.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:logging/logging.dart';
import 'package:saber/components/canvas/_asset_cache.dart';
import 'package:saber/components/canvas/image/editor_image.dart';
import 'package:saber/data/editor/editor_core_info.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/is_this_a_test.dart';
import 'package:saber/data/versions/note_versions.dart';

/// What [NoteAssets.write] did.
class NoteAssetsResult {
  const new({
    required this.kept,
    required this.copied,
    required this.written,
    required this.errors,
  });

  /// Assets that were already where they belong and were not touched.
  final int kept;

  /// Assets that were copied from another file.
  final int copied;

  /// Assets that were written from memory.
  final int written;

  final List<Object> errors;

  bool get ok => errors.isEmpty;
}

/// The files next to a note that hold its pictures and PDFs
/// (`note.sbn2.0`, `note.sbn2.1`, …).
abstract class NoteAssets {
  static final log = Logger('NoteAssets');

  /// The ending of an asset while it is being put in place.
  static const stagingSuffix = '.new';

  static bool _samePath(File a, File b) =>
      a.absolute.path == b.absolute.path;

  static Future<void> _deleteQuietly(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {
      // It is left behind: it is never shown as a note or synced.
    }
  }

  /// Puts the [assets] of the note at [filePath] (with its extension) on
  /// disk.
  ///
  /// * An asset that is already where it belongs is left alone: a PDF or a
  ///   photo is not written again with every save.
  /// * An asset that comes from another file is copied on disk, without
  ///   being read into memory.
  /// * Everything is prepared before anything is replaced, so an asset
  ///   that moves to another number is never read after its old file was
  ///   overwritten.
  ///
  /// Afterwards the pictures that use an asset are told where it is now.
  /// Assets with a higher number than the last are not removed here: do
  /// that with [FileManager.removeUnusedAssets] once the note itself has
  /// been written.
  static Future<NoteAssetsResult> write(
    String filePath,
    OrderedAssetCache assets,
  ) async {
    final staged = <int, File>{};
    final fromFile = <int>{};
    final errors = <Object>[];
    var kept = 0;

    for (var i = 0; i < assets.length; i++) {
      final target = FileManager.getFile('$filePath.$i');
      final staging = File('${target.path}$stagingSuffix');
      try {
        final source = assets.fileAt(i);
        if (source != null) {
          if (_samePath(source, target)) {
            if (!await target.exists()) {
              throw FileSystemException(
                'The file of a picture is gone',
                target.path,
              );
            }
            kept++;
            continue;
          }
          await staging.parent.create(recursive: true);
          await source.copy(staging.path);
          fromFile.add(i);
        } else {
          final bytes = await assets.getBytes(i);
          await staging.parent.create(recursive: true);
          await staging.writeAsBytes(bytes, flush: true);
        }
        staged[i] = staging;
      } catch (e, st) {
        log.severe('Could not prepare asset $i of $filePath: $e', e, st);
        errors.add(e);
        await _deleteQuietly(staging);
      }
    }

    final replaced = <int>{};
    for (final MapEntry(key: i, value: staging) in staged.entries) {
      try {
        await FileManager.commitStagedFile('$filePath.$i', staging);
        replaced.add(i);
      } catch (e, st) {
        log.severe('Could not put asset $i of $filePath in place: $e', e, st);
        errors.add(e);
        await _deleteQuietly(staging);
      }
    }

    var svgChanged = false;
    for (final i in replaced) {
      final target = FileManager.getFile('$filePath.$i');
      // What was shown from this file before is not what is in it now.
      try {
        await FileImage(target).evict();
      } catch (_) {
        // Nothing was kept of it.
      }
      for (final owner in assets.ownersOf(i)) {
        if (owner is! EditorImage) continue;
        if (owner is SvgEditorImage) svgChanged = true;
        _tell(owner, target);
      }
    }
    if (svgChanged) svg.cache.clear();

    return NoteAssetsResult(
      kept: kept,
      copied: replaced.intersection(fromFile).length,
      written: replaced.difference(fromFile).length,
      errors: errors,
    );
  }

  static void _tell(EditorImage image, File file) {
    try {
      image.assetSavedTo(file);
    } catch (e, st) {
      // A picture of a note that was closed meanwhile.
      log.fine('Could not tell a picture where its file is: $e', e, st);
    }
  }

  /// The SHA-256 of each of [paths] (null for a file that can't be read).
  /// Kept apart so that it can run off the main thread.
  static Map<String, String?> _hashAll(List<String> paths) => {
    for (final path in paths)
      path: () {
        try {
          return NoteVersionStore.hashOfFile(File(path));
        } on FileSystemException {
          return null;
        }
      }(),
  };

  /// Earlier versions saved a copy of a PDF for each of its pages. This
  /// finds the copies among the files that the PDF pages of [coreInfo] are
  /// read from (same size and same content) and lets all the pages of one
  /// PDF read the same file. The next save then keeps that one file and
  /// removes the copies.
  ///
  /// Nothing on disk is changed here. Returns how many files are no longer
  /// needed.
  static Future<int> shareIdenticalPdfs(EditorCoreInfo coreInfo) async {
    final pagesOf = <String, List<PdfEditorImage>>{};
    for (final page in coreInfo.pages) {
      for (final image in [?page.backgroundImage, ...page.images]) {
        if (image is! PdfEditorImage) continue;
        final file = image.pdfFile;
        if (file == null) continue;
        pagesOf.putIfAbsent(file.absolute.path, () => []).add(image);
      }
    }
    if (pagesOf.length < 2) return 0;

    // Copies have the same size: only files that share theirs are read.
    final withSize = <int, List<String>>{};
    for (final path in pagesOf.keys) {
      try {
        withSize.putIfAbsent(await File(path).length(), () => []).add(path);
      } on FileSystemException {
        // A file that is not there is no copy of anything.
      }
    }
    final candidates = [
      for (final MapEntry(key: size, value: paths) in withSize.entries)
        if (size > 0 && paths.length > 1) ...paths,
    ];
    if (candidates.isEmpty) return 0;

    final hashes = isThisATest
        ? _hashAll(candidates)
        : await Isolate.run(() => _hashAll(candidates));

    final withContent = <String, List<String>>{};
    for (final path in candidates) {
      final hash = hashes[path];
      if (hash != null) withContent.putIfAbsent(hash, () => []).add(path);
    }

    /// The number an asset's file name ends with.
    int numberOf(String path) =>
        int.tryParse(path.substring(path.lastIndexOf('.') + 1)) ?? 1 << 30;

    var spared = 0;
    for (final copies in withContent.values) {
      if (copies.length < 2) continue;
      copies.sort((a, b) => numberOf(a).compareTo(numberOf(b)));
      final kept = File(copies.first);
      for (final copy in copies.skip(1)) {
        for (final image in pagesOf[copy]!) {
          // The note may have been closed or changed meanwhile.
          if (image.pdfFile?.absolute.path != copy) continue;
          _tell(image, kept);
        }
        spared++;
      }
    }
    if (spared > 0) {
      log.info('${coreInfo.filePath}: $spared copies of a PDF are shared');
    }
    return spared;
  }

  /// Tells the pictures of [coreInfo] that the files of the note moved
  /// from [oldFilePath] to [newFilePath] (both with their extension), so
  /// that they are read from where they are now.
  static void moved(
    EditorCoreInfo coreInfo,
    String oldFilePath,
    String newFilePath,
  ) {
    if (oldFilePath == newFilePath) return;
    final oldPrefix = '${FileManager.getFile(oldFilePath).absolute.path}.';
    final newPrefix = '${FileManager.getFile(newFilePath).absolute.path}.';
    var svgChanged = false;
    for (final page in coreInfo.pages) {
      for (final image in [?page.backgroundImage, ...page.images]) {
        final path = image.assetFile?.absolute.path;
        if (path == null || !path.startsWith(oldPrefix)) continue;
        final number = path.substring(oldPrefix.length);
        if (int.tryParse(number) == null) continue;
        if (image is SvgEditorImage) svgChanged = true;
        _tell(image, File('$newPrefix$number'));
      }
    }
    if (svgChanged) svg.cache.clear();
  }

}
