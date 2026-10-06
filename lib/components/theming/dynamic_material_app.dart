import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:go_router/go_router.dart';
import 'package:saber/components/eink/eink_refresh_overlay.dart';
import 'package:saber/components/eink/eink_scope.dart';
import 'package:saber/components/theming/saber_theme.dart';
import 'package:saber/components/theming/yaru_builder.dart';
import 'package:saber/data/eink/eink_service.dart';
import 'package:saber/data/eink/eink_style.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/i18n/extensions/redirecting_localization_delegate.dart';
import 'package:saber/i18n/strings.g.dart';
import 'package:window_manager/window_manager.dart';

class DynamicMaterialApp extends StatefulHookWidget {
  const new({
    super.key,
    required this.title,
    required this.router,
    this.defaultSwatch = Colors.yellow,
  });

  final String title;
  final Color defaultSwatch;
  final GoRouter router;

  @override
  State<DynamicMaterialApp> createState() => DynamicMaterialAppState();

  static final ValueNotifier<bool> _isFullscreen = ValueNotifier(false);
  static bool get isFullscreen => _isFullscreen.value;

  static void setFullscreen(bool value, {required bool updateSystem}) {
    _isFullscreen.value = value;
    if (!updateSystem) return;

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      windowManager.setFullScreen(value);
    } else {
      SystemChrome.setEnabledSystemUIMode(
        value ? SystemUiMode.immersive : SystemUiMode.edgeToEdge,
      );
    }
  }

  static void addFullscreenListener(void Function() listener) {
    _isFullscreen.addListener(listener);
  }

  static void removeFullscreenListener(void Function() listener) {
    _isFullscreen.removeListener(listener);
  }
}

