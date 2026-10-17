import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saber/components/editor_gn/float_bar.dart';
import 'package:saber/components/editor_gn/gn_bar.dart';
import 'package:saber/components/editor_gn/gn_pen_settings.dart';
import 'package:saber/components/toolbar/quick_style_bar.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/flavor_config.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/tools/eraser.dart';
import 'package:saber/data/tools/pen.dart';
import 'package:saber/i18n/strings.g.dart';
import 'package:saber/pages/editor/editor.dart';

import 'utils/test_mock_channel_handlers.dart';

void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupMockPathProvider();
    setupMockPrinting();
    setupMockWindowManager();
    FlavorConfig.setup();
    await FileManager.init();
    stows.editorFloatingBar.value = true;
  });

  tearDown(() => stows.editorFloatingBar.value = false);

  Future<EditorState> pumpEditor(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      TranslationProvider(child: MaterialApp(home: Editor())),
    );
    final editor = tester.state<EditorState>(find.byType(Editor));
    addTearDown(editor.cancelAutosaveAndMarkSaved);
    await tester.pump();
    await tester.pump();
    return editor;
  }

  test('the fixed notebook layout is the default', () {
    expect(stows.editorGnLayout.defaultValue, isTrue);
    expect(stows.editorFloatingBar.defaultValue, isFalse);
  });

  test('the controls take one row less on a wide screen', () {
    expect(
      FloatEditorBar.reservedHeight(1500),
      lessThan(FloatEditorBar.reservedHeight(800)),
    );
  });

  testWidgets('the page fills the screen and the tools float over it', (
    tester,
  ) async {
    await pumpEditor(tester, const Size(1280, 800));
    expect(find.byType(AppBar), findsNothing);
    expect(find.byType(GnEditorBar), findsNothing);
    expect(find.byType(FloatEditorBar), findsOneWidget);
    for (final key in [
      'floatPen',
      'floatEraser',
      'floatLasso',
      'floatNoteName',
    ]) {
      expect(find.byKey(Key(key)), findsOneWidget, reason: key);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('on a narrow screen it works the same', (tester) async {
    await pumpEditor(tester, const Size(700, 1000));
    expect(find.byKey(const Key('floatPen')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the pen\'s quick options hang under the tool box and can be '
      'hidden', (tester) async {
    final editor = await pumpEditor(tester, const Size(1280, 800));
    await tester.tap(find.byKey(const Key('floatEraser')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('floatPen')));
    await tester.pump();
    expect(editor.currentTool, isA<Pen>());
    expect(find.byType(QuickStyleBar), findsOneWidget);

    await tester.tap(find.byKey(const Key('floatQuickControls')));
    await tester.pump();
    expect(find.byType(QuickStyleBar), findsNothing);

    await tester.tap(find.byKey(const Key('floatQuickControls')));
    await tester.pump();
    expect(find.byType(QuickStyleBar), findsOneWidget);
  });

  testWidgets('tapping the pen in use opens its settings', (tester) async {
    await pumpEditor(tester, const Size(1280, 800));
    await tester.tap(find.byKey(const Key('floatEraser')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('floatPen')));
    await tester.pump();
    expect(find.byType(GnPenSettings), findsNothing);
    await tester.tap(find.byKey(const Key('floatPen')));
    await tester.pumpAndSettle();
    expect(find.byType(GnPenSettings), findsOneWidget);
  });

  testWidgets('the eraser button picks the eraser', (tester) async {
    final editor = await pumpEditor(tester, const Size(1280, 800));
    await tester.tap(find.byKey(const Key('floatEraser')));
    await tester.pump();
    expect(editor.currentTool, isA<Eraser>());
  });

  testWidgets('the first page starts under the controls', (tester) async {
    final editor = await pumpEditor(tester, const Size(1280, 800));
    final box = editor.coreInfo.pages.first.renderBox;
    expect(box, isNotNull);
    final top = box!.localToGlobal(Offset.zero).dy;
    expect(top, greaterThanOrEqualTo(FloatEditorBar.reservedHeight(1280)));
  });
}
