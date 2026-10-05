// Renders the main screens on a tablet-sized surface so that UI work can be
// reviewed from CI without a device. Run with
// `--tags screens --update-goldens`; the images land in test/defter_shots/
// and are not committed.
@Tags(['screens'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_screenshot/golden_screenshot.dart';
import 'package:perfect_freehand/perfect_freehand.dart';
import 'package:saber/components/canvas/_stroke.dart';
import 'package:saber/components/canvas/canvas.dart' as saber;
import 'package:saber/components/canvas/pencil_shader.dart';
import 'package:saber/components/home/new_notebook_dialog.dart';
import 'package:saber/components/home/syncing_button.dart';
import 'package:saber/components/eink/eink_scope.dart';
import 'package:saber/components/theming/saber_theme.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/benchmark/synthetic_notes.dart';
import 'package:saber/data/defter_strings.dart';
import 'package:saber/data/eink/eink_style.dart';
import 'package:saber/data/eink/eink_texture.dart';
import 'package:saber/data/flavor_config.dart';
import 'package:saber/data/open_tabs.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/sentry/sentry_init.dart';
import 'package:saber/data/tools/pen.dart';
import 'package:saber/data/tools/select.dart';
import 'package:saber/data/tools/shape_analysis.dart';
import 'package:saber/data/tools/shape_snap.dart';
import 'package:saber/data/tools/stroke_properties.dart';
import 'package:saber/i18n/strings.g.dart';
import 'package:saber/pages/editor/editor.dart';
import 'package:saber/pages/home/browse.dart';
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
    setupMockWindowManager();
    disableSentryForTesting();

    FlavorConfig.setup();
    StrokeOptionsExtension.setDefaults();
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
      // Real directory listings don't complete inside the test zone.
      children: DirectoryChildren(
        ['Projeler', 'Toplantılar'],
        [
          'Annotate images and diagrams',
          'Golden ratio',
          'Import PDFs',
          'Metric Spaces Week 1',
          'You can type notes too!',
          'Coding review 1',
          'HG Week 6',
          'Topology week 1',
        ],
      ),
      child: const HomePage(subpage: HomePage.browseSubpage, path: null),
    );
    _shot(
      theme: theme,
      name: 'new_notebook',
      child: const HomePage(subpage: HomePage.recentSubpage, path: null),
      afterLoad: (tester) async {
        NewNotebookDialog.show(tester.element(find.byType(HomePage)));
        await tester.pump();
      },
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
      afterLoad: (tester) async {
        // Pretend two other notebooks were opened earlier.
        OpenTabs.open('/Golden ratio');
        OpenTabs.open('/Import PDFs');
        await tester.pump();
      },
    );
    // What the benchmark writes on: 1,000 synthetic letters on one page.
    final syntheticNote = SyntheticNotes.note(strokes: 1000);
    _shot(
      theme: theme,
      name: 'benchmark_note',
      child: Scaffold(
        body: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Center(
            child: SizedBox(
              width: 1000,
              height: 1400,
              child: saber.Canvas(
                path: syntheticNote.filePath,
                page: syntheticNote.pages.first,
                pageIndex: 0,
                textEditing: false,
                coreInfo: syntheticNote,
                currentStroke: null,
                currentStrokeDetectedShape: null,
                currentSelection: null,
                setAsBackground: null,
                currentTool: Pen.currentPen,
                currentScale: 1,
              ),
            ),
          ),
        ),
      ),
    );
    _shot(
      theme: theme,
      name: 'editor_pages',
      child: Editor(path: '/Metric Spaces Week 1'),
      afterLoad: (tester) async {
        OpenTabs.reset();
        await tester.pump();
        final editor = tester.state<EditorState>(find.byType(Editor));
        editor.toggleBookmark(0);
        editor.showPageGrid();
        await tester.pump();
      },
    );
    _shot(
      theme: theme,
      name: 'editor_sidebar',
      child: Editor(path: '/Metric Spaces Week 1'),
      afterLoad: (tester) async {
        OpenTabs.reset();
        stows.editorPageSidebar.value = true;
        addTearDown(() => stows.editorPageSidebar.value = false);
        await tester.pump();
      },
    );
    _shot(
      theme: theme,
      name: 'editor_shape_selected',
      child: Editor(path: '/Metric Spaces Week 1'),
      afterLoad: (tester) async {
        OpenTabs.reset();
        await tester.pump();
        final editor = tester.state<EditorState>(find.byType(Editor));
        final page = editor.coreInfo.pages.first;
        Stroke raw() => Stroke(
          color: Colors.indigo,
          pressureEnabled: false,
          options: StrokeOptions(size: 6),
          pageIndex: 0,
          page: page,
          toolId: .fountainPen,
        );
        final quad = ShapeBuilder.build(
          raw(),
          ShapeGuess(
            kind: ShapeKind.polygon,
            points: const [
              Offset(180, 200),
              Offset(520, 230),
              Offset(450, 420),
              Offset(230, 380),
            ],
          ),
        );
        final ellipse = ShapeBuilder.build(
          raw()..color = Colors.deepOrange,
          ShapeGuess(
            kind: ShapeKind.ellipse,
            center: const Offset(760, 320),
            radiusX: 130,
            radiusY: 70,
            rotation: 0.3,
          ),
        );
        page.strokes
          ..add(quad)
          ..add(ellipse);
        final select = Select.currentSelect;
        select.selectResult = SelectResult(
          pageIndex: 0,
          strokes: [quad],
          images: [],
          path: Path()..addRect(quad.bounds.inflate(12)),
        );
        select.doneSelecting = true;
        editor.currentTool = select;
        page.redrawStrokes();
        tester.element(find.byType(Editor)).markNeedsBuild();
        await tester.pump();
      },
    );

    // E-ink mode next to the normal look, on the same notes: an empty page
    // with the interface, a dense handwritten page, a page with a photo and
    // a PDF page.
    const eInk = EInkStyle();
    for (final (scene, path) in [
      ('blank', '/e-ink bos not'),
      ('handwriting', '/Metric Spaces Week 1'),
      ('photo', '/Annotate images and diagrams'),
      ('pdf', '/Import PDFs'),
    ]) {
      _shot(
        theme: theme,
        name: 'cmp_${scene}_normal',
        child: Editor(path: path),
        afterLoad: (_) async => OpenTabs.reset(),
      );
      _shot(
        theme: theme,
        eInk: eInk,
        name: 'cmp_${scene}_eink',
        child: Editor(path: path),
        afterLoad: (_) async => OpenTabs.reset(),
      );
    }
    _shot(
      theme: theme,
      eInk: eInk,
      name: 'eink_library',
      children: DirectoryChildren(
        ['Projeler', 'Toplantılar'],
        [
          'Annotate images and diagrams',
          'Golden ratio',
          'Import PDFs',
          'Metric Spaces Week 1',
          'You can type notes too!',
          'Coding review 1',
          'HG Week 6',
          'Topology week 1',
        ],
      ),
      child: const HomePage(subpage: HomePage.browseSubpage, path: null),
    );
    _shot(
      theme: theme,
      eInk: eInk,
      name: 'eink_settings',
      child: const HomePage(subpage: HomePage.settingsSubpage, path: null),
      afterLoad: (tester) async {
        // the e-ink section is far down the list
        await tester.ensureVisible(find.text(DefterStrings.eInkSection).first);
        await tester.pump();
      },
    );
    _shot(
      theme: theme,
      eInk: eInk,
      name: 'eink_new_notebook',
      child: const HomePage(subpage: HomePage.recentSubpage, path: null),
      afterLoad: (tester) async {
        NewNotebookDialog.show(tester.element(find.byType(HomePage)));
        await tester.pump();
      },
    );
  });
}

