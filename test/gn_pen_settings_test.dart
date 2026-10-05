import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saber/components/editor_gn/gn_pen_settings.dart';
import 'package:saber/data/flavor_config.dart';
import 'package:saber/data/defter_strings.dart';
import 'package:saber/data/tools/pen.dart';
import 'package:saber/data/tools/pen_feel.dart';
import 'package:sbn/tool_id.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlavorConfig.setup();

  testWidgets('sliders change the pen\'s real stroke options', (tester) async {
    final pen = Pen.fountainPen();
    final streamline = pen.options.streamline;
    final thinning = pen.options.thinning;
    final sharpness = pen.tipSharpness;
    addTearDown(() {
      pen.tipSharpness = sharpness;
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

    // Tip sharpness, pressure sensitivity, line stabilization, size.
    final sliders = find.byType(Slider);
    expect(sliders, findsNWidgets(4));

    final sharp = tester.getRect(sliders.at(0));
    await tester.tapAt(Offset(sharp.left + 8, sharp.center.dy));
    await tester.pump();
    expect(pen.tipSharpness, 0);
    expect(pen.strokeOptions.end.taperEnabled, isFalse);
    await tester.tapAt(Offset(sharp.right - 8, sharp.center.dy));
    await tester.pump();
    expect(pen.tipSharpness, 1);
    expect(pen.strokeOptions.end.taperEnabled, isTrue);

    final stab = tester.getRect(sliders.at(2));
    await tester.tapAt(Offset(stab.right - 8, stab.center.dy));
    await tester.pump();
    expect(pen.options.streamline, greaterThan(0.9));

    final press = tester.getRect(sliders.at(1));
    await tester.tapAt(Offset(press.left + 8, press.center.dy));
    await tester.pump();
    expect(pen.options.thinning, lessThan(0.1));
  });

  testWidgets('the three pens can be chosen, the brush included', (
    tester,
  ) async {
    Pen pen = Pen.fountainPen();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: GnPenSettings(getTool: () => pen, setTool: (p) => pen = p),
          ),
        ),
      ),
    );
    expect(pen.kind, PenKind.fountain);

    await tester.tap(find.text(DefterStrings.brushPen).last);
    await tester.pump();
    expect(pen.kind, PenKind.brush);
    expect(pen.brush, isTrue);
    // Stored like a fountain pen line, so older versions can read it.
    expect(pen.toolId, ToolId.fountainPen);
    expect(find.byType(Slider), findsNWidgets(4));

    await tester.tap(find.text(DefterStrings.ballpointPenName).last);
    await tester.pump();
    expect(pen.kind, PenKind.ballpoint);
    // No tip sharpness for the ballpoint.
    expect(find.byType(Slider), findsNWidgets(3));
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
