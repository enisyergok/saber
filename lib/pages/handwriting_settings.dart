import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:saber/data/crash_log.dart';
import 'package:saber/data/defter_strings.dart';
import 'package:saber/data/ocr/handwriting_recognizer.dart';
import 'package:saber/data/ocr/ink_recognizer.dart';
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
  bool _onDevice = stows.handwritingOnDevice.value;
  String _inkLang = stows.handwritingInkLang.value;
  bool _checkingModel = false;
  String? _modelResult;
  bool _modelOk = false;
  String? _crashText;

  @override
  void dispose() {
    _key.dispose();
    _model.dispose();
    super.dispose();
  }

  Future<void> _showCrashLog() async {
    final text = await CrashLog.read();
    if (!mounted) return;
    setState(() => _crashText = text.isEmpty ? '-' : text);
  }

  Future<void> _checkModel() async {
    setState(() {
      _checkingModel = true;
      _modelResult = null;
    });
    var ok = false;
    String message;
    try {
      await InkRecognizer.ensureModel(_inkLang);
      ok = true;
      message = DefterStrings.inkModelReady;
    } on HandwritingException catch (e) {
      message = e.message;
    } catch (e) {
      message = '$e';
    }
    if (!mounted) return;
    setState(() {
      _checkingModel = false;
      _modelOk = ok;
      _modelResult = message;
    });
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
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(DefterStrings.inkOnDevice),
            subtitle: Text(DefterStrings.inkOnDeviceSubtitle),
            value: _onDevice,
            onChanged: (v) {
              setState(() => _onDevice = v);
              stows.handwritingOnDevice.value = v;
            },
          ),
          if (_onDevice) ...[
            const SizedBox(height: 8),
            Text(DefterStrings.inkLanguage),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: [
                for (final e in InkRecognizer.languages.entries)
                  ButtonSegment(value: e.key, label: Text(e.value)),
              ],
              selected: {_inkLang},
              onSelectionChanged: (v) {
                setState(() {
                  _inkLang = v.first;
                  _modelResult = null;
                });
                stows.handwritingInkLang.value = v.first;
              },
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _checkingModel ? null : _checkModel,
              icon: _checkingModel
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Symbols.download_rounded),
              label: Text(DefterStrings.inkCheckModel),
            ),
            TextButton.icon(
              onPressed: _showCrashLog,
              icon: const Icon(Symbols.bug_report_rounded),
              label: Text(DefterStrings.crashLogShow),
            ),
            if (_crashText != null) ...[
              SelectableText(
                _crashText!,
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              ),
              TextButton(
                onPressed: () async {
                  await CrashLog.clear();
                  if (mounted) setState(() => _crashText = null);
                },
                child: Text(DefterStrings.crashLogClear),
              ),
            ],
            if (_modelResult != null) ...[
              const SizedBox(height: 8),
              Text(
                _modelResult!,
                style: TextStyle(
                  color: _modelOk
                      ? ColorScheme.of(context).primary
                      : ColorScheme.of(context).error,
                ),
              ),
            ],
          ],
          const SizedBox(height: 20),
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
