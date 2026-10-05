import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saber/data/flavor_config.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/tools/eraser.dart';
import 'package:saber/data/tools/highlighter.dart';
import 'package:saber/data/tools/pen.dart';
import 'package:saber/data/tools/pen_feel.dart';
import 'package:saber/data/tools/pen_styles.dart';
import 'package:saber/data/tools/pencil.dart';
import 'package:saber/data/tools/shape_pen.dart';
import 'package:sbn/tool_id.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlavorConfig.setup();

  tearDown(PenProfiles.restore);

  test('each of the six pens is made and told apart', () {
    for (final style in PenStyle.values) {
      final pen = PenStyles.create(style);
      expect(PenStyles.of(pen), style, reason: '$style');
      expect(PenStyles.name(style), isNotEmpty);
    }
    expect(PenStyles.create(PenStyle.pencil), isA<Pencil>());
    expect(PenStyles.create(PenStyle.marker), isA<Highlighter>());
    expect(PenStyles.of(ShapePen()), isNull);
    expect(PenStyles.of(Eraser()), isNull);
  });

  test('brush and calligraphy lines are saved as fountain pen lines', () {
    // so a note stays readable by versions without these pens
    expect(Pen.brushPen().toolId, ToolId.fountainPen);
    expect(Pen.calligraphyPen().toolId, ToolId.fountainPen);
    expect(Pen.calligraphyPen().kind, PenKind.calligraphy);
    expect(Pen.calligraphyPen().variant, PenVariant.calligraphy);
    expect(Pen.fountainPen().variant, PenVariant.plain);
  });

  test('a profile sets the pen and is recognised on it afterwards', () {
    final pen = Pen.fountainPen();
    final saved = PenProfile.capture(pen);
    addTearDown(() => saved.applyTo(pen));

    final profile = PenProfile(
      style: PenStyle.fountain,
      size: 9,
      opacity: 0.5,
      sharpness: 0.25,
      sensitivity: 0.8,
      stabilization: 0.3,
    );
    pen.color = const Color(0xFF2563EB);
    profile.applyTo(pen);
    expect(pen.options.size, 9);
    expect(pen.options.thinning, 0.8);
    expect(pen.options.streamline, 0.3);
    expect(pen.tipSharpness, 0.25);
    // the colour is kept, only made see-through
    expect(pen.color.withValues(alpha: 1), const Color(0xFF2563EB));
    expect(pen.color.a, closeTo(0.5, 0.01));
    expect(profile.matches(pen), isTrue);

    pen.options.size = 10;
    expect(profile.matches(pen), isFalse);
    pen.options.size = 9;
    expect(profile.matches(Pen.ballpointPen()), isFalse);

    final again = PenProfile.capture(pen, id: 'x', name: 'Mine');
    expect(again.size, 9);
    expect(again.sharpness, 0.25);
    expect(again.opacity, closeTo(0.5, 0.01));
    expect(again.style, PenStyle.fountain);
  });

  test('a size outside what the pen allows is brought back in', () {
    final marker = Highlighter();
    final before = marker.options.size;
    addTearDown(() => marker.options.size = before);
    PenProfile(
      style: PenStyle.marker,
      size: 3,
      sensitivity: 0.5,
      stabilization: 0.5,
    ).applyTo(marker);
    expect(marker.options.size, marker.sizeMin);
  });

  test('the built-in profiles each match one of the six pens', () {
    final profiles = PenProfiles.builtIn();
    expect(profiles, hasLength(6));
    expect(profiles.map((p) => p.id).toSet(), hasLength(6));
    for (final profile in profiles) {
      expect(profile.name, isNotEmpty);
      expect(profile.subtitle, isNotEmpty);
      final pen = PenStyles.create(profile.style);
      final saved = PenProfile.capture(pen);
      profile.applyTo(pen);
      expect(profile.matches(pen), isTrue, reason: profile.id);
      saved.applyTo(pen);
    }
  });

  test('profiles are saved, read back and restored', () {
    expect(PenProfiles.load().map((p) => p.id), contains('notes'));

    final profiles = PenProfiles.load()
      ..removeWhere((p) => p.id == 'marker')
      ..add(
        PenProfile(
          id: PenProfiles.newId(PenProfiles.builtIn()),
          name: 'Kırmızı kalem',
          subtitle: 'Düzeltme',
          style: PenStyle.calligraphy,
          size: 14,
          opacity: 0.6,
          sensitivity: 0.7,
          stabilization: 0.2,
        ),
      );
    PenProfiles.save(profiles);

    final loaded = PenProfiles.load();
    expect(loaded, hasLength(6));
    expect(loaded.map((p) => p.id), isNot(contains('marker')));
    final mine = loaded.last;
    expect(mine.id, 'custom7');
    expect(mine.name, 'Kırmızı kalem');
    expect(mine.style, PenStyle.calligraphy);
    expect(mine.size, 14);
    expect(mine.opacity, closeTo(0.6, 1e-9));

    PenProfiles.restore();
    expect(PenProfiles.load().map((p) => p.id), contains('marker'));
    expect(stows.penProfiles.value, isEmpty);
  });

  test('saved profiles that cannot be read are left out, not guessed', () {
    expect(PenProfiles.decode(''), isNull);
    expect(PenProfiles.decode('not json'), isNull);
    expect(PenProfiles.decode('{"a":1}'), isNull);
    final some = PenProfiles.decode(
      '[{"style":"fountain","size":4,"name":"ok"},'
      '{"style":"quill","size":4},{"style":"brush","size":-1},7]',
    )!;
    expect(some, hasLength(1));
    expect(some.single.name, 'ok');
    expect(some.single.sensitivity, 0.5);
  });

  test('resetting a pen gives it the settings it started with', () {
    final pen = Pen.brushPen();
    final saved = PenProfile.capture(pen);
    addTearDown(() => saved.applyTo(pen));
    pen.options.size = 30;
    pen.tipSharpness = 0;
    PenStyles.defaults(PenStyle.brush).applyTo(pen);
    expect(pen.options.size, 12);
    expect(pen.tipSharpness, 0.75);
    expect(pen.options.thinning, 0.5);
  });
}
