import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saber/components/canvas/_canvas_painter.dart';
import 'package:saber/components/canvas/inner_canvas.dart';
import 'package:saber/data/benchmark/synthetic_notes.dart';
import 'package:saber/data/editor/editor_core_info.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/flavor_config.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/tools/stroke_properties.dart';

import 'utils/test_mock_channel_handlers.dart';

void main() {
  group('Ink layers:', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupMockPathProvider();
    FlavorConfig.setup();
    StrokeOptionsExtension.setDefaults();

    setUpAll(() async {
      await FileManager.init(shouldWatchRootDirectory: false);
    });

    late EditorCoreInfo note;
    final paints = <InkLayer, int>{};

    int count(InkLayer layer) => paints[layer] ?? 0;

    setUp(() {
      paints.clear();
      CanvasPainter.debugOnPaint = (layer) =>
          paints[layer] = (paints[layer] ?? 0) + 1;
      note = SyntheticNotes.note(strokes: 40);
    });
    tearDown(() {
      CanvasPainter.debugOnPaint = null;
    });

    Future<void> pumpCanvas(WidgetTester tester) async {
      final page = note.pages.first;
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: page.size.width,
            height: page.size.height,
            child: InnerCanvas(
              pageIndex: 0,
              redrawPageListenable: page,
              liveInkListenable: page.liveInkListenable,
              width: page.size.width,
              height: page.size.height,
              coreInfo: note,
              currentStroke: null,
              currentStrokeDetectedShape: null,
              currentSelection: null,
              currentToolIsSelect: false,
              currentScale: 1,
            ),
          ),
        ),
      );
      stows.editorAutoInvert; // make sure prefs are readable
    }

    testWidgets('both layers paint once initially', (tester) async {
      await pumpCanvas(tester);
      expect(count(.dry), 1);
      expect(count(.live), 1);
    });

    testWidgets('pen movement repaints only the live layer', (tester) async {
      await pumpCanvas(tester);
      paints.clear();

      final page = note.pages.first;
      for (var i = 0; i < 10; i++) {
        page.redrawLiveInk();
        await tester.pump();
      }

      expect(count(.live), 10);
      expect(count(.dry), 0, reason: 'finished strokes must not be repainted');
    });

    testWidgets('redrawStrokes repaints both layers', (tester) async {
      await pumpCanvas(tester);
      paints.clear();

      note.pages.first.redrawStrokes();
      await tester.pump();

      expect(count(.live), 1);
      expect(count(.dry), 1);
    });
  });
}
