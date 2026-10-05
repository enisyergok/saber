import 'dart:async';

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

  // What Flutter is told about the pen's pressure.
  final _stroke = <double>[];
  double? _pressure, _rangeMin, _rangeMax, _seenLow, _seenHigh;

  static const _input = MethodChannel('defter/input');

  /// What Android itself reports to the window (before Flutter sees it).
  List<String> _native = const [];
  String _devices = '';
  Timer? _poll;

  @override
  void initState() {
    HardwareKeyboard.instance.addHandler(_onKey);
    super.initState();
    unawaited(_loadDevices());
    _poll = Timer.periodic(
      const Duration(milliseconds: 400),
      (_) => unawaited(_loadNative()),
    );
  }

  @override
  void dispose() {
    _poll?.cancel();
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  Future<void> _loadDevices() async {
    try {
      final devices = await _input.invokeMethod<String>('devices');
      if (mounted) setState(() => _devices = devices ?? '');
    } on MissingPluginException {
      // not Android
    }
  }

  Future<void> _loadNative() async {
    try {
      final events = await _input.invokeListMethod<String>('events');
      if (!mounted || events == null) return;
      if (events.length == _native.length &&
          (events.isEmpty || events.first == _native.first)) {
        return;
      }
      setState(() => _native = events);
    } on MissingPluginException {
      _poll?.cancel();
    }
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
    if (event is PointerDownEvent) _stroke.clear();
    if (event is PointerDownEvent || event is PointerMoveEvent) {
      _stroke.add(event.pressure);
    }
    if (event is PointerUpEvent && _stroke.length > 3) {
      _add(_strokeSummary(_stroke, event.pressureMin, event.pressureMax));
      _stroke.clear();
    }
    if (event is! PointerHoverEvent) {
      setState(() {
        _pressure = event.pressure;
        _rangeMin = event.pressureMin;
        _rangeMax = event.pressureMax;
        _seenLow = _seenLow == null
            ? event.pressure
            : (event.pressure < _seenLow! ? event.pressure : _seenLow);
        _seenHigh = _seenHigh == null
            ? event.pressure
            : (event.pressure > _seenHigh! ? event.pressure : _seenHigh);
      });
    }
    // only changes are listed, or moving the pen would flood the list
    if (event.buttons == _lastButtons && event.kind == _lastKind) return;
    _lastButtons = event.buttons;
    _lastKind = event.kind;
    _add(
      'Kalem: tür ${event.kind.name}, düğme değeri ${event.buttons}'
      '${event is PointerHoverEvent ? ' (havada)' : ''}',
    );
  }

  /// How the pressure was spread over one line: if most of it sits at the
  /// top of the range, no thickness change can be seen however it is drawn.
  static String _strokeSummary(List<double> values, double min, double max) {
    final sorted = [...values]..sort();
    double at(double f) => sorted[((sorted.length - 1) * f).round()];
    final range = max - min;
    String n(double v) =>
        (range == 0 ? v : (v - min) / range).toStringAsFixed(2);
    final mean = values.reduce((a, b) => a + b) / values.length;
    return 'Çizgi (${values.length} nokta): en düşük ${n(sorted.first)}, '
        'ortanca ${n(at(0.5))}, ortalama ${n(mean)}, '
        '%90 ${n(at(0.9))}, en yüksek ${n(sorted.last)} (0–1 ölçeğinde)';
  }

  Widget _pressureBox(ColorScheme colors) {
    final p = _pressure;
    final min = _rangeMin, max = _rangeMax;
    final hasRange = min != null && max != null && min != max;
    final String verdict;
    if (p == null) {
      verdict = DefterStrings.pressureNone;
    } else if (!hasRange) {
      verdict = DefterStrings.pressureNoRange;
    } else if (_seenHigh! - _seenLow! < 0.05 * (max - min)) {
      verdict = DefterStrings.pressureFlat;
    } else {
      verdict = DefterStrings.pressureWorks;
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              p == null
                  ? DefterStrings.pressureLabel
                  : '${DefterStrings.pressureLabel}: ${p.toStringAsFixed(3)}'
                        ' (${min?.toStringAsFixed(2)} – '
                        '${max?.toStringAsFixed(2)}), '
                        '${_seenLow!.toStringAsFixed(3)} … '
                        '${_seenHigh!.toStringAsFixed(3)}',
              style: _mono,
            ),
            if (hasRange && p != null)
              LinearProgressIndicator(
                value: ((p - min) / (max - min)).clamp(0.0, 1.0),
              ),
            const SizedBox(height: 4),
            Text(verdict),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = ColorScheme.of(context);
    return AlertDialog(
      title: Text(DefterStrings.stylusTest),
      content: SizedBox(
        width: 460,
        height: 640,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(DefterStrings.stylusTestHint),
            const SizedBox(height: 8),
            _pressureBox(colors),
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
            const SizedBox(height: 8),
            Text(
              DefterStrings.stylusTestNative,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 4),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: colors.outline),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView(
                  padding: const EdgeInsets.all(8),
                  children: [
                    for (final line in _native)
                      Text(line, style: _mono),
                    if (_devices.isNotEmpty) ...[
                      const Divider(),
                      Text(_devices, style: _mono),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            setState(_events.clear);
            unawaited(_input.invokeMethod<void>('clear').catchError((_) {}));
            setState(() => _native = const []);
          },
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

const _mono = TextStyle(fontFamily: 'monospace', fontSize: 12);

class _Signal {
  const _Signal(this.text, this.penKey);

  final String text;
  final bool penKey;
}
