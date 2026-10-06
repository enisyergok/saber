import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:saber/components/home/preview_card.dart';
import 'package:saber/components/navbar/home_sidebar.dart';
import 'package:saber/components/navbar/vertical_navbar.dart';
import 'package:saber/data/defter_strings.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/flavor_config.dart';
import 'package:saber/data/notebooks/paper_templates.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/routes.dart';
import 'package:saber/i18n/strings.g.dart';
import 'package:saber/pages/home/browse.dart';
import 'package:saber/pages/home/dashboard.dart';
import 'package:saber/pages/home/home.dart';
import 'package:saber/pages/home/new_notebook_wizard.dart';
import 'package:saber/pages/home/template_gallery.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlavorConfig.setup();
  stows.sentryConsent.value = .granted;

  const folders = {
    'Dersler': ['Fizik', 'Kimya'],
    'Projeler': <String>[],
  };

  void tablet(WidgetTester tester, [Size size = const Size(1280, 800)]) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  group('Sidebar', () {
    Future<List<String>> pumpSidebar(
      WidgetTester tester, {
      String subpage = HomePage.dashboardSubpage,
      String? path,
    }) async {
      tablet(tester);
      final went = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                HomeSidebar(
                  subpage: subpage,
                  path: path,
                  go: went.add,
                  loadFolders: () async => folders,
                ),
                const Expanded(child: SizedBox()),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      return went;
    }

    testWidgets('it leads to every part of the home screen', (tester) async {
      final went = await pumpSidebar(tester);
      for (final label in [
        DefterStrings.navHome,
        DefterStrings.navNotes,
        DefterStrings.navRecent,
        DefterStrings.navWhiteboard,
        DefterStrings.navSettings,
      ]) {
        await tester.tap(find.text(label));
      }
      expect(went, [
        RoutePaths.dashboard,
        HomeRoutes.browseFilePath('/'),
        HomeRoutes.routes[1].path,
        HomeRoutes.routes[2].path,
        HomeRoutes.routes[3].path,
      ]);
      // every tab of the classic navigation is still reachable
      expect(went.toSet(), containsAll(HomeRoutes.routes.map((r) => r.path)));
    });

    testWidgets('planners and templates open their galleries', (tester) async {
      await pumpSidebar(tester);
      await tester.tap(find.text(DefterStrings.navPlanners));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TemplateGalleryPage>(find.byType(TemplateGalleryPage)).group,
        PaperGroup.planner,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text(DefterStrings.navTemplates));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TemplateGalleryPage>(find.byType(TemplateGalleryPage)).group,
        isNull,
      );
    });

    testWidgets('folders are listed, open their notes and unfold', (
      tester,
    ) async {
      final went = await pumpSidebar(tester);
      expect(find.text('Dersler'), findsOneWidget);
      expect(find.text('Projeler'), findsOneWidget);
      // what is inside a folder shows when it is unfolded
      expect(find.text('Fizik'), findsNothing);
      await tester.tap(find.byIcon(Symbols.expand_more_rounded));
      await tester.pump();
      expect(find.text('Fizik'), findsOneWidget);

      await tester.tap(find.text('Projeler'));
      await tester.tap(find.text('Kimya'));
      expect(went, [
        HomeRoutes.browseFilePath('/Projeler'),
        HomeRoutes.browseFilePath('/Dersler/Kimya'),
      ]);

      // the whole list folds away
      await tester.tap(find.byTooltip(DefterStrings.folders));
      await tester.pump();
      expect(find.text('Dersler'), findsNothing);
    });

    testWidgets('a new folder needs a name that is free', (tester) async {
      await pumpSidebar(tester);
      await tester.tap(find.text(DefterStrings.newFolder));
      await tester.pumpAndSettle();
      expect(find.byType(NewFolderNameDialog), findsOneWidget);

      await tester.enterText(find.byType(TextField), ' Dersler ');
      await tester.tap(find.text(DefterStrings.stepCreate));
      await tester.pump();
      expect(find.text(DefterStrings.folderNameExists), findsOneWidget);
      expect(find.byType(NewFolderNameDialog), findsOneWidget);

      await tester.tap(find.text(DefterStrings.cancelWord));
      await tester.pumpAndSettle();
      expect(find.byType(NewFolderNameDialog), findsNothing);
    });

    test('folder names are checked', () {
      const existing = {'Dersler'};
      expect(NewFolderNameDialog.validate('  ', existing), isNotNull);
      expect(NewFolderNameDialog.validate('a/b', existing), isNotNull);
      expect(NewFolderNameDialog.validate(r'a\b', existing), isNotNull);
      expect(NewFolderNameDialog.validate('Dersler', existing), isNotNull);
      expect(NewFolderNameDialog.validate('Arşiv', existing), isNull);
    });

    test('a folder always has the same colour', () {
      expect(folderColour('/Dersler'), folderColour('/Dersler'));
      final colours = {
        for (final name in ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j'])
          folderColour('/$name'),
      };
      expect(colours.length, greaterThan(3));
    });
  });

  group('Home screen', () {
    tearDown(() {
      DashboardPage.overrideData = null;
      HomeSidebar.overrideFolders = null;
      BrowsePage.overrideChildren = null;
      stows.homeDashboard.value = true;
      stows.layoutSize.value = .auto;
    });

    /// The home screen inside a router that remembers where it went.
    Future<GoRouter> pumpHome(
      WidgetTester tester, {
      String subpage = HomePage.dashboardSubpage,
      Size screen = const Size(1280, 800),
    }) async {
      tablet(tester, screen);
      DashboardPage.overrideData = const DashboardData(
        recent: [],
        folders: {'Dersler': 12, 'Projeler': 0},
      );
      HomeSidebar.overrideFolders = folders;
      // Real directory listings don't complete inside a widget test.
      BrowsePage.overrideChildren = DirectoryChildren(
        const ['Fizik', 'Kimya'],
        const [],
      );
      final router = GoRouter(
        initialLocation: '${RoutePaths.prefixOfHome}/$subpage',
        routes: [
          GoRoute(
            path: RoutePaths.home,
            builder: (context, state) => HomePage(
              subpage: state.pathParameters['subpage']!,
              path: state.uri.queryParameters['path'],
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        TranslationProvider(child: MaterialApp.router(routerConfig: router)),
      );
      await tester.pump();
      await tester.pump();
      return router;
    }

    testWidgets('a tablet opens on the home screen with its sidebar', (
      tester,
    ) async {
      await pumpHome(tester);
      expect(find.byType(DashboardPage), findsOneWidget);
      expect(find.byType(HomeSidebar), findsOneWidget);
      expect(find.byType(VerticalNavbar), findsNothing);
      expect(find.text(DefterStrings.heroTitle), findsOneWidget);
      for (final label in [
        DefterStrings.actionNewNote,
        DefterStrings.actionFromTemplate,
        DefterStrings.actionImportPdf,
        DefterStrings.actionAddImage,
        DefterStrings.actionNewFolder,
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      // folders with how much is in each
      expect(find.text(DefterStrings.itemCount(12)), findsOneWidget);
      expect(find.text(DefterStrings.itemCount(0)), findsOneWidget);
      // nothing opened yet: a way to begin instead of an empty row
      expect(find.text(DefterStrings.noRecentNotes), findsOneWidget);
      expect(find.byType(PreviewCard), findsNothing);
    });

    testWidgets('a folder card opens the folder', (tester) async {
      final router = await pumpHome(tester);
      // the card, not the sidebar entry of the same name
      await tester.tap(find.text('Dersler').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(BrowsePage), findsOneWidget);
      expect(
        router.routerDelegate.currentConfiguration.uri.toString(),
        HomeRoutes.browseFilePath('/Dersler'),
      );
    });

    testWidgets('new note opens the wizard, a template chip its gallery', (
      tester,
    ) async {
      // tall enough that nothing has to be scrolled to
      await pumpHome(tester, screen: const Size(1280, 1800));
      expect(find.text(DefterStrings.actionNewNote), findsOneWidget);
      await tester.tap(find.text(DefterStrings.actionNewNote));
      await tester.pumpAndSettle();
      expect(find.byType(NewNotebookWizard), findsOneWidget);
      expect(
        find.text(DefterStrings.cancelWord),
        findsOneWidget,
        reason: 'the wizard can be left',
      );
      await tester.tap(find.text(DefterStrings.cancelWord));
      await tester.pumpAndSettle();
      expect(find.byType(NewNotebookWizard), findsNothing);

      final chip = find.widgetWithText(
        ActionChip,
        PaperGroup.engineering.label,
      );
      expect(chip, findsOneWidget, reason: 'the kinds of templates are listed');
      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(find.byType(TemplateGalleryPage), findsOneWidget);
      expect(
        tester.widget<TemplateGalleryPage>(find.byType(TemplateGalleryPage)).group,
        PaperGroup.engineering,
      );
    });

    testWidgets('the sidebar stays when another part is open', (tester) async {
      final router = await pumpHome(tester, subpage: HomePage.browseSubpage);
      expect(find.byType(HomeSidebar), findsOneWidget);
      expect(find.byType(DashboardPage), findsNothing);
      expect(find.byType(BrowsePage), findsOneWidget);
      await tester.tap(find.text(DefterStrings.navHome));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(DashboardPage), findsOneWidget);
      expect(
        router.routerDelegate.currentConfiguration.uri.toString(),
        RoutePaths.dashboard,
      );
    });

    testWidgets('switched off, the classic home screen is back', (tester) async {
      stows.homeDashboard.value = false;
      await pumpHome(tester);
      expect(find.byType(HomeSidebar), findsNothing);
      expect(find.byType(DashboardPage), findsNothing);
      expect(find.byType(BrowsePage), findsOneWidget);
      expect(find.byType(VerticalNavbar), findsOneWidget);
    });

    testWidgets('a phone keeps its bottom bar and shows the notes', (
      tester,
    ) async {
      await pumpHome(tester, screen: const Size(390, 800));
      expect(find.byType(HomeSidebar), findsNothing);
      expect(find.byType(DashboardPage), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  test('the home screen has an address of its own', () {
    expect(RoutePaths.dashboard, '/home/dashboard');
    expect(HomePage.subpages, isNot(contains(HomePage.dashboardSubpage)));
    expect(
      RoutePaths.editWithImage('/Not', '/tmp/a b.png'),
      '/edit?path=%2FNot&imagePath=%2Ftmp%2Fa+b.png',
    );
  });
}
