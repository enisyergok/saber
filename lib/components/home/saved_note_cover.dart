import 'package:flutter/material.dart';
import 'package:saber/components/home/live_note_cover.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/pages/editor/editor.dart';

class SavedNoteCover extends StatelessWidget {
  const SavedNoteCover({super.key, required this.notePath});

  /// The same extension-free path used by the editor route.
  final String notePath;

  @override
  Widget build(BuildContext context) {
    final previewPath = '$notePath${Editor.extension}.p';
    return LiveNoteCover(
      key: ValueKey(previewPath),
      load: () => FileManager.readFile(previewPath, retries: 0),
      changes: FileManager.fileWriteStream.stream
          .where((event) => event.filePath.replaceAll('\\', '/') == previewPath)
          .map<void>((_) {}),
    );
  }
}
