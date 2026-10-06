import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_screenshot/golden_screenshot.dart';
import 'package:saber/components/canvas/image/editor_image.dart';
import 'package:saber/data/defter_strings.dart';
import 'package:saber/data/device_camera.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/flavor_config.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/versions/note_versions.dart';
import 'package:saber/i18n/strings.g.dart';
import 'package:saber/pages/editor/editor.dart';

import 'utils/test_mock_channel_handlers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late Directory temp;
  setUp(() => temp = Directory.systemTemp.createTempSync('device_camera_test'));
  tearDown(() {
    messenger.setMockMethodCallHandler(DeviceCamera.channel, null);
    DeviceCamera.availableOverride = null;
    temp.deleteSync(recursive: true);
  });

  /// A real picture, as the camera app would leave it.
  File photoFile(String name) => File('${temp.path}/$name')
    ..writeAsBytesSync(
      File('test/demo_notes/Import PDFs.sbn2.0').readAsBytesSync(),
    );

  group('The device camera:', () {
    test('hands over the photo that was taken and tidies up', () async {
      final photo = photoFile('photo_1.jpg');
      final bytes = photo.readAsBytesSync();
      final calls = <String>[];
      messenger.setMockMethodCallHandler(DeviceCamera.channel, (call) async {
        calls.add(call.method);
        return photo.path;
      });

      final taken = await DeviceCamera.takePhoto();
      expect(calls, ['takePhoto']);
      expect(taken, isNotNull);
      expect(taken!.bytes, bytes);
      expect(taken.extension, '.jpg');
      expect(photo.existsSync(), isFalse, reason: 'it is in the note now');
    });

    test('gives nothing when the camera was closed without a photo', () async {
      messenger.setMockMethodCallHandler(
        DeviceCamera.channel,
        (call) async => null,
      );
      expect(await DeviceCamera.takePhoto(), isNull);

      // A photo file with nothing in it is no photo.
      final empty = File('${temp.path}/photo_2.jpg')
        ..writeAsBytesSync(const []);
      messenger.setMockMethodCallHandler(
        DeviceCamera.channel,
        (call) async => empty.path,
      );
      expect(await DeviceCamera.takePhoto(), isNull);
    });

    test('says why when no photo can be taken', () async {
      Future<DeviceCameraFailure?> failure() async {
        try {
          await DeviceCamera.takePhoto();
          return null;
        } on DeviceCameraException catch (e) {
          return e.failure;
        }
      }

      messenger.setMockMethodCallHandler(
        DeviceCamera.channel,
        (call) async => throw PlatformException(code: 'no_camera'),
      );
      expect(await failure(), DeviceCameraFailure.noCamera);

      messenger.setMockMethodCallHandler(
        DeviceCamera.channel,
        (call) async => throw PlatformException(code: 'busy'),
      );
      expect(await failure(), DeviceCameraFailure.busy);

      messenger.setMockMethodCallHandler(
        DeviceCamera.channel,
        (call) async => throw PlatformException(code: 'failed', message: 'x'),
      );
      expect(await failure(), DeviceCameraFailure.failed);

      // The photo that was promised is not there.
      messenger.setMockMethodCallHandler(
        DeviceCamera.channel,
        (call) async => '${temp.path}/missing.jpg',
      );
      expect(await failure(), DeviceCameraFailure.failed);

      // A device (or a desktop) where the app has no camera side at all.
      messenger.setMockMethodCallHandler(DeviceCamera.channel, null);
      expect(await failure(), DeviceCameraFailure.noCamera);

      for (final value in DeviceCameraFailure.values) {
        expect(DefterStrings.cameraFailed(value.name), isNotEmpty);
      }
    });

    test('is offered on Android only, unless a test says otherwise', () {
      expect(DeviceCamera.isAvailable, Platform.isAndroid);
      DeviceCamera.availableOverride = true;
      expect(DeviceCamera.isAvailable, isTrue);
      DeviceCamera.availableOverride = false;
      expect(DeviceCamera.isAvailable, isFalse);
    });
  });

  testGoldens('Editor: a photo taken with the camera lands on the page', (
    tester,
  ) async {
    setupMockPathProvider();
    setupMockPrinting();
    FlavorConfig.setup();
    stows.editorGnLayout.value = false;
    DeviceCamera.availableOverride = true;
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

    String? answer;
    PlatformException? error;
    var asked = 0;
    messenger.setMockMethodCallHandler(DeviceCamera.channel, (call) async {
      asked++;
      if (error != null) throw error!;
      return answer;
    });

    await tester.pumpWidget(
      TranslationProvider(
        child: ScreenshotApp(
          device: GoldenScreenshotDevices.androidPhone.device,
          home: Editor(path: '/Kamera notu'),
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

    // The camera has a button of its own next to the gallery's.
    expect(find.byKey(const Key('takePhoto')), findsOneWidget);
    expect(find.byTooltip(DefterStrings.takePhoto), findsOneWidget);

    Future<int> take() async {
      final added = await tester.runAsync(
        () => editor.takePhoto().timeout(const Duration(seconds: 30)),
      );
      await tester.pump();
      return added!;
    }

    int photos() => editor.coreInfo.pages.first.images.length;

    // The camera was closed without a photo: the page is as it was.
    answer = null;
    expect(await take(), 0);
    expect(asked, 1);
    expect(photos(), 0);
    expect(editor.history.canUndo, isFalse);

    // No camera app: said so, nothing added.
    error = PlatformException(code: 'no_camera');
    expect(await take(), 0);
    await tester.pump();
    expect(find.text(DefterStrings.cameraFailed('noCamera')), findsOneWidget);
    expect(photos(), 0);
    error = null;
    ScaffoldMessenger.of(
      tester.element(find.byType(Editor)),
    ).removeCurrentSnackBar();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // A photo is taken.
    final photo = photoFile('photo_3.jpg');
    final bytes = photo.readAsBytesSync();
    answer = photo.path;
    expect(await take(), 1);
    expect(photos(), 1);
    final image = editor.coreInfo.pages.first.images.single;
    expect(image, isA<PngEditorImage>());
    expect(image.extension, '.jpg');
    expect(((image as PngEditorImage).imageProvider! as MemoryImage).bytes,
        bytes);
    expect(editor.history.canUndo, isTrue, reason: 'it can be undone');
    expect(photo.existsSync(), isFalse);

    // It is saved with the note.
    await tester.runAsync(
      () => editor.saveToFile().timeout(const Duration(seconds: 60)),
    );
    await tester.pump();
    expect(
      File('${temp.path}/docs/Kamera notu.sbn2').existsSync(),
      isTrue,
    );
    final saved = File('${temp.path}/docs/Kamera notu.sbn2.0');
    expect(saved.existsSync(), isTrue);
    expect(saved.lengthSync(), greaterThan(0));
    expect(File('${saved.path}.new').existsSync(), isFalse);
  });
}
