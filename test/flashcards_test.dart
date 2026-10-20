import 'package:test/test.dart';
import 'package:saber/data/flashcards/flashcards.dart';

void main() {
  final start = DateTime(2026, 10, 20, 9);

  test('good reviews follow the one day then six day schedule', () {
    final card = Flashcard.newCard(id: 'a', front: '2+2', back: '4');

    final first = FlashcardReviewEngine.review(
      card,
      FlashcardQuality.good,
      now: start,
    );
    final second = FlashcardReviewEngine.review(
      first,
      FlashcardQuality.good,
      now: start.add(const Duration(days: 1)),
    );

    expect(first.repetitions, 1);
    expect(first.intervalDays, 1);
    expect(first.nextReviewAt, start.add(const Duration(days: 1)));
    expect(second.repetitions, 2);
    expect(second.intervalDays, 6);
    expect(second.nextReviewAt, start.add(const Duration(days: 7)));
  });

  test('again resets repetitions and schedules the card for tomorrow', () {
    final card = Flashcard.newCard(id: 'a', front: 'Soru', back: 'Cevap');
    final learned = FlashcardReviewEngine.review(
      card,
      FlashcardQuality.easy,
      now: start,
    );
    final failed = FlashcardReviewEngine.review(
      learned,
      FlashcardQuality.again,
      now: start.add(const Duration(days: 4)),
    );

    expect(failed.repetitions, 0);
    expect(failed.intervalDays, 1);
    expect(failed.nextReviewAt, start.add(const Duration(days: 5)));
  });

  test('ease factor never drops below 1.30 and intervals cap at 90 days', () {
    var card = Flashcard.newCard(id: 'a', front: 'Soru', back: 'Cevap');
    for (var i = 0; i < 30; i++) {
      card = FlashcardReviewEngine.review(
        card,
        FlashcardQuality.hard,
        now: start.add(Duration(days: i)),
      );
    }
    expect(card.easeFactor, greaterThanOrEqualTo(1.3));

    card = card.copyWith(intervalDays: 89, repetitions: 8);
    final extended = FlashcardReviewEngine.review(
      card,
      FlashcardQuality.easy,
      now: start,
    );
    expect(extended.intervalDays, 90);
  });

  test('card JSON round trip preserves scheduling state', () {
    final card = FlashcardReviewEngine.review(
      Flashcard.newCard(id: 'id-1', front: 'Ön', back: 'Arka', deck: 'Ders'),
      FlashcardQuality.good,
      now: start,
    );

    final decoded = Flashcard.fromJson(card.toJson());

    expect(decoded, card);
  });
}
