import 'dart:convert';

import 'package:perfect_freehand/perfect_freehand.dart';
import 'package:saber/data/defter_strings.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/tools/_tool.dart';
import 'package:saber/data/tools/highlighter.dart';
import 'package:saber/data/tools/pen.dart';
import 'package:saber/data/tools/pen_feel.dart';
import 'package:saber/data/tools/pencil.dart';

/// The six pens of the pen panel.
enum PenStyle { fountain, ballpoint, brush, pencil, marker, calligraphy }

/// What the pen panel needs to know about each [PenStyle].
abstract class PenStyles {
  /// Which of the six pens [tool] is; null for anything else (the shape
  /// pen, the eraser, ...).
  static PenStyle? of(Tool tool) {
    if (tool is Highlighter) return PenStyle.marker;
    if (tool is Pencil) return PenStyle.pencil;
    if (tool is! Pen) return null;
    return switch (tool.kind) {
      PenKind.fountain => PenStyle.fountain,
      PenKind.ballpoint => PenStyle.ballpoint,
      PenKind.brush => PenStyle.brush,
      PenKind.calligraphy => PenStyle.calligraphy,
      null => null,
    };
  }

  /// The pen of [style], with the settings it was last used with.
  static Pen create(PenStyle style) => switch (style) {
    PenStyle.fountain => Pen.fountainPen(),
    PenStyle.ballpoint => Pen.ballpointPen(),
    PenStyle.brush => Pen.brushPen(),
    PenStyle.calligraphy => Pen.calligraphyPen(),
    PenStyle.pencil => Pencil.currentPencil,
    PenStyle.marker => Highlighter.currentHighlighter,
  };

  static String name(PenStyle style) => switch (style) {
    PenStyle.fountain => DefterStrings.styleFountain,
    PenStyle.ballpoint => DefterStrings.styleBallpoint,
    PenStyle.brush => DefterStrings.styleBrush,
    PenStyle.pencil => DefterStrings.stylePencil,
    PenStyle.marker => DefterStrings.styleMarker,
    PenStyle.calligraphy => DefterStrings.styleCalligraphy,
  };

  static Object icon(PenStyle style) => switch (style) {
    PenStyle.fountain => Pen.fountainPenIcon,
    PenStyle.ballpoint => Pen.ballpointPenIcon,
    PenStyle.brush => Pen.brushPenIcon,
    PenStyle.pencil => Pencil.pencilIcon,
    PenStyle.marker => Highlighter.highlighterIcon,
    PenStyle.calligraphy => Pen.calligraphyPenIcon,
  };

  /// Whether the colour of [style] can be made see-through in the panel.
  /// The marker is always see-through and the pencil is drawn by a shader.
  static bool hasOpacity(PenStyle style) =>
      style != PenStyle.marker && style != PenStyle.pencil;

  static bool hasSharpness(PenStyle style) =>
      style == PenStyle.fountain || style == PenStyle.brush;

  static bool hasPressure(PenStyle style) => style != PenStyle.marker;

  /// Whether the pressure curve of the panel shapes the lines of [style].
  static bool hasCurve(PenStyle style) =>
      style != PenStyle.marker && style != PenStyle.pencil;

  /// The settings [style] starts with, used by "reset".
  static PenProfile defaults(PenStyle style) {
    final plain = StrokeOptions();
    return switch (style) {
      PenStyle.fountain => PenProfile(
        style: style,
        size: 5,
        sensitivity: 0.5,
        sharpness: 0.75,
        stabilization: plain.streamline,
      ),
      PenStyle.ballpoint => PenProfile(
        style: style,
        size: 5,
        sensitivity: 0.5,
        stabilization: plain.streamline,
      ),
      PenStyle.brush => PenProfile(
        style: style,
        size: 12,
        sensitivity: 0.5,
        sharpness: 0.75,
        stabilization: plain.streamline,
      ),
      PenStyle.pencil => PenProfile(
        style: style,
        size: 5,
        sensitivity: plain.thinning,
        stabilization: 0.1,
      ),
      PenStyle.marker => PenProfile(
        style: style,
        size: 50,
        sensitivity: plain.thinning,
        stabilization: plain.streamline,
      ),
      PenStyle.calligraphy => PenProfile(
        style: style,
        size: 10,
        sensitivity: 0.5,
        stabilization: plain.streamline,
      ),
    };
  }
}

/// A pen with all its settings, to go back to with one tap.
class PenProfile {
  PenProfile({
    this.id = '',
    this.name = '',
    this.subtitle = '',
    required this.style,
    required this.size,
    this.opacity = 1,
    this.sharpness = 0,
    required this.sensitivity,
    required this.stabilization,
  });

  final String id;
  String name;
  String subtitle;
  final PenStyle style;

  /// The pen size in page units (see `PenAssist.mmPerUnit`).
  final double size;
  final double opacity, sharpness, sensitivity, stabilization;

  /// The settings [pen] has right now.
  factory PenProfile.capture(
    Pen pen, {
    String id = '',
    String name = '',
    String subtitle = '',
  }) {
    final style = PenStyles.of(pen) ?? PenStyle.fountain;
    return PenProfile(
      id: id,
      name: name,
      subtitle: subtitle,
      style: style,
      size: pen.options.size,
      opacity: PenStyles.hasOpacity(style) ? pen.color.a : 1,
      sharpness: pen.tipSharpness,
      sensitivity: pen.options.thinning,
      stabilization: pen.options.streamline,
    );
  }

