import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:saber/components/theming/defter_design.dart';
import 'package:saber/data/eink/eink_style.dart';
import 'package:saber/data/prefs.dart';
import 'package:sbn/font_fallbacks.dart';
import 'package:yaru/yaru.dart';

abstract class SaberTheme {
  /// Defter's theme for [colorScheme]: its accent on neutral paper, with
  /// one set of corners, lines, shadows and motion for every component.
  static ThemeData createTheme(
    ColorScheme colorScheme,
    TargetPlatform platform,
  ) {
    colorScheme = DefterDesign.withPaper(colorScheme);
    final light = colorScheme.brightness == .light;
    final textTheme = _Components.textTheme(platform, colorScheme);
    // The same styles with their sizes filled in, for the components that
    // are given a whole style here (a theme's own styles only get their
    // sizes where they are used).
    final type = Typography.material2021(
      platform: platform,
      colorScheme: colorScheme,
    ).englishLike.merge(textTheme);
    final hairline = BorderSide(color: colorScheme.outlineVariant, width: 1);
    // The shadow under what floats: wide and faint.
    final shadow = colorScheme.shadow.withValues(alpha: light ? 0.18 : 0.6);

    final buttonText = WidgetStatePropertyAll(
      type.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    );
    const buttonShape = WidgetStatePropertyAll<OutlinedBorder>(
      DefterDesign.controlShape,
    );
    const buttonSize = WidgetStatePropertyAll(Size(48, 44));
    const buttonPadding = WidgetStatePropertyAll<EdgeInsetsGeometry>(
      EdgeInsets.symmetric(horizontal: 18, vertical: 10),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: textTheme,
      platform: platform,
      scaffoldBackgroundColor: colorScheme.surface,
      canvasColor: colorScheme.surface,
      cardColor: colorScheme.surface,
      shadowColor: shadow,
      // A press dims what is pressed; nothing ripples.
      splashFactory: NoSplash.splashFactory,
      highlightColor: colorScheme.onSurface.withValues(alpha: 0.06),
      hoverColor: colorScheme.onSurface.withValues(alpha: 0.04),
      focusColor: colorScheme.primary.withValues(alpha: 0.10),
      dividerColor: colorScheme.outlineVariant,
      progressIndicatorTheme: _Components.progressIndicatorTheme,
      cupertinoOverrideTheme: _Components.cupertinoOverrideTheme,
      // Pages slide in from the side and can be followed with the eye.
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          for (final target in TargetPlatform.values)
            target: const DefterPageTransitionsBuilder(),
        },
      ),
      iconTheme: IconThemeData(
        color: colorScheme.onSurface,
        size: 24,
        weight: 400,
        opticalSize: 24,
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
        titleTextStyle: type.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
      ),
      cardTheme: _Components.cardTheme(colorScheme),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: shadow,
        elevation: 12,
        shape: DefterDesign.sheetShape,
        titleTextStyle: type.titleLarge?.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        contentTextStyle: type.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
          height: 1.4,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surface,
        modalBackgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: shadow,
        elevation: 12,
        modalElevation: 12,
        dragHandleColor: colorScheme.outline,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(DefterDesign.radiusSheet),
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: shadow,
        elevation: 8,
        shape: DefterDesign.cardShape,
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(colorScheme.surface),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shadowColor: WidgetStatePropertyAll(shadow),
          elevation: const WidgetStatePropertyAll(8),
          shape: const WidgetStatePropertyAll(DefterDesign.cardShape),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colorScheme.inverseSurface,
        // (Left to take its size where it is shown, like the same style
        // of the e-ink theme: the two are blended when the mode changes.)
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onInverseSurface,
        ),
        actionTextColor: colorScheme.inversePrimary,
        elevation: 6,
        shape: DefterDesign.controlShape,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: colorScheme.inverseSurface.withValues(alpha: 0.94),
          borderRadius: const BorderRadius.all(Radius.circular(8)),
        ),
        textStyle: type.bodySmall?.copyWith(
          color: colorScheme.onInverseSurface,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        waitDuration: const Duration(milliseconds: 500),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          shape: buttonShape,
          textStyle: buttonText,
          minimumSize: buttonSize,
          padding: buttonPadding,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          shape: buttonShape,
          textStyle: buttonText,
          minimumSize: buttonSize,
          padding: buttonPadding,
          // A quiet button: a tint of paper, the accent for its words.
          elevation: const WidgetStatePropertyAll(0),
          shadowColor: const WidgetStatePropertyAll(Colors.transparent),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? colorScheme.onSurface.withValues(alpha: 0.06)
                : colorScheme.surfaceContainerHigh,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? colorScheme.onSurface.withValues(alpha: 0.38)
                : colorScheme.primary,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          shape: buttonShape,
          textStyle: buttonText,
          minimumSize: buttonSize,
          padding: buttonPadding,
          side: WidgetStatePropertyAll(
            BorderSide(color: colorScheme.outline, width: 1),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(shape: buttonShape, textStyle: buttonText),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: buttonShape,
          side: WidgetStatePropertyAll(hairline),
          textStyle: WidgetStatePropertyAll(
            type.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? colorScheme.primaryContainer
                : colorScheme.surface,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? colorScheme.onPrimaryContainer
                : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surface,
        selectedColor: colorScheme.primaryContainer,
        surfaceTintColor: Colors.transparent,
        side: hairline,
        shape: DefterDesign.controlShape,
        labelStyle: type.labelLarge?.copyWith(
          fontWeight: FontWeight.w500,
        ),
        showCheckmark: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainer,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(DefterDesign.radiusControl),
          ),
          borderSide: BorderSide.none,
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(DefterDesign.radiusControl),
          ),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(
            Radius.circular(DefterDesign.radiusControl),
          ),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
      ),
      switchTheme: SwitchThemeData(
        // A white knob that slides on a track of accent or of grey.
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        thumbIcon: const WidgetStatePropertyAll<Icon?>(null),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
        trackColor: WidgetStateProperty.resolveWith((states) {
          final on = states.contains(WidgetState.selected);
          final color = on ? colorScheme.primary : colorScheme.outline;
          return states.contains(WidgetState.disabled)
              ? color.withValues(alpha: 0.4)
              : color;
        }),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      sliderTheme: SliderThemeData(
        trackHeight: 4,
        activeTrackColor: colorScheme.primary,
        inactiveTrackColor: colorScheme.surfaceContainerHighest,
        thumbColor: light ? Colors.white : colorScheme.onSurface,
        overlayColor: Colors.transparent,
        thumbShape: const RoundSliderThumbShape(
          enabledThumbRadius: 11,
          elevation: 3,
          pressedElevation: 5,
        ),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
      ),
      checkboxTheme: const CheckboxThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(5)),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: colorScheme.onSurfaceVariant,
        shape: DefterDesign.controlShape,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 4,
        focusElevation: 4,
        hoverElevation: 5,
        highlightElevation: 2,
        shape: DefterDesign.cardShape,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: colorScheme.primaryContainer,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        indicatorColor: colorScheme.primaryContainer,
      ),
      scrollbarTheme: ScrollbarThemeData(
        radius: const Radius.circular(4),
        thickness: const WidgetStatePropertyAll(5.0),
        thumbColor: WidgetStatePropertyAll(
          colorScheme.onSurface.withValues(alpha: 0.28),
        ),
      ),
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

    return createTheme(
      DefterDesign.colorScheme(brightness, accent: seedColor),
      platform,
    );
  }

  /// The theme when no accent colour was chosen: Defter's own ink blue.
  static ThemeData createDefaultTheme(
    Brightness brightness,
    TargetPlatform platform,
  ) => createTheme(DefterDesign.colorScheme(brightness), platform);

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
    final base = colorScheme.brightness == .dark
        ? typography.white
        : typography.black;
    // Titles are set a little tighter and heavier than Material's, body
    // text without extra tracking: closer to a printed page.
    final textTheme = base.copyWith(
      displaySmall: base.displaySmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
      ),
      headlineLarge: base.headlineLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
      ),
      titleSmall: base.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
      bodyLarge: base.bodyLarge?.copyWith(letterSpacing: 0),
      bodyMedium: base.bodyMedium?.copyWith(letterSpacing: 0),
      bodySmall: base.bodySmall?.copyWith(letterSpacing: 0.1),
      labelLarge: base.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
    );

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
        borderRadius: const .all(.circular(DefterDesign.radiusCard)),
        side: BorderSide(color: colorScheme.outlineVariant, width: 1),
      ),
    );
  }

  static const cupertinoOverrideTheme = NoDefaultCupertinoThemeData(
    applyThemeToAll: true,
  );

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
