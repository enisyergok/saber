import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_screenshot/golden_screenshot.dart';
import 'package:saber/components/canvas/_asset_cache.dart';
import 'package:saber/components/canvas/canvas_image.dart';
import 'package:saber/components/canvas/image/editor_image.dart';
import 'package:saber/components/canvas/save_indicator.dart';
import 'package:saber/data/editor/editor_core_info.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/flavor_config.dart';
import 'package:saber/data/pdf/pdf_pick.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/tools/pen.dart';
import 'package:saber/data/tools/select.dart';
import 'package:saber/data/versions/note_versions.dart';
import 'package:saber/i18n/strings.g.dart';
import 'package:saber/pages/editor/editor.dart';

import 'utils/test_mock_channel_handlers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupMockPathProvider();
  FlavorConfig.setup();

  late Directory temp;
  setUp(() => temp = Directory.systemTemp.createTempSync('image_actions_test'));
  tearDown(() {
    try {
      temp.deleteSync(recursive: true);
    } on FileSystemException {
      // Still in use by something that is being closed.
    }
  });

  final pngBytes = File(
    'test/demo_notes/Import PDFs.sbn2.0',
  ).readAsBytesSync();

  group('A picture that is turned:', () {
    final cache = AssetCache();
    PngEditorImage picture() => PngEditorImage(
      id: 1,
      assetCache: cache,
      extension: '.png',
      imageProvider: MemoryImage(pngBytes),
      pageIndex: 0,
      pageSize: const Size(1000, 1400),
      onMoveImage: null,
      onDeleteImage: null,
      onMiscChange: null,
      naturalSize: const Size(400, 200),
      srcRect: const Rect.fromLTWH(0, 0, 400, 200),
      dstRect: const Rect.fromLTWH(100, 300, 400, 200),
    );

    test('a quarter turn swaps its sides about its middle', () {
      final image = picture();
      var notified = 0;
      image.addListener(() => notified++);
      expect(image.quarterTurns, 0);

      image.rotateQuarter();
      expect(image.quarterTurns, 1);
      expect(image.dstRect, const Rect.fromLTWH(200, 200, 200, 400));
      expect(image.dstRect.center, const Offset(300, 400));
      expect(notified, greaterThan(0));

      image.rotateQuarter();
      expect(image.quarterTurns, 2);
      expect(image.dstRect, const Rect.fromLTWH(100, 300, 400, 200));
      image.rotateQuarter();
      image.rotateQuarter();
      expect(image.quarterTurns, 0, reason: 'four quarters are a full turn');
      expect(image.dstRect, const Rect.fromLTWH(100, 300, 400, 200));

      // Half a turn keeps the box, but is a change all the same.
      notified = 0;
      image.rotateQuarter(2);
      expect(image.quarterTurns, 2);
      expect(image.dstRect, const Rect.fromLTWH(100, 300, 400, 200));
      expect(notified, 1);
      image.rotateQuarter(-3);
      expect(image.quarterTurns, 3);

      // What the history has not heard of yet is handed over once.
      expect(image.takeUnreportedTurns(), 4 + 2 - 3);
      expect(image.takeUnreportedTurns(), 0);
    });

    test('the turn is saved with the note and found again', () {
      final image = picture()..rotateQuarter(3);
      final json = image.toJson(OrderedAssetCache());
      expect(json['r'], 3);
      expect(json['w'], 200);
      expect(json['h'], 400);

      final again = EditorImage.fromJson(
        json,
        inlineAssets: [pngBytes],
        sbnPath: '/x',
        assetCache: cache,
      );
      expect(again.quarterTurns, 3);
      expect(again.dstRect, image.dstRect);
      expect(image.copy().quarterTurns, 3);

      // A picture that was never turned is saved as before.
      expect(picture().toJson(OrderedAssetCache()).containsKey('r'), isFalse);
      final plain = picture().toJson(OrderedAssetCache());
      expect(
        EditorImage.fromJson(
          plain,
          inlineAssets: [pngBytes],
          sbnPath: '/x',
          assetCache: cache,
        ).quarterTurns,
        0,
      );
    });
  });

  testGoldens('Editor: tapping a picture shows its buttons; turning and '
      'deleting can be undone', (tester) async {
    setupMockPrinting();
    stows.editorGnLayout.value = false;
    stows.editorFingerDrawing.value = false;
    stows.autosaveDelay.value = -1;
    addTearDown(() => stows.autosaveDelay.value = 10000);
    EditorImage.shouldLoadOutImmediately = true;
    addTearDown(() => EditorImage.shouldLoadOutImmediately = false);

    Directory('${temp.path}/docs').createSync();
    NoteVersions.rootOverride = Directory('${temp.path}/versions');
    addTearDown(() => NoteVersions.rootOverride = null);
    await tester.runAsync(
      () => FileManager.init(
        documentsDirectory: '${temp.path}/docs',
        shouldWatchRootDirectory: false,
      ),
    );

    const path = '/Resimli not';
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
    Future<void> wait([int ms = 100]) => tester.runAsync(
      () => Future<void>.delayed(Duration(milliseconds: ms)),
    );
    await wait(500);
    await tester.pump();

    // A picture is put on the page (as a photo or a piece of a PDF is).
    final added = await tester.runAsync(
      () => editor.applyPdfPick(
        'unused',
        PdfPickImage(
          png: pngBytes,
          pixelSize: const Size(595, 841),
          fractionOfPage: const Size(0.3, 0.3),
        ),
      ),
    );
    expect(added, isTrue);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final image = editor.coreInfo.pages.first.images.single;
    final placed = image.dstRect;
    expect(placed.width, closeTo(300, 0.01));

    /// The same box, give or take what turning twice does to the last
    /// digits of a number.
    void expectSameBox(Rect actual, Rect expected) {
      expect(actual.left, closeTo(expected.left, 1e-6));
      expect(actual.top, closeTo(expected.top, 1e-6));
      expect(actual.right, closeTo(expected.right, 1e-6));
      expect(actual.bottom, closeTo(expected.bottom, 1e-6));
    }

    final actions = find.byKey(const Key('imageActions'));
    final rotate = find.byKey(const Key('imageRotate'));
    final delete = find.byKey(const Key('imageDelete'));

    // New pictures start out active: their buttons are there.
    expect(editor.currentTool, isA<Select>());
    expect(actions, findsOneWidget);
    expect(rotate, findsOneWidget);
    expect(delete, findsOneWidget);
    expect(find.byKey(const Key('imageMore')), findsOneWidget);
    // They are the size of a fingertip on screen, whatever the page's scale.
    expect(
      tester.getRect(rotate).shortestSide,
      closeTo(CanvasImage.actionButtonSize, 2),
    );
    // And beside the picture, not on it.
    expect(
      tester
          .getRect(actions)
          .overlaps(tester.getRect(find.byType(CanvasImage)).deflate(1)),
      isFalse,
    );

    // -- turning
    await tester.tap(rotate);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(image.quarterTurns, 1);
    expect(image.dstRect.width, closeTo(placed.height, 0.01));
    expect(image.dstRect.height, closeTo(placed.width, 0.01));
    expect(image.dstRect.center.dx, closeTo(placed.center.dx, 0.01));
    expect(image.dstRect.center.dy, closeTo(placed.center.dy, 0.01));
    expect(actions, findsOneWidget, reason: 'it stays active');
    // The picture on screen is as wide as it was high.
    final shown = tester.getSize(find.byType(CanvasImage));
    expect(shown.width / shown.height, closeTo(placed.height / placed.width, 0.02));

    await tester.tap(rotate);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(image.quarterTurns, 2);
    expectSameBox(image.dstRect, placed);

    // Each turn is undone on its own.
    editor.undo();
    await tester.pump();
    expect(image.quarterTurns, 1);
    expect(image.dstRect.width, closeTo(placed.height, 0.01));
    editor.undo();
    await tester.pump();
    expect(image.quarterTurns, 0);
    expectSameBox(image.dstRect, placed);
    editor.redo();
    await tester.pump();
    expect(image.quarterTurns, 1);
    expect(image.dstRect.height, closeTo(placed.width, 0.01));
    await tester.pump(const Duration(milliseconds: 400));

    // The turn is saved with the note.
    Future<void> save() async {
      // ignore: invalid_use_of_protected_member
      editor.setState(() {});
      await tester.runAsync(
        () => editor.saveToFile().timeout(const Duration(seconds: 60)),
      );
      await wait();
      await tester.pump();
    }

    editor.autosaveAfterDelay();
    await save();
    expect(editor.savingState.value, SavingState.saved);
    final disk = (await tester.runAsync(
      () => EditorCoreInfo.loadFromFilePath(path),
    ))!;
    addTearDown(disk.dispose);
    expect(disk.pages.first.images.single.quarterTurns, 1);
    expect(disk.pages.first.images.single.dstRect.width,
        closeTo(placed.height, 0.5));

    // -- from the pen: a finger tap on the picture brings the buttons up
    final pen = Pen.currentPen;
    editor.currentTool = pen;
    // ignore: invalid_use_of_protected_member
    editor.setState(() {});
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(actions, findsNothing, reason: 'with the pen, pictures are at rest');

    final page = editor.coreInfo.pages.first;
    Offset onScreen(Offset onPage) => page.renderBox!.localToGlobal(onPage);
    final strokesBefore = page.strokes.length;

    // A finger tap beside the picture changes nothing.
    await tester.tapAt(onScreen(const Offset(80, 1250)));
    await tester.pump(const Duration(milliseconds: 30));
    expect(editor.currentTool, same(pen));
    expect(actions, findsNothing);

    // A finger that drags over the picture moves the page, it is no tap.
    final drag = await tester.startGesture(onScreen(image.dstRect.center));
    await drag.moveBy(const Offset(0, -60));
    await drag.up();
    await tester.pump(const Duration(milliseconds: 30));
    expect(editor.currentTool, same(pen));
    expect(actions, findsNothing);

    // A quick tap on it does nothing.
    await tester.tapAt(onScreen(image.dstRect.center));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(seconds: 4));
    expect(editor.currentTool, same(pen));
    expect(actions, findsNothing);

    /// Presses the middle of the picture for [seconds] seconds.
    Future<void> holdPicture(double seconds) async {
      final finger = await tester.startGesture(
        onScreen(image.dstRect.center),
      );
      await tester.pump(Duration(milliseconds: (seconds * 1000).round()));
      await finger.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    // Two seconds is not enough.
    await holdPicture(2);
    expect(editor.currentTool, same(pen));
    expect(actions, findsNothing);

    // Three is.
    await holdPicture(3.2);
    expect(editor.currentTool, isA<Select>());
    expect(actions, findsOneWidget);
    expect(page.strokes.length, strokesBefore, reason: 'a tap draws nothing');

    // Writing with the pen right after: the picture is let go and the pen
    // writes, as if nothing had been tapped.
    final stylus = await tester.createGesture(kind: PointerDeviceKind.stylus);
    final start = onScreen(const Offset(80, 1250));
    await stylus.down(start, timeStamp: const Duration(seconds: 5));
    for (var i = 1; i <= 10; i++) {
      await stylus.moveBy(
        const Offset(3, 2),
        timeStamp: Duration(seconds: 5, milliseconds: i * 10),
      );
    }
    await stylus.up(timeStamp: const Duration(seconds: 6));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(editor.currentTool, same(pen));
    expect(page.strokes.length, strokesBefore + 1);
    expect(actions, findsNothing);
    expect(page.images.single, same(image));

    // -- deleting
    await holdPicture(3.2);
    expect(actions, findsOneWidget);
    await tester.tap(delete);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(page.images, isEmpty);
    expect(actions, findsNothing);
    editor.undo();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(page.images.single, same(image));
    expect(image.quarterTurns, 1, reason: 'as it was, turn and all');

    editor.cancelAutosaveAndMarkSaved();
    await tester.pump(const Duration(milliseconds: 500));
  });
}
