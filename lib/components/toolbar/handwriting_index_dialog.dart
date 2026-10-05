import 'package:flutter/material.dart';
import 'package:saber/data/defter_strings.dart';
import 'package:saber/data/editor/editor_core_info.dart';
import 'package:saber/data/ocr/handwriting_recognizer.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/search/handwriting_text.dart';
import 'package:saber/data/search/note_search.dart';

/// Asks before reading a note's handwriting for search, then reads it while
/// showing progress. Nothing is sent before the person says "Start".
class HandwritingIndexDialog extends StatefulWidget {
  const HandwritingIndexDialog({super.key, required this.note});

  final EditorCoreInfo note;

  /// True when the handwriting was added to search.
  static Future<bool?> show(BuildContext context, EditorCoreInfo note) {
    if (stows.openRouterApiKey.value.trim().isEmpty) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(DefterStrings.recognizeNoKey)),
      );
      return Future.value(false);
    }
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => HandwritingIndexDialog(note: note),
    );
  }

  @override
  State<HandwritingIndexDialog> createState() => _HandwritingIndexDialogState();
}

class _HandwritingIndexDialogState extends State<HandwritingIndexDialog> {
  late final int _chunks = HandwritingIndexer.countChunks(widget.note);
  bool _running = false;
  bool _cancelled = false;
  int _done = 0;
  String? _error;

  int get _total => _chunks.clamp(0, HandwritingIndexer.maxChunks);

  Future<void> _start() async {
    setState(() {
      _running = true;
      _error = null;
    });
    try {
      final result = await HandwritingIndexer.index(
        widget.note,
        recognize: (png) => HandwritingRecognizer.recognize(
          png,
          apiKey: stows.openRouterApiKey.value,
          model: stows.handwritingModel.value,
        ),
        isCancelled: () => _cancelled,
        onProgress: (p) {
          if (mounted) setState(() => _done = p.done);
        },
      );
      NoteSearchIndex.shared.setHandwriting(
        widget.note.filePath,
        result.pages,
      );
      if (mounted) Navigator.pop(context, true);
    } on HandwritingIndexCancelled {
      if (mounted) Navigator.pop(context, false);
    } on HandwritingException catch (e) {
      if (!mounted) return;
      setState(() {
        _running = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_chunks == 0) {
      return AlertDialog(
        title: Text(DefterStrings.hwConfirmTitle),
        content: Text(DefterStrings.hwNoWriting),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(DefterStrings.close),
          ),
        ],
      );
    }
    return AlertDialog(
      title: Text(DefterStrings.hwConfirmTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_running) ...[
              Text(DefterStrings.hwProgress(_done, _total)),
              const SizedBox(height: 12),
              LinearProgressIndicator(value: _total == 0 ? null : _done / _total),
            ] else ...[
              Text(DefterStrings.hwConfirmBody(_total)),
              if (_chunks > HandwritingIndexer.maxChunks) ...[
                const SizedBox(height: 8),
                Text(DefterStrings.hwCapped(HandwritingIndexer.maxChunks)),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: ColorScheme.of(context).error),
                ),
              ],
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            if (_running) {
              _cancelled = true; // stops after the picture being read
            } else {
              Navigator.pop(context, false);
            }
          },
          child: Text(DefterStrings.hwCancel),
        ),
        if (!_running)
          FilledButton(
            onPressed: _start,
            child: Text(DefterStrings.hwStart),
          ),
      ],
    );
  }
}
