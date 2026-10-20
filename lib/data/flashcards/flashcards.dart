import 'package:meta/meta.dart';

enum FlashcardQuality {
  again(0),
  hard(3),
  good(4),
  easy(5);

  const FlashcardQuality(this.value);
  final int value;
}

@immutable
class Flashcard {
  const Flashcard({
    required this.id,
    required this.front,
    required this.back,
    required this.deck,
    required this.createdAt,
    required this.nextReviewAt,
    required this.repetitions,
    required this.intervalDays,
    required this.easeFactor,
    this.lastQuality,
  });

  factory Flashcard.newCard({
    required String id,
    required String front,
    required String back,
    String deck = 'Genel',
    DateTime? createdAt,
  }) {
    final created = createdAt ?? DateTime.now();
    return Flashcard(
      id: id,
      front: front.trim(),
      back: back.trim(),
      deck: deck.trim().isEmpty ? 'Genel' : deck.trim(),
      createdAt: created,
      nextReviewAt: created,
      repetitions: 0,
      intervalDays: 0,
      easeFactor: 2.5,
    );
  }

  factory Flashcard.fromJson(Map<String, dynamic> json) {
    return Flashcard(
      id: json['id'] as String,
      front: json['front'] as String,
      back: json['back'] as String,
      deck: (json['deck'] as String?) ?? 'Genel',
      createdAt: DateTime.parse(json['createdAt'] as String),
      nextReviewAt: DateTime.parse(json['nextReviewAt'] as String),
      repetitions: (json['repetitions'] as num?)?.toInt() ?? 0,
      intervalDays: (json['intervalDays'] as num?)?.toInt() ?? 0,
      easeFactor: (json['easeFactor'] as num?)?.toDouble() ?? 2.5,
      lastQuality: (json['lastQuality'] as num?)?.toInt(),
    );
  }

  final String id;
  final String front;
  final String back;
  final String deck;
  final DateTime createdAt;
  final DateTime nextReviewAt;
  final int repetitions;
  final int intervalDays;
  final double easeFactor;
  final int? lastQuality;

  Flashcard copyWith({
    String? front,
    String? back,
    String? deck,
    DateTime? nextReviewAt,
    int? repetitions,
    int? intervalDays,
    double? easeFactor,
    int? lastQuality,
  }) => Flashcard(
    id: id,
    front: front ?? this.front,
    back: back ?? this.back,
    deck: deck ?? this.deck,
    createdAt: createdAt,
    nextReviewAt: nextReviewAt ?? this.nextReviewAt,
    repetitions: repetitions ?? this.repetitions,
    intervalDays: intervalDays ?? this.intervalDays,
    easeFactor: easeFactor ?? this.easeFactor,
    lastQuality: lastQuality ?? this.lastQuality,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'front': front,
    'back': back,
    'deck': deck,
    'createdAt': createdAt.toIso8601String(),
    'nextReviewAt': nextReviewAt.toIso8601String(),
    'repetitions': repetitions,
    'intervalDays': intervalDays,
    'easeFactor': easeFactor,
    'lastQuality': lastQuality,
  };

  @override
  bool operator ==(Object other) =>
      other is Flashcard &&
      other.id == id &&
      other.front == front &&
      other.back == back &&
      other.deck == deck &&
      other.createdAt == createdAt &&
      other.nextReviewAt == nextReviewAt &&
      other.repetitions == repetitions &&
      other.intervalDays == intervalDays &&
      other.easeFactor == easeFactor &&
      other.lastQuality == lastQuality;

  @override
  int get hashCode => Object.hash(
    id,
    front,
    back,
    deck,
    createdAt,
    nextReviewAt,
    repetitions,
    intervalDays,
    easeFactor,
    lastQuality,
  );
}

abstract final class FlashcardReviewEngine {
  static Flashcard review(
    Flashcard card,
    FlashcardQuality quality, {
    DateTime? now,
  }) {
    final reviewedAt = now ?? DateTime.now();
    final ease = _ease(card.easeFactor, quality.value);
    if (quality.value < 3) {
      return card.copyWith(
        nextReviewAt: reviewedAt.add(const Duration(days: 1)),
        repetitions: 0,
        intervalDays: 1,
        easeFactor: ease,
        lastQuality: quality.value,
      );
    }

    final repetitions = card.repetitions + 1;
    final interval = switch (repetitions) {
      1 => 1,
      2 => 6,
      _ => (card.intervalDays * ease).round().clamp(1, 90),
    };
    return card.copyWith(
      nextReviewAt: reviewedAt.add(Duration(days: interval)),
      repetitions: repetitions,
      intervalDays: interval,
      easeFactor: ease,
      lastQuality: quality.value,
    );
  }

  static double _ease(double current, int quality) {
    final next =
        current + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));
    return next.clamp(1.3, 3.0);
  }
}