  /// Gives [pen] (a pen of [style]) these settings. Its colour is kept;
  /// only how see-through it is changes.
  void applyTo(Pen pen) {
    pen.options
      ..size = size.clamp(pen.sizeMin, pen.sizeMax)
      ..streamline = stabilization.clamp(0.0, 1.0);
    if (PenStyles.hasPressure(style)) {
      pen.options.thinning = sensitivity.clamp(0.0, 1.0);
    }
    if (PenStyles.hasSharpness(style)) pen.tipSharpness = sharpness;
    if (PenStyles.hasOpacity(style)) {
      pen.color = pen.color.withValues(alpha: opacity.clamp(0.1, 1.0));
    }
  }

  static bool _near(double a, double b) => (a - b).abs() < 0.011;

  /// Whether [pen] is set exactly as this profile sets it.
  bool matches(Pen pen) {
    final style = PenStyles.of(pen);
    if (style != this.style) return false;
    return _near(pen.options.size, size.clamp(pen.sizeMin, pen.sizeMax)) &&
        _near(pen.options.streamline, stabilization) &&
        (!PenStyles.hasPressure(style!) ||
            _near(pen.options.thinning, sensitivity)) &&
        (!PenStyles.hasSharpness(style) ||
            _near(pen.tipSharpness, sharpness)) &&
        (!PenStyles.hasOpacity(style) || _near(pen.color.a, opacity));
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'subtitle': subtitle,
    'style': style.name,
    'size': size,
    'opacity': opacity,
    'sharpness': sharpness,
    'sensitivity': sensitivity,
    'stabilization': stabilization,
  };

  static PenProfile? fromJson(Object? json) {
    if (json is! Map) return null;
    PenStyle? style;
    for (final candidate in PenStyle.values) {
      if (candidate.name == json['style']) style = candidate;
    }
    final size = json['size'];
    if (style == null || size is! num || size <= 0) return null;
    double number(String key, double fallback) {
      final value = json[key];
      return value is num ? value.toDouble().clamp(0.0, 1.0) : fallback;
    }

    return PenProfile(
      id: '${json['id'] ?? ''}',
      name: '${json['name'] ?? ''}',
      subtitle: '${json['subtitle'] ?? ''}',
      style: style,
      size: size.toDouble(),
      opacity: number('opacity', 1),
      sharpness: number('sharpness', 0),
      sensitivity: number('sensitivity', 0.5),
      stabilization: number('stabilization', 0.5),
    );
  }
}

/// The list of pen profiles: the ones the app comes with until the list is
/// changed, then whatever was saved.
abstract class PenProfiles {
  /// The profiles the app comes with, named in the current language.
  static List<PenProfile> builtIn() {
    final plain = StrokeOptions();
    return [
      PenProfile(
        id: 'notes',
        name: DefterStrings.profileNotes,
        subtitle: DefterStrings.profileNotesHint,
        style: PenStyle.fountain,
        size: 4,
        sensitivity: 0.5,
        sharpness: 0.75,
        stabilization: 0.25,
      ),
      PenProfile(
        id: 'heading',
        name: DefterStrings.profileHeading,
        subtitle: DefterStrings.profileHeadingHint,
        style: PenStyle.fountain,
        size: 9,
        sensitivity: 0.5,
        sharpness: 0.5,
        stabilization: 0.25,
      ),
      PenProfile(
        id: 'sketch',
        name: DefterStrings.profileSketch,
        subtitle: DefterStrings.profileSketchHint,
        style: PenStyle.pencil,
        size: 5,
        sensitivity: plain.thinning,
        stabilization: 0.5,
      ),
      PenProfile(
        id: 'technical',
        name: DefterStrings.profileTechnical,
        subtitle: DefterStrings.profileTechnicalHint,
        style: PenStyle.ballpoint,
        size: 3,
        sensitivity: 0,
        stabilization: 0.75,
      ),
      PenProfile(
        id: 'engineering',
        name: DefterStrings.profileEngineering,
        subtitle: DefterStrings.profileEngineeringHint,
        style: PenStyle.ballpoint,
        size: 5,
        sensitivity: 0,
        stabilization: 0.5,
      ),
      PenProfile(
        id: 'marker',
        name: DefterStrings.profileMarker,
        subtitle: DefterStrings.profileMarkerHint,
        style: PenStyle.marker,
        size: 50,
        sensitivity: plain.thinning,
        stabilization: plain.streamline,
      ),
    ];
  }

  static String encode(List<PenProfile> profiles) =>
      jsonEncode([for (final profile in profiles) profile.toJson()]);

  /// Reads [encode]'s text. Entries that can't be read are left out;
  /// null if the text as a whole can't be read.
  static List<PenProfile>? decode(String text) {
    if (text.isEmpty) return null;
    try {
      final json = jsonDecode(text);
      if (json is! List) return null;
      return [
        for (final entry in json)
          if (PenProfile.fromJson(entry) case final profile?) profile,
      ];
    } on FormatException {
      return null;
    }
  }

  static List<PenProfile> load() =>
      decode(stows.penProfiles.value) ?? builtIn();

  static void save(List<PenProfile> profiles) =>
      stows.penProfiles.value = encode(profiles);

  /// Forgets every change: back to [builtIn].
  static void restore() => stows.penProfiles.value = '';

  /// An id no profile in [profiles] has yet.
  static String newId(List<PenProfile> profiles) {
    var n = profiles.length + 1;
    while (profiles.any((profile) => profile.id == 'custom$n')) {
      n++;
    }
    return 'custom$n';
  }
}
