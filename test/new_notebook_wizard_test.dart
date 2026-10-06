import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:saber/components/home/paper_thumb.dart';
import 'package:saber/data/covers/cover_designs.dart';
import 'package:saber/data/defter_strings.dart';
import 'package:saber/data/flavor_config.dart';
import 'package:saber/data/notebooks/notebook_spec.dart';
import 'package:saber/data/notebooks/paper_templates.dart';
import 'package:saber/pages/home/new_notebook_wizard.dart';
import 'package:saber/pages/home/template_gallery.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlavorConfig.setup();

  /// Opens the wizard on a tablet-sized screen; the list fills with what
  /// it returns when it closes.
  Future<List<NotebookSpec?>> openWizard(
    WidgetTester tester, {
    NotebookSpec? initial,
    int startAt = 0,
    Size screen = const Size(1280, 800),
  }) async {
    tester.view.physicalSize = screen;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final results = <NotebookSpec?>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                results.add(
                  await showDialog<NotebookSpec>(
                    context: context,
                    builder: (context) => NewNotebookWizard(
                      initial: initial,
                      startAt: startAt,
                      loadFolders: () async => const [
                        '/Dersler',
                        '/Dersler/Fizik',
                        '/Projeler',
                      ],
                    ),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(NewNotebookWizard), findsOneWidget);
    return results;
  }

  Future<void> next(WidgetTester tester) async {
    await tester.tap(find.text(DefterStrings.next));
    await tester.pumpAndSettle();
  }

  testWidgets('the six steps make a notebook as it was chosen', (tester) async {
    final results = await openWizard(tester);

    // 1: the paper, from the planner tab
    await tester.tap(find.widgetWithText(ChoiceChip, PaperGroup.planner.label));
    await tester.pumpAndSettle();
    final gantt = PaperTemplates.byId('gantt');
    expect(find.text(gantt.name), findsOneWidget);
    expect(find.text(PaperTemplates.byId('circuit').name), findsNothing);
    await tester.tap(find.text(gantt.name));
    await tester.pump();
    await next(tester);

    // 2: the cover, from the classic tab
    expect(find.text(DefterStrings.coverDesign), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, DefterStrings.coverClassic));
    await tester.pumpAndSettle();
    final leather = CoverDesigns.byId('c-navy')!;
    await tester.tap(find.byTooltip(leather.name));
    await tester.pump();
    await next(tester);

    // 3: A5, landscape, cream paper
    await tester.tap(find.text('A5'));
    await tester.tap(find.text(DefterStrings.orientationLandscape));
    await tester.pump();
    expect(find.text('210 × 148 mm'), findsOneWidget);
    await tester.tap(find.text(DefterStrings.colourCream));
    await tester.pump();
    await next(tester);

    // 4: the name
    await tester.enterText(find.byType(TextField), '  Proje planı ');
    await next(tester);

    // 5: the folder
    expect(find.text('Fizik'), findsOneWidget);
    await tester.tap(find.text('Projeler'));
    await tester.pump();
    await next(tester);

    // 6: a last look, then make it
    expect(find.text(gantt.name), findsOneWidget);
    expect(find.text(leather.name), findsOneWidget);
    expect(find.text('Proje planı'), findsOneWidget);
    expect(find.text('/Projeler'), findsOneWidget);
    expect(find.text(DefterStrings.next), findsNothing);
    await tester.tap(find.byIcon(Symbols.check_rounded));
    await tester.pumpAndSettle();

    expect(find.byType(NewNotebookWizard), findsNothing);
    final spec = results.single!;
    expect(spec.template.id, 'gantt');
    expect(spec.cover?.id, 'c-navy');
    expect(spec.format, PaperFormat.a5);
    expect(spec.landscape, isTrue);
    expect(spec.paperColor, const Color(0xFFFFF8E7));
    expect(spec.name, 'Proje planı');
    expect(spec.folder, '/Projeler');
    expect(spec.folderPrefix, '/Projeler/');
  });

  testWidgets('a notebook can be made at once, with the defaults', (
    tester,
  ) async {
    final results = await openWizard(tester);
    // the button comes after the step of the same name at the side
    await tester.tap(find.text(DefterStrings.stepCreate).last);
    await tester.pumpAndSettle();

    final spec = results.single!;
    expect(spec.template.id, 'blank');
    expect(spec.cover, isNull);
    expect(spec.format, PaperFormat.standard);
    expect(spec.name, isEmpty);
    expect(spec.folder, '/');
  });

  testWidgets('a name that cannot be a file name is not accepted', (
    tester,
  ) async {
    final results = await openWizard(tester, startAt: 3);
    await tester.enterText(find.byType(TextField), 'a/b');
    await next(tester);
    // still on the name, with the reason shown
    expect(find.byType(TextField), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).decoration?.errorText,
      isNotNull,
    );

    // nor from the last step: making it comes back to the name
    await tester.enterText(find.byType(TextField), 'Tamam');
    await tester.pump();
    await next(tester);
    await next(tester);
    await tester.tap(find.text(DefterStrings.back));
    await tester.pumpAndSettle();
    await tester.tap(find.text(DefterStrings.back));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'x/y');
    // the button comes after the step of the same name at the side
    await tester.tap(find.text(DefterStrings.stepCreate).last);
    await tester.pumpAndSettle();
    expect(find.byType(NewNotebookWizard), findsOneWidget);
    expect(results, isEmpty);
  });

  testWidgets('cancelling makes nothing', (tester) async {
    final results = await openWizard(tester);
    await tester.tap(find.text(DefterStrings.cancelWord));
    await tester.pumpAndSettle();
    expect(results, [null]);
  });

  testWidgets('it opens with what was already chosen', (tester) async {
    final results = await openWizard(
      tester,
      initial: NotebookSpec(
        folder: '/Dersler',
        template: PaperTemplates.byId('circuit'),
      ),
      startAt: 1,
    );
    // on the cover step
    expect(find.text(DefterStrings.coverDesign), findsOneWidget);
    // the button comes after the step of the same name at the side
    await tester.tap(find.text(DefterStrings.stepCreate).last);
    await tester.pumpAndSettle();
    final spec = results.single!;
    expect(spec.template.id, 'circuit');
    expect(spec.folder, '/Dersler');
  });

  testWidgets('the steps at the side jump straight to a step', (tester) async {
    await openWizard(tester);
    await tester.tap(find.text(DefterStrings.stepFolder));
    await tester.pumpAndSettle();
    expect(find.text(DefterStrings.rootFolder), findsOneWidget);
    await tester.tap(find.text(DefterStrings.stepSize).first);
    await tester.pumpAndSettle();
    expect(find.text('A4'), findsOneWidget);
    expect(find.text('B5'), findsOneWidget);
  });

  testWidgets('it fits a phone', (tester) async {
    await openWizard(tester, screen: const Size(390, 800));
    expect(tester.takeException(), isNull);
    for (var i = 0; i < 5; i++) {
      await next(tester);
      expect(tester.takeException(), isNull, reason: 'step ${i + 2}');
    }
  });

  testWidgets('a gallery shows one kind of paper by topic', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        home: TemplateGalleryPage(group: PaperGroup.engineering),
      ),
    );
    expect(
      find.text(DefterStrings.templatesOf(PaperGroup.engineering.label)),
      findsOneWidget,
    );
    final all = PaperTemplates.inGroup(PaperGroup.engineering).length;
    expect(find.byType(PaperThumb), findsNWidgets(all));

    await tester.tap(
      find.widgetWithText(ChoiceChip, PaperTopic.electronics.label),
    );
    await tester.pumpAndSettle();
    final electronics = PaperTemplates.about(
      PaperGroup.engineering,
      PaperTopic.electronics,
    );
    expect(find.byType(PaperThumb), findsNWidgets(electronics.length));
    expect(find.text(PaperTemplates.byId('pcb').name), findsOneWidget);
    expect(find.text(PaperTemplates.byId('millimetre').name), findsNothing);
  });

  testWidgets('the gallery of everything has a tab for each kind', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: TemplateGalleryPage()));
    expect(find.text(DefterStrings.navTemplates), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, PaperGroup.diagram.label));
    await tester.pumpAndSettle();
    // the kind's topics appear as a second row
    expect(
      find.widgetWithText(ChoiceChip, PaperTopic.mindMap.label),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(ChoiceChip, PaperTopic.mindMap.label));
    await tester.pumpAndSettle();
    expect(
      find.byType(PaperThumb),
      findsNWidgets(
        PaperTemplates.about(PaperGroup.diagram, PaperTopic.mindMap).length,
      ),
    );
  });
}
