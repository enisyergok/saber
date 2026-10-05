import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:saber/data/defter_strings.dart';
import 'package:saber/data/tools/stylus_action.dart';

/// Lists the signals the pen sends (key presses and button changes) as they
/// happen, to find out how a pen's double tap or side button reaches the app.
class StylusTestDialog extends StatefulWidget {
  const StylusTestDialog({super.key});

  @override
  State<StylusTestDialog> createState() => _StylusTestDialogState();
}

class _StylusTestDialogState extends State<StylusTestDialog> {
  static const _maxEvents = 40;

  final _events = <_Signal>[];
  int _lastButtons = -1;
  PointerDeviceKind? _lastKind;

  @override
  void initState() {
    HardwareKeyboard.instance.addHandler(_onKey);
    super.initState();
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  void _add(String text, {bool penKey = false}) {
    if (!mounted) return;
    setState(() {
      _events.insert(0, _Signal(text, penKey));
      if (_events.length > _maxEvents) _events.removeLast();
    });
  }

  bool _onKey(KeyEvent event) {
    final id = event.logicalKey.keyId;
    final kind = switch (event) {
      KeyDownEvent() => 'basıldı',
      KeyUpEvent() => 'bırakıldı',
      _ => 'tekrar',
    };
    final name = event.logicalKey.debugName ?? event.logicalKey.keyLabel;
    _add(
      'Tuş $kind: kimlik 0x${id.toRadixString(16)}'
      '${name.isEmpty ? '' : ' ($name)'}',
      penKey: StylusKeys.isStylusKey(id),
    );
    return false;
  }

  void _onPointer(PointerEvent event) {
    final isStylus =
        event.kind == PointerDeviceKind.stylus ||
        event.kind == PointerDeviceKind.invertedStylus;
    if (!isStylus) return;
    // only changes are listed, or moving the pen would flood the list
    if (event.buttons == _lastButtons && event.kind == _lastKind) return;
    _lastButtons = event.buttons;
    _lastKind = event.kind;
    _add(
      'Kalem: tür ${event.kind.name}, düğme değeri ${event.buttons}'
      '${event is PointerHoverEvent ? ' (havada)' : ''}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = ColorScheme.of(context);
    return AlertDialog(
      title: Text(DefterStrings.stylusTest),
      content: SizedBox(
        width: 460,
        height: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(DefterStrings.stylusTestHint),
            const SizedBox(height: 8),
            Expanded(
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: _onPointer,
                onPointerMove: _onPointer,
                onPointerUp: _onPointer,
                onPointerHover: _onPointer,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: colors.outline),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _events.isEmpty
                      ? Center(child: Text(DefterStrings.stylusTestNothing))
                      : ListView.builder(
                          itemCount: _events.length,
                          itemBuilder: (context, i) {
                            final signal = _events[i];
                            return ListTile(
                              dense: true,
                              leading: signal.penKey
                                  ? Icon(Icons.check_circle, color: colors.primary)
                                  : const Icon(Icons.circle_outlined, size: 16),
                              title: Text(signal.text),
                              subtitle: signal.penKey
                                  ? Text(DefterStrings.stylusTestDetected)
                                  : null,
                            );
                          },
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => setState(_events.clear),
          child: Text(DefterStrings.stylusTestClear),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).closeButtonLabel),
        ),
      ],
    );
  }
}

class _Signal {
  const _Signal(this.text, this.penKey);

  final String text;
  final bool penKey;
}
