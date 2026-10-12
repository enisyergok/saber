import 'package:saber/components/canvas/_stroke.dart';
import 'package:saber/data/defter_strings.dart';
import 'package:saber/data/ocr/handwriting_recognizer.dart';
import 'package:saber/data/ocr/ink_recognizer.dart';
import 'package:saber/data/prefs.dart';

/// Reads handwriting the way the settings ask: on the device first, and
/// with OpenRouter (when a key is set) if that is off or fails.
abstract class HandwritingService {
  static Future<String> recognizeStrokes(List<Stroke> strokes) async {
    if (strokes.isEmpty) {
      throw HandwritingException(DefterStrings.recognizeNoStrokes);
    }
    final key = stows.openRouterApiKey.value.trim();
    if (stows.handwritingOnDevice.value) {
      try {
        return await InkRecognizer.recognize(
          strokes,
          language: stows.handwritingInkLang.value,
        );
      } on HandwritingException {
        if (key.isEmpty) rethrow;
        // fall back to OpenRouter below
      }
    }
    final png = await HandwritingRecognizer.renderStrokes(strokes);
    if (png == null) {
      throw HandwritingException(DefterStrings.recognizeNoStrokes);
    }
    return HandwritingRecognizer.recognize(
      png,
      apiKey: key,
      model: stows.handwritingModel.value,
    );
  }
}
