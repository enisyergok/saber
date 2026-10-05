import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saber/components/editor_gn/gn_pen_settings.dart';
import 'package:saber/data/flavor_config.dart';
import 'package:saber/data/tools/pen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlavorConfig.setup();

  testWidgets('sliders change the pen\'s real stroke options', (tester) async {
    final pen = Pen.fountainPen();
    final streamline = pen.options.streamline;
    final thinning = pen.options.thinning;
    addTearDown(() {
      pen.options.streamline = streamline;
      pen.options.thinning = thinning;
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: GnPenSettings(getTool: () => pen, setTool: (_) {}),
          ),
        ),
      ),
    );

    // Size, tip sharpness, pressure sensitivity, line stabilization.
    final sliders = find.byType(Slider);
    expect(sliders, findsNWidgets(4));

    final stab = tester.getRect(sliders.at(3));
    await tester.tapAt(Offset(stab.right - 8, stab.center.dy));
    await tester.pump();
    expect(pen.options.streamline, greaterThan(0.9));

    final press = tester.getRect(sliders.at(2));
    await tester.tapAt(Offset(press.left + 8, press.center.dy));
    await tester.pump();
    expect(pen.options.thinning, lessThan(0.1));
  });

  test('the preview line has points that vary with pressure', () {
    const size = Size(200, 80);
    final withPressure = PenPreviewPainter.samplePoints(size, pressure: true);
    final without = PenPreviewPainter.samplePoints(size, pressure: false);
    expect(withPressure.first.pressure, isNotNull);
    expect(without.first.pressure, isNull);
    expect(withPressure.length, without.length);
  });
}
