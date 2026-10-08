import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:perfect_freehand/perfect_freehand.dart';
import 'package:saber/components/home/home_layout_button.dart';
import 'package:saber/components/home/sort_button.dart';
import 'package:saber/components/navbar/responsive_navbar.dart';
import 'package:saber/data/codecs/base64_codec.dart';
import 'package:saber/data/flavor_config.dart';
import 'package:saber/data/quota.dart';
import 'package:saber/data/sentry/sentry_consent.dart';
import 'package:saber/data/tools/highlighter.dart';
import 'package:saber/data/tools/pen.dart';
import 'package:sbn/canvas_background_pattern.dart';
import 'package:sbn/tool_id.dart';
import 'package:stow/stow.dart';
import 'package:stow_codecs/stow_codecs.dart';
import 'package:stow_plain/stow_plain.dart';
import 'package:stow_secure/stow_secure.dart';

/// If false, all stows are stuck at their default values.
var _isOnMainIsolate = false;

final stows = Stows();

class Stows {
  new() {
    recentColorsLength.addListener(() {
      // truncate if needed
      while (recentColorsLength.value < recentColorsPositioned.value.length) {
        // remove oldest color
        final removed = recentColorsChronological.value.removeAt(0);
        recentColorsPositioned.value.remove(removed);
      }
    });
  }

  /// Call this before [runApp] to set [_isOnMainIsolate] to true.
  static void markAsOnMainIsolate() {
    _isOnMainIsolate = true;
  }

  final log = Logger('Stows');

  final customDataDir = PlainStow<String?>(
    'customDataDir',
    null,
    volatile: !_isOnMainIsolate,
  );

  final allowInsecureConnections = SecureStow.bool(
    'allowInsecureConnections',
    false,
    volatile: !_isOnMainIsolate,
  );
  final url = SecureStow('url', '', volatile: !_isOnMainIsolate);
  final username = SecureStow('username', '', volatile: !_isOnMainIsolate);

  /// the password used to login to Nextcloud
  final ncPassword = SecureStow('ncPassword', '', volatile: !_isOnMainIsolate);

  /// the password used to encrypt/decrypt notes
  final encPassword = SecureStow(
    'encPassword',
    '',
    volatile: !_isOnMainIsolate,
  );

  /// Whether the user is logged in and has provided both passwords.
  /// Please ensure that the relevant Prefs are loaded before using this.
  bool get loggedIn =>
      username.value.isNotEmpty &&
      ncPassword.value.isNotEmpty &&
      encPassword.value.isNotEmpty;

  final key = SecureStow('key', '', volatile: !_isOnMainIsolate);
  final iv = SecureStow('iv', '', volatile: !_isOnMainIsolate);

  final pfp = PlainStow<Uint8List?>(
    'pfp',
    null,
    codec: const Base64StowCodec(),
    volatile: !_isOnMainIsolate,
  );
  final syncInBackground = PlainStow(
    'syncInBackground',
    true,
    volatile: !_isOnMainIsolate,
  );

  final appTheme = PlainStow(
    'appTheme',
    ThemeMode.system,
    codec: const EnumCodec(ThemeMode.values),
    volatile: !_isOnMainIsolate,
  );

  /// The type of platform to theme. Default value is [defaultTargetPlatform].
  final platform = PlainStow(
    'platform',
    defaultTargetPlatform,
    codec: const EnumCodec(TargetPlatform.values),
    volatile: !_isOnMainIsolate,
  );
  final layoutSize = PlainStow(
    'layoutSize',
    LayoutSize.auto,
    codec: LayoutSize.codec,
    volatile: !_isOnMainIsolate,
  );

  /// The accent color of the app. If 0, the system accent color will be used.
  final accentColor = PlainStow<Color?>(
    'accentColor',
    null,
    codec: const ColorCodec(),
    volatile: !_isOnMainIsolate,
  );
  final hyperlegibleFont = PlainStow(
    'hyperlegibleFont',
    false,
    volatile: !_isOnMainIsolate,
  );

