import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:saber/data/file_manager/file_manager.dart';

/// The notebooks kept open as tabs in the editor, in tab order.
///
/// Paths are note paths without the file extension, e.g. `/Folder/My note`.
/// Tabs last for the session; they aren't restored after the app restarts.
abstract class OpenTabs {
  static const maxTabs = 8;

  static final paths = ValueNotifier<List<String>>(const []);

  static StreamSubscription<FileOperation>? _deleteSubscription;

  /// A deleted (or moved) note shouldn't linger as a tab,
  /// since opening it again would silently create an empty note.
  static void _listenForDeletes() {
    _deleteSubscription ??= FileManager.fileWriteStream.stream.listen((event) {
      if (event.type == FileOperationType.delete) close(event.filePath);
    });
  }

  /// Adds [path] as the last tab unless it's already open.
  static void open(String path) {
    _listenForDeletes();
    if (paths.value.contains(path)) return;
    final next = [...paths.value, path];
    while (next.length > maxTabs) {
      next.removeAt(0);
    }
    paths.value = next;
  }

  static void close(String path) {
    if (!paths.value.contains(path)) return;
    paths.value = [
      for (final other in paths.value)
        if (other != path) other,
    ];
  }

  /// Replaces the tab for [oldPath] with [newPath].
  ///
  /// [index] is where the old tab was, in case it has already been removed
  /// by the delete event that a rename broadcasts.
  static void rename(String oldPath, String newPath, {int? index}) {
    final current = paths.value;
    final position = current.contains(oldPath)
        ? current.indexOf(oldPath)
        : index;
    final next = [
      for (final other in current)
        if (other != oldPath && other != newPath) other,
    ];
    next.insert((position ?? next.length).clamp(0, next.length), newPath);
    paths.value = next;
  }

  @visibleForTesting
  static void reset() => paths.value = const [];
}
