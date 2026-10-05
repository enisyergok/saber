import 'package:flutter/material.dart';
import 'package:saber/components/eink/eink_refresh.dart';
import 'package:saber/components/eink/eink_scope.dart';
import 'package:saber/data/eink/eink_style.dart';

/// Draws the short e-ink refresh over [child] when [EInkRefresh] asks for
/// one. It never blocks touches or the pen, and costs nothing while idle.
class EInkRefreshOverlay extends StatefulWidget {
  const new({super.key, required this.child});

  final Widget? child;

  @override
  State<EInkRefreshOverlay> createState() => _EInkRefreshOverlayState();
}

class _EInkRefreshOverlayState extends State<EInkRefreshOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this)
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) setState(() {});
    });
  int _lastSerial = EInkRefresh.instance.serial;

  @override
  void initState() {
    super.initState();
    EInkRefresh.instance.addListener(_onRefresh);
  }

  @override
  void dispose() {
    EInkRefresh.instance.removeListener(_onRefresh);
    _controller.dispose();
    super.dispose();
  }

  void _onRefresh() {
    if (!mounted || EInkRefresh.instance.serial == _lastSerial) return;
    _lastSerial = EInkRefresh.instance.serial;
    final style = EInkScope.maybeOf(context);
    if (style == null || !style.refreshEffect) return;
    if (MediaQuery.disableAnimationsOf(context)) return;
    _controller.duration = switch (EInkRefresh.instance.kind) {
      EInkRefreshKind.full => const Duration(milliseconds: 560),
      _ => const Duration(milliseconds: 280),
    };
    _controller.forward(from: 0);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final style = EInkScope.maybeOf(context);
    final child = widget.child ?? const SizedBox.shrink();
    // The same widgets are built with e-ink mode on or off, so switching
    // the mode never rebuilds (and so never resets) the app below.
    return Stack(
      fit: StackFit.passthrough,
      children: [
        RepaintBoundary(child: child),
        if (style != null && _controller.isAnimating)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => CustomPaint(
                  painter: EInkRefreshPainter(
                    kind: EInkRefresh.instance.kind ?? EInkRefreshKind.pageTurn,
                    t: _controller.value,
                    style: style,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The flash itself, as a function of time [t] (0 to 1).
class EInkRefreshPainter extends CustomPainter {
  const new({
    required this.kind,
    required this.t,
    required this.style,
  });

  final EInkRefreshKind kind;
  final double t;
  final EInkStyle style;

  /// The colour and opacity of the flash at [t].
  static (Color, double) frame(EInkRefreshKind kind, double t, EInkStyle style) {
    switch (kind) {
      case EInkRefreshKind.pageTurn:
        // grey comes up quickly, then the page shows through again
        final grey = Color.lerp(style.paper, style.ink, 0.35)!;
        final alpha = t < 0.3 ? t / 0.3 * 0.30 : (1 - t) / 0.7 * 0.30;
        return (grey, alpha);
      case EInkRefreshKind.full:
        // dark, then light, then the page
        if (t < 0.25) return (style.ink, t / 0.25 * 0.95);
        if (t < 0.5) {
          final k = (t - 0.25) / 0.25;
          return (Color.lerp(style.ink, style.paper, k)!, 0.95);
        }
        return (style.paper, (1 - t) / 0.5 * 0.95);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final (color, alpha) = frame(kind, t, style);
    if (alpha <= 0) return;
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = color.withValues(alpha: alpha.clamp(0.0, 1.0)),
    );
  }

  @override
  bool shouldRepaint(EInkRefreshPainter old) =>
      old.t != t || old.kind != kind || old.style != style;
}