  /// The Goodnotes-style editor: a dark top bar with tabs and tools, and the
  /// options of the tool in use hanging from it over the page.
  final editorGnLayout = PlainStow(
    'editorGnLayout',
    true,
    volatile: !_isOnMainIsolate,
  );

  final editorToolbarAlignment = PlainStow(
    'editorToolbarAlignment',
    AxisDirection.up,
    codec: const EnumCodec(AxisDirection.values),
    volatile: !_isOnMainIsolate,
  );
  final editorToolbarShowInFullscreen = PlainStow(
    'editorToolbarShowInFullscreen',
    true,
    volatile: !_isOnMainIsolate,
  );
  /// The radius of the eraser, in page units.
  final eraserSize = PlainStow(
    'eraserSize',
    10.0,
    volatile: !_isOnMainIsolate,
  );

  /// Whether the eraser rubs out only what it passes over (true) or takes
  /// away every stroke it touches as a whole (false).
  final eraserPrecise = PlainStow(
    'eraserPrecise',
    true,
    volatile: !_isOnMainIsolate,
  );

  /// The OpenRouter key used for handwriting recognition. Empty if not set.
  final openRouterApiKey = PlainStow<String>(
    'openRouterApiKey',
    '',
    volatile: !_isOnMainIsolate,
  );

  /// The OpenRouter model used for handwriting recognition.
  final handwritingModel = PlainStow<String>(
    'handwritingModel',
    'google/gemini-3.8-flash',
    volatile: !_isOnMainIsolate,
  );
  final editorFingerDrawing = PlainStow(
    'editorFingerDrawing',
    true,
    volatile: !_isOnMainIsolate,
  );
  final editorAutoInvert = PlainStow(
    'editorAutoInvert',
    true,
    volatile: !_isOnMainIsolate,
  );
  final preferGreyscale = PlainStow(
    'preferGreyscale',
    false,
    volatile: !_isOnMainIsolate,
  );
  final editorPromptRename = PlainStow(
    'editorPromptRename',
    isDesktop,
    volatile: !_isOnMainIsolate,
  );
  final autosaveDelay = PlainStow(
    'autosaveDelay',
    10000,
    volatile: !_isOnMainIsolate,
  );
  /// Whether the line is drawn a little ahead of the pen tip while writing.
  ///
  /// (Its key changed when the prediction was rewritten: the first version
  /// hardly ever worked, so many people had it turned off, and the new one
  /// starts on for everyone. It can be turned off again in Settings.)
  final penPrediction = PlainStow(
    'penPredictionV2',
    true,
    volatile: !_isOnMainIsolate,
  );

  /// Whether straight lines drawn with the shape pen get an arrowhead.
  final shapePenArrows = PlainStow(
    'shapePenArrows',
    false,
    volatile: !_isOnMainIsolate,
  );

  /// Hold the pen still after drawing a shape to straighten it, with the
  /// normal pens.
  /// Stretches a stylus' narrow pressure range over the full line width and
  /// falls back to speed based width when the pressure never changes.
  final pressureAuto = PlainStow(
    'pressureAuto',
    true,
    volatile: !_isOnMainIsolate,
  );

  final shapeHoldToSnap = PlainStow(
    'shapeHoldToSnap',
    true,
    volatile: !_isOnMainIsolate,
  );

  /// How long (milliseconds) the pen is held still before the shape snaps.
  final shapeHoldDelay = PlainStow(
    'shapeHoldDelay',
    600,
    volatile: !_isOnMainIsolate,
  );

  /// Recognise polygons, ellipses and arcs, not only the basic shapes.
  final advancedShapes = PlainStow(
    'advancedShapes',
    true,
    volatile: !_isOnMainIsolate,
  );

