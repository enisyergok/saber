import 'package:flutter/widgets.dart';
import 'package:saber/data/eink/eink_style.dart';

/// Tells everything below it that e-ink mode is on, and how it looks.
///
/// Placed above the whole app while the mode is on. Exports build their own
/// widget tree without a scope, so they stay in the notes' own colours
/// unless the user asks for the e-ink look.
class EInkScope extends InheritedWidget {
  const new({super.key, required this.style, required super.child});

  /// Null while e-ink mode is off.
  final EInkStyle? style;

  static EInkStyle? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<EInkScope>()?.style;

  @override
  bool updateShouldNotify(EInkScope oldWidget) => style != oldWidget.style;
}
