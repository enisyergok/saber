import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_screenshot/golden_screenshot.dart';
import 'package:saber/components/canvas/_stroke.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/flavor_config.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/tools/pen.dart';
import 'package:saber/data/tools/pen_assist.dart';
import 'package:saber/i18n/strings.g.dart';
import 'package:saber/pages/editor/editor.dart';
import 'package:sbn/canvas_background_pattern.dart';

import 'utils/test_mock_channel_handlers.dart';

void main() {
  testGoldens('Editor: the technical tools of the pen panel', (tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();

    setupMockPathProvider();
    setupMockPrinting();

    FlavorConfig.setup();
    stows.editorGnLayout.value = false;
    stows.shapeHoldToSnap.value = false;
    addTearDown(() {
      stows.shapeHoldToSnap.value = true;
      stows.rulerMode.value = false;
      stows.angleGuide.value = false;
      stows.dimensionMode.value = false;
      stows.autoShapes.value = false;
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
    final page = editor.coreInfo.pages.first;
    final pen = Pen.fountainPen();
    editor.currentTool = pen;

    void draw(List<Offset> points) {
      editor.dragPageIndex = 0;
      pen.onDragStart(points.first, page, 0, 0.5);
      for (final point in points.skip(1)) {
        pen.onDragUpdate(point, 0.5);
      }
      editor.onDrawEnd(ScaleEndDetails());
    }

    // Ruler with the angle guide: a level line, whatever the hand does.
    stows.rulerMode.value = true;
    stows.angleGuide.value = true;
    draw(const [Offset(100, 500), Offset(250, 520), Offset(385, 508)]);
    await tester.pump();
    expect(page.strokes, hasLength(1));
    final ends = page.strokes.single.vertexHandles!;
    expect(ends.first, const Offset(100, 500));
    expect(ends.last.dy, closeTo(500, 1e-6));

    // Dimensions: the line comes with arrowheads and its length as ink.
    stows.dimensionMode.value = true;
    draw(const [Offset(100, 700), Offset(385.7, 700)]);
    await tester.pump();
    final withDimension = page.strokes.length;
    expect(withDimension, 1 + 1 + 10);
    expect(PenAssist.dimensionsOf(page.strokes[1]), hasLength(10));

    // One undo takes the line and its dimension away together.
    editor.undo();
    await tester.pump();
    expect(page.strokes, hasLength(1));
    editor.redo();
    await tester.pump();
    expect(page.strokes, hasLength(withDimension));

    // Shapes without holding: a drawn circle becomes a circle.
    stows.rulerMode.value = false;
    stows.angleGuide.value = false;
    stows.dimensionMode.value = false;
    stows.autoShapes.value = true;
    draw([
      for (var i = 0; i <= 80; i++)
        const Offset(500, 300) + Offset.fromDirection(6.2832 * i / 80, 100),
    ]);
    await tester.pump();
    expect(page.strokes.last.runtimeType.toString(), 'CircleStroke');

    // With it off, the same drawing stays handwriting.
    stows.autoShapes.value = false;
    draw([
      for (var i = 0; i <= 80; i++)
        const Offset(500, 700) + Offset.fromDirection(6.2832 * i / 80, 100),
    ]);
    await tester.pump();
    expect(page.strokes.last.runtimeType, Stroke);

    // The grid puts the note on squared paper and back, and can be undone.
    final paper = editor.coreInfo.backgroundPattern;
    expect(paper, isNot(CanvasBackgroundPattern.grid));
    editor.toggleGrid();
    await tester.pump();
    expect(editor.coreInfo.backgroundPattern, CanvasBackgroundPattern.grid);
    editor.toggleGrid();
    await tester.pump();
    expect(editor.coreInfo.backgroundPattern, paper);
    editor.toggleGrid();
    editor.undo();
    await tester.pump();
    expect(editor.coreInfo.backgroundPattern, paper);
  });
}
