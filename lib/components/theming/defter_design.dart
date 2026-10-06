import 'package:flutter/cupertino.dart' show CupertinoPageTransition;
import 'package:flutter/material.dart';
import 'package:saber/components/eink/eink_scope.dart';
import 'package:saber/data/is_this_a_test.dart';

/// Defter's look in one place: ink on paper.
///
/// One deep ink blue carries the brand (the editor's bar, the main
/// buttons, what is selected); everything around it is quiet, neutral
/// paper. Corners come in three sizes, shadows in two, and everything
/// that moves uses the same few durations and curves.
abstract class DefterDesign {
  // -- colour ---------------------------------------------------------------

  /// The ink blue that is used when no accent colour was chosen.
  static const ink = Color(0xFF2949AE);

  /// The colours of the whole app for [brightness], built around [accent]
  /// (the ink blue if none is given). The surfaces are the same neutral
  /// paper whatever the accent: only what is tinted changes.
  static ColorScheme colorScheme(Brightness brightness, {Color? accent}) {
    final light = brightness == Brightness.light;
    final seeded = ColorScheme.fromSeed(
      seedColor: accent ?? ink,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    );
    final primary = accent == null && light ? ink : seeded.primary;
    final hsl = HSLColor.fromColor(primary);
    // What is tinted (a selected row, a chosen chip) is a wash of the
    // accent over the paper, whatever the accent: never a second colour.
    return withPaper(
      seeded.copyWith(
        primary: primary,
        onPrimary: accent == null && light ? Colors.white : null,
        primaryContainer: light
            ? Color.lerp(Colors.white, primary, 0.14)
            : Color.lerp(const Color(0xFF111216), primary, 0.28),
        onPrimaryContainer: light
            ? hsl.withLightness(0.24).toColor()
            : Color.lerp(Colors.white, primary, 0.25),
        secondaryContainer: light
            ? Color.lerp(Colors.white, primary, 0.10)
            : Color.lerp(const Color(0xFF111216), primary, 0.20),
        onSecondaryContainer: light
            ? hsl.withLightness(0.24).toColor()
            : Color.lerp(Colors.white, primary, 0.25),
      ),
    );
  }

  /// [scheme] with Defter's neutral surfaces, lines and shadows in place
  /// of its own tinted ones.
  static ColorScheme withPaper(ColorScheme scheme) {
    final light = scheme.brightness == Brightness.light;
    return scheme.copyWith(
      surface: light ? const Color(0xFFFFFFFF) : const Color(0xFF111216),
      surfaceBright: light ? const Color(0xFFFFFFFF) : const Color(0xFF2C2F36),
      surfaceDim: light ? const Color(0xFFE5E7EC) : const Color(0xFF0C0D10),
      surfaceContainerLowest: light
          ? const Color(0xFFFFFFFF)
          : const Color(0xFF0C0D10),
      surfaceContainerLow: light
          ? const Color(0xFFF6F7F9)
          : const Color(0xFF17181D),
      surfaceContainer: light
          ? const Color(0xFFF1F2F5)
          : const Color(0xFF1B1D22),
      surfaceContainerHigh: light
          ? const Color(0xFFEBEDF1)
          : const Color(0xFF23252B),
      surfaceContainerHighest: light
          ? const Color(0xFFE4E6EB)
          : const Color(0xFF2C2F36),
      onSurface: light ? const Color(0xFF15171C) : const Color(0xFFECEDF1),
      onSurfaceVariant: light
          ? const Color(0xFF596070)
          : const Color(0xFFA7ACB7),
      outline: light ? const Color(0xFFB4B9C5) : const Color(0xFF5B606B),
      outlineVariant: light
          ? const Color(0xFFE1E3E9)
          : const Color(0xFF2E3138),
      inverseSurface: light
          ? const Color(0xFF24262C)
          : const Color(0xFFECEDF1),
      onInverseSurface: light
          ? const Color(0xFFF3F4F7)
          : const Color(0xFF15171C),
      // No colour wash over raised surfaces: height is shown by shadow.
      surfaceTint: Colors.transparent,
      shadow: const Color(0xFF0B1226),
      scrim: const Color(0xFF0B1226),
    );
  }

  /// The colour of the editor's bar: the accent, deep enough for white
  /// icons to sit on it.
  static Color headerOf(ColorScheme scheme) {
    final hsl = HSLColor.fromColor(scheme.primary);
    final dark = scheme.brightness == Brightness.dark;
    return hsl
        .withSaturation((hsl.saturation * 0.85).clamp(0.0, 0.62).toDouble())
        .withLightness(dark ? 0.15 : 0.24)
        .toColor();
  }

  // -- shape ----------------------------------------------------------------

  /// Buttons, fields, chips, menu rows.
  static const radiusControl = 12.0;

  /// Cards and tiles.
  static const radiusCard = 16.0;

  /// Dialogs, sheets and floating panels.
  static const radiusSheet = 24.0;

