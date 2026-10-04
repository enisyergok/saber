import 'package:flutter/material.dart';
import 'package:saber/data/defter_strings.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/pages/editor/editor.dart';

/// Lists the notes that were deleted and lets the person restore them or
/// delete them for good.
class TrashPage extends StatefulWidget {
  const TrashPage({super.key});

  @override
  State<TrashPage> createState() => _TrashPageState();
}

class _TrashPageState extends State<TrashPage> {
  List<String>? _notes;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final notes = await FileManager.listTrash();
    if (mounted) setState(() => _notes = notes);
  }

  /// A trashed path as the person knew it: no trash folder, no extension.
  static String displayName(String trashedPath) {
    var path = trashedPath.substring(FileManager.trashDirectory.length);
    for (final extension in [Editor.extension, Editor.extensionOldJson]) {
      if (path.endsWith(extension)) {
        path = path.substring(0, path.length - extension.length);
        break;
      }
    }
    return path.startsWith('/') ? path.substring(1) : path;
  }

  Future<void> _restore(String trashedPath) async {
    await FileManager.restoreFromTrash(trashedPath);
    await _reload();
  }

  Future<void> _deleteForever(String trashedPath) async {
    await FileManager.deleteFile(trashedPath);
    await _reload();
  }

  Future<void> _confirmEmpty() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(DefterStrings.emptyTrash),
        content: Text(DefterStrings.emptyTrashConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(DefterStrings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(DefterStrings.emptyTrash),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await FileManager.emptyTrash();
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final notes = _notes;
    return Scaffold(
      appBar: AppBar(
        title: Text(DefterStrings.trash),
        actions: [
          if (notes != null && notes.isNotEmpty)
            IconButton(
              tooltip: DefterStrings.emptyTrash,
              icon: const Icon(Icons.delete_sweep),
              onPressed: _confirmEmpty,
            ),
        ],
      ),
      body: switch (notes) {
        null => const Center(child: CircularProgressIndicator()),
        [] => Center(child: Text(DefterStrings.trashEmpty)),
        _ => ListView.builder(
          itemCount: notes.length,
          itemBuilder: (context, index) {
            final trashedPath = notes[index];
            return ListTile(
              leading: const Icon(Icons.description_outlined),
              title: Text(displayName(trashedPath)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: DefterStrings.restore,
                    icon: const Icon(Icons.restore),
                    onPressed: () => _restore(trashedPath),
                  ),
                  IconButton(
                    tooltip: DefterStrings.deleteForever,
                    icon: const Icon(Icons.delete_forever),
                    onPressed: () => _deleteForever(trashedPath),
                  ),
                ],
              ),
            );
          },
        ),
      },
    );
  }
}
