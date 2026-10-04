import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:saber/data/ai/note_assistant.dart';
import 'package:saber/data/defter_strings.dart';
import 'package:saber/data/ocr/handwriting_recognizer.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/routes.dart';
import 'package:saber/data/search/note_search.dart';

/// Ask a question and get an answer based on the person's notes.
class AskNotesPage extends StatefulWidget {
  const new({super.key});

  @override
  State<AskNotesPage> createState() => _AskNotesPageState();
}

class _AskNotesPageState extends State<AskNotesPage> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _error;
  NoteAnswer? _answer;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _ask() async {
    final question = _controller.text.trim();
    if (question.isEmpty || _busy) return;
    if (stows.openRouterApiKey.value.trim().isEmpty) {
      setState(() => _error = DefterStrings.recognizeNoKey);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _answer = null;
    });
    try {
      final index = NoteSearchIndex.shared;
      await index.load();
      await index.refresh();
      final answer = await NoteAssistant.ask(
        index,
        question,
        apiKey: stows.openRouterApiKey.value,
        model: stows.handwritingModel.value,
      );
      if (!mounted) return;
      setState(() => _answer = answer);
    } on HandwritingException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final answer = _answer;
    return Scaffold(
      appBar: AppBar(title: Text(DefterStrings.askNotes)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _controller,
            minLines: 1,
            maxLines: 4,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: DefterStrings.askHint,
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                tooltip: DefterStrings.ask,
                icon: const Icon(Icons.send),
                onPressed: _ask,
              ),
            ),
            onSubmitted: (_) => _ask(),
          ),
          const SizedBox(height: 8),
          Text(
            '${DefterStrings.askSending}\n${DefterStrings.askTypedOnly}',
            style: TextTheme.of(context).bodySmall,
          ),
          const SizedBox(height: 16),
          if (_busy) const LinearProgressIndicator(),
          if (_error != null) Text(_error!),
          if (answer != null) ...[
            if (answer.text.isEmpty)
              Text(DefterStrings.askNoNotes)
            else
              SelectableText(
                answer.text,
                style: TextTheme.of(context).bodyLarge,
              ),
            const SizedBox(height: 20),
            if (answer.sources.isNotEmpty)
              Text(
                DefterStrings.askSources,
                style: TextTheme.of(context).titleSmall,
              ),
            for (final source in answer.sources)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.description_outlined),
                title: Text(source.name),
                onTap: () =>
                    context.push(RoutePaths.editFilePath(source.path)),
              ),
          ],
        ],
      ),
    );
  }
}