  /// Ends and corners of shapes snap to those of nearby shapes.
  final shapeSnapEndpoints = PlainStow(
    'shapeSnapEndpoints',
    true,
    volatile: !_isOnMainIsolate,
  );

  /// E-ink mode: shows notes and the app on imitation paper in greys. It is
  /// only how things are displayed; notes keep their own colours.
  final eInkMode = PlainStow(
    'eInkMode',
    false,
    volatile: !_isOnMainIsolate,
  );

  /// 0 = neutral paper, 1 = warm paper.
  final eInkPaperWarmth = PlainStow(
    'eInkPaperWarmth',
    0.4,
    volatile: !_isOnMainIsolate,
  );

  /// 0 = soft dark grey ink, 1 = near-black ink.
  final eInkInkDarkness = PlainStow(
    'eInkInkDarkness',
    0.8,
    volatile: !_isOnMainIsolate,
  );

  /// Strength of the paper grain, 0 to 1.
  final eInkTexture = PlainStow(
    'eInkTexture',
    0.3,
    volatile: !_isOnMainIsolate,
  );

  /// The short refresh on page turns and "refresh page".
  final eInkRefreshEffect = PlainStow(
    'eInkRefreshEffect',
    true,
    volatile: !_isOnMainIsolate,
  );

  /// How bright the app's window is while e-ink mode is on:
  /// 0 = leave it to the system, 1 = 70%, 2 = 50%, 3 = 35%.
  final eInkBrightness = PlainStow(
    'eInkBrightness',
    0,
    volatile: !_isOnMainIsolate,
  );

  /// Whether exports (PDF, PNG) use the e-ink look while e-ink mode is on.
  final eInkExport = PlainStow(
    'eInkExport',
    false,
    volatile: !_isOnMainIsolate,
  );

  /// Shows the pen latency recording button in the editor.
  final penProbe = PlainStow(
    'penProbe',
    false,
    volatile: !_isOnMainIsolate,
  );

  /// What a stylus button press (the pen's double tap, for example) does.
  /// An index into `StylusAction.values`.
  final stylusAction = PlainStow(
    'stylusAction',
    1, // StylusAction.toggleEraser
    volatile: !_isOnMainIsolate,
  );

  /// How many quick presses of the stylus button make one trigger (1 or 2).
  /// Some pens already send one event for their double tap.
  final stylusTapsNeeded = PlainStow(
    'stylusTapsNeeded',
    1,
    volatile: !_isOnMainIsolate,
  );

  /// Whether the editor shows the page thumbnails beside the page, on wide
  /// screens.
  final editorPageSidebar = PlainStow(
    'editorPageSidebar',
    false,
    volatile: !_isOnMainIsolate,
  );

  final shapeRecognitionDelay = PlainStow(
    'shapeRecognitionDelay',
    500,
    volatile: !_isOnMainIsolate,
  );
  final autoStraightenLines = PlainStow(
    'autoStraightenLines',
    true,
    volatile: !_isOnMainIsolate,
  );

  final printPageIndicators = PlainStow(
    'printPageIndicators',
    false,
    volatile: !_isOnMainIsolate,
  );

  final maxImageSize = PlainStow<double>(
    'maxImageSize',
    1000,
    volatile: !_isOnMainIsolate,
  );

  final autoClearWhiteboardOnExit = PlainStow(
    'autoClearWhiteboardOnExit',
    false,
    volatile: !_isOnMainIsolate,
  );

  final disableEraserAfterUse = PlainStow(
    'disableEraserAfterUse',
    false,
    volatile: !_isOnMainIsolate,
  );
  final hideFingerDrawingToggle = PlainStow(
    'hideFingerDrawingToggle',
    false,
    volatile: !_isOnMainIsolate,
  );

  /// People don't know to turn off finger drawing when using a stylus,
  /// so we can do it automatically.
  final autoDisableFingerDrawingWhenStylusDetected = PlainStow(
    'autoDisableFingerDrawingWhenStylusDetected',
    true,
    volatile: !_isOnMainIsolate,
  );

