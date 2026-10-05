import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:saber/components/eink/eink_scope.dart';
import 'package:saber/components/theming/dynamic_material_app.dart';
import 'package:saber/data/eink/eink_style.dart';
import 'package:saber/data/flavor_config.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/i18n/strings.g.dart';

class _Counter extends StatefulWidget {
  const new();

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int taps = 0;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: () => setState(() => taps++),
    child: Text('taps: $taps'),
  );
}

void main() {
  group('E-ink mode in the app:', () {
    setUpAll(FlavorConfig.setup);

    tearDown(() {
      stows.eInkMode.value = stows.eInkMode.defaultValue;
      stows.eInkPaperWarmth.value = stows.eInkPaperWarmth.defaultValue;
      stows.platform.value = stows.platform.defaultValue;
    });

    Future<void> pump(WidgetTester tester) async {
      final router = GoRouter(
        routes: [GoRoute(path: '/', builder: (_, _) => const _Counter())],
      );
      await tester.pumpWidget(
        TranslationProvider(
          child: DynamicMaterialApp(title: 'title', router: router),
        ),
      );
    }

    testWidgets('is off by default, and the normal theme is used', (
      tester,
    ) async {
      await pump(tester);
      final context = tester.element(find.byType(_Counter));
      expect(EInkScope.maybeOf(context), isNull);
      expect(
        Theme.of(context).colorScheme.surface,
        isNot(const EInkStyle().paper),
      );
    });

    testWidgets('switches the whole app to the paper theme, and back', (
      tester,
    ) async {
      await pump(tester);

      stows.eInkMode.value = true;
      await tester.pumpAndSettle();
      var context = tester.element(find.byType(_Counter));
      expect(EInkScope.maybeOf(context), const EInkStyle());
      expect(Theme.of(context).colorScheme.surface, const EInkStyle().paper);
      // dark system theme or not, e-ink is paper
      expect(Theme.brightnessOf(context), Brightness.light);

      stows.eInkMode.value = false;
      await tester.pumpAndSettle();
      context = tester.element(find.byType(_Counter));
      expect(EInkScope.maybeOf(context), isNull);
    });

    testWidgets('following the settings: warmth changes the paper', (
      tester,
    ) async {
      await pump(tester);
      stows.eInkMode.value = true;
      stows.eInkPaperWarmth.value = 1;
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(_Counter));
      expect(
        Theme.of(context).colorScheme.surface,
        const EInkStyle(paperWarmth: 1).paper,
      );
    });

    testWidgets('turning the mode on or off does not reset the screen', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.byType(TextButton));
      await tester.pump();
      await tester.tap(find.byType(TextButton));
      await tester.pump();
      expect(find.text('taps: 2'), findsOneWidget);

      stows.eInkMode.value = true;
      await tester.pump();
      expect(find.text('taps: 2'), findsOneWidget);

      stows.eInkMode.value = false;
      await tester.pump();
      expect(find.text('taps: 2'), findsOneWidget);
    });

    for (final platform in TargetPlatform.values) {
      testWidgets('builds on ${platform.name}', (tester) async {
        stows.platform.value = platform;
        stows.eInkMode.value = true;
        await pump(tester);
        expect(tester.takeException(), isNull);
        final app = tester.widget<ExplicitlyThemedApp>(
          find.byType(ExplicitlyThemedApp),
        );
        expect(app.theme.platform, platform);
        expect(app.themeMode, ThemeMode.light);
        expect(app.eInk, isNotNull);
      });
    }
  });
}