class DynamicMaterialAppState extends State<DynamicMaterialApp>
    with WindowListener {
  @override
  void initState() {
    windowManager.addListener(this);
    SystemChrome.setSystemUIChangeCallback(_onFullscreenChange);
    EInkService.init();

    super.initState();
  }

  @override
  void onWindowEnterFullScreen() {
    DynamicMaterialApp.setFullscreen(true, updateSystem: false);
  }

  @override
  void onWindowLeaveFullScreen() {
    DynamicMaterialApp.setFullscreen(false, updateSystem: false);
  }

  Future<void> _onFullscreenChange(bool systemOverlaysAreVisible) async {
    DynamicMaterialApp.setFullscreen(
      !systemOverlaysAreVisible,
      updateSystem: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = useValueListenable(stows.appTheme);
    final platform = useValueListenable(stows.platform);
    var chosenAccentColor = useValueListenable(stows.accentColor);
    if ((chosenAccentColor?.a ?? 0) < double.minPositive)
      chosenAccentColor = null; // discard transparent accent color
    useListenable(stows.hyperlegibleFont);

    final eInkMode = useValueListenable(stows.eInkMode);
    final eInkStyle = EInkStyle(
      paperWarmth: useValueListenable(stows.eInkPaperWarmth),
      inkDarkness: useValueListenable(stows.eInkInkDarkness),
      texture: useValueListenable(stows.eInkTexture),
      refreshEffect: useValueListenable(stows.eInkRefreshEffect),
    );

    // E-ink mode: one grey paper theme whatever the system theme and accent
    if (eInkMode) {
      final eInkTheme = SaberTheme.createEInkTheme(eInkStyle, platform);
      return ExplicitlyThemedApp(
        title: widget.title,
        router: widget.router,
        themeMode: ThemeMode.light,
        theme: eInkTheme,
        darkTheme: eInkTheme,
        highContrastTheme: eInkTheme,
        highContrastDarkTheme: eInkTheme,
        eInk: eInkStyle,
      );
    }

    // Use Yaru theme, with or without [chosenAccentColor]
    if (platform == .linux) {
      return YaruBuilder(
        primary: chosenAccentColor, // if null, falls back to system color
        platform: platform,
        builder: (context, theme) {
          return ExplicitlyThemedApp(
            title: widget.title,
            router: widget.router,
            themeMode: themeMode,
            theme: theme,
            darkTheme: theme,
            highContrastTheme: theme,
            highContrastDarkTheme: theme,
          );
        },
      );
    }

    // Use [chosenAccentColor] with material/cupertino theme
    if (chosenAccentColor != null) {
      return ExplicitlyThemedApp(
        title: widget.title,
        router: widget.router,
        themeMode: themeMode,
        theme: SaberTheme.createThemeFromSeed(
          chosenAccentColor,
          .light,
          platform,
        ),
        darkTheme: SaberTheme.createThemeFromSeed(
          chosenAccentColor,
          .dark,
          platform,
        ),
      );
    }

    // No accent colour was chosen: Defter's own colours. (Not the colours
    // of the device's wallpaper: the app looks the same on every device,
    // and its parts always go together.)
    return ExplicitlyThemedApp(
      title: widget.title,
      router: widget.router,
      themeMode: themeMode,
      theme: SaberTheme.createDefaultTheme(.light, platform),
      darkTheme: SaberTheme.createDefaultTheme(.dark, platform),
    );
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    SystemChrome.setSystemUIChangeCallback(null);

    super.dispose();
  }
}

@visibleForTesting
class ExplicitlyThemedApp extends StatelessWidget {
  @protected
  const new({
    super.key,
    required this.title,
    required this.router,
    required this.themeMode,
    required this.theme,
    required this.darkTheme,
    this.highContrastTheme,
    this.highContrastDarkTheme,
    this.eInk,
  });

  final String title;
  final GoRouter router;
  final ThemeMode themeMode;
  final ThemeData theme;
  final ThemeData? darkTheme, highContrastTheme, highContrastDarkTheme;

  /// The e-ink look, or null when e-ink mode is off.
  final EInkStyle? eInk;

  static final _materialAppKey = GlobalKey<State<MaterialApp>>();

  @override
  Widget build(BuildContext context) {
    final highContrastTheme =
        this.highContrastTheme ??
        theme.copyWith(colorScheme: theme.colorScheme.withHighContrast());
    final highContrastDarkTheme =
        this.highContrastDarkTheme ??
        darkTheme?.copyWith(
          colorScheme: darkTheme?.colorScheme.withHighContrast(),
        );

    return MaterialApp.router(
      key: _materialAppKey,
      title: title,
      routeInformationProvider: router.routeInformationProvider,
      routeInformationParser: router.routeInformationParser,
      routerDelegate: router.routerDelegate,
      locale: TranslationProvider.of(context).flutterLocale,
      supportedLocales: AppLocaleUtils.supportedLocales,
      localizationsDelegates: const [
        RedirectingLocalizationDelegate<CupertinoLocalizations>(
          GlobalCupertinoLocalizations.delegate,
        ),
        RedirectingLocalizationDelegate<MaterialLocalizations>(
          GlobalMaterialLocalizations.delegate,
        ),
        RedirectingLocalizationDelegate<WidgetsLocalizations>(
          GlobalWidgetsLocalizations.delegate,
        ),
        RedirectingLocalizationDelegate<FlutterQuillLocalizations>(
          FlutterQuillLocalizations.delegate,
        ),
      ],
      themeMode: themeMode,
      // an e-ink screen has no use for a fade between themes
      themeAnimationDuration: eInk != null ? Duration.zero : kThemeAnimationDuration,
      theme: theme,
      darkTheme: darkTheme,
      highContrastTheme: highContrastTheme,
      highContrastDarkTheme: highContrastDarkTheme,
      debugShowCheckedModeBanner: false,
      builder: (context, child) => EInkScope(
        style: eInk,
        child: EInkRefreshOverlay(child: child),
      ),
    );
  }
}

extension on ColorScheme {
  ColorScheme withHighContrast() => ColorScheme.fromSeed(
    brightness: brightness,
    seedColor: primary,
    surface: brightness == .light ? Colors.white : Colors.black,
    contrastLevel: 1,
  );
}
