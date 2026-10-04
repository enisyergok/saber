import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:saber/data/ai/note_assistant.dart';
import 'package:saber/data/search/note_search.dart';

NoteSearchIndex _index() {
  final index = NoteSearchIndex();
  void add(String path, String text) => index.put(
    NoteSearchEntry(path: path, modifiedMs: 1, text: text),
  );
  add('/Toplantı 3 Ekim', 'Müşteri teslim tarihini 15 Kasım olarak onayladı.\nBütçe 40 bin.');
  add('/Alışveriş', 'süt, ekmek, yumurta');
  add('/Proje notları', 'Teslim tarihi için tedarikçi gecikmesi riski var.');
  return index;
}

void main() {
  group('Ask my notes:', () {
    test('keywords drop filler words and endings', () {
      final words = NoteAssistant.keywords('Toplantıda teslim tarihi neydi?');
      expect(words, contains('toplanti'));
      expect(words, contains('teslim'));
      expect(words, contains('tarihi'));
      expect(words, isNot(contains('neydi')));
    });

    test('the best matching notes come first', () {
      final found = NoteAssistant.retrieve(
        _index(),
        'Toplantıda teslim tarihi neydi?',
      );
      expect(found.first.name, 'Toplantı 3 Ekim');
      expect(found.map((e) => e.name), isNot(contains('Alışveriş')));
    });

    test('nothing is found for unrelated questions', () {
      expect(NoteAssistant.retrieve(_index(), 'uzay mekiği'), isEmpty);
    });

    test('long notes are cut to the relevant lines', () {
      final index = NoteSearchIndex()
        ..put(
          NoteSearchEntry(
            path: '/uzun',
            modifiedMs: 1,
            text: '${List.filled(400, 'dolgu satırı').join('\n')}\nHEDEF kelimesi burada',
          ),
        );
      final found = NoteAssistant.retrieve(index, 'hedef kelimesi');
      expect(found.single.text.contains('HEDEF'), isTrue);
      expect(found.single.text.length, lessThanOrEqualTo(NoteAssistant.maxCharsPerNote));
    });

    test('the request holds the notes and the question', () {
      final body = NoteAssistant.buildRequestBody(
        model: 'm',
        question: 'Soru?',
        excerpts: NoteAssistant.retrieve(_index(), 'teslim tarihi'),
      );
      final user = ((body['messages'] as List)[1] as Map)['content'] as String;
      expect(user, contains('Question: Soru?'));
      expect(user, contains('Toplantı 3 Ekim'));
    });

    test('asking without matching notes sends nothing', () async {
      var called = false;
      final client = MockClient((_) async {
        called = true;
        return http.Response('', 200);
      });
      final answer = await NoteAssistant.ask(
        _index(),
        'uzay mekiği',
        apiKey: 'k',
        client: client,
      );
      expect(answer.text, isEmpty);
      expect(called, isFalse);
    });

    test('the answer comes with its sources', () async {
      final client = MockClient(
        (_) async => http.Response.bytes(
          utf8.encode('{"choices":[{"message":{"content":"15 Kasım"}}]}'),
          200,
        ),
      );
      final answer = await NoteAssistant.ask(
        _index(),
        'teslim tarihi ne zaman',
        apiKey: 'k',
        client: client,
      );
      expect(answer.text, '15 Kasım');
      expect(answer.sources, isNotEmpty);
    });
  });
}
