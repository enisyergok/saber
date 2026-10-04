// Renders the main screens on a tablet-sized surface so that UI work can be
// reviewed from CI without a device. Run with `--update-goldens`; the images
// land in test/defter_shots/ and are not committed.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_screenshot/golden_screenshot.dart';
import 'package:saber/components/canvas/pencil_shader.dart';
import 'package:saber/components/home/syncing_button.dart';
import 'package:saber/components/theming/saber_theme.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/flavor_config.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/sentry/sentry_init.dart';
import 'package:saber/i18n/strings.g.dart';
import 'package:saber/pages/editor/editor.dart';
import 'package:saber/pages/home/home.dart';
import 'package:yaru/yaru.dart';

import 'screenshot_goldens_test.dart';
import 'utils/test_mock_channel_handlers.dart';
import 'utils/test_user.dart';

final _baseTablet = GoldenScreenshotDevices.androidTablet.device;

/// Roughly a HUAWEI MatePad 11.5" (2200x1440) in landscape.
final _tablet = ScreenshotDevice(
  platform: _baseTablet.platform,
  resolution: const Size(2200, 1440),
  pixelRatio: 1.75,
  goldenSubFolder: 'defter/',
  frameBuilder: _baseTablet.frameBuilder,
);

void main() {
  group('Defter screens:', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    BackgroundIsolateBinaryMessenger.ensureInitialized(
      ServicesBinding.rootIsolateToken!,
    );

    setupMockPathProvider();
    setupMockPrinting();
    disableSentryForTesting();

    FlavorConfig.setup();
    SyncingButton.debugForceButtonActive = true;

    stows.lastStorageQuota.value = TestUser.getQuota();
    stows.username.value = 'myusername';
    stows.sentryConsent.value = .granted;

    setUpAll(() async {
      await Future.wait([
        FileManager.init(shouldWatchRootDirectory: false),
        PencilShader.init(),
      ]);
      await setupDemoFiles();
      await FileManager.createFolder('/Toplantılar');
      await FileManager.createFolder('/Projeler');
    });

    final theme = SaberTheme.createThemeFromSeed(
      YaruColors.blue,
      Brightness.light,
      TargetPlatform.android,
    );

    _shot(
      theme: theme,
      name: 'library',
      child: const HomePage(subpage: HomePage.browseSubpage, path: null),
    );
    _shot(
      theme: theme,
      name: 'recent',
      child: const HomePage(subpage: HomePage.recentSubpage, path: null),
    );
    _shot(
      theme: theme,
      name: 'editor',
      child: Editor(path: '/Metric Spaces Week 1'),
    );
  });
}

void _shot({
  required ThemeData theme,
  required String name,
  required Widget child,
}) {
  testGoldens(name, (tester) async {
    stows.platform.value = _tablet.platform;
    await tester.runAsync(() => LocaleSettings.setLocaleRaw('tr'));

    final widget = ScreenshotApp.withConditionalTitlebar(
      theme: theme,
      device: _tablet,
      title: 'Defter',
      home: TranslationProvider(child: child),
    );
    await tester.pumpWidget(widget);
    await tester.pump();

    for (final editorState in tester.stateList<EditorState>(
      find.byType(Editor),
    )) {
      // Wait for the editor to load
      while (editorState.coreInfo.isEmpty) {
        await tester.runAsync(
          () => Future.delayed(const Duration(milliseconds: 100)),
        );
      }
      await tester.pump();
    }

    // Give async directory listings a moment to complete.
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump();

    await tester.loadAssets();
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('defter_shots/$name.png'),
    );
  });
}
