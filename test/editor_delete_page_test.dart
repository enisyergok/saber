import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_screenshot/golden_screenshot.dart';
import 'package:saber/components/canvas/_stroke.dart';
import 'package:saber/components/editor/page_menu.dart';
import 'package:saber/components/editor/page_sidebar.dart';
import 'package:saber/components/toolbar/editor_page_grid.dart';
import 'package:saber/data/defter_strings.dart';
import 'package:saber/data/editor/editor_core_info.dart';
import 'package:saber/data/editor/editor_history.dart';
import 'package:saber/data/editor/page.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/flavor_config.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/tools/pen.dart';
import 'package:saber/data/versions/note_versions.dart';
import 'package:saber/i18n/strings.g.dart';
import 'package:saber/pages/editor/editor.dart';

import 'utils/test_mock_channel_handlers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupMockPathProvider();
  FlavorConfig.setup();

  group('Pages of a notebook in the editor:', () {
    late Directory temp;

    setUp(() {
      temp = Directory.systemTemp.createTempSync('delete_page_test');
      Directory('${temp.path}/docs').createSync();
      NoteVersions.rootOverride = Directory('${temp.path}/versions');
    });
    tearDown(() {
      NoteVersions.rootOverride = null;
      temp.deleteSync(recursive: true);
    });

    Future<EditorState> openEditor(WidgetTester tester, String path) async {
      setupMockPrinting();
      setupMockWindowManager();
      stows.editorGnLayout.value = false;
      stows.autosaveDelay.value = -1;
      stows.shapeHoldToSnap.value = false;
      stows.penPrediction.value = false;
      addTearDown(() {
        stows.autosaveDelay.value = stows.autosaveDelay.defaultValue;
        stows.shapeHoldToSnap.value = true;
        stows.penPrediction.value = true;
      });
      await tester.runAsync(
        () => FileManager.init(
          documentsDirectory: '${temp.path}/docs',
          shouldWatchRootDirectory: false,
        ),
      );
      await tester.pumpWidget(
        TranslationProvider(
          child: ScreenshotApp(
            device: GoldenScreenshotDevices.androidPhone.device,
            home: Editor(path: path),
          ),
        ),
      );
      final editor = tester.state<EditorState>(find.byType(Editor));
      addTearDown(editor.cancelAutosaveAndMarkSaved);
      for (var i = 0; i < 100 && editor.coreInfo.filePath != path; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();
      }
      expect(editor.coreInfo.filePath, path);
      return editor;
    }

    /// Writes a line on page [pageIndex], [y] down the page.
    Stroke write(EditorState editor, int pageIndex, {double y = 200}) {
      final pen = Pen.fountainPen();
      editor.currentTool = pen;
      editor.createPage(pageIndex - 1);
      final page = editor.coreInfo.pages[pageIndex];
      editor.dragPageIndex = pageIndex;
      pen.onDragStart(Offset(100, y), page, pageIndex, 0.5);
      for (var x = 120.0; x <= 400; x += 20) {
        pen.onDragUpdate(Offset(x, y), 0.5);
      }
      editor.onDrawEnd(ScaleEndDetails());
      return page.strokes.last;
    }

    /// Lets the "page deleted" message go, so no timer outlives the test.
    Future<void> letMessagesGo(WidgetTester tester) async {
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 1));
    }

    testGoldens('a page is taken out, with what is on it; the pages after '
        'it move up; undo puts it back', (tester) async {
      final editor = await openEditor(tester, '/Sayfalar');
      final first = write(editor, 0);
      final second = write(editor, 1);
      final third = write(editor, 2);
      await tester.pump();
      final pages = editor.coreInfo.pages;
      expect(pages.length, 4, reason: 'three written pages and an empty one');
      final secondPage = pages[1], thirdPage = pages[2];

      expect(editor.canDeletePage(1), isTrue);
      editor.deletePage(1);
      await tester.pump();

      expect(pages.length, 3);
      expect(pages, isNot(contains(secondPage)));
      expect(pages[1], same(thirdPage));
      expect(pages[0].strokes, [first]);
      expect(pages[1].strokes, [third]);
      // Every stroke knows the page it is on now
      expect(first.pageIndex, 0);
      expect(third.pageIndex, 1);
      expect(find.byKey(const ValueKey('pageDeleted')), findsOneWidget);
      expect(find.text(DefterStrings.pageDeleted(2)), findsOneWidget);

      // What is rubbed out on a page that moved comes back on that page
      pages[1].strokes.remove(third);
      editor.history.recordChange(
        EditorHistoryItem(
          type: .erase,
          pageIndex: 1,
          strokes: [third],
          images: const [],
        ),
      );
      editor.undo();
      await tester.pump();
      expect(pages[1].strokes, [third]);
      expect(pages[0].strokes, [first]);

      // Undo: the page is back where it was, with its line
      editor.undo();
      await tester.pump();
      expect(pages.length, 4);
      expect(pages[1], same(secondPage));
      expect(pages[1].strokes, [second]);
      expect(pages[2], same(thirdPage));
      expect(second.pageIndex, 1);
      expect(third.pageIndex, 2);

      // Redo: gone again
      editor.redo();
      await tester.pump();
      expect(pages.length, 3);
      expect(pages[1], same(thirdPage));
      expect(third.pageIndex, 1);

      await letMessagesGo(tester);
    });

    testGoldens('the message offers to undo', (tester) async {
      final editor = await openEditor(tester, '/Geri al');
      write(editor, 0);
      write(editor, 1);
      await tester.pump();
      final pages = editor.coreInfo.pages;
      final secondPage = pages[1];

      editor.deletePage(1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      expect(pages, isNot(contains(secondPage)));

      await tester.tap(find.text(DefterStrings.undoAction));
      await tester.pump();
      expect(pages[1], same(secondPage));

      await letMessagesGo(tester);
    });

    testGoldens('pages that were added and left empty can be deleted, down '
        'to the one page a notebook keeps', (tester) async {
      final editor = await openEditor(tester, '/Boş sayfalar');
      write(editor, 0);
      await tester.pump();
      final pages = editor.coreInfo.pages;
      // Three pages are added with the "+" of the bar
      editor.insertPageAfter(0);
      editor.insertPageAfter(1);
      editor.insertPageAfter(2);
      await tester.pump();
      expect(pages.length, 5);

      // ... and deleted again, the last one too
      for (var i = pages.length - 1; i >= 1; i--) {
        expect(editor.canDeletePage(i), isTrue, reason: 'page ${i + 1}');
        editor.deletePage(i);
        await tester.pump();
      }
      expect(pages.length, 1);
      expect(pages.single.strokes, hasLength(1));

      // The page that is left can go as well: an empty page takes its place
      expect(editor.canDeletePage(0), isTrue);
      editor.deletePage(0);
      await tester.pump();
      expect(pages.length, 1);
      expect(pages.single.isEmpty, isTrue);
      // ... and that one stays
      expect(editor.canDeletePage(0), isFalse);
      editor.deletePage(0);
      await tester.pump();
      expect(pages.length, 1);

      // Writing on the last page gives the notebook its next page again
      write(editor, 0);
      await tester.pump();
      expect(pages.length, 2);
      expect(pages.last.isEmpty, isTrue);

      await letMessagesGo(tester);
    });

    testGoldens('a page is copied after itself, and undo takes the copy',
        (tester) async {
      final editor = await openEditor(tester, '/Kopya');
      final line = write(editor, 0);
      final after = write(editor, 1);
      await tester.pump();
      final pages = editor.coreInfo.pages;
      final original = pages[0], next = pages[1];

      editor.duplicatePage(0);
      await tester.pump();
      expect(pages.length, 4);
      expect(pages[0], same(original));
      expect(pages[2], same(next));
      final copy = pages[1];
      expect(copy.strokes, hasLength(1));
      expect(copy.strokes.single, isNot(same(line)));
      expect(copy.strokes.single.pageIndex, 1);
      expect(line.pageIndex, 0);
      expect(after.pageIndex, 2);

      editor.undo();
      await tester.pump();
      expect(pages.length, 3);
      expect(pages[0], same(original));
      expect(pages[0].strokes, [line]);
      expect(pages[1], same(next));
      expect(after.pageIndex, 1);
    });

    testGoldens('a deleted page is gone from the saved note', (tester) async {
      const path = '/Kaydedilen';
      final editor = await openEditor(tester, path);
      write(editor, 0, y: 100);
      write(editor, 1, y: 300);
      write(editor, 2, y: 500);
      await tester.pump();

      editor.deletePage(1);
      await tester.pump();
      await tester.runAsync(
        () => editor.saveToFile().timeout(const Duration(seconds: 60)),
      );
      await tester.pump();
      expect(editor.savingState.value, SavingState.saved);

      final saved = (await tester.runAsync(
        () => EditorCoreInfo.loadFromFilePath(path),
      ))!;
      addTearDown(saved.dispose);
      final written = saved.pages.where((page) => page.isNotEmpty).toList();
      expect(written.length, 2);
      expect(written[0].strokes.single.pointOffsets.first.dy, 100);
      expect(written[1].strokes.single.pointOffsets.first.dy, 500);

      await letMessagesGo(tester);
    });
  });

  group('The page menu:', () {
    EditorCoreInfo notebook(int pages) {
      final info = EditorCoreInfo(filePath: '/Defter');
      for (var i = 0; i < pages; i++) {
        info.pages.add(EditorPage(size: const Size(1000, 1400)));
      }
      return info;
    }

    testWidgets('every page in the strip beside the editor has one', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final info = notebook(3);
      addTearDown(info.dispose);
      final asked = <(int, PageAction)>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                PageSidebar(
                  coreInfo: info,
                  currentPage: ValueNotifier(0),
                  onPageSelected: (_) {},
                  onPageAction: (page, action) => asked.add((page, action)),
                  canDeletePage: (_) => true,
                ),
                const Expanded(child: SizedBox()),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      for (var i = 0; i < 3; i++) {
        expect(find.byKey(PageMenuButton.keyFor(i)), findsOneWidget);
      }

      await tester.tap(find.byKey(PageMenuButton.keyFor(1)));
      await tester.pumpAndSettle();
      expect(find.text(DefterStrings.duplicatePage), findsOneWidget);
      await tester.tap(find.byKey(PageMenuButton.deleteKey));
      await tester.pumpAndSettle();
      expect(asked, [(1, PageAction.delete)]);

      await tester.tap(find.byKey(PageMenuButton.keyFor(2)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(PageMenuButton.duplicateKey));
      await tester.pumpAndSettle();
      expect(asked.last, (2, PageAction.duplicate));
    });

    testWidgets('a note that cannot be changed has none', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final info = notebook(2);
      addTearDown(info.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                PageSidebar(
                  coreInfo: info,
                  currentPage: ValueNotifier(0),
                  onPageSelected: (_) {},
                ),
                const Expanded(child: SizedBox()),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(PageMenuButton), findsNothing);
    });

    testWidgets('the page that cannot be deleted says so', (tester) async {
      final asked = <PageAction>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: PageMenuButton(
                pageIndex: 0,
                canDelete: false,
                onAction: asked.add,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(PageMenuButton.keyFor(0)));
      await tester.pumpAndSettle();
      final item = tester.widget<PopupMenuItem<PageAction>>(
        find.byKey(PageMenuButton.deleteKey),
      );
      expect(item.enabled, isFalse);
      await tester.tap(find.byKey(PageMenuButton.deleteKey));
      await tester.pumpAndSettle();
      expect(asked, isEmpty);
    });

    testWidgets('the page overview deletes a page and shows what is left', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final info = notebook(3);
      addTearDown(info.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditorPageGrid(
              coreInfo: info,
              currentPageIndex: 0,
              onPageSelected: (_) {},
              toggleBookmark: (_) {},
              openPageManager: () {},
              canDeletePage: (_) => true,
              onPageAction: (page, action) {
                if (action == PageAction.delete) {
                  info.pages.removeAt(page).dispose();
                }
              },
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(PageMenuButton), findsNWidgets(3));

      await tester.tap(find.byKey(PageMenuButton.keyFor(2)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(PageMenuButton.deleteKey));
      await tester.pumpAndSettle();

      expect(info.pages.length, 2);
      expect(find.byType(PageMenuButton), findsNWidgets(2));
      expect(find.byKey(PageMenuButton.keyFor(2)), findsNothing);
    });
  });
}
