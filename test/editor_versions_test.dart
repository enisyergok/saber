import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:golden_screenshot/golden_screenshot.dart';
import 'package:saber/components/canvas/save_indicator.dart';
import 'package:saber/components/toolbar/note_versions_dialog.dart';
import 'package:saber/data/defter_strings.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/flavor_config.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/versions/note_versions.dart';
import 'package:saber/i18n/strings.g.dart';
import 'package:saber/pages/editor/editor.dart';

import 'utils/test_editor.dart';
import 'utils/test_mock_channel_handlers.dart';

void main() {
  testGoldens('Editor: versions are kept as a note is written, and one is '
      'brought back', (tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupMockPathProvider();
    setupMockPrinting();
    FlavorConfig.setup();
    stows.editorGnLayout.value = false;
    stows.versionHistory.value = true;

    final temp = Directory.systemTemp.createTempSync('editor_versions_test');
    addTearDown(() => temp.deleteSync(recursive: true));
    Directory('${temp.path}/docs').createSync();
    NoteVersions.rootOverride = Directory('${temp.path}/versions');
    addTearDown(() => NoteVersions.rootOverride = null);
    await tester.runAsync(
      () => FileManager.init(
        documentsDirectory: '${temp.path}/docs',
        shouldWatchRootDirectory: false,
      ),
    );

    const path = '/Sürümlü not';
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
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pump();
    expect(editor.coreInfo.pages, isNotEmpty);
    expect(editor.coreInfo.filePath, path);

    Future<void> wait([int ms = 100]) => tester.runAsync(
      () => Future<void>.delayed(Duration(milliseconds: ms)),
    );
    Future<void> save() async {
      await tester.runAsync(
        () => editor.saveToFile().timeout(const Duration(seconds: 30)),
      );
      await wait();
      await tester.pump();
    }

    Future<List<NoteVersion>> versions() async =>
        (await tester.runAsync(() => NoteVersions.list(path)))!;
    int strokes() => editor.coreInfo.pages.first.strokes.length;

    // A note that was never saved has no versions.
    expect(await versions(), isEmpty);

    // The first save leaves the first version behind.
    editor.drawTestStroke();
    await tester.pump();
    await save();
    expect(editor.savingState.value, SavingState.saved);
    expect(File('${temp.path}/docs$path.sbn2').existsSync(), isTrue);
    var kept = await versions();
    expect(kept.length, 1);
    expect(kept.single.reason, NoteVersion.reasonAuto);
    final oneStroke = kept.single;

    // Saving again minutes later does not: one every ten minutes.
    editor.drawTestStroke();
    await tester.pump();
    await save();
    expect(strokes(), 2);
    expect((await versions()).length, 1);

    // Something that is not saved yet…
    editor.drawTestStroke();
    await tester.pump();
    expect(strokes(), 3);
    expect(editor.savingState.value, SavingState.waitingToSave);

    // …is saved and kept before the first version comes back.
    await tester.runAsync(
      () => editor
          .restoreVersion(oneStroke)
          .timeout(const Duration(seconds: 30)),
    );
    await wait();
    await tester.pump();
    expect(strokes(), 1);
    expect(editor.savingState.value, SavingState.saved);
    expect(editor.history.canUndo, isFalse);

    kept = await versions();
    expect(kept.length, 2);
    expect(kept.first.reason, NoteVersion.reasonRestore);

    // Going back to the version before the restore undoes it.
    await tester.runAsync(
      () => editor
          .restoreVersion(kept.first)
          .timeout(const Duration(seconds: 30)),
    );
    await wait();
    await tester.pump();
    expect(strokes(), 3);

    // The note still works as a note: it can be written on and saved.
    editor.drawTestStroke();
    await tester.pump();
    await save();
    expect(strokes(), 4);
    expect(editor.savingState.value, SavingState.saved);

    // The list of versions opens from the editor.
    editor.showVersions();
    await tester.pump();
    await tester.pump();
    expect(find.byType(NoteVersionsDialog), findsOneWidget);
    expect(
      find.text(DefterStrings.versionRestore),
      findsNWidgets((await versions()).length),
    );
    await tester.tap(find.text(DefterStrings.close));
    await tester.pump();
  });
}
