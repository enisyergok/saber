import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:saber/data/ocr/handwriting_recognizer.dart';
import 'package:saber/data/search/note_search.dart';

/// A piece of a note that is relevant to a question.
class NoteExcerpt {
  const new({required this.path, required this.name, required this.text});

  final String path;
  final String name;
  final String text;
}

class NoteAnswer {
  const new({required this.text, required this.sources});

  final String text;

  /// The notes the answer was based on.
  final List<NoteExcerpt> sources;
}

/// Answers questions from the person's own notes ("Notlarıma sor").
///
/// The notes are searched on the device and only the few relevant excerpts
/// are sent to the model, together with the question.
abstract class NoteAssistant {
  static const defaultModel = HandwritingRecognizer.defaultModel;

  static const maxNotes = 5;
  static const maxCharsPerNote = 1800;

  static const _systemPrompt =
      'You answer questions using only the notes provided. '
      'Answer in the language of the question (usually Turkish). '
      'Mention which note the information comes from, by its name. '
      'If the notes do not contain the answer, say so plainly instead of '
      'guessing. Be concise.';

  /// Words too common to say anything about a note.
  static const _stopWords = {
    've', 'bir', 'bu', 'su', 'şu', 'icin', 'ile', 'mi', 'mu', 'ne', 'nedir',
    'neydi', 'nerede', 'kim', 'hangi', 'nasil', 'var', 'yok', 'olan', 'gibi',
    'the', 'and', 'what', 'was', 'were', 'who', 'how', 'for', 'with', 'about',
    'did', 'does', 'are', 'is', 'my', 'of', 'in', 'on', 'to', 'ben', 'benim',
    'notlarimda', 'notlarim', 'notta', 'yazdim', 'yazmistim',
  };

  /// The words of [question] worth looking for, folded. Long words are cut
  /// short so Turkish endings still match ("toplantıda" finds "toplantı").
  static List<String> keywords(String question) {
    final result = <String>{};
    for (final word in NoteSearchIndex.fold(question).split(
      RegExp(r'[^a-z0-9]+'),
    )) {
      if (word.length < 3 || _stopWords.contains(word)) continue;
      result.add(word.length > 6 ? word.substring(0, word.length - 2) : word);
    }
    return result.toList();
  }

  static int _count(String haystack, String needle) {
    var count = 0;
    var from = 0;
    while (true) {
      final i = haystack.indexOf(needle, from);
      if (i < 0) return count;
      count++;
      from = i + needle.length;
    }
  }

  /// The notes that best match [question], with the lines that matter.
  static List<NoteExcerpt> retrieve(
    NoteSearchIndex index,
    String question, {
    int limit = maxNotes,
  }) {
    final terms = keywords(question);
    if (terms.isEmpty) return const [];

    final scored = <(double, NoteSearchEntry)>[];
    for (final entry in index.entries) {
      final name = NoteSearchIndex.fold(entry.name);
      final text = NoteSearchIndex.fold(entry.text);
      var score = 0.0;
      var matchedTerms = 0;
      for (final term in terms) {
        final inName = name.contains(term);
        final inText = _count(text, term);
        if (inName || inText > 0) matchedTerms++;
        score += (inName ? 4 : 0) + (inText > 5 ? 5 : inText);
      }
      if (matchedTerms == 0) continue;
      // Notes matching more of the question's words rank above notes that
      // mention one word often.
      score += matchedTerms * 10;
      scored.add((score, entry));
    }
    scored.sort((a, b) => b.$1.compareTo(a.$1));

    return [
      for (final (_, entry) in scored.take(limit))
        NoteExcerpt(
          path: entry.path,
          name: entry.name,
          text: _excerpt(entry.text, terms),
        ),
    ];
  }

  /// The lines of [text] that contain a keyword (with the line before and
  /// after), up to [maxCharsPerNote]; the start of the note if none do.
  static String _excerpt(String text, List<String> terms) {
    if (text.length <= maxCharsPerNote) return text;
    final lines = text.split('\n');
    final folded = [for (final line in lines) NoteSearchIndex.fold(line)];
    final keep = <int>{};
    for (var i = 0; i < lines.length; i++) {
      if (terms.any(folded[i].contains)) {
        keep.addAll([if (i > 0) i - 1, i, if (i + 1 < lines.length) i + 1]);
      }
    }
    final buffer = StringBuffer();
    for (final i in (keep.isEmpty ? [0, 1, 2] : keep.toList()..sort())) {
      if (i >= lines.length) break;
      if (buffer.length + lines[i].length > maxCharsPerNote) break;
      buffer.writeln(lines[i]);
    }
    return buffer.toString().trim();
  }

  static Map<String, dynamic> buildRequestBody({
    required String model,
    required String question,
    required List<NoteExcerpt> excerpts,
  }) {
    final notes = StringBuffer();
    for (final excerpt in excerpts) {
      notes
        ..writeln('--- Note: ${excerpt.name} ---')
        ..writeln(excerpt.text)
        ..writeln();
    }
    return {
      'model': model,
      'temperature': 0.2,
      'messages': [
        {'role': 'system', 'content': _systemPrompt},
        {'role': 'user', 'content': 'Notes:\n$notes\nQuestion: $question'},
      ],
    };
  }

  static Future<NoteAnswer> ask(
    NoteSearchIndex index,
    String question, {
    required String apiKey,
    String model = defaultModel,
    http.Client? client,
  }) async {
    if (apiKey.trim().isEmpty) throw const HandwritingException('No API key');
    final excerpts = retrieve(index, question);
    if (excerpts.isEmpty) return const NoteAnswer(text: '', sources: []);

    final httpClient = client ?? http.Client();
    try {
      final response = await httpClient
          .post(
            Uri.parse(HandwritingRecognizer.endpoint),
            headers: {
              'Authorization': 'Bearer ${apiKey.trim()}',
              'Content-Type': 'application/json',
              'X-Title': 'Defter',
            },
            body: jsonEncode(
              buildRequestBody(
                model: model,
                question: question,
                excerpts: excerpts,
              ),
            ),
          )
          .timeout(const Duration(seconds: 60));
      final text = HandwritingRecognizer.parseResponse(
        response.statusCode,
        utf8.decode(response.bodyBytes),
      );
      return NoteAnswer(text: text, sources: excerpts);
    } on HandwritingException {
      rethrow;
    } catch (e) {
      throw HandwritingException('Could not reach OpenRouter: $e');
    } finally {
      if (client == null) httpClient.close();
    }
  }
}