  final recentColorsChronological = PlainStow(
    'recentColorsChronological',
    <String>[],
    volatile: !_isOnMainIsolate,
  );
  final recentColorsPositioned = PlainStow(
    'recentColorsPositioned',
    <String>[],
    volatile: !_isOnMainIsolate,
  );
  final pinnedColors = PlainStow(
    'pinnedColors',
    <String>[],
    volatile: !_isOnMainIsolate,
  );
  final recentColorsDontSavePresets = PlainStow(
    'dontSavePresetColors',
    false,
    volatile: !_isOnMainIsolate,
  );
  final recentColorsLength = PlainStow(
    'recentColorsLength',
    5,
    volatile: !_isOnMainIsolate,
  );

  final lastTool = PlainStow(
    'lastTool',
    ToolId.fountainPen,
    codec: ToolId.codec,
    volatile: !_isOnMainIsolate,
  );
  static StrokeOptions _strokeOptionsFromJson(Object json) =>
      StrokeOptions.fromJson(json as Map<String, dynamic>);
  final lastFountainPenOptions = PlainStow.json(
        'lastFountainPenProperties',
        Pen.fountainPenOptions,
        fromJson: _strokeOptionsFromJson,
        volatile: !_isOnMainIsolate,
      ),
      lastBallpointPenOptions = PlainStow.json(
        'lastBallpointPenProperties',
        Pen.ballpointPenOptions,
        fromJson: _strokeOptionsFromJson,
        volatile: !_isOnMainIsolate,
      ),
      lastHighlighterOptions = PlainStow.json(
        'lastHighlighterProperties',
        Pen.highlighterOptions,
        fromJson: _strokeOptionsFromJson,
        volatile: !_isOnMainIsolate,
      ),
      lastPencilOptions = PlainStow.json(
        'lastPencilProperties',
        Pen.pencilOptions,
        fromJson: _strokeOptionsFromJson,
        volatile: !_isOnMainIsolate,
      ),
      lastShapePenOptions = PlainStow.json(
        'lastShapePenProperties',
        Pen.shapePenOptions,
        fromJson: _strokeOptionsFromJson,
        volatile: !_isOnMainIsolate,
      ),
      lastBrushPenOptions = PlainStow.json(
        'lastBrushPenProperties',
        Pen.brushPenOptions,
        fromJson: _strokeOptionsFromJson,
        volatile: !_isOnMainIsolate,
      ),
      lastCalligraphyPenOptions = PlainStow.json(
        'lastCalligraphyPenProperties',
        Pen.calligraphyPenOptions,
        fromJson: _strokeOptionsFromJson,
        volatile: !_isOnMainIsolate,
      );

  /// How pointed the ends of the fountain and brush pens' lines are, 0..1.
  final fountainTipSharpness = PlainStow(
        'fountainTipSharpness',
        0.75,
        volatile: !_isOnMainIsolate,
      ),
      brushTipSharpness = PlainStow(
        'brushTipSharpness',
        0.75,
        volatile: !_isOnMainIsolate,
      );

  /// Whether earlier states of notes are kept as they are written, so that
  /// they can be brought back (see `NoteVersions`).
  final versionHistory = PlainStow(
    'versionHistory',
    true,
    volatile: !_isOnMainIsolate,
  );

  /// What is remembered of the backup last made on this device (see
  /// `LastBackup`); empty if none was made.
  final lastBackup = PlainStow('lastBackup', '', volatile: !_isOnMainIsolate);

  /// The home screen with a sidebar, recent notes, folders and templates,
  /// shown first on tablets instead of the plain list of notes.
  final homeDashboard = PlainStow(
    'homeDashboard',
    true,
    volatile: !_isOnMainIsolate,
  );

