import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_screenshot/golden_screenshot.dart';
import 'package:saber/data/editor/page.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/flavor_config.dart';
import 'package:saber/data/notebooks/notebook_spec.dart';
import 'package:saber/data/notebooks/paper_templates.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/i18n/strings.g.dart';
import 'package:saber/pages/editor/editor.dart';
import 'package:sbn/canvas_background_pattern.dart';

import 'utils/test_editor.dart';
import 'utils/test_mock_channel_handlers.dart';

void main() {
  testGoldens('Editor: a notebook made in the new notebook screen', (
    tester,
  ) async {
    TestWidgetsFlutterBinding.ensureInitialized();

    setupMockPathProvider();
    setupMockPrinting();

    FlavorConfig.setup();
    stows.editorGnLayout.value = false;
    final paper = stows.lastBackgroundPattern.value;
    final spacing = stows.lastLineHeight.value;
    addTearDown(() {
      stows.lastBackgroundPattern.value = paper;
      stows.lastLineHeight.value = spacing;
    });
    await tester.runAsync(FileManager.init);

    await tester.pumpWidget(
      TranslationProvider(
        child: ScreenshotApp(
          device: GoldenScreenshotDevices.androidPhone.device,
          home: Editor(),
        ),
      ),
    );
    final editor = tester.state<EditorState>(find.byType(Editor));
    addTearDown(editor.cancelAutosaveAndMarkSaved);

    // A5 on its side, cream, narrow ruled.
    final spec = NotebookSpec(
      template: PaperTemplates.byId('lined-narrow'),
      format: PaperFormat.a5,
      landscape: true,
      paperColor: const Color(0xFFFFF8E7),
    );
    await editor.applyNotebookSpec(spec);
    await tester.pump();

    final info = editor.coreInfo;
    expect(info.backgroundPattern, CanvasBackgroundPattern.lined);
    expect(info.lineHeight, 30);
    expect(info.backgroundColor, const Color(0xFFFFF8E7));
    expect(info.pages, isNotEmpty);
    for (final page in info.pages) {
      expect(page.size, spec.pageSize);
    }
    expect(spec.pageSize.width, greaterThan(spec.pageSize.height));
    // the paper becomes the one new notes start on, as before
    expect(stows.lastBackgroundPattern.value, CanvasBackgroundPattern.lined);

    // Pages added later are in the notebook's format too.
    editor.insertPageAfter(0);
    await tester.pump();
    expect(info.pages[1].size, spec.pageSize);
    editor.createPage(info.pages.length + 1);
    expect(info.pages.last.size, spec.pageSize);
    expect(info.pages.last.size, isNot(EditorPage.defaultSize));

    // Once there is something on the note, a setup no longer changes it.
    editor.drawTestStroke();
    await tester.pump();
    await editor.applyNotebookSpec(
      NotebookSpec(template: PaperTemplates.byId('gantt')),
    );
    expect(info.backgroundPattern, CanvasBackgroundPattern.lined);
    expect(info.pages.first.size, spec.pageSize);
  });
}
