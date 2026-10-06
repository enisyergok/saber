import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saber/data/defter_strings.dart';
import 'package:saber/data/display_rate.dart';
import 'package:saber/pages/display_rate.dart';

void main() {
  group('Frame rate meter:', () {
    /// Feeds frames that are [gapMicros] apart.
    FrameRateMeter fed(int gapMicros, int frames, {FrameRateMeter? meter}) {
      meter ??= FrameRateMeter();
      var time = Duration.zero;
      for (var i = 0; i < frames; i++) {
        meter.add(time);
        time += Duration(microseconds: gapMicros);
      }
      return meter;
    }

    test('gives the rate the frames really come at', () {
      expect(fed(16667, 60).rate, closeTo(60, 0.1));
      expect(fed(8333, 120).rate, closeTo(120, 0.1));
      expect(fed(11111, 90).rate, closeTo(90, 0.1));
      expect(fed(6944, 144).rate, closeTo(144, 0.2));
    });

    test('gives nothing before enough frames were seen', () {
      final meter = FrameRateMeter(needed: 12);
      expect(meter.rate, isNull);
      fed(8333, 12, meter: meter); // 11 gaps
      expect(meter.rate, isNull);
      meter.add(const Duration(microseconds: 8333 * 12));
      expect(meter.rate, closeTo(120, 0.1));
      meter.clear();
      expect(meter.rate, isNull);
    });

    test('a few late frames do not make the screen look slower', () {
      final meter = FrameRateMeter();
      var time = Duration.zero;
      for (var i = 0; i < 80; i++) {
        meter.add(time);
        // Every tenth frame takes twice as long.
        time += Duration(microseconds: i % 10 == 9 ? 16666 : 8333);
      }
      expect(meter.rate, closeTo(120, 0.1));
    });

    test('follows the screen when it changes its rate', () {
      final meter = FrameRateMeter(keep: 30);
      var time = Duration.zero;
      for (var i = 0; i < 100; i++) {
        meter.add(time);
        time += const Duration(microseconds: 8333);
      }
      expect(meter.rate, closeTo(120, 0.1));
      for (var i = 0; i < 40; i++) {
        meter.add(time);
        time += const Duration(microseconds: 16667);
      }
      expect(meter.rate, closeTo(60, 0.1));
    });

    test('ignores a clock that stands still or goes back', () {
      final meter = FrameRateMeter(needed: 2);
      meter
        ..add(const Duration(milliseconds: 100))
        ..add(const Duration(milliseconds: 100))
        ..add(const Duration(milliseconds: 50));
      expect(meter.rate, isNull);
      meter
        ..add(const Duration(milliseconds: 60))
        ..add(const Duration(milliseconds: 70));
      expect(meter.rate, closeTo(100, 0.1));
    });
  });

  group('What the rate means:', () {
    test('compares what is measured with what the screen can do', () {
      DisplayRateVerdict of(double? max, double? measured) =>
          DisplayRate.verdict(max: max, measured: measured);

      expect(of(null, 60), DisplayRateVerdict.unknown);
      expect(of(120, null), DisplayRateVerdict.unknown);
      expect(of(60, 59.9), DisplayRateVerdict.noFasterMode);
      expect(of(60, null), DisplayRateVerdict.noFasterMode);
      expect(of(120, 119.9), DisplayRateVerdict.full);
      expect(of(144, 143.6), DisplayRateVerdict.full);
      expect(of(120, 60), DisplayRateVerdict.heldBack);
      expect(of(120, 90), DisplayRateVerdict.heldBack);
      expect(of(144, 120), DisplayRateVerdict.heldBack);
      expect(of(90, 60.1), DisplayRateVerdict.heldBack);
    });

    test('reads what the device says, leaving out what is not there', () {
      final info = DisplayRateInfo.fromMap(const {
        'max': 120.00001,
        'mode': 60,
        'app': 60.0,
        'sdk': 34,
        'maker': 'HONOR',
        'model': 'ROD2-W09',
        'details': '1: 2800x1840 @ 60 Hz, 2: 2800x1840 @ 120 Hz',
      });
      expect(info.max, closeTo(120, 0.001));
      expect(info.mode, 60);
      expect(info.app, 60);
      expect(info.sdk, 34);
      expect(info.maker, 'HONOR');
      expect(info.details, contains('120 Hz'));

      final empty = DisplayRateInfo.fromMap(const {'max': 0, 'sdk': '34'});
      expect(empty.max, isNull);
      expect(empty.sdk, isNull);
      expect(empty.model, isNull);
    });
  });

  group('Screen rate page:', () {
    Future<void> show(
      WidgetTester tester, {
      required DisplayRateInfo? info,
      Future<bool> Function()? openSettings,
    }) async {
      // Tall enough for the whole page to be on screen.
      tester.view.physicalSize = const Size(900, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: DisplayRatePage(
            read: () async => info,
            openSettings: openSettings ?? () async => true,
          ),
        ),
      );
      await tester.pump();
    }

    /// Lets [frames] frames pass, [gapMicros] apart.
    Future<void> frames(WidgetTester tester, int gapMicros, int frames) async {
      for (var i = 0; i < frames; i++) {
        await tester.pump(Duration(microseconds: gapMicros));
      }
    }

    String textOf(WidgetTester tester, String key) =>
        tester.widget<Text>(find.byKey(Key(key))).data!;

    testWidgets('says so when the device holds the app back', (tester) async {
      var opened = 0;
      await show(
        tester,
        info: const DisplayRateInfo(max: 120, mode: 60, app: 60, sdk: 34),
        openSettings: () async {
          opened++;
          return true;
        },
      );
      expect(textOf(tester, 'rateMax'), '120 Hz');
      expect(textOf(tester, 'rateGiven'), '60 Hz');
      // Nothing is claimed before it was measured.
      expect(textOf(tester, 'rateMeasured'), '—');
      expect(find.byKey(const Key('rateVerdict-unknown')), findsOneWidget);

      // The test draws 60 frames a second.
      await frames(tester, 16667, 80);
      expect(textOf(tester, 'rateMeasured'), DefterStrings.rateFrames('60.0'));
      expect(find.byKey(const Key('rateVerdict-heldBack')), findsOneWidget);
      expect(
        find.text(DefterStrings.rateHeldBack('120 Hz', '60 Hz')),
        findsOneWidget,
      );
      expect(find.text(DefterStrings.rateSteps), findsOneWidget);

      await tester.tap(find.byKey(const Key('rateOpenSettings')));
      await tester.pump();
      expect(opened, 1);
    });

    testWidgets('is content when the app is drawn at full rate', (
      tester,
    ) async {
      await show(
        tester,
        info: const DisplayRateInfo(max: 120, mode: 120, app: 120, sdk: 35),
      );
      await frames(tester, 8333, 120);
      expect(textOf(tester, 'rateMeasured'), DefterStrings.rateFrames('120.0'));
      expect(find.byKey(const Key('rateVerdict-full')), findsOneWidget);
      expect(find.text(DefterStrings.rateFull('120 Hz')), findsOneWidget);
      expect(find.text(DefterStrings.rateSteps), findsNothing);
    });

    testWidgets('does not promise more than the screen has', (tester) async {
      await show(
        tester,
        info: const DisplayRateInfo(max: 60, mode: 60, app: 60, sdk: 33),
      );
      await frames(tester, 16667, 60);
      expect(find.byKey(const Key('rateVerdict-noFasterMode')), findsOneWidget);
      expect(
        find.text(DefterStrings.rateNoFasterMode('60 Hz')),
        findsOneWidget,
      );
      // Some devices hide the fast modes while they are switched off: the
      // way to switch them on is shown here too.
      expect(find.text(DefterStrings.rateSteps), findsOneWidget);
    });

    testWidgets('still measures when the device says nothing, and tells '
        'when the settings can not be opened', (tester) async {
      await show(tester, info: null, openSettings: () async => false);
      await frames(tester, 16667, 60);
      expect(textOf(tester, 'rateMax'), '—');
      expect(textOf(tester, 'rateMeasured'), DefterStrings.rateFrames('60.0'));
      expect(find.text(DefterStrings.rateNoInfo), findsOneWidget);

      await tester.tap(find.byKey(const Key('rateOpenSettings')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text(DefterStrings.rateSettingsNotOpened), findsOneWidget);
      // Let the message leave before the page is taken down.
      ScaffoldMessenger.of(
        tester.element(find.byType(Scaffold).first),
      ).removeCurrentSnackBar();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
