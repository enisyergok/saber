import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_screenshot/golden_screenshot.dart';
import 'package:saber/components/editor_gn/gn_bar.dart';
import 'package:saber/components/editor_gn/gn_pen_settings.dart';
import 'package:saber/components/home/noteva_library.dart';
import 'package:saber/components/settings/settings_sections.dart';
import 'package:saber/components/settings/settings_subtitle.dart';
import 'package:saber/components/theming/saber_theme.dart';
import 'package:saber/data/defter_strings.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/flavor_config.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/tools/pen.dart';
import 'package:saber/data/tools/highlighter.dart';
import 'package:saber/i18n/strings.g.dart';
import 'package:saber/pages/editor/editor.dart';
import 'package:saber/pages/home/dashboard.dart';
import 'package:saber/pages/home/home.dart';
import 'package:saber/components/navbar/home_sidebar.dart';
import 'package:saber/pages/home/template_gallery.dart';
import 'package:saber/pages/home/settings.dart';
import 'package:saber/pages/home/new_notebook_wizard.dart';
import 'package:saber/pages/favorites.dart';
import 'package:saber/pages/search.dart';
import 'package:saber/pages/trash.dart';
import 'package:saber/components/home/library_sidebar.dart';

import 'utils/test_mock_channel_handlers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    setupMockPathProvider();
    setupMockPrinting();
    setupMockWindowManager();
    FlavorConfig.setup();
    await FileManager.init();
    stows.editorGnLayout.value = true;
    stows.editorFloatingBar.value = false;
    stows.homeDashboard.value = true;
    // Each editor starts from a known tool, not the previous test's choice.
    stows.lastTool.value = .fountainPen;
    stows.lastPenVariant.value = 0;
  });

  Future<void> pump(
    WidgetTester tester,
    Size size,
    Widget page, {
    bool dark = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          theme: SaberTheme.createThemeFromSeed(
            const Color(0xFF2949AE),
            dark ? Brightness.dark : Brightness.light,
            TargetPlatform.android,
          ),
          home: page,
        ),
      ),
    );
    await tester.loadAssets();
    await tester.pump();
    await tester.pump();
  }

  // Optional review captures, not baseline assertions. CI uploads these for
  // visual review; the behavior/overflow checks below always run.
  Future<void> capture(WidgetTester tester, String name) async {
    if (!const bool.fromEnvironment('CAPTURE_UI')) return;
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/redesign/$name.png'),
    );
  }

  test('interface upgrade runs once and preserves later choices', () async {
    stows.interfaceRevision.value = 0;
    stows.editorGnLayout.value = false;
    stows.editorFloatingBar.value = true;
    stows.homeDashboard.value = false;
    await stows.migrateInterface();
    expect(stows.editorGnLayout.value, isTrue);
    expect(stows.editorFloatingBar.value, isFalse);
    expect(stows.homeDashboard.value, isTrue);
    stows.editorFloatingBar.value = true;
    await stows.migrateInterface();
    expect(stows.editorFloatingBar.value, isTrue);
  });

  for (final (name, size) in [
    ('phone', const Size(390, 844)),
    ('tablet', const Size(1280, 800)),
  ]) {
    for (final (screen, page) in <(String, Widget)>[
      ('favorites', const FavoritesPage()),
      ('search', const SearchPage(refreshIndex: false)),
      ('trash', const TrashPage()),
    ]) {
      testWidgets('$screen $name retains library navigation and fits', (
        tester,
      ) async {
        await pump(tester, size, page);
        await tester.pumpAndSettle();
        expect(
          find.byType(LibrarySidebar),
          size.width >= 700 ? findsOneWidget : findsNothing,
        );
        expect(tester.takeException(), isNull);
        await capture(tester, '${screen}_$name');
      });
    }
    testWidgets('real home entry $name matches the approved light library', (
      tester,
    ) async {
      stows.sentryConsent.value = .granted;
      DashboardPage.overrideData = DashboardData(
        documents: [
          LibraryDocument(
            id: '/one',
            title: 'Adsız Not Defteri (1)',
            subtitle: 'Bugün, 12:30',
            modified: DateTime(2026, 10, 19, 12, 30),
          ),
          LibraryDocument(
            id: '/two',
            title: 'Adsız Not Defteri',
            subtitle: 'Bugün, 10:51',
            modified: DateTime(2026, 10, 19, 10, 51),
          ),
          const LibraryDocument(
            id: '/folder',
            title: 'Adsız',
            subtitle: '21.09.2023, 16:39',
            folder: true,
          ),
        ],
      );
      addTearDown(() => DashboardPage.overrideData = null);
      await pump(
        tester,
        size,
        const HomePage(subpage: HomePage.dashboardSubpage, path: null),
        dark: true,
      );
      expect(find.byType(NotevaLibrary), findsOneWidget);
      expect(find.byType(HomeSidebar), findsNothing);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(ActionChip), findsNothing);
      expect(find.byKey(const Key('libraryTitle')), findsOneWidget);
      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(NotevaLibrary),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(material.color, Colors.white);
      expect(tester.takeException(), isNull);
      await capture(tester, 'real_home_$name');
    });

    testWidgets('library $name has search and functional create menu', (
      tester,
    ) async {
      await pump(
        tester,
        size,
        DashboardPage(
          load: () async => const DashboardData(
            folders: {'Dersler': 12, 'Projeler': 4, 'Kisisel': 2},
          ),
        ),
      );
      expect(find.byType(NotevaLibrary), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(find.byTooltip('Görünümü değiştir'), findsOneWidget);
      await capture(tester, 'library_$name');
      await tester.tap(find.byKey(const Key('libraryCreateMenu')));
      await tester.pumpAndSettle();
      expect(find.byType(NewNotebookWizard), findsNothing);
      await tester.tap(
        find.widgetWithText(PopupMenuItem<String>, DefterStrings.actionNewNote),
      );
      await tester.pumpAndSettle();
      expect(find.byType(NewNotebookWizard), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'fixed editor $name exposes drawing tools and fits the screen',
      (tester) async {
        await pump(tester, size, Editor());
        final editor = tester.state<EditorState>(find.byType(Editor));
        addTearDown(editor.cancelAutosaveAndMarkSaved);
        expect(find.byType(GnEditorBar), findsOneWidget);
        expect(tester.takeException(), isNull);
        await capture(tester, 'editor_$name');
        final highlighter = find.byTooltip(t.editor.pens.highlighter);
        await tester.ensureVisible(highlighter);
        await tester.tap(highlighter);
        await tester.pump();
        expect(editor.currentTool, isA<Highlighter>());
        await tester.tap(highlighter);
        await tester.pumpAndSettle();
        expect(find.byType(GnPenSettings), findsOneWidget);
        expect(tester.takeException(), isNull);
        await capture(tester, 'tool_menu_$name');
        // Tapping the selected tool again closes its settings.
        await tester.tap(highlighter);
        await tester.pumpAndSettle();
        expect(find.byType(GnPenSettings), findsNothing);
      },
    );

    testWidgets('template gallery $name stays within its viewport', (
      tester,
    ) async {
      await pump(tester, size, const TemplateGalleryPage());
      expect(tester.takeException(), isNull);
      await capture(tester, 'templates_$name');
    });
  }

  testWidgets('settings categories switch the visible section', (tester) async {
    await pump(
      tester,
      const Size(1280, 800),
      const Scaffold(
        body: SettingsSections(
          title: 'Ayarlar',
          children: [
            SettingsSubtitle(subtitle: 'Genel'),
            ListTile(title: Text('Tema')),
            SettingsSubtitle(subtitle: 'Kalem'),
            ListTile(title: Text('Basinc')),
          ],
        ),
      ),
    );
    expect(find.text('Tema'), findsOneWidget);
    expect(find.text('Basinc'), findsNothing);
    await tester.tap(find.widgetWithText(ListTile, 'Kalem'));
    await tester.pumpAndSettle();
    expect(find.text('Tema'), findsNothing);
    expect(find.text('Basinc'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await capture(tester, 'settings_tablet');
  });

  testWidgets('dark pen settings fit a phone', (tester) async {
    Pen pen = Pen.fountainPen();
    await pump(
      tester,
      const Size(390, 844),
      Scaffold(
        body: Align(
          alignment: Alignment.topCenter,
          child: GnPenSettings(
            getTool: () => pen,
            setTool: (value) => pen = value,
          ),
        ),
      ),
      dark: true,
    );
    expect(tester.takeException(), isNull);
    await capture(tester, 'pen_dark_phone');
  });

  for (final (name, size) in [
    ('phone', const Size(390, 844)),
    ('tablet', const Size(1280, 800)),
  ]) {
    testWidgets('actual settings $name has grouped categories', (tester) async {
      await pump(tester, size, const SettingsPage());
      expect(find.byType(SettingsSections), findsOneWidget);
      expect(tester.takeException(), isNull);
      await capture(tester, 'settings_full_$name');
    });

    testWidgets('new notebook $name exposes labeled creation stages', (
      tester,
    ) async {
      await pump(
        tester,
        size,
        Scaffold(
          body: NewNotebookWizard(
            loadFolders: () async => const ['/Dersler', '/Projeler'],
          ),
        ),
      );
      expect(find.text(DefterStrings.wizardTitle), findsOneWidget);
      expect(tester.takeException(), isNull);
      await capture(tester, 'new_notebook_$name');
    });
  }
}
