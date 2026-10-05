import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:saber/data/eink/eink_style.dart';
import 'package:saber/data/prefs.dart';
import 'package:sbn/font_fallbacks.dart';
import 'package:yaru/yaru.dart';

abstract class SaberTheme {
  static ThemeData createTheme(
    ColorScheme colorScheme,
    TargetPlatform platform,
  ) {
    colorScheme = _adjustColorScheme(colorScheme, platform);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: _Components.textTheme(platform, colorScheme),
      platform: platform,
      progressIndicatorTheme: _Components.progressIndicatorTheme,
      cardColor: colorScheme.surface,
      cardTheme: _Components.cardTheme(colorScheme),
      cupertinoOverrideTheme: _Components.cupertinoOverrideTheme,
      appBarTheme: _Components.appBarTheme,
    );
  }

  /// The colour scheme of e-ink mode: only greys, on [EInkStyle.paper].
  ///
  /// Every text and icon colour keeps at least 4.5:1 contrast against the
  /// paper, outlines at least 3:1.
  static ColorScheme createEInkColorScheme(EInkStyle style) {
    final paper = style.paper;
    final ink = style.ink;
    // [t] of the way from paper to ink
    Color step(double t) => Color.lerp(paper, ink, t)!;
    final base = ColorScheme.fromSeed(
      seedColor: const Color(0xFF777777),
      brightness: .light,
      dynamicSchemeVariant: .monochrome,
    );
    return base.copyWith(
      primary: ink,
      onPrimary: paper,
      primaryContainer: step(0.14),
      onPrimaryContainer: ink,
      secondary: Color.lerp(ink, paper, 0.12),
      onSecondary: paper,
      secondaryContainer: step(0.10),
      onSecondaryContainer: ink,
      tertiary: Color.lerp(ink, paper, 0.12),
      onTertiary: paper,
      tertiaryContainer: step(0.14),
      onTertiaryContainer: ink,
      error: ink,
      onError: paper,
      errorContainer: step(0.18),
      onErrorContainer: ink,
      surface: paper,
      onSurface: ink,
      onSurfaceVariant: Color.lerp(ink, paper, 0.12),
      surfaceDim: step(0.07),
      surfaceBright: paper,
      surfaceContainerLowest: paper,
      surfaceContainerLow: step(0.03),
      surfaceContainer: step(0.05),
      surfaceContainerHigh: step(0.08),
      surfaceContainerHighest: step(0.11),
      outline: Color.lerp(ink, paper, 0.28),
      outlineVariant: step(0.30),
      inverseSurface: ink,
      onInverseSurface: paper,
      inversePrimary: paper,
      surfaceTint: Colors.transparent,
      shadow: Colors.black,
      scrim: Colors.black,
    );
  }

  /// The theme of e-ink mode: flat, bordered, grey, with no shadows,
  /// ripples or page animations (none of which an e-ink screen does well).
  static ThemeData createEInkTheme(EInkStyle style, TargetPlatform platform) {
    final colorScheme = createEInkColorScheme(style);
    final ink = colorScheme.onSurface;
    final border = BorderSide(color: colorScheme.outline, width: 1.5);
    final shape = RoundedRectangleBorder(
      borderRadius: const BorderRadius.all(Radius.circular(6)),
      side: border,
    );
    final textTheme = _Components.textTheme(
      platform,
      colorScheme,
    ).apply(bodyColor: ink, displayColor: ink);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: textTheme,
      platform: platform,
      scaffoldBackgroundColor: colorScheme.surface,
      canvasColor: colorScheme.surface,
      cardColor: colorScheme.surface,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      iconTheme: IconThemeData(color: ink),
      dividerTheme: DividerThemeData(color: colorScheme.outline, thickness: 1),
      progressIndicatorTheme: _Components.progressIndicatorTheme,
      cupertinoOverrideTheme: _Components.cupertinoOverrideTheme,
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          for (final target in TargetPlatform.values)
            target: const _InstantPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: colorScheme.surface,
        foregroundColor: ink,
        shape: Border(bottom: border),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        shape: shape,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        shape: shape,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
          side: border,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        shape: shape,
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(colorScheme.surface),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shadowColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(0),
          shape: WidgetStatePropertyAll(shape),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onInverseSurface,
        ),
        actionTextColor: colorScheme.onInverseSurface,
        elevation: 0,
        shape: shape,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        backgroundColor: colorScheme.surface,
        foregroundColor: ink,
        shape: shape,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: colorScheme.surfaceContainerHighest,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        indicatorColor: colorScheme.surfaceContainerHighest,
      ),
      listTileTheme: ListTileThemeData(iconColor: ink, textColor: ink),
    );
  }

  static ThemeData createThemeFromSeed(
    Color seedColor,
    Brightness brightness,
    TargetPlatform platform, {
    @Deprecated(
      'High contrast is not implemented here. '
      'Use ColorScheme.withHighContrast() instead',
    )
    bool highContrast = false,
  }) {
    if (platform == .linux) {
      return getThemeFromYaru(seedColor, brightness, platform, highContrast);
    }

    final ColorScheme colorScheme;
    if (platform.isCupertino) {
      final bg = brightness == .light
          ? CupertinoColors.systemBackground.color
          : CupertinoColors.systemBackground.darkColor;
      colorScheme = ColorScheme.fromSeed(
        brightness: brightness,
        seedColor: seedColor,
        surface: bg,
        surfaceTint: bg,
        dynamicSchemeVariant: .neutral,
      );
    } else {
      colorScheme = ColorScheme.fromSeed(
        brightness: brightness,
        seedColor: seedColor,
      );
    }
    return createTheme(colorScheme, platform);
  }

  /// Adjusts certain colors in the [ColorScheme].
  static ColorScheme _adjustColorScheme(
    ColorScheme colorScheme,
    TargetPlatform platform,
  ) {
    return colorScheme.copyWith(
      surface: platform.isCupertino
          ? (colorScheme.brightness == .light
                ? CupertinoColors.white
                : CupertinoColors.darkBackgroundGray)
          : null,
      // Hack: Mimic Material 3 Expressive color schemes by making
      // surfaceContainer much closer to surface.
      // Remove this when Flutter supports M3E natively.
      surfaceContainer: Color.lerp(
        colorScheme.surface,
        colorScheme.surfaceTint,
        0.02,
      )!,
    );
  }

  static ThemeData getThemeFromYaru(
    Color primaryColor,
    Brightness brightness,
    TargetPlatform platform,
    bool highContrast,
  ) {
    var base = brightness == .light
        ? createYaruLightTheme(
            primaryColor: primaryColor,
            fontFamily: stows.hyperlegibleFont.value
                ? 'AtkinsonHyperlegibleNext'
                : 'Adwaita Sans',
            fontFamilyFallback: saberSansSerifFontFallbacks,
          )
        : createYaruDarkTheme(
            primaryColor: primaryColor,
            fontFamily: stows.hyperlegibleFont.value
                ? 'AtkinsonHyperlegibleNext'
                : 'Adwaita Sans',
            fontFamilyFallback: saberSansSerifFontFallbacks,
          );
    base = base.copyWith(visualDensity: .defaultDensityForPlatform(platform));
    return getThemeFromYaruFixed(base, platform);
  }

  static ThemeData getThemeFromYaruFixed(
    ThemeData base,
    TargetPlatform platform,
  ) {
    final textTheme = _Components.textTheme(platform, base.colorScheme);
    final fontFamily = textTheme.bodyMedium!.fontFamily;
    final fontFamilyFallback = textTheme.bodyMedium!.fontFamilyFallback;
    return base.copyWith(
      platform: platform,
      textTheme: textTheme,
      progressIndicatorTheme: _Components.progressIndicatorTheme,
      cardTheme: _Components.cardTheme(base.colorScheme),
      cupertinoOverrideTheme: _Components.cupertinoOverrideTheme,
      listTileTheme: base.listTileTheme.copyWith(
        // Yaru forces list tiles to use Ubuntu font, fix that
        titleTextStyle: base.listTileTheme.titleTextStyle?.copyWith(
          fontFamily: fontFamily,
          fontFamilyFallback: fontFamilyFallback,
        ),
        subtitleTextStyle: base.listTileTheme.subtitleTextStyle?.copyWith(
          fontFamily: fontFamily,
          fontFamilyFallback: fontFamilyFallback,
        ),
        leadingAndTrailingTextStyle: base
            .listTileTheme
            .leadingAndTrailingTextStyle
            ?.copyWith(
              fontFamily: fontFamily,
              fontFamilyFallback: fontFamilyFallback,
            ),
      ),
      // Leave Yaru's app bar theme, since it adds a border bottom.
      // appBarTheme: _Components.appBarTheme,
    );
  }
}