  /// Which of the pens that share the fountain pen's [ToolId] was last
  /// used: an index into `PenVariant.values`.
  final lastPenVariant = PlainStow(
    'lastPenVariant',
    0,
    volatile: !_isOnMainIsolate,
  );

  /// The pressure curve of the pen panel (see `PressureCurve.encode`);
  /// empty for the standard one.
  final pressureCurve = PlainStow<String>(
    'pressureCurve',
    '',
    volatile: !_isOnMainIsolate,
  );

  /// The pen profiles of the pen panel as JSON; empty for the ones that
  /// come with the app.
  final penProfiles = PlainStow<String>(
    'penProfiles',
    '',
    volatile: !_isOnMainIsolate,
  );

  /// Ruler: every line is drawn straight from where the pen went down.
  final rulerMode = PlainStow('rulerMode', false, volatile: !_isOnMainIsolate);

  /// Angle guide: straight lines turn to the nearest 15 degrees.
  final angleGuide = PlainStow(
    'angleGuide',
    false,
    volatile: !_isOnMainIsolate,
  );

  /// Measuring: the length of what is being drawn is shown over the page.
  final measureMode = PlainStow(
    'measureMode',
    false,
    volatile: !_isOnMainIsolate,
  );

  /// Dimensions: straight lines, circles and rectangles get their size
  /// written next to them.
  final dimensionMode = PlainStow(
    'dimensionMode',
    false,
    volatile: !_isOnMainIsolate,
  );

  /// Circles, rectangles and polygons are recognised when the pen is
  /// lifted, without holding it still first.
  final autoShapes = PlainStow(
    'autoShapes',
    false,
    volatile: !_isOnMainIsolate,
  );

  /// Nearly regular shapes are made regular when they are recognised.
  final shapeAutoCorrect = PlainStow(
    'shapeAutoCorrect',
    true,
    volatile: !_isOnMainIsolate,
  );

  /// Whether the line preview of the pen panel is folded away.
  final penPreviewCollapsed = PlainStow(
    'penPreviewCollapsed',
    false,
    volatile: !_isOnMainIsolate,
  );
  final lastFountainPenColor = PlainStow(
        'lastFountainPenColor',
        Colors.black.toARGB32(),
        volatile: !_isOnMainIsolate,
      ),
      lastBallpointPenColor = PlainStow(
        'lastBallpointPenColor',
        Colors.black.toARGB32(),
        volatile: !_isOnMainIsolate,
      ),
      lastHighlighterColor = PlainStow(
        'lastHighlighterColor',
        Colors.yellow.withAlpha(Highlighter.alpha).toARGB32(),
        volatile: !_isOnMainIsolate,
      ),
      lastPencilColor = PlainStow(
        'lastPencilColor',
        Colors.black.toARGB32(),
        volatile: !_isOnMainIsolate,
      ),
      lastShapePenColor = PlainStow(
        'lastShapePenColor',
        Colors.black.toARGB32(),
        volatile: !_isOnMainIsolate,
      );
  final lastBackgroundPattern = PlainStow(
    'lastBackgroundPattern',
    CanvasBackgroundPattern.none,
    codec: const EnumCodec(CanvasBackgroundPattern.values),
    volatile: !_isOnMainIsolate,
  );
  static const defaultLineHeight = 40;
  static const defaultLineThickness = 3;
  final lastLineHeight = PlainStow(
    'lastLineHeight',
    defaultLineHeight,
    volatile: !_isOnMainIsolate,
  );
  final lastLineThickness = PlainStow(
    'lastLineThickness',
    defaultLineThickness,
    volatile: !_isOnMainIsolate,
  );
  final lastZoomLock = PlainStow(
        'lastZoomLock',
        false,
        volatile: !_isOnMainIsolate,
      ),
      lastSingleFingerPanLock = PlainStow(
        'lastSingleFingerPanLock',
        false,
        volatile: !_isOnMainIsolate,
      ),
      lastAxisAlignedPanLock = PlainStow(
        'lastAxisAlignedPanLock',
        false,
        volatile: !_isOnMainIsolate,
      );

