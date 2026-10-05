import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saber/components/editor_gn/gn_pen_profiles.dart';
import 'package:saber/components/editor_gn/gn_pen_settings.dart';
import 'package:saber/data/defter_strings.dart';
import 'package:saber/data/flavor_config.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/tools/highlighter.dart';
import 'package:saber/data/tools/pen.dart';
import 'package:saber/data/tools/pen_feel.dart';
import 'package:saber/data/tools/pen_styles.dart';
import 'package:saber/data/tools/pencil.dart';
import 'package:saber/data/tools/pressure_curve.dart';
import 'package:sbn/tool_id.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlavorConfig.setup();

  /// The settings every pen had before a test, put back after it.
  late Map<PenStyle, PenProfile> saved;

  setUp(() {
    saved = {
      for (final style in PenStyle.values)
        style: PenProfile.capture(PenStyles.create(style)),
    };
    stows.pressureCurve.value = '';
    PenFeel.curve = PressureCurve.standard;
  });
  tearDown(() {
    for (final MapEntry(key: style, value: profile) in saved.entries) {
      profile.applyTo(PenStyles.create(style));
    }
    PenProfiles.restore();
    stows.pressureCurve.value = '';
    stows.rulerMode.value = false;
    stows.angleGuide.value = false;
    stows.measureMode.value = false;
    stows.dimensionMode.value = false;
    stows.autoShapes.value = false;
    stows.autoStraightenLines.value = true;
    stows.shapeAutoCorrect.value = true;
    stows.shapeSnapEndpoints.value = true;
    stows.shapeHoldToSnap.value = true;
    stows.penPreviewCollapsed.value = false;
  });

  /// Shows the panel on a tablet-sized screen, tall enough that nothing
  /// has to be scrolled to.
  Future<({Pen Function() pen, List<String> calls})> pumpPanel(
    WidgetTester tester, {
    Pen? start,
    Size screen = const Size(1280, 1500),
    bool gridOn = false,
  }) async {
    tester.view.physicalSize = screen;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    Pen pen = start ?? Pen.fountainPen();
    final calls = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: GnPenSettings(
              getTool: () => pen,
              setTool: (p) => pen = p,
              onClose: () => calls.add('close'),
              openColorPicker: () => calls.add('colors'),
              toggleGrid: () => calls.add('grid'),
              gridOn: gridOn,
              maxHeight: 1400,
            ),
          ),
        ),
      ),
    );
    return (pen: () => pen, calls: calls);
  }

  Future<void> tapSlider(WidgetTester tester, int index, {required bool right}) async {
    final rect = tester.getRect(find.byType(Slider).at(index));
    await tester.tapAt(
      Offset(right ? rect.right - 4 : rect.left + 4, rect.center.dy),
    );
    await tester.pump();
  }

  testWidgets('the sliders change the pen\'s real settings', (tester) async {
    final panel = await pumpPanel(tester);
    final pen = panel.pen();

    // Thickness, opacity, tip sharpness, pressure sensitivity, stabilization.
    expect(find.byType(Slider), findsNWidgets(5));

    await tapSlider(tester, 0, right: true);
    expect(pen.options.size, closeTo(pen.sizeMax, 0.3));
    // 25 units of a 1000 unit, 210 mm page
    expect(find.text('5,25 mm'), findsOneWidget);
    await tapSlider(tester, 0, right: false);
    expect(pen.options.size, closeTo(pen.sizeMin, 0.3));

    await tapSlider(tester, 1, right: false);
    expect(pen.color.a, closeTo(0.1, 0.03));
    await tapSlider(tester, 1, right: true);
    expect(pen.color.a, closeTo(1, 0.03));

    await tapSlider(tester, 2, right: false);
    expect(pen.tipSharpness, 0);
    expect(pen.strokeOptions.end.taperEnabled, isFalse);
    await tapSlider(tester, 2, right: true);
    expect(pen.tipSharpness, 1);
    expect(pen.strokeOptions.end.taperEnabled, isTrue);

    await tapSlider(tester, 3, right: false);
    expect(pen.options.thinning, lessThan(0.05));
    expect(find.text('0%'), findsWidgets);

    await tapSlider(tester, 4, right: true);
    expect(pen.options.streamline, greaterThan(0.95));
  });

  testWidgets('each of the six pens can be chosen', (tester) async {
    final panel = await pumpPanel(tester);
    final start = panel.pen()..color = const Color(0xFF2563EB);
    expect(PenStyles.of(start), PenStyle.fountain);

    Future<Pen> choose(String label) async {
      await tester.tap(find.text(label).first);
      await tester.pump();
      return panel.pen();
    }

    var pen = await choose(DefterStrings.styleBrush);
    expect(pen.kind, PenKind.brush);
    // Stored like a fountain pen line, so older versions can read it.
    expect(pen.toolId, ToolId.fountainPen);
    // the colour in use goes with the pen
    expect(pen.color, const Color(0xFF2563EB));
    expect(find.byType(Slider), findsNWidgets(5));

    pen = await choose(DefterStrings.styleBallpoint);
    expect(pen.kind, PenKind.ballpoint);
    // no tip sharpness for the ballpoint
    expect(find.byType(Slider), findsNWidgets(4));
    expect(find.text(DefterStrings.tipSharpnessLabel), findsNothing);

    pen = await choose(DefterStrings.styleCalligraphy);
    expect(pen.kind, PenKind.calligraphy);
    expect(find.byType(Slider), findsNWidgets(4));
    expect(find.byType(PressureCurveEditor), findsOneWidget);

    pen = await choose(DefterStrings.stylePencil);
    expect(pen, isA<Pencil>());
    // thickness, pressure sensitivity, stabilization; no curve
    expect(find.byType(Slider), findsNWidgets(3));
    expect(find.byType(PressureCurveEditor), findsNothing);

    pen = await choose(DefterStrings.styleMarker);
    expect(pen, isA<Highlighter>());
    // the marker keeps its own see-through colour
    expect(pen.color.a, lessThan(1));
    expect(find.byType(Slider), findsNWidgets(2));
    expect(find.text(DefterStrings.opacityLabel), findsNothing);

    pen = await choose(DefterStrings.styleFountain);
    expect(pen.kind, PenKind.fountain);
  });

  testWidgets('reset puts the pen and the curve back', (tester) async {
    final panel = await pumpPanel(tester);
    final pen = panel.pen();
    pen.options.size = 20;
    pen.tipSharpness = 0;
    stows.pressureCurve.value = PressureCurve.linear.encode();

    await tester.tap(find.text(DefterStrings.reset));
    await tester.pump();
    expect(pen.options.size, 5);
    expect(pen.tipSharpness, 0.75);
    expect(pen.options.thinning, 0.5);
    expect(stows.pressureCurve.value, isEmpty);
    expect(PenFeel.curve, PressureCurve.standard);
  });

  testWidgets('dragging a point of the pressure curve changes it', (
    tester,
  ) async {
    await pumpPanel(tester);
    final editor = find.byType(PressureCurveEditor);
    final rect = tester.getRect(editor);
    final from =
        rect.topLeft +
        PressureCurveEditor.pointAt(PressureCurve.standard, 2, rect.size);

    // The middle point, pulled down to the bottom of the graph.
    await tester.dragFrom(from, Offset(0, rect.height));
    await tester.pump();

    final curve = PenFeel.curve;
    // it can't go below the point before it
    expect(curve.ys[1], closeTo(curve.ys[0], 1e-9));
    expect(curve.ys[0], PressureCurve.standard.ys[0]);
    expect(curve.ys[2], PressureCurve.standard.ys[2]);
    // saved for the next line and the next start
    expect(PressureCurve.parse(stows.pressureCurve.value), curve);
    expect(curve, isNot(PressureCurve.standard));
  });

  test('the curve graph maps a touch to a point and a height', () {
    const size = Size(220, 120);
    const curve = PressureCurve.standard;
    final third = PressureCurveEditor.pointAt(curve, 3, size);
    final moved = PressureCurveEditor.dragged(
      curve,
      third + const Offset(3, -2),
      size,
    );
    // the nearest point sideways is the third one
    expect(moved.ys[0], curve.ys[0]);
    expect(moved.ys[1], curve.ys[1]);
    expect(moved.ys[2], greaterThan(curve.ys[2]));
    expect(moved.ys[3], curve.ys[3]);
    // the first point is fixed: a touch at the far left moves the second
    final left = PressureCurveEditor.dragged(curve, const Offset(0, 60), size);
    expect(left.ys[0], isNot(curve.ys[0]));
  });

  testWidgets('the technical tools switch the real settings', (tester) async {
    final panel = await pumpPanel(tester);

    final tools = {
      DefterStrings.toolShapes: stows.autoShapes,
      DefterStrings.toolAngle: stows.angleGuide,
      DefterStrings.toolRuler: stows.rulerMode,
      DefterStrings.toolMeasure: stows.measureMode,
      DefterStrings.toolDimension: stows.dimensionMode,
    };
    for (final MapEntry(key: label, value: pref) in tools.entries) {
      expect(pref.value, isFalse, reason: label);
      await tester.tap(find.text(label));
      await tester.pump();
      expect(pref.value, isTrue, reason: label);
      await tester.tap(find.text(label));
      await tester.pump();
      expect(pref.value, isFalse, reason: label);
    }

    // Straight lines are on to begin with.
    expect(stows.autoStraightenLines.value, isTrue);
    await tester.tap(find.text(DefterStrings.toolStraightLine));
    await tester.pump();
    expect(stows.autoStraightenLines.value, isFalse);

    await tester.tap(find.text(DefterStrings.toolGrid));
    expect(panel.calls, ['grid']);
  });

  testWidgets('the advanced switches, the colours and closing work', (
    tester,
  ) async {
    final panel = await pumpPanel(tester);

    final switches = find.byType(Switch);
    expect(switches, findsNWidgets(3));
    final prefs = [
      stows.shapeHoldToSnap,
      stows.shapeAutoCorrect,
      stows.shapeSnapEndpoints,
    ];
    for (var i = 0; i < 3; i++) {
      expect(prefs[i].value, isTrue);
      await tester.tap(switches.at(i));
      await tester.pump();
      expect(prefs[i].value, isFalse, reason: '$i');
    }

    await tester.tap(find.text(DefterStrings.penGestures));
    await tester.pumpAndSettle();
    expect(find.byType(PenGesturesDialog), findsOneWidget);
    final before = stows.stylusAction.value;
    addTearDown(() => stows.stylusAction.value = before);
    await tester.tap(find.text(DefterStrings.stylusUndo));
    await tester.pumpAndSettle();
    expect(stows.stylusAction.value, isNot(before));
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip(DefterStrings.colorPicker));
    await tester.tap(find.byTooltip(DefterStrings.close));
    expect(panel.calls, ['colors', 'close']);

    // The preview folds away and comes back.
    expect(find.byType(CustomPaint), findsWidgets);
    await tester.tap(find.byTooltip(DefterStrings.preview));
    await tester.pump();
    expect(stows.penPreviewCollapsed.value, isTrue);
    expect(find.text(DefterStrings.preview), findsOneWidget);
  });

  testWidgets('a profile sets the pen with one tap', (tester) async {
    final panel = await pumpPanel(tester);
    // On a wide screen the profiles have their own card.
    expect(find.byType(GnPenProfiles), findsOneWidget);
    expect(find.text(DefterStrings.penProfiles), findsOneWidget);

    await tester.tap(find.text(DefterStrings.profileTechnical));
    await tester.pump();
    var pen = panel.pen();
    expect(pen.kind, PenKind.ballpoint);
    expect(pen.options.size, 3);
    expect(pen.options.thinning, 0);
    expect(pen.options.streamline, 0.75);

    await tester.tap(find.text(DefterStrings.profileHeading));
    await tester.pump();
    pen = panel.pen();
    expect(pen.kind, PenKind.fountain);
    expect(pen.options.size, 9);
    expect(pen.tipSharpness, 0.5);

    await tester.tap(find.text(DefterStrings.profileSketch));
    await tester.pump();
    expect(panel.pen(), isA<Pencil>());
  });

  testWidgets('profiles can be added, updated, renamed and deleted', (
    tester,
  ) async {
    final panel = await pumpPanel(tester);
    final pen = panel.pen();
    pen.options.size = 7;

    await tester.tap(find.byTooltip(DefterStrings.addProfile));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Kırmızı kalem');
    await tester.tap(find.text(DefterStrings.save));
    await tester.pumpAndSettle();

    expect(find.text('Kırmızı kalem'), findsOneWidget);
    var profiles = PenProfiles.load();
    expect(profiles, hasLength(7));
    expect(profiles.last.name, 'Kırmızı kalem');
    expect(profiles.last.size, 7);
    expect(profiles.last.style, PenStyle.fountain);

    Future<void> menu(String item) async {
      // the new profile is the last row
      await tester.tap(find.byIcon(Icons.more_vert).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text(item));
      await tester.pumpAndSettle();
    }

    pen.options.size = 11;
    await menu(DefterStrings.profileUpdate);
    profiles = PenProfiles.load();
    expect(profiles.last.size, 11);
    expect(profiles.last.name, 'Kırmızı kalem');

    await menu(DefterStrings.profileRename);
    await tester.enterText(find.byType(TextField), 'Düzeltme');
    await tester.tap(find.text(DefterStrings.save));
    await tester.pumpAndSettle();
    expect(PenProfiles.load().last.name, 'Düzeltme');
    expect(find.text('Düzeltme'), findsOneWidget);

    await menu(DefterStrings.profileDelete);
    expect(PenProfiles.load(), hasLength(6));
    expect(find.text('Düzeltme'), findsNothing);
  });

  testWidgets('on a narrow screen the profiles go under the settings', (
    tester,
  ) async {
    await pumpPanel(tester, screen: const Size(700, 1900));
    expect(tester.takeException(), isNull);
    expect(find.byType(GnPenProfiles), findsOneWidget);
    final panel = tester.getRect(find.byType(GnPenSettings));
    expect(panel.width, lessThanOrEqualTo(700));
    final profiles = tester.getRect(find.byType(GnPenProfiles));
    final behaviours = tester.getRect(
      find.text(DefterStrings.advancedBehaviours),
    );
    expect(profiles.top, greaterThan(behaviours.bottom));
  });

  testWidgets('the grid tile shows whether the page is squared', (
    tester,
  ) async {
    int switchedOn() => tester
        .widgetList<Semantics>(find.byType(Semantics))
        .where((semantics) => semantics.properties.toggled == true)
        .length;

    await pumpPanel(tester, gridOn: false);
    final without = switchedOn();
    await pumpPanel(tester, gridOn: true);
    expect(switchedOn(), without + 1);
  });

  test('the preview line has points that vary with pressure', () {
    const size = Size(200, 80);
    final withPressure = PenPreviewPainter.samplePoints(size, pressure: true);
    final without = PenPreviewPainter.samplePoints(size, pressure: false);
    expect(withPressure.first.pressure, isNotNull);
    expect(without.first.pressure, isNull);
    expect(withPressure.length, without.length);

    // The nib's line is thick and thin by its direction.
    final nib = PenPreviewPainter.samplePoints(size, pressure: true, nib: true);
    final pressures = nib.map((p) => p.pressure!).toList();
    expect(pressures.reduce((a, b) => a > b ? a : b), greaterThan(0.8));
    expect(pressures.reduce((a, b) => a < b ? a : b), lessThan(0.6));
  });

  test('the profile line is drawn with the profile\'s own settings', () {
    final profiles = PenProfiles.builtIn();
    final notes = PenProfilePainter.optionsFor(profiles[0]);
    final heading = PenProfilePainter.optionsFor(profiles[1]);
    expect(heading.size, greaterThan(notes.size));
    expect(notes.end.taperEnabled, isTrue);
    // the technical pen is even and blunt
    final technical = PenProfilePainter.optionsFor(profiles[3]);
    expect(technical.thinning, 0);
    expect(technical.end.taperEnabled, isFalse);
  });
}
