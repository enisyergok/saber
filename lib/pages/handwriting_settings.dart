import 'package:flutter/material.dart';
import 'package:saber/data/defter_strings.dart';
import 'package:saber/data/ocr/handwriting_recognizer.dart';
import 'package:saber/data/prefs.dart';

/// The OpenRouter key and model used to read handwriting.
class HandwritingSettingsPage extends StatefulWidget {
  const new({super.key});

  @override
  State<HandwritingSettingsPage> createState() =>
      _HandwritingSettingsPageState();
}

class _HandwritingSettingsPageState extends State<HandwritingSettingsPage> {
  late final _key = TextEditingController(text: stows.openRouterApiKey.value);
  late final _model = TextEditingController(text: stows.handwritingModel.value);
  bool _hideKey = true;

  @override
  void dispose() {
    _key.dispose();
    _model.dispose();
    super.dispose();
  }

  void _save() {
    stows.openRouterApiKey.value = _key.text.trim();
    final model = _model.text.trim();
    stows.handwritingModel.value = model.isEmpty
        ? HandwritingRecognizer.defaultModel
        : model;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(DefterStrings.handwritingSettings)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(DefterStrings.recognizeNote),
          const SizedBox(height: 20),
          TextField(
            controller: _key,
            obscureText: _hideKey,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: DefterStrings.apiKey,
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(_hideKey ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _hideKey = !_hideKey),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _model,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: DefterStrings.modelName,
              helperText: HandwritingRecognizer.defaultModel,
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                tooltip: DefterStrings.resetDefault,
                icon: const Icon(Icons.restart_alt),
                onPressed: () =>
                    _model.text = HandwritingRecognizer.defaultModel,
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: Text(DefterStrings.save)),
        ],
      ),
    );
  }
}
