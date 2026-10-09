import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saber/data/tools/pen_overlay.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('defter/ink');
  final calls = <String>[];

  setUp(() {
    calls.clear();
    PenOverlay.reset();
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          return true;
        });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Map<String, Object?> config() => {
    'color': 0xFF000000,
    'size': 6.0,
    'thinning': 0.3,
    'taper': 0.0,
    'pressure': [for (var i = 0; i < 17; i++) i / 16],
    'left': 0.0,
    'top': 0.0,
    'right': 100.0,
    'bottom': 100.0,
  };

  test('the same setup is only sent once', () async {
    PenOverlay.sync(config());
    PenOverlay.sync(config());
    await Future<void>.delayed(Duration.zero);
    expect(calls, ['config']);
  });

  test('a changed setup is sent again, and so is turning it off', () async {
    PenOverlay.sync(config());
    PenOverlay.sync({...config(), 'size': 9.0});
    PenOverlay.sync(null);
    await Future<void>.delayed(Duration.zero);
    expect(calls, ['config', 'config', 'config']);
  });

  testWidgets('the overlay is cleared two frames after a stroke', (tester) async {
    PenOverlay.sync(config());
    await tester.pump();
    calls.clear();
    PenOverlay.clearSoon();
    await tester.pump();
    expect(calls, isEmpty);
    await tester.pump();
    await tester.pump();
    expect(calls, ['clear']);
    // A widget test must hand this back before it ends.
    debugDefaultTargetPlatformOverride = null;
  });

  test('where the overlay is off, nothing is sent', () async {
    PenOverlay.sync(null);
    PenOverlay.clearSoon();
    await Future<void>.delayed(Duration.zero);
    expect(calls, isEmpty);
  });

  test('off Android nothing is sent', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    PenOverlay.sync(config());
    await Future<void>.delayed(Duration.zero);
    expect(calls, isEmpty);
  });
}
