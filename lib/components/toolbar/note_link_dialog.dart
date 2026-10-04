import 'package:flutter/material.dart';
import 'package:saber/data/defter_strings.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/search/note_search.dart';

/// Lets the person pick a note to link to. Pops its path (without extension).
class NoteLinkDialog extends StatefulWidget {
  const new({super.key, this.excludePath});

  /// The note being edited, which isn't offered.
  final String? excludePath;

  static Future<String?> show(BuildContext context, {String? excludePath}) {
    return showDialog<String>(
      context: context,
      builder: (_) => NoteLinkDialog(excludePath: excludePath),
    );
  }

  @override
  State<NoteLinkDialog> createState() => _NoteLinkDialogState();
}

class _NoteLinkDialogState extends State<NoteLinkDialog> {
  List<String>? _notes;
  var _query = '';

  @override
  void initState() {
    super.initState();
    FileManager.getAllFiles().then((all) {
      if (!mounted) return;
      setState(() {
        _notes = all.where((p) => p != widget.excludePath).toList()..sort();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final folded = NoteSearchIndex.fold(_query.trim());
    final notes = [
      for (final path in _notes ?? const <String>[])
        if (NoteSearchIndex.fold(path).contains(folded)) path,
    ];
    return AlertDialog(
      title: Text(DefterStrings.linkToNote),
      content: SizedBox(
        width: 420,
        height: 420,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: DefterStrings.search,
                border: const OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _notes == null
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: notes.length,
                      itemBuilder: (context, i) => ListTile(
                        leading: const Icon(Icons.description_outlined),
                        title: Text(
                          notes[i].substring(notes[i].lastIndexOf('/') + 1),
                        ),
                        subtitle: Text(notes[i]),
                        onTap: () => Navigator.of(context).pop(notes[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(DefterStrings.cancel),
        ),
      ],
    );
  }
}
