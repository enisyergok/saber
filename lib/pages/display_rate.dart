import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:saber/data/defter_strings.dart';
import 'package:saber/data/display_rate.dart';

/// Shows how fast the screen can be drawn, how fast the app is really
/// drawn on it right now (measured from its own frames), and what to do
/// when the device holds the app back.
class DisplayRatePage extends StatefulWidget {
  const new({
    super.key,
    this.read,
    this.openSettings,
    @visibleForTesting this.frozenAt,
  });

  /// What reads the device's answer; the real one if not given.
  final Future<DisplayRateInfo?> Function()? read;

  /// For pictures of this page only: this rate is shown and nothing is
  /// measured (a page that keeps drawing can't be photographed in a test).
  final double? frozenAt;

  /// What opens the device's screen settings; the real one if not given.
  final Future<bool> Function()? openSettings;

  @override
  State<DisplayRatePage> createState() => _DisplayRatePageState();
}

class _DisplayRatePageState extends State<DisplayRatePage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _meter = FrameRateMeter();
  final _sweep = ValueNotifier<double>(0);
  late final Ticker _ticker;

  DisplayRateInfo? _info;
  double? _measured;
  Duration _shownAt = Duration.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = createTicker(_onFrame);
    if (widget.frozenAt == null) {
      _ticker.start();
    } else {
      _measured = widget.frozenAt;
    }
    unawaited(_read());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _sweep.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back from the settings: the answer may be another one now.
    if (state == AppLifecycleState.resumed) {
      _meter.clear();
      unawaited(_read());
    }
  }

  Future<void> _read() async {
    final info = await (widget.read ?? DisplayRate.read)();
    if (!mounted) return;
    setState(() => _info = info);
  }

  void _onFrame(Duration elapsed) {
    _meter.add(elapsed);
    // Something is drawn with every frame, as when writing.
    _sweep.value = (elapsed.inMicroseconds % 1500000) / 1500000;
    if ((elapsed - _shownAt).inMilliseconds < 400) return;
    _shownAt = elapsed;
    final rate = _meter.rate;
    if (rate != _measured) setState(() => _measured = rate);
  }

  String _hz(double? value) =>
      value == null ? '—' : '${value.round()} Hz';

  String get _report {
    final info = _info;
    return [
      'Defter ekran hızı',
      'ölçülen: ${_measured?.toStringAsFixed(1) ?? '?'}',
      'en yüksek: ${info?.max?.toStringAsFixed(1) ?? '?'}',
      'kip: ${info?.mode?.toStringAsFixed(1) ?? '?'}',
      'uygulamaya verilen: ${info?.app?.toStringAsFixed(1) ?? '?'}',
      'cihaz: ${info?.maker ?? '?'} ${info?.model ?? '?'}, API ${info?.sdk ?? '?'}',
      info?.details ?? '',
    ].join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final info = _info;
    // Where the device gives no answer, what Flutter was told is used.
    final flutterRate = View.of(context).display.refreshRate;
    final max = info?.max;
    final verdict = DisplayRate.verdict(max: max, measured: _measured);

    final (IconData icon, Color color, String text) = switch (verdict) {
      DisplayRateVerdict.full => (
        Icons.check_circle_outline,
        colorScheme.primary,
        DefterStrings.rateFull(_hz(max)),
      ),
      DisplayRateVerdict.noFasterMode => (
        Icons.info_outline,
        colorScheme.onSurfaceVariant,
        DefterStrings.rateNoFasterMode(_hz(max)),
      ),
      DisplayRateVerdict.heldBack => (
        Icons.warning_amber_outlined,
        colorScheme.error,
        DefterStrings.rateHeldBack(_hz(max), _hz(_measured)),
      ),
      DisplayRateVerdict.unknown => (
        Icons.hourglass_empty,
        colorScheme.onSurfaceVariant,
        info == null ? DefterStrings.rateNoInfo : DefterStrings.rateMeasuring,
      ),
    };

    Widget row(String label, String value, {Key? key}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
          Text(
            value,
            key: key,
            style: theme.textTheme.titleMedium?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(DefterStrings.rateTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(DefterStrings.rateIntro, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 12),
          row(DefterStrings.rateMax, _hz(max), key: const Key('rateMax')),
          row(
            DefterStrings.rateGiven,
            _hz(info?.app ?? (flutterRate > 0 ? flutterRate : null)),
            key: const Key('rateGiven'),
          ),
          row(
            DefterStrings.rateMeasured,
            _measured == null
                ? '—'
                : DefterStrings.rateFrames(_measured!.toStringAsFixed(1)),
            key: const Key('rateMeasured'),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 6,
            child: CustomPaint(
              painter: _SweepPainter(_sweep, colorScheme.primary),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            key: Key('rateVerdict-${verdict.name}'),
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: color),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(text, style: theme.textTheme.bodyLarge),
                        if (verdict == DisplayRateVerdict.heldBack ||
                            verdict == DisplayRateVerdict.noFasterMode) ...[
                          const SizedBox(height: 12),
                          Text(DefterStrings.rateSteps),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                key: const Key('rateOpenSettings'),
                icon: const Icon(Icons.settings_outlined),
                label: Text(DefterStrings.rateOpenSettings),
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final opened =
                      await (widget.openSettings ?? DisplayRate.openSettings)();
                  if (!opened) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(DefterStrings.rateSettingsNotOpened),
                      ),
                    );
                  }
                },
              ),
              OutlinedButton.icon(
                key: const Key('rateCopy'),
                icon: const Icon(Icons.copy),
                label: Text(DefterStrings.rateCopy),
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  await Clipboard.setData(ClipboardData(text: _report));
                  messenger.showSnackBar(
                    SnackBar(content: Text(DefterStrings.rateCopied)),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(DefterStrings.rateTouchHint, style: theme.textTheme.bodySmall),
          if (info != null) ...[
            const SizedBox(height: 16),
            SelectableText(
              '${info.maker ?? ''} ${info.model ?? ''} · API ${info.sdk ?? '?'}\n'
              '${info.details ?? ''}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A mark that moves a little with every frame, so that a frame is really
/// drawn each time (as it is while writing).
class _SweepPainter extends CustomPainter {
  _SweepPainter(this.position, this.color) : super(repaint: position);

  final ValueListenable<double> position;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final track = Paint()..color = color.withValues(alpha: 0.15);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(3)),
      track,
    );
    final width = math.max(24.0, size.width * 0.08);
    final x = (size.width - width) * (0.5 - 0.5 * math.cos(position.value * 2 * math.pi));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, 0, width, size.height),
        const Radius.circular(3),
      ),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_SweepPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.position != position;
}
