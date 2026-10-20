import 'package:flutter/material.dart';
import 'package:saber/components/home/library_screen.dart';
import 'package:saber/components/home/library_sidebar.dart';
import 'package:saber/data/defter_strings.dart';
import 'package:saber/data/flashcards/flashcards.dart';
import 'package:saber/data/flashcards/flashcard_store.dart';

class FlashcardsPage extends StatefulWidget {
  const FlashcardsPage({super.key, this.store = const FlashcardStore()});

  final FlashcardStore store;

  @override
  State<FlashcardsPage> createState() => _FlashcardsPageState();
}

class _FlashcardsPageState extends State<FlashcardsPage> {
  List<Flashcard> _cards = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final cards = await widget.store.load();
      if (!mounted) return;
      setState(() {
        _cards = cards;
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  List<Flashcard> get _dueCards {
    final now = DateTime.now();
    return _cards.where((card) => !card.nextReviewAt.isAfter(now)).toList();
  }

  Future<void> _addCard() async {
    final card = await showDialog<Flashcard>(
      context: context,
      builder: (_) => const FlashcardEditorDialog(),
    );
    if (card == null) return;
    await _save([..._cards, card]);
  }

  Future<void> _save(List<Flashcard> cards) async {
    await widget.store.save(cards);
    if (!mounted) return;
    setState(() => _cards = cards);
  }

  Future<void> _review(Flashcard card) async {
    final quality = await showDialog<FlashcardQuality>(
      context: context,
      builder: (_) => _ReviewDialog(card: card),
    );
    if (quality == null) return;
    final updated = FlashcardReviewEngine.review(card, quality);
    await _save([
      for (final item in _cards) item.id == updated.id ? updated : item,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return LibraryScreen(
      title: DefterStrings.flashcardsTitle,
      destination: LibraryDestination.flashcards,
      actions: [
        IconButton(
          tooltip: DefterStrings.flashcardsAdd,
          onPressed: _loading ? null : _addCard,
          icon: const Icon(Icons.add, color: Color(0xff4485bf)),
        ),
      ],
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
                children: [
                  _Summary(
                    total: _cards.length,
                    due: _dueCards.length,
                    onAdd: _addCard,
                  ),
                  const SizedBox(height: 20),
                  if (_cards.isEmpty)
                    SizedBox(
                      height: 220,
                      child: Center(child: Text(DefterStrings.flashcardsEmpty)),
                    )
                  else ...[
                    if (_dueCards.isNotEmpty)
                      _SectionTitle(
                        title: DefterStrings.flashcardsDue,
                        count: _dueCards.length,
                      ),
                    for (final card in _dueCards)
                      _CardTile(card: card, onReview: () => _review(card)),
                    const SizedBox(height: 14),
                    _SectionTitle(
                      title: DefterStrings.flashcardsAll,
                      count: _cards.length,
                    ),
                    for (final card in _cards)
                      _CardTile(card: card, onReview: () => _review(card)),
                  ],
                ],
              ),
            ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.total, required this.due, required this.onAdd});
  final int total, due;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    color: const Color(0xffeef4fb),
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          const Icon(Icons.style_outlined, color: Color(0xff4485bf), size: 30),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${DefterStrings.flashcardsDue}: $due'),
                const SizedBox(height: 4),
                Text('${DefterStrings.flashcardsAll}: $total'),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: Text(DefterStrings.flashcardsAdd),
          ),
        ],
      ),
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.count});
  final String title;
  final int count;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      '$title ($count)',
      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
    ),
  );
}

class _CardTile extends StatelessWidget {
  const _CardTile({required this.card, required this.onReview});
  final Flashcard card;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    margin: const EdgeInsets.only(bottom: 8),
    shape: RoundedRectangleBorder(
      side: const BorderSide(color: Color(0xffe1e5ea)),
      borderRadius: BorderRadius.circular(10),
    ),
    child: ListTile(
      title: Text(card.front, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(card.deck),
      trailing: OutlinedButton(
        onPressed: onReview,
        child: Text(DefterStrings.flashcardsGood),
      ),
    ),
  );
}

class FlashcardEditorDialog extends StatefulWidget {
  const FlashcardEditorDialog({super.key});

  @override
  State<FlashcardEditorDialog> createState() => _FlashcardEditorDialogState();
}

class _FlashcardEditorDialogState extends State<FlashcardEditorDialog> {
  final _front = TextEditingController();
  final _back = TextEditingController();
  final _deck = TextEditingController(text: 'Genel');

  @override
  void dispose() {
    _front.dispose();
    _back.dispose();
    _deck.dispose();
    super.dispose();
  }

  void _submit() {
    if (_front.text.trim().isEmpty || _back.text.trim().isEmpty) return;
    Navigator.pop(
      context,
      Flashcard.newCard(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        front: _front.text,
        back: _back.text,
        deck: _deck.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(DefterStrings.flashcardsAdd),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _front,
            autofocus: true,
            decoration: InputDecoration(
              labelText: DefterStrings.flashcardsFront,
            ),
          ),
          TextField(
            controller: _back,
            decoration: InputDecoration(
              labelText: DefterStrings.flashcardsBack,
            ),
            minLines: 2,
            maxLines: 5,
          ),
          TextField(
            controller: _deck,
            decoration: InputDecoration(
              labelText: DefterStrings.flashcardsDeck,
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(DefterStrings.flashcardsCancel),
      ),
      FilledButton(
        onPressed: _submit,
        child: Text(DefterStrings.flashcardsSave),
      ),
    ],
  );
}

class _ReviewDialog extends StatefulWidget {
  const _ReviewDialog({required this.card});
  final Flashcard card;

  @override
  State<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<_ReviewDialog> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.card.deck),
    content: SizedBox(
      width: 360,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.card.front, style: const TextStyle(fontSize: 22)),
          if (_revealed) ...[
            const Divider(height: 28),
            Text(widget.card.back, style: const TextStyle(fontSize: 18)),
          ],
        ],
      ),
    ),
    actions: _revealed
        ? [
            _qualityButton(
              FlashcardQuality.again,
              DefterStrings.flashcardsAgain,
            ),
            _qualityButton(FlashcardQuality.hard, DefterStrings.flashcardsHard),
            _qualityButton(FlashcardQuality.good, DefterStrings.flashcardsGood),
            _qualityButton(FlashcardQuality.easy, DefterStrings.flashcardsEasy),
          ]
        : [
            FilledButton(
              onPressed: () => setState(() => _revealed = true),
              child: Text(DefterStrings.flashcardsReveal),
            ),
          ],
  );

  Widget _qualityButton(FlashcardQuality quality, String label) => TextButton(
    onPressed: () => Navigator.pop(context, quality),
    child: Text(label),
  );
}
