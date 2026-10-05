import 'package:flutter/foundation.dart';

/// What kind of refresh to show.
enum EInkRefreshKind {
  /// A faint grey flash, for turning to another page.
  pageTurn,

  /// The full flash (dark, light, then the page), for "refresh page".
  full,
}

/// Asks the screen to show an e-ink refresh. Nothing happens unless e-ink
/// mode and its refresh effect are on, and the person hasn't asked for
/// reduced motion; see `EInkRefreshOverlay`.
class EInkRefresh extends ChangeNotifier {
  new._();

  static final instance = new._();

  /// Page turns closer together than this show one flash, so scrolling
  /// quickly through pages doesn't flicker.
  static const minGap = Duration(milliseconds: 800);

  /// Set by the editor: true while the pen is on the page. Nothing is
  /// flashed over the writing then.
  static bool Function() isWriting = () => false;

  EInkRefreshKind? kind;
  int serial = 0;
  DateTime? _lastPageTurn;

  void pageTurn({DateTime? now}) {
    final time = now ?? DateTime.now();
    final last = _lastPageTurn;
    if (last != null && time.difference(last) < minGap) return;
    _lastPageTurn = time;
    _request(EInkRefreshKind.pageTurn);
  }

  void full() => _request(EInkRefreshKind.full);

  void _request(EInkRefreshKind requested) {
    if (isWriting()) return;
    kind = requested;
    serial++;
    notifyListeners();
  }
}
