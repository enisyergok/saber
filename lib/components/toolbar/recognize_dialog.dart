import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:saber/components/canvas/_stroke.dart';
import 'package:saber/data/defter_strings.dart';
import 'package:saber/data/ocr/handwriting_recognizer.dart';
import 'package:saber/data/prefs.dart';

/// Reads the handwriting of [strokes] and shows the text, which can be
/// edited and copied.
class RecognizeDialog extends StatefulWidget {
  const new({super.key, required this.strokes});

  final List<Stroke> strokes;

  static Future<void> show(BuildContext context, List<Stroke> strokes) {
    return showDialog<void>(
      context: context,
      builder: (_) => RecognizeDialog(strokes: strokes),
    );
  }

  @override
  State<RecognizeDialog> createState() => _RecognizeDialogState();
}

class _RecognizeDialogState extends State<RecognizeDialog> {
  final _controller = TextEditingController();
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _run();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    try {
      final png = await HandwritingRecognizer.renderStrokes(widget.strokes);
      if (png == null) throw HandwritingException(DefterStrings.recognizeNoStrokes);
      final text = await HandwritingRecognizer.recognize(
        png,
        apiKey: stows.openRouterApiKey.value,
        model: stows.handwritingModel.value,
      );
      if (!mounted) return;
      setState(() {
        _controller.text = text;
        _error = text.isEmpty ? DefterStrings.recognizeEmpty : null;
        _loading = false;
      });
    } on HandwritingException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(DefterStrings.recognize),
      content: SizedBox(
        width: 480,
        child: _loading
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const LinearProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(DefterStrings.recognizing),
                ],
              )
            : _error != null
            ? Text(_error!)
            : TextField(controller: _controller, maxLines: null, minLines: 4),
      ),
      actions: [
        if (!_loading && _error == null)
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: _controller.text));
              if (!context.mounted) return;
              ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                SnackBar(content: Text(DefterStrings.copied)),
              );
            },
            child: Text(DefterStrings.copy),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(DefterStrings.close),
        ),
      ],
    );
  }
}