abstract class _Components {
  static TextTheme textTheme(TargetPlatform platform, ColorScheme colorScheme) {
    final typography = Typography.material2021(
      platform: platform,
      colorScheme: colorScheme,
    );
    final textTheme = colorScheme.brightness == .dark
        ? typography.white
        : typography.black;

    if (stows.hyperlegibleFont.value) {
      return textTheme.withFont(
        fontFamily: 'AtkinsonHyperlegibleNext',
        fontFamilyFallback: saberSansSerifFontFallbacks,
      );
    } else if (platform == .linux) {
      // Flutter picks Roboto but Adwaita Sans is a better default
      return textTheme.withFont(fontFamily: 'Adwaita Sans');
    } else {
      return textTheme;
    }
  }

  static const progressIndicatorTheme = ProgressIndicatorThemeData(
    // ignore: deprecated_member_use
    year2023: false,
    stopIndicatorColor: Colors.transparent,
  );

  static CardThemeData cardTheme(ColorScheme colorScheme) {
    return CardThemeData(
      elevation: 0,
      color: colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: const .all(.circular(kYaruContainerRadius)),
        side: BorderSide(
          color: colorScheme.onSurface.withValues(alpha: 0.12),
          width: 2,
        ),
      ),
    );
  }

  static const cupertinoOverrideTheme = NoDefaultCupertinoThemeData(
    applyThemeToAll: true,
  );

  static const appBarTheme = AppBarTheme(centerTitle: false);
}

extension SaberThemePlatform on TargetPlatform {
  bool get isCupertino => switch (this) {
    .iOS => true,
    .macOS => true,
    _ => false,
  };
}

/// Page changes happen at once; an e-ink screen has no use for slides.
class _InstantPageTransitionsBuilder extends PageTransitionsBuilder {
  const new();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;
}