void _shot({
  required ThemeData theme,
  EInkStyle? eInk,
  required String name,
  required Widget child,
  DirectoryChildren? children,
  Future<void> Function(WidgetTester tester)? afterLoad,
}) {
  testGoldens(name, (tester) async {
    BrowsePage.overrideChildren = children;
    addTearDown(() => BrowsePage.overrideChildren = null);
    stows.platform.value = _tablet.platform;
    await tester.runAsync(() => LocaleSettings.setLocaleRaw('tr'));

    if (eInk != null) {
      stows.eInkMode.value = true;
      addTearDown(() => stows.eInkMode.value = false);
      // The paper grain is made before the page is drawn, as it is in the app.
      if (eInk.textureStep > 0) {
        await tester.runAsync(
          () => EInkTexture.load(
            eInk.textureStep,
            maxAlpha: EInkStyle.maxGrainAlpha,
          ),
        );
      }
    }

    final widget = ScreenshotApp.withConditionalTitlebar(
      theme: eInk == null
          ? theme
          : SaberTheme.createEInkTheme(eInk, _tablet.platform),
      device: _tablet,
      title: 'Defter',
      home: TranslationProvider(
        child: eInk == null
            ? child
            : EInkScope(style: eInk, child: child),
      ),
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

    await afterLoad?.call(tester);

    await tester.loadAssets();
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('defter_shots/$name.png'),
    );
  });
}
