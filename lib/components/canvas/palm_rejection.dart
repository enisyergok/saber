import 'package:flutter/gestures.dart';

/// Decides which touches belong to a resting palm instead of a finger.
///
/// While a stylus is touching the screen (and for a moment after it lifts),
/// new touches are ignored, so a hand resting on the tablet can't pan, zoom
/// or turn a pen stroke into a two-finger gesture.
class PalmRejection {
  /// How long after the stylus last touched the screen new touches are still
  /// treated as part of the same hand.
  static const graceAfterStylus = Duration(milliseconds: 300);

  /// The stylus pointers currently touching the screen.
  final _stylusDown = <int>{};

  /// When a stylus last touched down, moved or lifted.
  Duration? _lastStylusActivity;

  /// Whether a stylus is touching the screen right now.
  bool get isStylusDown => _stylusDown.isNotEmpty;

  static bool isStylus(PointerEvent event) =>
      event.kind == PointerDeviceKind.stylus ||
      event.kind == PointerDeviceKind.invertedStylus;

  /// Feed every pointer event to this, in the order received.
  void handleEvent(PointerEvent event) {
    if (!isStylus(event)) return;

    if (event is PointerDownEvent) {
      _stylusDown.add(event.pointer);
      _lastStylusActivity = event.timeStamp;
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      _stylusDown.remove(event.pointer);
      _lastStylusActivity = event.timeStamp;
    } else if (event is PointerMoveEvent && _stylusDown.contains(event.pointer)) {
      _lastStylusActivity = event.timeStamp;
    }
    // Hover events are deliberately ignored: with the pen held in the air a
    // finger should still be able to scroll.
  }

  /// Whether a new touch should be ignored because of the stylus.
  /// Only touches are ever rejected, never the stylus itself or a mouse.
  bool shouldRejectNewPointer(PointerDownEvent event) {
    if (event.kind != PointerDeviceKind.touch) return false;
    if (isStylusDown) return true;

    final last = _lastStylusActivity;
    if (last == null) return false;
    final elapsed = event.timeStamp - last;
    return elapsed >= Duration.zero && elapsed <= graceAfterStylus;
  }
}
