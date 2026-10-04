import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:http/http.dart' as http;
import 'package:saber/components/canvas/_stroke.dart';

class HandwritingException implements Exception {
  const new(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Turns handwriting into text with a vision model through OpenRouter.
///
/// This is optional and needs the internet: the handwriting is drawn into a
/// picture which is sent to OpenRouter, and nothing is sent unless the
/// person asks for it.
abstract class HandwritingRecognizer {
  static const endpoint = 'https://openrouter.ai/api/v1/chat/completions';

  /// Gemini models did best on handwriting in public benchmarks, and this
  /// one is cheap. It can be changed in the settings.
  static const defaultModel = 'google/gemini-3.8-flash';

  static const prompt =
      'Transcribe the handwritten text in this image exactly as written. '
      'The text is most likely Turkish or English: keep Turkish letters '
      '(ç, ğ, ı, İ, ö, ş, ü) and the line breaks. '
      'Do not translate, correct or explain. '
      'Answer with the transcription only. '
      'If there is no readable handwriting, answer with an empty message.';

  /// The longest side of the picture sent to the model, in pixels.
  static const maxImageSide = 1600.0;

  static Map<String, dynamic> buildRequestBody({
    required String model,
    required Uint8List png,
  }) {
    return {
      'model': model,
      'temperature': 0,
      'messages': [
        {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': prompt},
            {
              'type': 'image_url',
              'image_url': {'url': 'data:image/png;base64,${base64Encode(png)}'},
            },
          ],
        },
      ],
    };
  }

  /// The transcription in an OpenRouter response, or a
  /// [HandwritingException] saying what went wrong.
  static String parseResponse(int statusCode, String body) {
    Map<String, dynamic>? json;
    try {
      json = jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      json = null;
    }

    final error = json?['error'];
    if (error is Map && error['message'] is String) {
      throw HandwritingException(error['message'] as String);
    }
    if (statusCode == 401 || statusCode == 403) {
      throw const HandwritingException('API key was not accepted');
    }
    if (statusCode != 200 || json == null) {
      throw HandwritingException('Unexpected response ($statusCode)');
    }

    final choices = json['choices'];
    if (choices is! List || choices.isEmpty) {
      throw const HandwritingException('The model returned no answer');
    }
    final content = (choices.first as Map)['message']?['content'];
    final String text;
    if (content is String) {
      text = content;
    } else if (content is List) {
      text = content
          .whereType<Map>()
          .map((part) => part['text'])
          .whereType<String>()
          .join();
    } else {
      text = '';
    }
    return text.trim();
  }

  static Future<String> recognize(
    Uint8List png, {
    required String apiKey,
    String model = defaultModel,
    http.Client? client,
  }) async {
    if (apiKey.trim().isEmpty) {
      throw const HandwritingException('No API key');
    }
    final httpClient = client ?? http.Client();
    try {
      final response = await httpClient
          .post(
            Uri.parse(endpoint),
            headers: {
              'Authorization': 'Bearer ${apiKey.trim()}',
              'Content-Type': 'application/json',
              'X-Title': 'Defter',
            },
            body: jsonEncode(buildRequestBody(model: model, png: png)),
          )
          .timeout(const Duration(seconds: 60));
      return parseResponse(response.statusCode, utf8.decode(response.bodyBytes));
    } on HandwritingException {
      rethrow;
    } catch (e) {
      throw HandwritingException('Could not reach OpenRouter: $e');
    } finally {
      if (client == null) httpClient.close();
    }
  }

  /// The size of the picture for strokes covering [bounds].
  static ({double scale, int width, int height}) imageSize(
    Rect bounds, {
    double padding = 24,
  }) {
    final w = bounds.width + padding * 2;
    final h = bounds.height + padding * 2;
    final scale = (maxImageSide / (w > h ? w : h)).clamp(0.0, 2.0);
    return (
      scale: scale,
      width: (w * scale).ceil().clamp(1, 1 << 14),
      height: (h * scale).ceil().clamp(1, 1 << 14),
    );
  }

  /// Draws [strokes] in black on white, cropped to what is written.
  /// Null if there is nothing to draw.
  static Future<Uint8List?> renderStrokes(
    List<Stroke> strokes, {
    double padding = 24,
  }) async {
    if (strokes.isEmpty) return null;
    var bounds = strokes.first.bounds;
    for (final stroke in strokes.skip(1)) {
      bounds = bounds.expandToInclude(stroke.bounds);
    }
    if (bounds.isEmpty && bounds.width == 0 && bounds.height == 0) return null;

    final size = imageSize(bounds, padding: padding);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width.toDouble(), size.height.toDouble()),
      Paint()..color = const Color(0xFFFFFFFF),
    );
    canvas.scale(size.scale);
    canvas.translate(padding - bounds.left, padding - bounds.top);

    final paint = Paint()..color = const Color(0xFF000000);
    for (final stroke in strokes) {
      canvas.drawPath(stroke.highQualityPath, paint);
    }

    final image = await recorder.endRecording().toImage(
      size.width,
      size.height,
    );
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }
}