  final homeLayout = PlainStow(
    'homeLayout',
    HomeLayout.masonryGrid,
    codec: HomeLayout.codec,
    volatile: !_isOnMainIsolate,
  );
  final browseSortMetric = PlainStow(
    'browseSortMetric',
    SortMetric.nameAToZ,
    codec: SortMetric.codec,
    volatile: !_isOnMainIsolate,
  );
  final recentFiles = PlainStow(
    'recentFiles',
    <String>[],
    volatile: !_isOnMainIsolate,
  );

  /// Notes marked as favourites, as file paths with their extension.
  final favoriteFiles = PlainStow(
    'favoriteFiles',
    <String>[],
    volatile: !_isOnMainIsolate,
  );

  /// File paths that have been deleted locally
  final fileSyncAlreadyDeleted = PlainStow(
    'fileSyncAlreadyDeleted',
    <String>{},
    volatile: !_isOnMainIsolate,
  );

  /// File paths that are known to be corrupted on Nextcloud
  final fileSyncCorruptFiles = PlainStow(
    'fileSyncCorruptFiles',
    <String>{},
    volatile: !_isOnMainIsolate,
  );

  /// Set when we want to resync everything.
  /// Files on the server older than this date will be
  /// reuploaded with the local version.
  /// By default, we resync everything uploaded before v0.18.4, since uploads before then resulted in 0B files.
  final fileSyncResyncEverythingDate = PlainStow(
    'fileSyncResyncEverythingDate',
    DateTime.parse('2023-12-10T10:06:31.000Z'),
    codec: const DateTimeCodec(),
    volatile: !_isOnMainIsolate,
  );

  /// The last storage quota that was fetched from Nextcloud
  final lastStorageQuota = PlainStow<Quota?>(
    'lastStorageQuota',
    null,
    codec: const QuotaCodec(),
    volatile: !_isOnMainIsolate,
  );

  final shouldCheckForUpdates = PlainStow(
    'shouldCheckForUpdates',
    FlavorConfig.shouldCheckForUpdatesByDefault && !Platform.isLinux,
    volatile: !_isOnMainIsolate,
  );
  final shouldAlwaysAlertForUpdates = PlainStow(
    'shouldAlwaysAlertForUpdates',
    kDebugMode ? true : false,
    volatile: !_isOnMainIsolate,
  );

  final locale = PlainStow('locale', '', volatile: !_isOnMainIsolate);

  final sentryConsent = PlainStow(
    'sentryConsent',
    SentryConsent.unknown,
    codec: SentryConsent.codec,
    volatile: !_isOnMainIsolate,
  );

  @pragma('vm:platform-const')
  static final isDesktop =
      Platform.isLinux || Platform.isWindows || Platform.isMacOS;
}

/// An [Stow] that transforms the value of another [Stow].
class TransformedStow<T_in, T_out> extends Stow<dynamic, T_out, dynamic> {
  final Stow<dynamic, T_in, dynamic> parent;
  final T_out Function(T_in) transform;
  final T_in Function(T_out) reverseTransform;

  @override
  T_out get value => transform(parent.value);

  @override
  set value(T_out value) => parent.value = reverseTransform(value);

  new(this.parent, this.transform, this.reverseTransform)
    : super(parent.key, transform(parent.defaultValue), volatile: true) {
    parent.addListener(notifyListeners);
  }

  @override
  Future<dynamic> protectedRead() async => null;

  @override
  Future<void> protectedWrite(dynamic value) async {}

  @override
  String toString() {
    return 'TransformedPref<$T_in, $T_out>(from ${parent.key}, $value)';
  }

  @override
  void dispose() {
    parent.removeListener(notifyListeners);
    super.dispose();
  }
}
