import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saber/components/canvas/palm_rejection.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/flavor_config.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/pages/editor/editor.dart';

import 'utils/test_mock_channel_handlers.dart';

PointerDownEvent _down(PointerDeviceKind kind, int pointer, int ms) =>
    PointerDownEvent(
      kind: kind,
      pointer: pointer,
      timeStamp: Duration(milliseconds: ms),
    );

void main() {
  group('PalmRejection logic:', () {
    test('touches are accepted when no stylus has been seen', () {
      final palm = PalmRejection();
      expect(palm.shouldRejectNewPointer(_down(.touch, 1, 0)), isFalse);
    });

    test('touches are rejected while the stylus is down', () {
      final palm = PalmRejection();
      palm.handleEvent(_down(.stylus, 1, 0));
      expect(palm.isStylusDown, isTrue);
      expect(palm.shouldRejectNewPointer(_down(.touch, 2, 5000)), isTrue);
    });

    test('touches stay rejected for a moment after the stylus lifts', () {
      final palm = PalmRejection();
      palm.handleEvent(_down(.stylus, 1, 0));
      palm.handleEvent(
        const PointerUpEvent(
          kind: .stylus,
          pointer: 1,
          timeStamp: Duration(milliseconds: 1000),
        ),
      );
      expect(palm.isStylusDown, isFalse);
      expect(palm.shouldRejectNewPointer(_down(.touch, 2, 1200)), isTrue);
      expect(palm.shouldRejectNewPointer(_down(.touch, 3, 1400)), isFalse);
    });

    test('a cancelled stylus pointer counts as lifted', () {
      final palm = PalmRejection();
      palm.handleEvent(_down(.stylus, 1, 0));
      palm.handleEvent(
        const PointerCancelEvent(
          kind: .stylus,
          pointer: 1,
          timeStamp: Duration(milliseconds: 10),
        ),
      );
      expect(palm.isStylusDown, isFalse);
    });

    test('the stylus, inverted stylus and mouse are never rejected', () {
      final palm = PalmRejection();
      palm.handleEvent(_down(.stylus, 1, 0));
      for (final kind in <PointerDeviceKind>[
        .stylus,
        .invertedStylus,
        .mouse,
      ]) {
        expect(palm.shouldRejectNewPointer(_down(kind, 9, 10)), isFalse);
      }
    });

    test('hovering does not block touches', () {
      final palm = PalmRejection();
      palm.handleEvent(
        const PointerHoverEvent(
          kind: .stylus,
          timeStamp: Duration(milliseconds: 100),
        ),
      );
      expect(palm.shouldRejectNewPointer(_down(.touch, 2, 110)), isFalse);
    });
  });

  group('Palm during stylus drawing:', () {
    FlavorConfig.setup();
    FileManager.documentsDirectory =
        '$tmpDir/palm_rejection_test/'
        '${FileManager.appRootDirectoryPrefix}';
    stows.editorFingerDrawing.value = false;

    /// Draws a short stylus stroke at the centre of the editor and returns
    /// how far apart (in x) the recorded points ended up.
    Future<double> drawWithPalm(
      WidgetTester tester, {
      required bool palmFirst,
    }) async {
      await tester.pumpWidget(MaterialApp(home: Editor(path: '/palm-test')));
      final editorState = tester.state<EditorState>(find.byType(Editor));
      await tester.pump();

      final center = tester.getCenter(find.byType(Editor));
      final palmPosition = center + const Offset(250, 120);
      final pen = await tester.createGesture(kind: .stylus);
      final palm = await tester.createGesture(
        kind: .touch,
        pointer: 7,
      );

      if (palmFirst) {
        await palm.down(palmPosition, timeStamp: Duration.zero);
        await pen.moveTo(center, timeStamp: const Duration(milliseconds: 40));
        await pen.down(center, timeStamp: const Duration(milliseconds: 50));
      } else {
        await pen.moveTo(center, timeStamp: Duration.zero);
        await pen.down(center, timeStamp: const Duration(milliseconds: 10));
        await palm.down(palmPosition, timeStamp: const Duration(milliseconds: 60));
      }
      for (var i = 1; i <= 10; ++i) {
        await pen.moveBy(
          Offset(i / 2, i / 2),
          timeStamp: Duration(milliseconds: 100 + i * 10),
        );
        // The palm drifts a little as the hand moves.
        await palm.moveBy(
          const Offset(1, 1),
          timeStamp: Duration(milliseconds: 100 + i * 10),
        );
      }
      await pen.up(timeStamp: const Duration(milliseconds: 400));
      await palm.up(timeStamp: const Duration(milliseconds: 420));
      await tester.pump();

      final strokes = editorState.coreInfo.pages.first.strokes;
      expect(strokes, hasLength(1), reason: 'the pen stroke must survive');
      final xs = strokes.single.points.map((p) => p.dx);
      return xs.reduce((a, b) => a > b ? a : b) -
          xs.reduce((a, b) => a < b ? a : b);
    }

    testWidgets('palm resting before the pen lands is ignored', (tester) async {
      final spread = await drawWithPalm(tester, palmFirst: true);
      // Without rejection the focal point is halfway to the palm (~125 px).
      expect(spread, lessThan(40));
    });

    testWidgets('palm landing while the pen is down is ignored', (tester) async {
      final spread = await drawWithPalm(tester, palmFirst: false);
      expect(spread, lessThan(40));
    });

    testWidgets('a finger alone never draws and does not break the pen', (
      tester,
    ) async {
      await tester.pumpWidget(MaterialApp(home: Editor(path: '/palm-test-2')));
      final editorState = tester.state<EditorState>(find.byType(Editor));
      await tester.pump();

      final center = tester.getCenter(find.byType(Editor));
      final finger = await tester.createGesture(kind: .touch);
      await finger.down(center, timeStamp: Duration.zero);
      await finger.moveBy(const Offset(0, 60), timeStamp: const Duration(milliseconds: 50));
      await finger.up(timeStamp: const Duration(milliseconds: 100));
      await tester.pump();
      expect(editorState.coreInfo.pages.first.strokes, isEmpty);

      final pen = await tester.createGesture(kind: .stylus);
      await pen.down(center, timeStamp: const Duration(seconds: 5));
      for (var i = 1; i <= 10; ++i) {
        await pen.moveBy(
          const Offset(2, 2),
          timeStamp: Duration(seconds: 5, milliseconds: i * 10),
        );
      }
      await pen.up(timeStamp: const Duration(seconds: 6));
      await tester.pump();
      expect(editorState.coreInfo.pages.first.strokes, hasLength(1));
    });
  });
}
