import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
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
  bool _testing = false;
  String? _testResult;
  bool _testOk = false;

  @override
  void dispose() {
    _key.dispose();
    _model.dispose();
    super.dispose();
  }

  Future<void> _test() async {
    setState(() {
      _testing = true;
      _testResult = null;
    });
    String message;
    var ok = false;
    try {
      final png = await HandwritingRecognizer.renderTestImage();
      final model = _model.text.trim().isEmpty
          ? HandwritingRecognizer.defaultModel
          : _model.text.trim();
      final text = await HandwritingRecognizer.recognize(
        png,
        apiKey: _key.text.trim(),
        model: model,
      );
      ok = true;
      message = DefterStrings.testRead(HandwritingRecognizer.testPhrase, text);
    } on HandwritingException catch (e) {
      message = e.message;
    } catch (e) {
      message = '$e';
    }
    if (!mounted) return;
    setState(() {
      _testing = false;
      _testOk = ok;
      _testResult = message;
    });
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
                icon: Icon(_hideKey ? Symbols.visibility_rounded : Symbols.visibility_off_rounded),
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
                icon: const Icon(Symbols.restart_alt_rounded),
                onPressed: () =>
                    _model.text = HandwritingRecognizer.defaultModel,
              ),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _testing ? null : _test,
            icon: _testing
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Symbols.wifi_tethering_rounded),
            label: Text(DefterStrings.testConnection),
          ),
          if (_testResult != null) ...[
            const SizedBox(height: 8),
            Text(
              _testResult!,
              style: TextStyle(
                color: _testOk
                    ? ColorScheme.of(context).primary
                    : ColorScheme.of(context).error,
              ),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: Text(DefterStrings.save)),
        ],
      ),
    );
  }
}
