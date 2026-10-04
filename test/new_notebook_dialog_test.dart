import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saber/components/home/new_notebook_dialog.dart';
import 'package:saber/data/flavor_config.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/i18n/strings.g.dart';
import 'package:sbn/canvas_background_pattern.dart';

void main() {
  group('NewNotebookDialog', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    FlavorConfig.setup();

    /// Opens the dialog and returns a holder for its eventual result.
    Future<List<String?>> openDialog(WidgetTester tester) async {
      final results = <String?>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  results.add(await NewNotebookDialog.show(context));
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(NewNotebookDialog), findsOneWidget);
      return results;
    }

    setUp(() {
      stows.lastBackgroundPattern.value = CanvasBackgroundPattern.none;
    });

    testWidgets('an empty name is accepted', (tester) async {
      final results = await openDialog(tester);

      await tester.tap(find.text(t.home.newFolder.create));
      await tester.pumpAndSettle();

      expect(find.byType(NewNotebookDialog), findsNothing);
      expect(results, ['']);
    });

    testWidgets('returns the trimmed name', (tester) async {
      final results = await openDialog(tester);

      await tester.enterText(find.byType(TextField), '  Meeting notes ');
      await tester.tap(find.text(t.home.newFolder.create));
      await tester.pumpAndSettle();

      expect(results, ['Meeting notes']);
    });

    testWidgets('rejects names that are not valid file names', (tester) async {
      final results = await openDialog(tester);

      await tester.enterText(find.byType(TextField), 'a/b');
      await tester.tap(find.text(t.home.newFolder.create));
      await tester.pumpAndSettle();

      // Still open, with the error shown.
      expect(find.byType(NewNotebookDialog), findsOneWidget);
      expect(
        find.text(t.home.renameNote.noteNameForbiddenCharacters),
        findsOneWidget,
      );
      expect(results, isEmpty);
    });

    testWidgets('cancel returns null and keeps the last paper', (tester) async {
      final results = await openDialog(tester);

      await tester.tap(find.text(t.common.cancel));
      await tester.pumpAndSettle();

      expect(results, [null]);
      expect(stows.lastBackgroundPattern.value, CanvasBackgroundPattern.none);
    });

    testWidgets('the chosen paper becomes the default for new notes', (
      tester,
    ) async {
      await openDialog(tester);

      // Papers are listed in the order of [NewNotebookDialog.papers];
      // each one is an InkWell inside the horizontal list.
      final paperIndex = NewNotebookDialog.papers.indexOf(
        CanvasBackgroundPattern.grid,
      );
      final papers = find.descendant(
        of: find.byType(ListView),
        matching: find.byType(InkWell),
      );
      await tester.tap(papers.at(paperIndex));
      await tester.pump();

      await tester.tap(find.text(t.home.newFolder.create));
      await tester.pumpAndSettle();

      expect(stows.lastBackgroundPattern.value, CanvasBackgroundPattern.grid);
    });
  });
}
