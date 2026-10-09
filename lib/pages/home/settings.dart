import 'dart:io';

import 'package:collapsible/collapsible.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:saber/components/navbar/responsive_navbar.dart';
import 'package:saber/components/settings/app_info.dart';
import 'package:saber/components/settings/nextcloud_profile.dart';
import 'package:saber/components/settings/settings_button.dart';
import 'package:saber/components/settings/settings_color.dart';
import 'package:saber/components/settings/settings_directory_selector.dart';
import 'package:saber/components/settings/settings_dropdown.dart';
import 'package:saber/components/settings/settings_selection.dart';
import 'package:saber/components/settings/settings_slider.dart';
import 'package:saber/components/settings/settings_sentry.dart';
import 'package:saber/components/settings/settings_subtitle.dart';
import 'package:saber/components/settings/settings_switch.dart';
import 'package:saber/components/settings/stylus_test_dialog.dart';
import 'package:saber/components/settings/update_manager.dart';
import 'package:saber/components/theming/adaptive_alert_dialog.dart';
import 'package:saber/components/theming/adaptive_toggle_buttons.dart';
import 'package:saber/components/theming/saber_theme.dart';
import 'package:saber/components/theming/uni_icon.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/flavor_config.dart';
import 'package:saber/data/is_this_a_test.dart';
import 'package:saber/data/locales.dart';
import 'package:saber/data/defter_strings.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/routes.dart';
import 'package:saber/data/sentry/sentry_init.dart';
import 'package:saber/data/tools/shape_pen.dart';
import 'package:saber/data/tools/stylus_action.dart';
import 'package:saber/i18n/strings.g.dart';
import 'package:saber/pages/backup.dart';
import 'package:saber/pages/benchmark.dart';
import 'package:saber/pages/display_rate.dart';
import 'package:saber/pages/handwriting_settings.dart';
import 'package:saber/pages/sync_status.dart';
import 'package:saber/pages/trash.dart';
import 'package:stow/stow.dart';

class const SettingsPage({super.key}) extends StatefulWidget {
  @override
  State<SettingsPage> createState() => _SettingsPageState();

  static Future<bool?> showResetDialog({
    required BuildContext context,
    required Stow pref,
    required String prefTitle,
  }) async {
    if (pref.value == pref.defaultValue) return null;
    return await showDialog(
      context: context,
      builder: (context) => AdaptiveAlertDialog(
        title: Text(t.settings.reset.title),
        content: Text(prefTitle),
        actions: [
          CupertinoDialogAction(
            onPressed: () {
              Navigator.of(context).pop(false);
            },
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              pref.value = pref.defaultValue;
              Navigator.of(context).pop(true);
            },
            child: Text(t.settings.reset.button),
          ),
        ],
      ),
    );
  }
}

abstract class _SettingsStows {
  static final appTheme = TransformedStow(
    stows.appTheme,
    (ThemeMode value) => value.index,
    (int value) => ThemeMode.values[value],
  );

  static final platform = TransformedStow(
    stows.platform,
    (TargetPlatform value) => value.index,
    (int value) => TargetPlatform.values[value],
  );

  static final layoutSize = TransformedStow(
    stows.layoutSize,
    (LayoutSize value) => value.index,
    (int value) => LayoutSize.values[value],
  );

  static final editorToolbarAlignment = TransformedStow(
    stows.editorToolbarAlignment,
    (AxisDirection value) => value.index,
    (int value) => AxisDirection.values[value],
  );
}

class _SettingsPageState extends State<SettingsPage> {
  late TargetPlatform platform;

  @override
  void initState() {
    stows.locale.addListener(onChanged);
    UpdateManager.status.addListener(onChanged);
    super.initState();
  }

  void onChanged() {
    setState(() {});
  }

  // In tests, pretend the current platform is the defaultTargetPlatform
  bool get usesCupertinoByDefault =>
      switch (isThisATest ? platform : defaultTargetPlatform) {
        .iOS => true,
        .macOS => true,
        _ => false,
      };
  bool get usesYaruByDefault =>
      switch (isThisATest ? platform : defaultTargetPlatform) {
        .linux => true,
        _ => false,
      };
  bool get usesMaterialByDefault =>
      !usesCupertinoByDefault && !usesYaruByDefault;

