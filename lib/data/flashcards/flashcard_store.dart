import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/flashcards/flashcards.dart';

class FlashcardStore {
  const FlashcardStore();

  static const filePath = '/flashcards.json';

  Future<List<Flashcard>> load() async {
    final bytes = await FileManager.readFile(filePath);
    if (bytes == null) return [];
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! List) return [];
      return [
        for (final item in decoded)
          if (item is Map<String, dynamic>) Flashcard.fromJson(item),
      ];
    } on Object catch (error) {
      debugPrint('Çalışma kartları okunamadı: $error');
      return [];
    }
  }

  Future<void> save(List<Flashcard> cards) async {
    final payload = jsonEncode(cards.map((card) => card.toJson()).toList());
    await FileManager.writeFile(
      filePath,
      utf8.encode(payload),
      awaitWrite: true,
      alsoUpload: false,
    );
  }
}
