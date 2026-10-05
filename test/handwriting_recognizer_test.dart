import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:saber/data/ocr/handwriting_recognizer.dart';

void main() {
  group('Handwriting recognition:', () {
    test('the request carries the model, the prompt and the picture', () {
      final png = Uint8List.fromList([1, 2, 3]);
      final body = HandwritingRecognizer.buildRequestBody(
        model: 'google/x',
        png: png,
      );
      expect(body['model'], 'google/x');
      final content = ((body['messages'] as List).single as Map)['content'] as List;
      expect((content[0] as Map)['text'], HandwritingRecognizer.prompt);
      expect(
        ((content[1] as Map)['image_url'] as Map)['url'],
        'data:image/png;base64,${base64Encode(png)}',
      );
    });

    test('reads the text from a normal answer', () {
      const body =
          '{"choices":[{"message":{"content":"  Merhaba dünya\\nİkinci satır "}}]}';
      expect(
        HandwritingRecognizer.parseResponse(200, body),
        'Merhaba dünya\nİkinci satır',
      );
    });

    test('reads the text from a list of parts', () {
      const body =
          '{"choices":[{"message":{"content":[{"type":"text","text":"a"},{"type":"text","text":"b"}]}}]}';
      expect(HandwritingRecognizer.parseResponse(200, body), 'ab');
    });

    test('errors say what went wrong', () {
      expect(
        () => HandwritingRecognizer.parseResponse(
          402,
          '{"error":{"message":"Insufficient credits"}}',
        ),
        throwsA(
          isA<HandwritingException>().having(
            (e) => e.message,
            'message',
            'Insufficient credits',
          ),
        ),
      );
      expect(
        () => HandwritingRecognizer.parseResponse(401, 'nope'),
        throwsA(isA<HandwritingException>()),
      );
      expect(
        () => HandwritingRecognizer.parseResponse(200, '{"choices":[]}'),
        throwsA(isA<HandwritingException>()),
      );
    });

    test('recognize sends the key and returns the text', () async {
      late http.Request seen;
      final client = MockClient((request) async {
        seen = request;
        return http.Response.bytes(
          utf8.encode('{"choices":[{"message":{"content":"şğü"}}]}'),
          200,
        );
      });
      final text = await HandwritingRecognizer.recognize(
        Uint8List.fromList([9]),
        apiKey: ' sk-test ',
        client: client,
      );
      expect(text, 'şğü');
      expect(seen.headers['Authorization'], 'Bearer sk-test');
      expect(seen.url.toString(), HandwritingRecognizer.endpoint);
    });

    test('nothing is sent without a key', () async {
      var called = false;
      final client = MockClient((request) async {
        called = true;
        return http.Response('', 200);
      });
      await expectLater(
        HandwritingRecognizer.recognize(
          Uint8List(0),
          apiKey: '  ',
          client: client,
        ),
        throwsA(isA<HandwritingException>()),
      );
      expect(called, isFalse);
    });

    test('a slow answer is retried once, then reported', () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        await Future<void>.delayed(const Duration(milliseconds: 300));
        return http.Response('{}', 200);
      });
      await expectLater(
        HandwritingRecognizer.recognize(
          Uint8List.fromList([1, 2, 3]),
          apiKey: 'sk-test',
          client: client,
          timeout: const Duration(milliseconds: 50),
        ),
        throwsA(isA<HandwritingException>()),
      );
      expect(calls, 2);
    });

    test('the picture is limited in size', () {
      final small = HandwritingRecognizer.imageSize(
        const Rect.fromLTWH(0, 0, 100, 50),
      );
      expect(small.scale, 2.0);
      final big = HandwritingRecognizer.imageSize(
        const Rect.fromLTWH(0, 0, 8000, 100),
      );
      expect(big.width, lessThanOrEqualTo(1601));
    });
  });
}
