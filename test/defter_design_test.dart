import 'package:flutter/cupertino.dart' show CupertinoPageTransition;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saber/components/eink/eink_scope.dart';
import 'package:saber/components/theming/defter_design.dart';
import 'package:saber/components/theming/saber_theme.dart';
import 'package:saber/data/eink/eink_style.dart';
import 'package:saber/data/flavor_config.dart';

const _accents = <Color?>[
  null,
  Color(0xFFFFD32E), // yellow
  Color(0xFFD32F2F), // red
  Color(0xFF2E7D32), // green
  Color(0xFF7B1FA2), // purple
  Color(0xFF607D8B), // nearly grey
];

double _contrast(Color a, Color b) => EInkStyle.contrastRatio(a, b);

void main() {
  setUpAll(FlavorConfig.setup);

  group('Defter colours:', () {
    test('without an accent the app is ink blue on white paper', () {
      final scheme = DefterDesign.colorScheme(Brightness.light);
      expect(scheme.primary, DefterDesign.ink);
      expect(scheme.onPrimary, Colors.white);
      expect(scheme.surface, Colors.white);
      expect(_contrast(scheme.primary, scheme.surface), greaterThan(4.5));
    });

    test('the paper is the same whatever the accent', () {
      for (final brightness in Brightness.values) {
        final plain = DefterDesign.colorScheme(brightness);
        for (final accent in _accents) {
          final scheme = DefterDesign.colorScheme(brightness, accent: accent);
          final reason = '$accent, ${brightness.name}';
          expect(scheme.surface, plain.surface, reason: reason);
          expect(scheme.surfaceContainer, plain.surfaceContainer, reason: reason);
          expect(scheme.onSurface, plain.onSurface, reason: reason);
          expect(scheme.outlineVariant, plain.outlineVariant, reason: reason);
          expect(scheme.surfaceTint, Colors.transparent, reason: reason);
        }
      }
    });

    test('everything written can be read', () {
      for (final brightness in Brightness.values) {
        for (final accent in _accents) {
          final scheme = DefterDesign.colorScheme(brightness, accent: accent);
          final reason = '$accent, ${brightness.name}';
          expect(
            _contrast(scheme.onSurface, scheme.surface),
            greaterThanOrEqualTo(7),
            reason: 'text, $reason',
          );
          expect(
            _contrast(scheme.onSurfaceVariant, scheme.surface),
            greaterThanOrEqualTo(4.5),
            reason: 'secondary text, $reason',
          );
          expect(
            _contrast(scheme.onSurfaceVariant, scheme.surfaceContainerHighest),
            greaterThanOrEqualTo(4.5),
            reason: 'secondary text on the greyest surface, $reason',
          );
          expect(
            _contrast(scheme.onPrimary, scheme.primary),
            greaterThanOrEqualTo(4.5),
            reason: 'text on the accent, $reason',
          );
          expect(
            _contrast(scheme.onPrimaryContainer, scheme.primaryContainer),
            greaterThanOrEqualTo(4.5),
            reason: 'text on a tinted row, $reason',
          );
          expect(
            _contrast(scheme.onSecondaryContainer, scheme.secondaryContainer),
            greaterThanOrEqualTo(4.5),
            reason: 'text on a lightly tinted row, $reason',
          );
        }
      }
    });

    test('a tint is a wash of the accent over the paper', () {
      for (final accent in _accents) {
        final scheme = DefterDesign.colorScheme(
          Brightness.light,
          accent: accent,
        );
        // Nearly paper: a selected row must not shout.
        expect(
          _contrast(scheme.primaryContainer, scheme.surface),
          lessThan(1.6),
          reason: '$accent',
        );
        expect(scheme.primaryContainer, isNot(scheme.surface));
      }
    });

    test('the editor bar is deep enough for white icons', () {
      for (final brightness in Brightness.values) {
        for (final accent in _accents) {
          final scheme = DefterDesign.colorScheme(brightness, accent: accent);
          expect(
            _contrast(Colors.white, DefterDesign.headerOf(scheme)),
            greaterThanOrEqualTo(7),
            reason: '$accent, ${brightness.name}',
          );
        }
      }
    });
  });

  group('Defter theme:', () {
    test('no ripples, and pages slide on every platform', () {
      for (final platform in TargetPlatform.values) {
        if (platform == TargetPlatform.linux) continue; // Yaru's own theme
        final theme = SaberTheme.createDefaultTheme(Brightness.light, platform);
        expect(theme.splashFactory, NoSplash.splashFactory);
        expect(
          theme.pageTransitionsTheme.builders[platform],
          isA<DefterPageTransitionsBuilder>(),
          reason: platform.name,
        );
      }
    });

    test('a chosen accent only changes the accent', () {
      const platform = TargetPlatform.android;
      final plain = SaberTheme.createDefaultTheme(Brightness.light, platform);
      final red = SaberTheme.createThemeFromSeed(
        const Color(0xFFD32F2F),
        Brightness.light,
        platform,
      );
      expect(red.colorScheme.primary, isNot(plain.colorScheme.primary));
      expect(red.scaffoldBackgroundColor, plain.scaffoldBackgroundColor);
      expect(red.cardTheme.shape, plain.cardTheme.shape);
      expect(red.dialogTheme.shape, plain.dialogTheme.shape);
    });

    test('the styles handed to components are whole', () {
      // A style without its size takes the size of whatever is around it:
      // titles shrink to body text without anything failing.
      for (final brightness in Brightness.values) {
        final theme = SaberTheme.createDefaultTheme(
          brightness,
          TargetPlatform.android,
        );
        final styles = <String, TextStyle?>{
          'app bar title': theme.appBarTheme.titleTextStyle,
          'dialog title': theme.dialogTheme.titleTextStyle,
          'dialog text': theme.dialogTheme.contentTextStyle,
          'tooltip': theme.tooltipTheme.textStyle,
          'chip': theme.chipTheme.labelStyle,
          'filled button': theme.filledButtonTheme.style?.textStyle?.resolve(
            const {},
          ),
          'outlined button': theme.outlinedButtonTheme.style?.textStyle
              ?.resolve(const {}),
          'text button': theme.textButtonTheme.style?.textStyle?.resolve(
            const {},
          ),
          'segmented button': theme.segmentedButtonTheme.style?.textStyle
              ?.resolve(const {}),
        };
        for (final MapEntry(key: what, value: style) in styles.entries) {
          final reason = '$what, ${brightness.name}';
          expect(style, isNotNull, reason: reason);
          expect(style!.fontSize, isNotNull, reason: reason);
          expect(style.inherit, isFalse, reason: reason);
        }
        expect(theme.appBarTheme.titleTextStyle!.fontSize, greaterThan(18));
        expect(theme.dialogTheme.titleTextStyle!.fontSize, 20);
      }
    });
  });

  group('Page transitions:', () {
    Widget app() => MaterialApp(
      theme: SaberTheme.createDefaultTheme(
        Brightness.light,
        TargetPlatform.android,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      const Scaffold(body: Center(child: Text('second'))),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    testWidgets('the new page slides in over the old one', (tester) async {
      await tester.pumpWidget(app());
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));

      expect(find.byType(CupertinoPageTransition), findsWidgets);
      // On its way in from the right, not there yet
      expect(tester.getTopLeft(find.text('second')).dx, greaterThan(400));

      await tester.pumpAndSettle();
      expect(tester.getCenter(find.text('second')).dx, closeTo(400, 1));
      expect(find.text('open'), findsNothing);
    });

    testWidgets('a stroke from the left edge does not go back', (tester) async {
      await tester.pumpWidget(app());
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('second'), findsOneWidget);

      // What a pen does when a line starts at the edge of the paper
      await tester.dragFrom(const Offset(4, 300), const Offset(500, 0));
      await tester.pumpAndSettle();

      expect(find.text('second'), findsOneWidget);
      expect(find.text('open'), findsNothing);
      expect(tester.getCenter(find.text('second')).dx, closeTo(400, 1));
    });

    testWidgets('nothing slides when animations are off', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );

      await tester.pumpWidget(app());
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));

      expect(find.byType(CupertinoPageTransition), findsNothing);
      expect(tester.getCenter(find.text('second')).dx, closeTo(400, 1));
      await tester.pumpAndSettle();
    });
  });

  group('PressScale:', () {
    double scaleOf(WidgetTester tester) =>
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;

    Widget pressable({
      required VoidCallback onTap,
      Widget Function(Widget child)? wrap,
    }) {
      final Widget child = Center(
        child: PressScale(
          child: GestureDetector(
            onTap: onTap,
            child: const ColoredBox(
              color: Colors.blue,
              child: SizedBox(width: 120, height: 80),
            ),
          ),
        ),
      );
      return MaterialApp(home: wrap == null ? child : wrap(child));
    }

    testWidgets('gives under the finger and still lets the tap through', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(pressable(onTap: () => taps++));
      expect(scaleOf(tester), 1);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(PressScale)),
      );
      await tester.pump();
      expect(scaleOf(tester), 0.97);

      await gesture.up();
      await tester.pump();
      expect(scaleOf(tester), 1);
      expect(taps, 1);
    });

    testWidgets('comes back when the press is called off', (tester) async {
      await tester.pumpWidget(pressable(onTap: () {}));
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(PressScale)),
      );
      await tester.pump();
      expect(scaleOf(tester), 0.97);

      await gesture.cancel();
      await tester.pump();
      expect(scaleOf(tester), 1);
    });

    testWidgets('stays still on an e-ink screen', (tester) async {
      await tester.pumpWidget(
        pressable(
          onTap: () {},
          wrap: (child) =>
              EInkScope(style: const EInkStyle(texture: 0), child: child),
        ),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(PressScale)),
      );
      await tester.pump();
      expect(scaleOf(tester), 1);
      await gesture.up();
      await tester.pump();
    });

    testWidgets('stays still when animations are off', (tester) async {
      await tester.pumpWidget(
        pressable(
          onTap: () {},
          wrap: (child) => MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: child,
          ),
        ),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(PressScale)),
      );
      await tester.pump();
      expect(scaleOf(tester), 1);
      await gesture.up();
      await tester.pump();
    });
  });

  group('FloatingPanel and Appear:', () {
    testWidgets('a panel is paper with a hairline and a shadow', (tester) async {
      final theme = SaberTheme.createDefaultTheme(
        Brightness.light,
        TargetPlatform.android,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Center(
            child: FloatingPanel(child: SizedBox(width: 100, height: 60)),
          ),
        ),
      );

      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(FloatingPanel),
          matching: find.byType(Material),
        ),
      );
      expect(material.color, theme.colorScheme.surface);
      final shape = material.shape! as RoundedRectangleBorder;
      expect(shape.side.color, theme.colorScheme.outlineVariant);
      expect(
        shape.borderRadius,
        BorderRadius.circular(DefterDesign.radiusSheet),
      );

      final box = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(FloatingPanel),
          matching: find.byType(DecoratedBox),
        ),
      );
      expect((box.decoration as ShapeDecoration).shadows, isNotEmpty);
      expect(tester.getSize(find.byType(FloatingPanel)), const Size(100, 60));
    });

    testWidgets('a pill has round ends', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(
            child: FloatingPanel.pill(child: SizedBox(width: 100, height: 40)),
          ),
        ),
      );
      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(FloatingPanel),
          matching: find.byType(Material),
        ),
      );
      expect(material.shape, isA<StadiumBorder>());
    });

    testWidgets('what appears is fully there once it has arrived', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(child: Appear(child: Text('panel'))),
        ),
      );
      await tester.pumpAndSettle();

      final fade = tester.widget<FadeTransition>(
        find.descendant(
          of: find.byType(Appear),
          matching: find.byType(FadeTransition),
        ),
      );
      final scale = tester.widget<ScaleTransition>(
        find.descendant(
          of: find.byType(Appear),
          matching: find.byType(ScaleTransition),
        ),
      );
      expect(fade.opacity.value, 1);
      expect(scale.scale.value, 1);
      expect(find.text('panel'), findsOneWidget);
    });
  });
}
