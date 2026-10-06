import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:logging/logging.dart';
import 'package:saber/components/canvas/_asset_cache.dart';
import 'package:saber/components/canvas/image/editor_image.dart';
import 'package:saber/data/editor/editor_core_info.dart';
import 'package:saber/data/file_manager/file_manager.dart';

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
