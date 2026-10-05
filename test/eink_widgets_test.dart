import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saber/components/canvas/_canvas_background_painter.dart';
import 'package:saber/components/canvas/_canvas_painter.dart';
import 'package:saber/components/canvas/inner_canvas.dart';
import 'package:saber/components/eink/eink_image_filter.dart';
import 'package:saber/components/eink/eink_refresh.dart';
import 'package:saber/components/eink/eink_refresh_overlay.dart';
import 'package:saber/components/eink/eink_scope.dart';
import 'package:saber/components/theming/saber_theme.dart';
import 'package:saber/data/benchmark/synthetic_notes.dart';
import 'package:saber/data/editor/editor_core_info.dart';
import 'package:saber/data/eink/eink_style.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/flavor_config.dart';
import 'package:saber/data/tools/stroke_properties.dart';

import 'utils/test_mock_channel_handlers.dart';

/// No grain, so nothing loads asynchronously and paints are countable.
const _style = EInkStyle(texture: 0);

void main() {
  group('E-ink theme:', () {
    test('text and icons are readable on the paper at every setting', () {
      for (final warmth in [0.0, 0.5, 1.0]) {
        for (final darkness in [0.0, 0.5, 1.0]) {
          final style = EInkStyle(paperWarmth: warmth, inkDarkness: darkness);
          final scheme = SaberTheme.createEInkColorScheme(style);
          final reason = 'warmth $warmth, darkness $darkness';

          void expectContrast(Color a, Color b, double min, String what) {
            expect(
              EInkStyle.contrastRatio(a, b),
              greaterThanOrEqualTo(min),
              reason: '$what at $reason',
            );
          }

          expectContrast(scheme.onSurface, scheme.surface, 4.5, 'text');
          expectContrast(
            scheme.onSurfaceVariant,
            scheme.surface,
            4.5,
            'secondary text',
          );
          expectContrast(scheme.onPrimary, scheme.primary, 4.5, 'button');
          expectContrast(
            scheme.onSecondary,
            scheme.secondary,
            4.5,
            'secondary button',
          );
          expectContrast(
            scheme.onPrimaryContainer,
            scheme.primaryContainer,
            4.5,
            'chip',
          );
          expectContrast(
            scheme.onSecondaryContainer,
            scheme.secondaryContainer,
            4.5,
            'tonal button',
          );
          expectContrast(
            scheme.onSurface,
            scheme.surfaceContainerHighest,
            4.5,
            'text on a card',
          );
          expectContrast(scheme.onError, scheme.error, 4.5, 'error');
          expectContrast(
            scheme.onInverseSurface,
            scheme.inverseSurface,
            4.5,
            'snack bar',
          );
          expectContrast(scheme.outline, scheme.surface, 3.0, 'borders');
        }
      }
    });

    test('is a light theme on the paper colour', () {
      final theme = SaberTheme.createEInkTheme(_style, TargetPlatform.android);
      expect(theme.brightness, Brightness.light);
      expect(theme.colorScheme.surface, _style.paper);
      expect(theme.scaffoldBackgroundColor, _style.paper);
    });

    test('has no shadows, ripples or page animations', () {
      final theme = SaberTheme.createEInkTheme(_style, TargetPlatform.android);
      expect(theme.splashFactory, NoSplash.splashFactory);
      expect(theme.cardTheme.elevation, 0);
      expect(theme.dialogTheme.elevation, 0);
      expect(theme.appBarTheme.scrolledUnderElevation, 0);
      expect(theme.bottomSheetTheme.elevation, 0);
      for (final platform in TargetPlatform.values) {
        final builder = theme.pageTransitionsTheme.builders[platform]!;
        final child = Container();
        // an instant transition returns its child untouched
        expect(
          builder.buildTransitions<void>(
            MaterialPageRoute<void>(builder: (_) => child),
            _FakeContext(),
            const AlwaysStoppedAnimation(0.5),
            const AlwaysStoppedAnimation(0),
            child,
          ),
          same(child),
        );
      }
    });

    testWidgets('a MaterialApp with it builds', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: SaberTheme.createEInkTheme(_style, TargetPlatform.android),
          home: Scaffold(
            appBar: AppBar(title: const Text('Defter')),
            body: ListView(
              children: [
                const ListTile(title: Text('Not')),
                ElevatedButton(onPressed: () {}, child: const Text('Tamam')),
                Card(child: const Text('Kart')),
              ],
            ),
          ),
        ),
      );
      expect(find.text('Defter'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('E-ink scope:', () {
    testWidgets('is null without a scope', (tester) async {
      EInkStyle? seen = const EInkStyle();
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            seen = EInkScope.maybeOf(context);
            return const SizedBox();
          },
        ),
      );
      expect(seen, isNull);
    });

    testWidgets('gives the style to widgets below, and updates them', (
      tester,
    ) async {
      final seen = <EInkStyle?>[];
      Widget build(EInkStyle? style) => EInkScope(
        style: style,
        child: Builder(
          builder: (context) {
            seen.add(EInkScope.maybeOf(context));
            return const SizedBox();
          },
        ),
      );
      await tester.pumpWidget(build(_style));
      await tester.pumpWidget(build(const EInkStyle(inkDarkness: 0.1)));
      await tester.pumpWidget(build(null));
      expect(seen, [_style, const EInkStyle(inkDarkness: 0.1), null]);
    });
  });

  group('E-ink pictures:', () {
    testWidgets('are filtered only in e-ink mode', (tester) async {
      const picture = SizedBox(width: 10, height: 10);
      await tester.pumpWidget(const EInkImageFilter(child: picture));
      expect(find.byType(ColorFiltered), findsNothing);

      await tester.pumpWidget(
        const EInkScope(
          style: _style,
          child: EInkImageFilter(child: picture),
        ),
      );
      expect(find.byType(ColorFiltered), findsOneWidget);
    });
  });

  group('E-ink refresh:', () {
    setUp(() {
      EInkRefresh.isWriting = () => false;
    });

    test('page turns closer together than the gap show one refresh', () {
      final refresh = EInkRefresh.instance;
      final before = refresh.serial;
      final start = DateTime(2026, 10, 5, 9);
      refresh.pageTurn(now: start);
      refresh.pageTurn(now: start.add(const Duration(milliseconds: 300)));
      refresh.pageTurn(now: start.add(const Duration(milliseconds: 700)));
      expect(refresh.serial, before + 1);
      refresh.pageTurn(now: start.add(EInkRefresh.minGap));
      expect(refresh.serial, before + 2);
    });

    test('nothing is flashed while the pen is writing', () {
      final refresh = EInkRefresh.instance;
      final before = refresh.serial;
      EInkRefresh.isWriting = () => true;
      refresh.full();
      refresh.pageTurn(now: DateTime(2030));
      expect(refresh.serial, before);
    });

    test('the page turn is a faint flash that fades out', () {
      final alphas = [
        for (var i = 0; i <= 20; i++)
          EInkRefreshPainter.frame(EInkRefreshKind.pageTurn, i / 20, _style).$2,
      ];
      expect(alphas.first, 0);
      expect(alphas.last, closeTo(0, 1e-9));
      // never covers the page: the old and new page show through
      expect(alphas.reduce((a, b) => a > b ? a : b), lessThanOrEqualTo(0.35));
    });

    test('the full refresh goes dark, then light, then shows the page', () {
      (Color, double) at(double t) =>
          EInkRefreshPainter.frame(EInkRefreshKind.full, t, _style);
      final dark = at(0.25);
      final light = at(0.5);
      expect(dark.$1, _style.ink);
      expect(dark.$2, greaterThan(0.9));
      expect(light.$1, _style.paper);
      expect(light.$2, greaterThan(0.9));
      expect(at(1).$2, closeTo(0, 1e-9));
    });

    testWidgets('shows over the app and clears afterwards', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: EInkScope(
            style: _style,
            child: EInkRefreshOverlay(child: Text('sayfa')),
          ),
        ),
      );
      expect(_flash(), findsNothing);

      EInkRefresh.instance.full();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(_flash(), findsOneWidget);
      // it never takes touches or the pen
      expect(
        find.ancestor(of: _flash(), matching: find.byType(IgnorePointer)),
        findsWidgets,
      );

      await tester.pumpAndSettle();
      expect(_flash(), findsNothing);
      expect(find.text('sayfa'), findsOneWidget);
    });

    testWidgets('is off when the refresh effect is switched off', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: EInkScope(
            style: EInkStyle(texture: 0, refreshEffect: false),
            child: EInkRefreshOverlay(child: Text('sayfa')),
          ),
        ),
      );
      EInkRefresh.instance.full();
      await tester.pump(const Duration(milliseconds: 100));
      expect(_flash(), findsNothing);
    });

    testWidgets('respects "reduce motion"', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: EInkScope(
              style: _style,
              child: EInkRefreshOverlay(child: Text('sayfa')),
            ),
          ),
        ),
      );
      EInkRefresh.instance.full();
      await tester.pump(const Duration(milliseconds: 100));
      expect(_flash(), findsNothing);
    });
  });

  group('E-ink page:', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupMockPathProvider();
    FlavorConfig.setup();
    StrokeOptionsExtension.setDefaults();

    setUpAll(() async {
      await FileManager.init(shouldWatchRootDirectory: false);
    });

    late EditorCoreInfo note;
    final paints = <InkLayer, int>{};

    setUp(() {
      paints.clear();
      CanvasPainter.debugOnPaint = (layer) =>
          paints[layer] = (paints[layer] ?? 0) + 1;
      note = SyntheticNotes.note(strokes: 40);
    });
    tearDown(() {
      CanvasPainter.debugOnPaint = null;
    });

    Future<void> pumpCanvas(WidgetTester tester, EInkStyle? style) async {
      final page = note.pages.first;
      await tester.pumpWidget(
        EInkScope(
          style: style,
          child: MaterialApp(
            home: SizedBox(
              width: page.size.width,
              height: page.size.height,
              child: InnerCanvas(
                pageIndex: 0,
                redrawPageListenable: page,
                liveInkListenable: page.liveInkListenable,
                width: page.size.width,
                height: page.size.height,
                coreInfo: note,
                currentStroke: null,
                currentStrokeDetectedShape: null,
                currentSelection: null,
                currentToolIsSelect: false,
                currentScale: 1,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('is drawn on paper in e-ink mode, white otherwise', (
      tester,
    ) async {
      await pumpCanvas(tester, _style);
      var background = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((paint) => paint.painter)
          .whereType<CanvasBackgroundPainter>()
          .single;
      expect(background.backgroundColor, _style.paper);
      expect(background.eInk, isTrue);
      expect(background.invert, isFalse);

      await pumpCanvas(tester, null);
      background = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((paint) => paint.painter)
          .whereType<CanvasBackgroundPainter>()
          .single;
      expect(background.backgroundColor, InnerCanvas.defaultBackgroundColor);
      expect(background.eInk, isFalse);
    });

    testWidgets('both ink layers get the style, and strokes are untouched', (
      tester,
    ) async {
      final colorsBefore = [for (final s in note.pages.first.strokes) s.color];
      await pumpCanvas(tester, _style);
      final painters = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .expand((paint) => [paint.painter, paint.foregroundPainter])
          .whereType<CanvasPainter>()
          .toList();
      expect(painters, hasLength(2));
      for (final painter in painters) {
        expect(painter.eInk, _style);
      }
      // a display preference only: the notes keep their colours
      expect([for (final s in note.pages.first.strokes) s.color], colorsBefore);
    });

    testWidgets('writing in e-ink mode still repaints only the live layer', (
      tester,
    ) async {
      await pumpCanvas(tester, _style);
      paints.clear();

      final page = note.pages.first;
      for (var i = 0; i < 10; i++) {
        page.redrawLiveInk();
        await tester.pump();
      }

      expect(paints[InkLayer.live], 10);
      expect(
        paints[InkLayer.dry] ?? 0,
        0,
        reason: 'finished strokes and paper must not be repainted per move',
      );
    });
  });
}

Finder _flash() => find.byWidgetPredicate(
  (widget) =>
      widget is CustomPaint && widget.painter is EInkRefreshPainter,
);

class _FakeContext extends Fake implements BuildContext {}