  static const controlShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(radiusControl)),
  );
  static const cardShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(radiusCard)),
  );
  static const sheetShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(radiusSheet)),
  );

  // -- depth ----------------------------------------------------------------

  /// The shadow of what floats over the page (tool strips, menus).
  static List<BoxShadow> floatingShadow(ColorScheme scheme) => [
    BoxShadow(
      color: scheme.shadow.withValues(
        alpha: scheme.brightness == Brightness.light ? 0.10 : 0.45,
      ),
      blurRadius: 18,
      offset: const Offset(0, 6),
    ),
    BoxShadow(
      color: scheme.shadow.withValues(
        alpha: scheme.brightness == Brightness.light ? 0.05 : 0.25,
      ),
      blurRadius: 3,
      offset: const Offset(0, 1),
    ),
  ];

  /// What floating things are made of: the paper itself in the light,
  /// a step above the dark page at night.
  static Color floatingSurface(ColorScheme scheme) =>
      scheme.brightness == Brightness.light
      ? scheme.surface
      : scheme.surfaceContainerHigh;

  // -- motion ---------------------------------------------------------------

  /// A press, a toggle.
  static Duration get fast =>
      isThisATest ? Duration.zero : const Duration(milliseconds: 140);

  /// Something appearing or changing place.
  static Duration get standard =>
      isThisATest ? Duration.zero : const Duration(milliseconds: 240);

  /// Whether nothing should move here: the system asks for no animations,
  /// or the screen is e-ink.
  static bool isStill(BuildContext context) =>
      (MediaQuery.maybeDisableAnimationsOf(context) ?? false) ||
      EInkScope.maybeOf(context) != null;

  /// Coming in: quick at first, settling gently.
  static const enter = Cubic(0.2, 0.8, 0.2, 1);

  /// Going away: without lingering.
  static const exit = Curves.easeInCubic;
}

/// How one page follows another: the new page slides in from the side
/// while the one before it steps back a little, so the eye can follow
/// where it went.
///
/// It is the movement of [CupertinoPageTransitionsBuilder] without its
/// swipe-back strip along the left edge: a pen stroke that starts at the
/// edge of the paper must stay a pen stroke.
class DefterPageTransitionsBuilder extends PageTransitionsBuilder {
  const new();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (DefterDesign.isStill(context)) return child;
    return CupertinoPageTransition(
      primaryRouteAnimation: animation,
      secondaryRouteAnimation: secondaryAnimation,
      linearTransition: false,
      child: child,
    );
  }
}

/// A surface that floats over the page: a strip of tools, a panel hanging
/// from the bar, the buttons next to a picture. Paper with a hairline
/// around it and a soft shadow under it, the same everywhere.
class FloatingPanel extends StatelessWidget {
  const new({
    super.key,
    required this.child,
    this.radius = DefterDesign.radiusSheet,
    this.color,
  });

  /// A panel with fully round ends (a pill).
  const FloatingPanel.pill({super.key, required this.child, this.color})
    : radius = null;

  final Widget child;

  /// The corner radius; null for a pill.
  final double? radius;

  /// The colour of the panel, if not [DefterDesign.floatingSurface].
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = ColorScheme.of(context);
    final side = BorderSide(color: colors.outlineVariant);
    final radius = this.radius;
    final ShapeBorder shape = radius == null
        ? StadiumBorder(side: side)
        : RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
            side: side,
          );
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: shape,
        shadows: DefterDesign.floatingShadow(colors),
      ),
      child: Material(
        color: color ?? DefterDesign.floatingSurface(colors),
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }
}

/// Lets [child] give a little under the finger: it shrinks slightly while
/// it is pressed and springs back when let go. It only watches the
/// pointer; taps are handled by whatever is inside as before.
class PressScale extends StatefulWidget {
  const new({super.key, required this.child, this.pressedScale = 0.97});

  final Widget child;
  final double pressedScale;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _pressed = false;

  void _set(bool pressed) {
    if (_pressed == pressed || !mounted) return;
    setState(() => _pressed = pressed);
  }

  @override
  Widget build(BuildContext context) {
    final still = DefterDesign.isStill(context);
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _pressed && !still ? widget.pressedScale : 1,
        duration: DefterDesign.fast,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Lets [child] arrive instead of popping up: it fades in while growing
/// the last few percent from [alignment] (where it hangs from).
class Appear extends StatefulWidget {
  const new({
    super.key,
    required this.child,
    this.alignment = Alignment.topCenter,
  });

  final Widget child;
  final Alignment alignment;

  @override
  State<Appear> createState() => _AppearState();
}

class _AppearState extends State<Appear> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: DefterDesign.standard,
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: DefterDesign.enter,
  );

  @override
  void initState() {
    super.initState();
    if (DefterDesign.standard == Duration.zero) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (DefterDesign.isStill(context)) _controller.value = 1;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _curve,
    child: ScaleTransition(
      scale: Tween<double>(begin: 0.96, end: 1).animate(_curve),
      alignment: widget.alignment,
      child: widget.child,
    ),
  );
}
