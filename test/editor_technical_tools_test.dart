import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/flavor_config.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/tools/pen_assist.dart';
import 'package:saber/pages/editor/editor.dart';

import 'utils/test_mock_channel_handlers.dart';

/// The technical tools of the pen panel, each switched on by itself and
/// used the way they are on a tablet: with a stylus, through the editor,
/// in the layout and with the settings the app starts with (lines are not
/// straightened by anything but the tool that is being tried).
void main() {
  FlavorConfig.setup();
  FileManager.documentsDirectory =
      '$tmpDir/technical_tools_test/'
      '${FileManager.appRootDirectoryPrefix}';

  final chip = find.byKey(const ValueKey('measureReadout'));

  setUp(() {
    stows.editorFingerDrawing.value = false;
    stows.autoStraightenLines.value = false;
    stows.autoShapes.value = false;
    stows.rulerMode.value = false;
    stows.angleGuide.value = false;
    stows.measureMode.value = false;
    stows.dimensionMode.value = false;
    PenAssist.showReadout(null);
  });
  tearDown(() {
    stows.autoStraightenLines.value = true;
    stows.angleGuide.value = false;
    stows.measureMode.value = false;
    stows.dimensionMode.value = false;
    PenAssist.showReadout(null);
    PenAssist.readoutAt.value = null;
  });

  Future<EditorState> pumpEditor(WidgetTester tester, String name) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: Editor(path: '/$name')));
    final editor = tester.state<EditorState>(find.byType(Editor));
    addTearDown(editor.cancelAutosaveAndMarkSaved);
    await tester.pump();
    expect(stows.editorGnLayout.value, isTrue, reason: 'the new layout');
    return editor;
  }

  /// Draws with the stylus through [points] (on screen), as a hand does:
  /// a hover first, then many small moves. Calls [midway] once half of the
  /// line is drawn, with the pen still down.
  Future<void> draw(
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

  /// A line from [a] to [b] as a hand draws it: not quite straight.
  List<Offset> byHand(Offset a, Offset b, {int steps = 40, double sway = 2}) {
    final along = b - a;
    final across = Offset(-along.dy, along.dx) / along.distance;
    return [
      for (var i = 0; i <= steps; i++)
        a + along * (i / steps) + across * (math.sin(i * 0.9) * sway),
    ];
  }

  List<Offset> circleByHand(Offset center, double radius) => [
    for (var i = 0; i <= 60; i++)
      center +
          Offset.fromDirection(
            2 * math.pi * i / 60,
            radius + math.sin(i * 1.3) * 1.5,
          ),
  ];

  // On a screen 1280 wide: a line going down to the right at about 18°.
  const from = Offset(400, 300), to = Offset(780, 423);

  testWidgets('nothing on: a line drawn by hand stays as it was drawn', (
    tester,
  ) async {
    final editor = await pumpEditor(tester, 'none');
    final page = editor.coreInfo.pages.first;
    await draw(tester, byHand(from, to));
    expect(page.strokes, hasLength(1));
    expect(page.strokes.single.vertexHandles, isNull);
    expect(chip, findsNothing);
  });

  testWidgets('angle guide alone: the line is made straight and turned to '
      'a step of 15 degrees', (tester) async {
    stows.angleGuide.value = true;
    final editor = await pumpEditor(tester, 'angle');
    final page = editor.coreInfo.pages.first;

    await draw(
      tester,
      byHand(from, to),
      midway: (pen) async {
        // While drawing, the angle the line will take is shown at the pen.
        expect(PenAssist.readout.value, matches(RegExp(r'^∠ \d+°$')));
        expect(chip, findsOneWidget);
        final rect = tester.getRect(chip);
        expect((rect.center.dx - pen.dx).abs(), lessThan(80));
        expect(rect.bottom, lessThan(pen.dy));
        expect(pen.dy - rect.bottom, lessThan(120));
      },
    );

    expect(page.strokes, hasLength(1));
    final ends = page.strokes.single.vertexHandles;
    expect(ends, isNotNull, reason: 'the line was made straight');
    expect(ends, hasLength(2));
    final degrees = (ends![1] - ends[0]).direction * 180 / math.pi;
    expect(degrees, closeTo(15, 1e-6), reason: 'drawn at about 18°');
    // What it was turned to stays on screen for a moment.
    expect(PenAssist.readout.value, '∠ 345°');
    expect(chip, findsOneWidget);
    editor.cancelAutosaveAndMarkSaved();
    await tester.pump(const Duration(seconds: 5));
    expect(chip, findsNothing);
  });

  testWidgets('angle guide: writing is not turned into lines', (tester) async {
    stows.angleGuide.value = true;
    final editor = await pumpEditor(tester, 'angle_writing');
    final page = editor.coreInfo.pages.first;
    // a wave, and a short tick
    await draw(tester, [
      for (var i = 0; i <= 40; i++)
        Offset(400 + i * 8.0, 300 + math.sin(i / 3) * 30),
    ]);
    await draw(tester, byHand(const Offset(500, 500), const Offset(512, 505)));
    expect(page.strokes, hasLength(2));
    for (final stroke in page.strokes) {
      expect(stroke.vertexHandles, isNull);
    }
  });

  testWidgets('measuring alone: the length is shown at the pen, the line is '
      'left as drawn', (tester) async {
    stows.measureMode.value = true;
    final editor = await pumpEditor(tester, 'measure');
    final page = editor.coreInfo.pages.first;

    String? whileDrawing;
    await draw(
      tester,
      byHand(from, to),
      midway: (pen) async {
        whileDrawing = PenAssist.readout.value;
        expect(chip, findsOneWidget);
        expect((tester.getRect(chip).center.dx - pen.dx).abs(), lessThan(80));
      },
    );
    expect(whileDrawing, matches(RegExp(r'^\d+(,\d)? mm  ∠ \d+°$')));

    expect(page.strokes, hasLength(1));
    expect(page.strokes.single.vertexHandles, isNull, reason: 'only measured');
    // the finished line: as long as it is along its path
    expect(PenAssist.readout.value, matches(RegExp(r'^\d+ mm$')));
    expect(chip, findsOneWidget);
    editor.cancelAutosaveAndMarkSaved();
    await tester.pump(const Duration(seconds: 5));
    expect(chip, findsNothing);
  });

  testWidgets('arrows and dimensions alone: a line gets arrowheads and its '
      'length, a circle its diameter', (tester) async {
    stows.dimensionMode.value = true;
    final editor = await pumpEditor(tester, 'dimension');
    final page = editor.coreInfo.pages.first;

    await draw(tester, byHand(from, to));
    final line = page.strokes.first;
    expect(line.vertexHandles, hasLength(2), reason: 'made straight');
    final extras = PenAssist.dimensionsOf(line).length;
    expect(extras, greaterThan(3), reason: 'two arrowheads and figures');
    expect(page.strokes, hasLength(1 + extras));

    // One undo takes the line and what was written to it away together.
    editor.undo();
    await tester.pump();
    expect(page.strokes, isEmpty);

    await draw(tester, circleByHand(const Offset(640, 450), 140));
    expect(page.strokes.first.runtimeType.toString(), 'CircleStroke');
    expect(page.strokes.length, greaterThan(3), reason: 'Ø and its figures');
    expect(chip, findsNothing, reason: 'measuring is off');
  });

  testWidgets('all three together', (tester) async {
    stows.angleGuide.value = true;
    stows.measureMode.value = true;
    stows.dimensionMode.value = true;
    final editor = await pumpEditor(tester, 'all');
    final page = editor.coreInfo.pages.first;

    await draw(tester, byHand(from, to));
    final line = page.strokes.first;
    final ends = line.vertexHandles!;
    expect((ends[1] - ends[0]).direction * 180 / math.pi, closeTo(15, 1e-6));
    expect(page.strokes.length, greaterThan(4));
    expect(PenAssist.readout.value, matches(RegExp(r'^\d+ mm  ∠ 345°$')));
    editor.cancelAutosaveAndMarkSaved();
    await tester.pump(const Duration(seconds: 5));
  });
}
