/// What a stylus button press (such as the double tap of some pens) does
/// in the editor.
enum StylusAction {
  none,
  toggleEraser,
  previousTool,
  lasso,
  highlighter,
  undo,
  redo;

  /// The action stored as [index] in the settings, or [fallback] if the
  /// number doesn't match any action.
  static StylusAction fromIndex(
    int index, {
    StylusAction fallback = StylusAction.toggleEraser,
  }) => index >= 0 && index < values.length ? values[index] : fallback;
}

/// Telling stylus button key events from other keys.
abstract class StylusKeys {
  /// Flutter's logical key ids for Android key codes it has no name for are
  /// this plane plus the key code.
  static const androidPlane = 0x11;

  /// Android's `KEYCODE_STYLUS_BUTTON_PRIMARY`, `_SECONDARY`, `_TERTIARY` and
  /// `_TAIL`.
  static const firstKeyCode = 308;
  static const lastKeyCode = 311;

  /// Whether the logical key [keyId] is one of Android's stylus button keys.
  static bool isStylusKey(int keyId) {
    if (keyId >> 32 != androidPlane) return false;
    final code = keyId & 0xFFFFFFFF;
    return code >= firstKeyCode && code <= lastKeyCode;
  }
}

/// Counts presses that follow each other quickly, so that a double press can
/// be told from two separate single ones.
class StylusTapCounter {
  StylusTapCounter({this.windowMs = 400});

  /// The most time (milliseconds) that may pass between two presses of a
  /// double press.
  final int windowMs;

  int _count = 0;
  int _lastMs = 0;

  /// A press happened at [nowMs]. Returns true when it completes a press of
  /// [needed] taps (1 means every press counts).
  bool press(int nowMs, {required int needed}) {
    if (needed <= 1) {
      _count = 0;
      return true;
    }
    if (_count > 0 && nowMs - _lastMs > windowMs) _count = 0;
    _count++;
    _lastMs = nowMs;
    if (_count >= needed) {
      _count = 0;
      return true;
    }
    return false;
  }

  void reset() => _count = 0;
}
