import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saber/components/canvas/eraser_cursor.dart';
import 'package:saber/components/toolbar/quick_style_bar.dart';
import 'package:saber/data/defter_strings.dart';
import 'package:saber/data/editor/editor_history.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/flavor_config.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/tools/eraser.dart';
import 'package:saber/data/tools/pen.dart';
import 'package:saber/pages/editor/editor.dart';

import 'utils/test_mock_channel_handlers.dart';

/// The eraser, used the way it is on a tablet: with a stylus, through the
/// editor, in the layout the app starts with.
void main() {
  FlavorConfig.setup();
  FileManager.documentsDirectory =
      '$tmpDir/editor_eraser_test/'
      '${FileManager.appRootDirectoryPrefix}';

  final cursor = find.byKey(const ValueKey('eraserCursor'));

  setUp(() {
    stows.editorFingerDrawing.value = false;
    stows.autoStraightenLines.value = false;
    stows.disableEraserAfterUse.value = false;
    stows.eraserPrecise.value = true;
    stows.eraserSize.value = 10;
  });
  tearDown(() {
    stows.autoStraightenLines.value = true;
    stows.eraserPrecise.value = true;
    stows.eraserSize.value = 10;
    EraserCursor.at.value = null;
  });

  Future<EditorState> pumpEditor(WidgetTester tester, String name) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: Editor(path: '/$name')));
    final editor = tester.state<EditorState>(find.byType(Editor));
    addTearDown(editor.cancelAutosaveAndMarkSaved);
    await tester.pump();
    return editor;
  }

  Future<void> drag(
    WidgetTester tester,
    List<Offset> points, {
    Future<void> Function(Offset pen)? midway,
  }) async {
    final gesture = await tester.createGesture(kind: PointerDeviceKind.stylus);
    await gesture.moveTo(points.first);
    await gesture.down(points.first);
    for (var i = 1; i < points.length; i++) {
      await gesture.moveTo(points[i], timeStamp: Duration(milliseconds: 8 * i));
      if (midway != null && i == points.length ~/ 2) {
        await tester.pump();
        await midway(points[i]);
      }
    }
    await gesture.up(timeStamp: Duration(milliseconds: 8 * points.length));
    await tester.pump();
  }

  List<Offset> line(Offset a, Offset b, {int steps = 40}) => [
    for (var i = 0; i <= steps; i++) Offset.lerp(a, b, i / steps)!,
  ];

  /// A line written across the page, a little wavy as writing is.
  List<Offset> written(double y) => [
    for (var i = 0; i <= 60; i++)
      Offset(300 + i * 8.0, y + math.sin(i / 4) * 6),
  ];

  testWidgets('rubs out only what it passes over, and it can be undone', (
    tester,
  ) async {
    final editor = await pumpEditor(tester, 'precise');
    final page = editor.coreInfo.pages.first;

    // Three lines, one under the other.
    for (final y in const [300.0, 360.0, 420.0]) {
      await drag(tester, written(y));
    }
    expect(page.strokes, hasLength(3));
    final first = page.strokes[0], second = page.strokes[1];
    final third = page.strokes[2];
    final secondLine = second.inkLine();

    // The eraser, drawn down through the middle of the second line only.
    editor.currentTool = Eraser();
    await tester.pump();
    await drag(
      tester,
      line(const Offset(540, 335), const Offset(540, 385), steps: 20),
      midway: (pen) async {
        // its footprint shows where it is
        expect(cursor, findsOneWidget);
        expect(EraserCursor.at.value!.centre, pen);
        expect(EraserCursor.at.value!.radius, greaterThan(4));
      },
    );
    expect(cursor, findsNothing, reason: 'gone when the eraser is lifted');

    // The first and third lines are untouched; the second is in two parts,
    // in its place between them.
    expect(page.strokes, hasLength(4));
    expect(identical(page.strokes[0], first), isTrue);
    expect(identical(page.strokes[3], third), isTrue);
    final left = page.strokes[1], right = page.strokes[2];
    expect(left.inkLine().first.at, secondLine.first.at);
    expect(right.inkLine().last.at, secondLine.last.at);
    expect(left.inkLine().last.at.dx, lessThan(right.inkLine().first.at.dx));
    // a gap about as wide as the eraser, where it went
    final gap = right.inkLine().first.at.dx - left.inkLine().last.at.dx;
    final onScreen = EraserCursor.at.value; // null now; the size is 10 units
    expect(onScreen, isNull);
    expect(gap, inInclusiveRange(18, 28));
    expect(left.color, second.color);
    expect(left.toolId, second.toolId);
    expect(editor.history.canUndo, isTrue);

    // One undo brings the line back whole, the very same stroke, in place.
    editor.undo();
    await tester.pump();
    expect(page.strokes, hasLength(3));
    expect(identical(page.strokes[1], second), isTrue);
    expect(identical(page.strokes[0], first), isTrue);
    expect(identical(page.strokes[2], third), isTrue);

    // And redo rubs it out again, the same way.
    editor.redo();
    await tester.pump();
    expect(page.strokes, hasLength(4));
    expect(identical(page.strokes[1], left), isTrue);
    expect(identical(page.strokes[2], right), isTrue);

    // Rubbing along the whole of a line takes all of it.
    await drag(
      tester,
      line(const Offset(280, 300), const Offset(800, 300), steps: 60),
    );
    expect(page.strokes, hasLength(3));
    expect(page.strokes.contains(first), isFalse);
    editor.undo();
    await tester.pump();
    expect(identical(page.strokes[0], first), isTrue, reason: 'back in place');
    expect(page.strokes, hasLength(4));
  });

  testWidgets('set to whole strokes, takes the stroke it touches', (
    tester,
  ) async {
    stows.eraserPrecise.value = false;
    final editor = await pumpEditor(tester, 'whole');
    final page = editor.coreInfo.pages.first;
    await drag(tester, written(300));
    await drag(tester, written(360));
    expect(page.strokes, hasLength(2));
    final kept = page.strokes[0];

    editor.currentTool = Eraser();
    await tester.pump();
    await drag(
      tester,
      line(const Offset(540, 335), const Offset(540, 385), steps: 20),
    );
    expect(page.strokes, [kept]);
    editor.undo();
    await tester.pump();
    expect(page.strokes, hasLength(2));
  });

  testWidgets('a shape that is rubbed loses only that part', (tester) async {
    stows.autoStraightenLines.value = true;
    final editor = await pumpEditor(tester, 'shape');
    final page = editor.coreInfo.pages.first;
    editor.currentTool = Pen.currentPen;
    // a straight line, made straight by the pen
    await drag(tester, line(const Offset(300, 300), const Offset(800, 300)));
    expect(page.strokes.single.vertexHandles, hasLength(2));

    editor.currentTool = Eraser();
    await tester.pump();
    await drag(
      tester,
      line(const Offset(540, 270), const Offset(540, 330), steps: 20),
    );
    expect(page.strokes, hasLength(2));
    for (final piece in page.strokes) {
      expect(piece.vertexHandles, hasLength(2), reason: 'still a line');
    }
  });

  testWidgets('the toolbar says how the eraser erases and how large it is', (
    tester,
  ) async {
    final eraser = Eraser(size: 10);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(child: EraserSizeBar(eraser: eraser, onSizeChanged: () {})),
        ),
      ),
    );
    expect(find.text(DefterStrings.eraserPrecise), findsOneWidget);
    expect(find.text(DefterStrings.eraserWhole), findsOneWidget);
    expect(Eraser.precise, isTrue);

    await tester.tap(find.text(DefterStrings.eraserWhole));
    await tester.pump();
    expect(stows.eraserPrecise.value, isFalse);
    expect(Eraser.precise, isFalse);
    await tester.tap(find.text(DefterStrings.eraserPrecise));
    await tester.pump();
    expect(stows.eraserPrecise.value, isTrue);

    // the smallest size is for a single letter
    await tester.tap(
      find.byTooltip(
        '${DefterStrings.eraserSize}: ${Eraser.sizePresets.first.round()}',
      ),
    );
    expect(eraser.size, 4);
    expect(tester.takeException(), isNull);
  });

  test('a change the eraser made is kept as what it replaced', () {
    expect(
      () => EditorHistoryItem(
        type: EditorHistoryItemType.replace,
        pageIndex: 0,
        strokes: const [],
        images: const [],
      ),
      throwsA(isA<AssertionError>()),
    );
  });
}