  static const cupertinoDirectionIcons = [
    CupertinoIcons.arrow_up_to_line,
    CupertinoIcons.arrow_right_to_line,
    CupertinoIcons.arrow_down_to_line,
    CupertinoIcons.arrow_left_to_line,
  ];
  static const materialDirectionIcons = [
    Symbols.north_rounded,
    Symbols.east_rounded,
    Symbols.south_rounded,
    Symbols.west_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    platform = Theme.of(context).platform;
    final cupertino = platform.isCupertino;

    final requiresManualUpdates = FlavorConfig.appStore.isEmpty;

    final materialIcon = switch (defaultTargetPlatform) {
      .windows => FontAwesomeIcons.windows,
      _ => Icons.android_rounded,
    };

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const .only(bottom: 8),
            sliver: SliverAppBar(
              collapsedHeight: kToolbarHeight,
              expandedHeight: 200,
              pinned: true,
              scrolledUnderElevation: 1,
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  t.home.titles.settings,
                  style: TextStyle(color: colorScheme.onSurface),
                ),
                centerTitle: false,
                titlePadding: const EdgeInsetsDirectional.only(
                  start: 16,
                  bottom: 16,
                ),
              ),
              actions: [
                if (UpdateManager.status.value != .upToDate)
                  IconButton(
                    tooltip: t.home.tooltips.showUpdateDialog,
                    icon: const Icon(Symbols.system_update_rounded),
                    onPressed: () {
                      UpdateManager.showUpdateDialog(
                        context,
                        userTriggered: true,
                      );
                    },
                  ),
              ],
            ),
          ),
          SliverSafeArea(
            sliver: SliverList.list(
              children: [
                const NextcloudProfile(),
                const Padding(padding: .all(8), child: AppInfo()),
                SettingsSubtitle(subtitle: t.settings.prefCategories.general),
                SettingsDropdown(
                  title: t.settings.prefLabels.locale,
                  icon: cupertino ? CupertinoIcons.globe : Symbols.language_rounded,
                  pref: stows.locale,
                  options: [
                    ToggleButtonsOption('', Text(t.settings.systemLanguage)),
                    ...AppLocaleUtils.supportedLocales.map((locale) {
                      final localeCode = locale.toLanguageTag();
                      final localeName = localeNames[localeCode];
                      assert(
                        localeName != null,
                        'Missing locale name for $localeCode',
                      );
                      return ToggleButtonsOption(
                        localeCode,
                        Text(localeName ?? localeCode),
                      );
                    }),
                  ],
                ),
                SettingsSelection(
                  title: t.settings.prefLabels.appTheme,
                  iconBuilder: (i) {
                    if (i == ThemeMode.system.index)
                      return Symbols.brightness_auto_rounded;
                    if (i == ThemeMode.light.index) return Icons.light_mode_rounded;
                    if (i == ThemeMode.dark.index) return Icons.dark_mode_rounded;
                    return null;
                  },
                  pref: _SettingsStows.appTheme,
                  optionsWidth: 60,
                  options: [
                    ToggleButtonsOption(
                      ThemeMode.system.index,
                      Icon(
                        Symbols.brightness_auto_rounded,
                        semanticLabel: t.settings.themeModes.system,
                      ),
                    ),
                    ToggleButtonsOption(
                      ThemeMode.light.index,
                      Icon(
                        Icons.light_mode_rounded,
                        semanticLabel: t.settings.themeModes.light,
                      ),
                    ),
                    ToggleButtonsOption(
                      ThemeMode.dark.index,
                      Icon(
                        Icons.dark_mode_rounded,
                        semanticLabel: t.settings.themeModes.dark,
                      ),
                    ),
                  ],
                ),
                SettingsSelection(
                  title: t.settings.prefLabels.platform,
                  iconBuilder: (i) => switch (stows.platform.value) {
                    .iOS || .macOS => Icons.apple_rounded,
                    .linux => FontAwesomeIcons.ubuntu,
                    _ => materialIcon,
                  },
                  pref: _SettingsStows.platform,
                  optionsWidth: 60,
                  options: [
                    ToggleButtonsOption(() {
                      if (usesMaterialByDefault)
                        return defaultTargetPlatform.index;
                      return TargetPlatform.android.index;
                    }(), UniIcon(materialIcon, semanticLabel: 'Material')),
                    ToggleButtonsOption(() {
                      // Hack to allow screenshot golden tests
                      if (kDebugMode && stows.platform.value.isCupertino)
                        return stows.platform.value.index;
                      if (usesCupertinoByDefault)
                        return defaultTargetPlatform.index;
                      return TargetPlatform.iOS.index;
                    }(), const Icon(Icons.apple_rounded, semanticLabel: 'Cupertino')),
                    ToggleButtonsOption(
                      () {
                        if (usesYaruByDefault)
                          return defaultTargetPlatform.index;
                        return TargetPlatform.linux.index;
                      }(),
                      const UniIcon(
                        FontAwesomeIcons.ubuntu,
                        semanticLabel: 'Yaru',
                      ),
                    ),
                  ],
                ),
                SettingsSelection(
                  title: t.settings.prefLabels.layoutSize,
                  subtitle: switch (stows.layoutSize.value) {
                    .auto => t.settings.layoutSizes.auto,
                    .phone => t.settings.layoutSizes.phone,
                    .tablet => t.settings.layoutSizes.tablet,
                  },
                  afterChange: (_) => setState(() {}),
                  iconBuilder: (i) => switch (LayoutSize.values[i]) {
                    .auto => Symbols.aspect_ratio_rounded,
                    .phone => Symbols.smartphone_rounded,
                    .tablet => Symbols.tablet_rounded,
                  },
                  pref: _SettingsStows.layoutSize,
                  optionsWidth: 60,
                  options: [
                    ToggleButtonsOption(
                      LayoutSize.auto.index,
                      Icon(
                        Symbols.aspect_ratio_rounded,
                        semanticLabel: t.settings.layoutSizes.auto,
                      ),
                    ),
                    ToggleButtonsOption(
                      LayoutSize.phone.index,
                      Icon(
                        Symbols.smartphone_rounded,
                        semanticLabel: t.settings.layoutSizes.phone,
                      ),
                    ),
                    ToggleButtonsOption(
                      LayoutSize.tablet.index,
                      Icon(
                        Symbols.tablet_rounded,
                        semanticLabel: t.settings.layoutSizes.tablet,
                      ),
                    ),
                  ],
                ),
                SettingsColor(
                  title: t.settings.prefLabels.customAccentColor,
                  icon: Symbols.colorize_rounded,
                  pref: stows.accentColor,
                ),
                SettingsSwitch(
                  title: t.settings.prefLabels.hyperlegibleFont,
                  subtitle: t.settings.prefDescriptions.hyperlegibleFont,
                  iconBuilder: (b) {
                    if (b)
                      return cupertino
                          ? CupertinoIcons.textformat
                          : Symbols.font_download_rounded;
                    return cupertino
                        ? CupertinoIcons.textformat_alt
                        : Symbols.font_download_off_rounded;
                  },
                  pref: stows.hyperlegibleFont,
                ),

                SettingsSubtitle(subtitle: t.settings.prefCategories.writing),
                SettingsSwitch(
                  title: t.settings.prefLabels.preferGreyscale,
                  subtitle: t.settings.prefDescriptions.preferGreyscale,
                  iconBuilder: (b) {
                    return b
                        ? Symbols.monochrome_photos_rounded
                        : Icons.enhance_photo_translate_rounded;
                  },
                  pref: stows.preferGreyscale,
                ),
                SettingsSwitch(
                  title: t.settings.prefLabels.autoClearWhiteboardOnExit,
                  subtitle:
                      t.settings.prefDescriptions.autoClearWhiteboardOnExit,
                  icon: Symbols.cleaning_services_rounded,
                  pref: stows.autoClearWhiteboardOnExit,
                ),
                SettingsSwitch(
                  title: t.settings.prefLabels.disableEraserAfterUse,
                  subtitle: t.settings.prefDescriptions.disableEraserAfterUse,
                  icon: Symbols.ink_eraser_rounded,
                  pref: stows.disableEraserAfterUse,
                ),
                ValueListenableBuilder(
                  valueListenable: stows.hideFingerDrawingToggle,
                  builder: (context, _, _) {
                    return SettingsSwitch(
                      title: t.settings.prefLabels.hideFingerDrawingToggle,
                      subtitle: () {
                        if (!stows.hideFingerDrawingToggle.value) {
                          return t
                              .settings
                              .prefDescriptions
                              .hideFingerDrawing
                              .shown;
                        } else if (stows.editorFingerDrawing.value) {
                          return t
                              .settings
                              .prefDescriptions
                              .hideFingerDrawing
                              .fixedOn;
                        } else {
                          return t
                              .settings
                              .prefDescriptions
                              .hideFingerDrawing
                              .fixedOff;
                        }
                      }(),
                      icon: CupertinoIcons.hand_draw_fill,
                      pref: stows.hideFingerDrawingToggle,
                    );
                  },
                ),
                ValueListenableBuilder(
                  valueListenable: stows.hideFingerDrawingToggle,
                  builder: (context, hideFingerDrawing, _) {
                    return Collapsible(
                      collapsed: hideFingerDrawing,
                      axis: CollapsibleAxis.vertical,
                      child: SettingsSwitch(
                        title: t
                            .settings
                            .prefLabels
                            .autoDisableFingerDrawingWhenStylusDetected,
                        subtitle: t
                            .settings
                            .prefDescriptions
                            .autoDisableFingerDrawingWhenStylusDetected,
                        icon: CupertinoIcons.pencil,
                        pref: stows.autoDisableFingerDrawingWhenStylusDetected,
                      ),
                    );
                  },
                ),

                SettingsSubtitle(subtitle: t.settings.prefCategories.editor),
                SettingsSwitch(
                  title: DefterStrings.gnLayout,
                  subtitle: DefterStrings.gnLayoutSubtitle,
                  icon: Symbols.view_agenda_rounded,
                  pref: stows.editorGnLayout,
                ),
                SettingsSwitch(
                  title: DefterStrings.homeDashboard,
                  subtitle: DefterStrings.homeDashboardSubtitle,
                  icon: Symbols.space_dashboard_rounded,
                  pref: stows.homeDashboard,
                ),
                SettingsSelection(
                  title: t.settings.prefLabels.editorToolbarAlignment,
                  subtitle:
                      t.settings.axisDirections[_SettingsStows
                          .editorToolbarAlignment
                          .value],
                  iconBuilder: (num i) {
                    if (i is! int || i >= materialDirectionIcons.length)
                      return null;
                    return cupertino
                        ? cupertinoDirectionIcons[i]
                        : materialDirectionIcons[i];
                  },
                  pref: _SettingsStows.editorToolbarAlignment,
                  optionsWidth: 60,
                  options: [
                    for (final AxisDirection direction in AxisDirection.values)
                      ToggleButtonsOption(
                        direction.index,
                        Icon(
                          cupertino
                              ? cupertinoDirectionIcons[direction.index]
                              : materialDirectionIcons[direction.index],
                          semanticLabel:
                              t.settings.axisDirections[direction.index],
                        ),
                      ),
                  ],
                  afterChange: (_) => setState(() {}),
                ),
                SettingsSwitch(
                  title: t.settings.prefLabels.editorToolbarShowInFullscreen,
                  icon: cupertino
                      ? CupertinoIcons.fullscreen
                      : Symbols.fullscreen_rounded,
                  pref: stows.editorToolbarShowInFullscreen,
                ),
                SettingsSwitch(
                  title: t.settings.prefLabels.editorAutoInvert,
                  iconBuilder: (b) {
                    return b ? Icons.invert_colors_on_rounded : Symbols.invert_colors_off_rounded;
                  },
                  pref: stows.editorAutoInvert,
                ),
                SettingsSwitch(
                  title: t.settings.prefLabels.editorPromptRename,
                  subtitle: t.settings.prefDescriptions.editorPromptRename,
                  iconBuilder: (b) {
                    if (b)
                      return cupertino
                          ? CupertinoIcons.keyboard
                          : Symbols.keyboard_rounded;
                    return cupertino
                        ? CupertinoIcons.keyboard_chevron_compact_down
                        : Symbols.keyboard_hide_rounded;
                  },
                  pref: stows.editorPromptRename,
                ),
                SettingsSwitch(
                  title: t.settings.prefLabels.recentColorsDontSavePresets,
                  icon: Symbols.palette_rounded,
                  pref: stows.recentColorsDontSavePresets,
                ),
                SettingsSelection(
                  title: t.settings.prefLabels.recentColorsLength,
                  icon: Symbols.history_rounded,
                  pref: stows.recentColorsLength,
                  options: const [
                    ToggleButtonsOption(5, Text('5')),
                    ToggleButtonsOption(10, Text('10')),
                  ],
                ),
                SettingsSwitch(
                  title: t.settings.prefLabels.printPageIndicators,
                  subtitle: t.settings.prefDescriptions.printPageIndicators,
                  icon: Symbols.numbers_rounded,
                  pref: stows.printPageIndicators,
                ),
                SettingsSubtitle(subtitle: DefterStrings.eInkSection),
                SettingsSwitch(
                  title: DefterStrings.eInkMode,
                  subtitle: DefterStrings.eInkModeSubtitle,
                  icon: Symbols.menu_book_rounded,
                  pref: stows.eInkMode,
                  afterChange: (_) => setState(() {}),
                ),
                if (stows.eInkMode.value) ...[
                  SettingsSlider(
                    title: DefterStrings.eInkPaperWarmth,
                    icon: Symbols.wb_sunny_rounded,
                    pref: stows.eInkPaperWarmth,
                  ),
                  SettingsSlider(
                    title: DefterStrings.eInkInkDarkness,
                    icon: Symbols.edit_rounded,
                    pref: stows.eInkInkDarkness,
                  ),
                  SettingsSlider(
                    title: DefterStrings.eInkTexture,
                    icon: Symbols.grain_rounded,
                    pref: stows.eInkTexture,
                  ),
                  SettingsSwitch(
                    title: DefterStrings.eInkRefresh,
                    subtitle: DefterStrings.eInkRefreshSubtitle,
                    icon: Symbols.refresh_rounded,
                    pref: stows.eInkRefreshEffect,
                  ),
                  SettingsSelection(
                    title: DefterStrings.eInkBrightness,
                    subtitle: DefterStrings.eInkBrightnessSubtitle,
                    icon: Symbols.brightness_6_rounded,
                    pref: stows.eInkBrightness,
                    options: [
                      ToggleButtonsOption(
                        0,
                        Text(DefterStrings.eInkBrightnessSystem),
                      ),
                      const ToggleButtonsOption(1, Text('70%')),
                      const ToggleButtonsOption(2, Text('50%')),
                      const ToggleButtonsOption(3, Text('35%')),
                    ],
                  ),
                  SettingsSwitch(
                    title: DefterStrings.eInkExport,
                    subtitle: DefterStrings.eInkExportSubtitle,
                    icon: Symbols.ios_share_rounded,
                    pref: stows.eInkExport,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Text(
                      DefterStrings.eInkLimits,
                      style: TextTheme.of(context).bodySmall,
                    ),
                  ),
                ],
                SettingsSubtitle(
                  subtitle: t.settings.prefCategories.performance,
                ),
                SettingsSelection(
                  title: t.settings.prefLabels.maxImageSize,
                  subtitle: t.settings.prefDescriptions.maxImageSize,
                  icon: Symbols.photo_size_select_large_rounded,
                  pref: stows.maxImageSize,
                  options: const <ToggleButtonsOption<double>>[
                    ToggleButtonsOption(500, Text('500')),
                    ToggleButtonsOption(1000, Text('1000')),
                    ToggleButtonsOption(2000, Text('2000')),
                  ],
                ),
                SettingsSelection(
                  title: t.settings.prefLabels.autosave,
                  subtitle: t.settings.prefDescriptions.autosave,
                  icon: Symbols.save_rounded,
                  pref: stows.autosaveDelay,
                  options: [
                    const ToggleButtonsOption(5000, Text('5s')),
                    const ToggleButtonsOption(10000, Text('10s')),
                    ToggleButtonsOption(-1, Text(t.settings.autosaveDisabled)),
                  ],
                ),
                SettingsSelection(
                  title: DefterStrings.stylusAction,
                  subtitle: DefterStrings.stylusActionSubtitle,
                  icon: Symbols.touch_app_rounded,
                  pref: stows.stylusAction,
                  options: [
                    ToggleButtonsOption(
                      StylusAction.none.index,
                      Text(DefterStrings.stylusNone),
                    ),
                    ToggleButtonsOption(
                      StylusAction.toggleEraser.index,
                      Text(DefterStrings.stylusToggleEraser),
                    ),
                    ToggleButtonsOption(
                      StylusAction.previousTool.index,
                      Text(DefterStrings.stylusPreviousTool),
                    ),
                    ToggleButtonsOption(
                      StylusAction.lasso.index,
                      Text(DefterStrings.stylusLasso),
                    ),
                    ToggleButtonsOption(
                      StylusAction.highlighter.index,
                      Text(DefterStrings.stylusHighlighter),
                    ),
                    ToggleButtonsOption(
                      StylusAction.undo.index,
                      Text(DefterStrings.stylusUndo),
                    ),
                    ToggleButtonsOption(
                      StylusAction.redo.index,
                      Text(DefterStrings.stylusRedo),
                    ),
                  ],
                ),
                SettingsSelection(
                  title: DefterStrings.stylusTaps,
                  subtitle: DefterStrings.stylusTapsSubtitle,
                  icon: Symbols.looks_two_rounded,
                  pref: stows.stylusTapsNeeded,
                  options: const [
                    ToggleButtonsOption(1, Text('1')),
                    ToggleButtonsOption(2, Text('2')),
                  ],
                ),
                SettingsButton(
                  title: DefterStrings.stylusTest,
                  subtitle: DefterStrings.stylusTestSubtitle,
                  icon: Symbols.bug_report_rounded,
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => const StylusTestDialog(),
                  ),
                ),
                SettingsSwitch(
                  title: DefterStrings.penProbe,
                  subtitle: DefterStrings.penProbeSubtitle,
                  icon: Symbols.speed_rounded,
                  pref: stows.penProbe,
                ),
                SettingsSwitch(
                  title: DefterStrings.penOverlay,
                  subtitle: DefterStrings.penOverlaySubtitle,
                  icon: Symbols.bolt_rounded,
                  pref: stows.penOverlay,
                ),
                SettingsSwitch(
                  title: DefterStrings.holdToSnap,
                  subtitle: DefterStrings.holdToSnapSubtitle,
                  icon: Symbols.gesture_rounded,
                  pref: stows.shapeHoldToSnap,
                ),
                SettingsSelection(
                  title: DefterStrings.holdDelay,
                  subtitle: DefterStrings.holdDelaySubtitle,
                  icon: Symbols.timer_rounded,
                  pref: stows.shapeHoldDelay,
                  options: const [
                    ToggleButtonsOption(400, Text('0.4s')),
                    ToggleButtonsOption(600, Text('0.6s')),
                    ToggleButtonsOption(900, Text('0.9s')),
                  ],
                ),
                SettingsSwitch(
                  title: DefterStrings.advancedShapes,
                  subtitle: DefterStrings.advancedShapesSubtitle,
                  icon: Symbols.interests_rounded,
                  pref: stows.advancedShapes,
                ),
                SettingsSwitch(
                  title: DefterStrings.snapEndpoints,
                  subtitle: DefterStrings.snapEndpointsSubtitle,
                  icon: Symbols.control_point_rounded,
                  pref: stows.shapeSnapEndpoints,
                ),
                SettingsSwitch(
                  title: DefterStrings.shapeArrows,
                  subtitle: DefterStrings.shapeArrowsSubtitle,
                  icon: Symbols.north_east_rounded,
                  pref: stows.shapePenArrows,
                ),
                SettingsSelection(
                  title: t.settings.prefLabels.shapeRecognitionDelay,
                  subtitle: t.settings.prefDescriptions.shapeRecognitionDelay,
                  icon: Symbols.shapes_rounded,
                  pref: stows.shapeRecognitionDelay,
                  options: [
                    const ToggleButtonsOption(500, Text('0.5s')),
                    const ToggleButtonsOption(1000, Text('1s')),
                    ToggleButtonsOption(
                      -1,
                      Text(t.settings.shapeRecognitionDisabled),
                    ),
                  ],
                  afterChange: (ms) {
                    ShapePen.debounceDuration = ShapePen.getDebounceFromPref();
                  },
                ),
                SettingsSwitch(
                  title: t.settings.prefLabels.autoStraightenLines,
                  subtitle: t.settings.prefDescriptions.autoStraightenLines,
                  icon: Symbols.straighten_rounded,
                  pref: stows.autoStraightenLines,
                ),
                SettingsSubtitle(subtitle: t.settings.prefCategories.advanced),
                if (isSentryAvailable) const SettingsSentryConsent(),
                if (Platform.isAndroid)
                  SettingsDirectorySelector(
                    title: t.settings.prefLabels.customDataDir,
                    icon: Icons.folder_rounded,
                  ),
                if (Platform.isWindows || Platform.isLinux || Platform.isMacOS)
                  SettingsButton(
                    title: t.settings.openDataDir,
                    icon: Icons.folder_open_rounded,
                    onPressed: () {
                      if (Platform.isWindows) {
                        Process.run('explorer', [
                          FileManager.documentsDirectory,
                        ]);
                      } else if (Platform.isLinux) {
                        Process.run('xdg-open', [
                          FileManager.documentsDirectory,
                        ]);
                      } else if (Platform.isMacOS) {
                        Process.run('open', [FileManager.documentsDirectory]);
                      }
                    },
                  ),
                if (requiresManualUpdates ||
                    stows.shouldCheckForUpdates.value !=
                        stows.shouldCheckForUpdates.defaultValue) ...[
                  SettingsSwitch(
                    title: t.settings.prefLabels.shouldCheckForUpdates,
                    icon: Symbols.system_update_rounded,
                    pref: stows.shouldCheckForUpdates,
                    afterChange: (_) => setState(() {}),
                  ),
                  Collapsible(
                    collapsed: !stows.shouldCheckForUpdates.value,
                    axis: CollapsibleAxis.vertical,
                    child: SettingsSwitch(
                      title: t.settings.prefLabels.shouldAlwaysAlertForUpdates,
                      subtitle: t
                          .settings
                          .prefDescriptions
                          .shouldAlwaysAlertForUpdates,
                      icon: Symbols.system_security_update_warning_rounded,
                      pref: stows.shouldAlwaysAlertForUpdates,
                    ),
                  ),
                ],
                SettingsSwitch(
                  title: t.settings.prefLabels.allowInsecureConnections,
                  subtitle:
                      t.settings.prefDescriptions.allowInsecureConnections,
                  icon: Symbols.private_connectivity_rounded,
                  pref: stows.allowInsecureConnections,
                ),
                SettingsButton(
                  title: t.logs.viewLogs,
                  subtitle: t.logs.debuggingInfo,
                  icon: Symbols.receipt_long_rounded,
                  onPressed: () => context.push(RoutePaths.logs),
                ),
                SettingsButton(
                  title: DefterStrings.backupTitle,
                  subtitle: DefterStrings.backupSettingsSubtitle,
                  icon: Symbols.backup_rounded,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => const BackupPage(),
                    ),
                  ),
                ),
                SettingsButton(
                  title: DefterStrings.trash,
                  subtitle: DefterStrings.trashSubtitle,
                  icon: Symbols.delete_rounded,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => const TrashPage(),
                    ),
                  ),
                ),
                SettingsButton(
                  title: DefterStrings.syncStatus,
                  subtitle: DefterStrings.syncStatusSubtitle,
                  icon: Symbols.cloud_sync_rounded,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => const SyncStatusPage(),
                    ),
                  ),
                ),
                SettingsButton(
                  title: DefterStrings.handwritingSettings,
                  subtitle: DefterStrings.handwritingSettingsSubtitle,
                  icon: Symbols.text_fields_rounded,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => const HandwritingSettingsPage(),
                    ),
                  ),
                ),
                SettingsButton(
                  title: DefterStrings.rateTitle,
                  subtitle: DefterStrings.rateSubtitle,
                  icon: Symbols.monitor_rounded,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => const DisplayRatePage(),
                    ),
                  ),
                ),
                SettingsButton(
                  title: DefterStrings.benchmark,
                  subtitle: DefterStrings.benchmarkSubtitle,
                  icon: Symbols.speed_rounded,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => const BenchmarkPage(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    stows.locale.removeListener(onChanged);
    UpdateManager.status.removeListener(onChanged);
    super.dispose();
  }
}
