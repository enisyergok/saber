import 'dart:io';
import 'dart:math';
import 'dart:ui' show FrameTiming;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:saber/data/ci_build.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:saber/components/canvas/_stroke.dart';
import 'package:saber/components/canvas/canvas.dart';
import 'package:saber/data/benchmark/pure_benchmarks.dart';
import 'package:saber/data/benchmark/synthetic_notes.dart';
import 'package:saber/data/defter_strings.dart';
import 'package:saber/data/editor/editor_core_info.dart';
import 'package:saber/data/tools/pen.dart';
import 'package:saber/data/version.dart';

/// Measures drawing and saving performance on the device it runs on.
///
/// Everything is synthetic and in memory: no note on disk is read or written.
class BenchmarkPage extends StatefulWidget {
  const BenchmarkPage({super.key});

  /// How many frames of simulated writing are timed per scenario.
  static const writingFrames = 240;

  /// A new stroke is started after this many points, like lifting the pen.
  static const pointsPerLiveStroke = 30;

  @override
  State<BenchmarkPage> createState() => _BenchmarkPageState();
}

class _BenchmarkPageState extends State<BenchmarkPage> {
  final _lines = <String>[];
  var _running = false;
  var _status = '';

  /// The note currently on screen for a writing scenario.
  EditorCoreInfo? _note;
  Stroke? _liveStroke;

  void _log(String line) {
    if (!mounted) return;
    setState(() => _lines.add(line));
  }

  static String _ms(Duration duration) =>
      (duration.inMicroseconds / 1000).toStringAsFixed(1);

  double get _refreshRate {
    final rate = View.of(context).display.refreshRate;
    return rate.isFinite && rate > 0 ? rate : 60;
  }

  Future<void> _run() async {
    final view = View.of(context);
    final refreshRate = _refreshRate;
    setState(() {
      _running = true;
      _lines.clear();
    });

    try {
      final size = view.physicalSize;
      _log(
        'Defter $buildName ($buildNumber)'
        '${ciBuild.isEmpty ? '' : ', build $ciBuild'}',
      );
      _log(
        'screen ${size.width.round()}x${size.height.round()} '
        '@${view.devicePixelRatio.toStringAsFixed(2)}x, '
        '${refreshRate.toStringAsFixed(0)} Hz '
        '(frame budget ${(1000 / refreshRate).toStringAsFixed(1)} ms)',
      );
      _log('memory at start: ${ProcessInfo.currentRss ~/ (1024 * 1024)} MB');
      _log('');

      _log('# stroke outline while drawing (total ms)');
      for (final points in const [100, 500, 2000]) {
        _setStatus('outline $points');
        await _yield();
        final elapsed = PureBenchmarks.outlineWhileDrawing(points);
        _log('outline $points points: ${_ms(elapsed)} ms');
      }
      _log('');

      _log('# writing on a page (ms per frame: p50 / p95 / p99 / max)');
      for (final strokes in const [0, 1000, 10000, 50000]) {
        await _measureWriting(strokes, refreshRate);
      }
      await _clearNote();
      _log('');

      _log('# save and open (ms)');
      for (final (strokes, pages) in const [
        (1000, 1),
        (10000, 1),
        (50000, 1),
        (30000, 100),
      ]) {
        _setStatus('save/open $strokes');
        await _yield();
        final note = SyntheticNotes.note(strokes: strokes, pages: pages);
        final saved = PureBenchmarks.serialize(note);
        note.dispose();
        final parse = await PureBenchmarks.parse(saved.bytes);
        _log(
          '$strokes strokes, $pages page(s): '
          'serialize ${_ms(saved.elapsed)} ms, '
          'open ${_ms(parse)} ms, '
          '${(saved.bytes.length / (1024 * 1024)).toStringAsFixed(2)} MB',
        );
      }
      _log('');
      _log('memory at end: ${ProcessInfo.currentRss ~/ (1024 * 1024)} MB');
    } catch (e, st) {
      _log('FAILED: $e');
      _log('$st'.split('\n').take(6).join('\n'));
    } finally {
      await _clearNote();
      if (mounted) {
        setState(() {
          _running = false;
          _status = '';
        });
      }
    }
  }

  /// Takes the note off screen, then frees it.
  Future<void> _clearNote() async {
    final note = _note;
    if (note == null) return;
    if (mounted) {
      setState(() {
        _note = null;
        _liveStroke = null;
      });
      await SchedulerBinding.instance.endOfFrame;
    }
    note.dispose();
  }

  void _setStatus(String status) {
    if (mounted) setState(() => _status = status);
  }

  /// Lets a frame through so the status text shows before blocking work.
  Future<void> _yield() async {
    await SchedulerBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }

  /// Shows a page with [strokes] existing strokes and writes on it,
  /// one point per frame, the way [EditorState.onDrawUpdate] does.
  Future<void> _measureWriting(int strokes, double refreshRate) async {
    _setStatus('writing on $strokes strokes');

    final buildStopwatch = Stopwatch()..start();
    final note = SyntheticNotes.note(strokes: strokes);
    final page = note.pages.first;
    buildStopwatch.stop();

    final previousNote = _note;
    final firstPaint = Stopwatch()..start();
    setState(() {
      _note = note;
      _liveStroke = null;
    });
    await SchedulerBinding.instance.endOfFrame;
    firstPaint.stop();
    // Only dispose the previous note once it has left the widget tree.
    previousNote?.dispose();
    // Let the first paint settle before timing.
    for (var i = 0; i < 5; i++) {
      await SchedulerBinding.instance.endOfFrame;
    }

    final timings = <FrameTiming>[];
    void onTimings(List<FrameTiming> batch) => timings.addAll(batch);
    SchedulerBinding.instance.addTimingsCallback(onTimings);

    final random = Random(3);
    var letterIndex = strokes;
    Stroke? stroke;
    var origin = Offset.zero;
    var width = 0.0;
    var height = 0.0;
    var phase = 0.0;
    var pointInStroke = 0;

    for (var frame = 0; frame < BenchmarkPage.writingFrames; frame++) {
      if (stroke == null ||
          pointInStroke >= BenchmarkPage.pointsPerLiveStroke) {
        if (stroke != null) {
          // Pen up: the stroke joins the page, as in EditorState.onDrawEnd.
          stroke.options.isComplete = true;
          stroke.markPolygonNeedsUpdating();
          page.insertStroke(stroke);
        }
        final newStroke = SyntheticNotes.emptyStroke(page: page);
        stroke = newStroke;
        origin = SyntheticNotes.letterOrigin(letterIndex++);
        width = 14 + random.nextDouble() * 8;
        height = 18 + random.nextDouble() * 10;
        phase = random.nextDouble() * pi;
        pointInStroke = 0;
        if (!mounted) break;
        setState(() => _liveStroke = newStroke);
      }

      final (position, pressure) = SyntheticNotes.letterPoint(
        origin: origin,
        i: pointInStroke++,
        points: BenchmarkPage.pointsPerLiveStroke,
        width: width,
        height: height,
        phase: phase,
      );
      stroke.addPoint(position, pressure);
      page.redrawLiveInk();
      await SchedulerBinding.instance.endOfFrame;
    }

    // Frame timings arrive in batches, up to about a second later.
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    SchedulerBinding.instance.removeTimingsCallback(onTimings);

    final measured = timings.length > BenchmarkPage.writingFrames
        ? timings.sublist(timings.length - BenchmarkPage.writingFrames)
        : timings;
    double toMs(Duration duration) => duration.inMicroseconds / 1000;
    final build = [for (final t in measured) toMs(t.buildDuration)];
    final raster = [for (final t in measured) toMs(t.rasterDuration)];
    final total = [for (final t in measured) toMs(t.totalSpan)];
    final budget = 1000 / refreshRate;
    final overBudget = total.where((ms) => ms > budget).length;

    String stats(List<double> values) => [
      percentile(values, 50),
      percentile(values, 95),
      percentile(values, 99),
      values.isEmpty ? double.nan : values.reduce(max),
    ].map((v) => v.toStringAsFixed(1)).join(' / ');

    _log('$strokes strokes (${measured.length} frames):');
    _log('  build  ${stats(build)}');
    _log('  raster ${stats(raster)}');
    _log('  total  ${stats(total)}');
    _log(
      '  over budget: $overBudget of ${measured.length} '
      '(${measured.isEmpty ? 0 : (100 * overBudget / measured.length).toStringAsFixed(1)}%)',
    );
    _log(
      '  generate ${_ms(buildStopwatch.elapsed)} ms, '
      'first frame ${_ms(firstPaint.elapsed)} ms',
    );
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _lines.join('\n')));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(DefterStrings.benchmarkCopied)));
  }

  @override
  Widget build(BuildContext context) {
    final note = _note;
    final textTheme = TextTheme.of(context);

    final Widget body;
    if (_running && note != null) {
      // Lay the page out as the editor does: full width, top of the page
      // in view, clipped by the viewport.
      body = LayoutBuilder(
        builder: (context, constraints) {
          final page = note.pages.first;
          final width = min(page.size.width, constraints.maxWidth);
          return SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: Center(
              child: SizedBox(
                width: width,
                height: width * page.size.height / page.size.width,
                child: Canvas(
                  path: note.filePath,
                  page: page,
                  pageIndex: 0,
                  textEditing: false,
                  coreInfo: note,
                  currentStroke: _liveStroke,
                  currentStrokeDetectedShape: null,
                  currentSelection: null,
                  setAsBackground: null,
                  currentTool: Pen.currentPen,
                  currentScale: 1,
                ),
              ),
            ),
          );
        },
      );
    } else if (_lines.isEmpty) {
      body = Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              DefterStrings.benchmarkIntro,
              style: textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    } else {
      body = SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SelectableText(
          _lines.join('\n'),
          style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _running
              ? '${DefterStrings.benchmarkRunning} · $_status'
              : DefterStrings.benchmark,
        ),
        actions: [
          if (!_running && _lines.isNotEmpty)
            IconButton(
              tooltip: DefterStrings.benchmarkCopy,
              icon: const Icon(Symbols.content_copy_rounded),
              onPressed: _copy,
            ),
        ],
      ),
      body: AbsorbPointer(absorbing: _running, child: body),
      floatingActionButton: _running
          ? null
          : FloatingActionButton.extended(
              onPressed: _run,
              icon: const Icon(Symbols.speed_rounded),
              label: Text(DefterStrings.benchmarkStart),
            ),
    );
  }
}
