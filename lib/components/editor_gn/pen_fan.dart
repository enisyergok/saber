import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:saber/components/editor_gn/gn_actions.dart';
import 'package:saber/components/editor_gn/pen_fan_geometry.dart';
import 'package:saber/components/eink/eink_scope.dart';
import 'package:saber/components/theming/uni_icon.dart';
import 'package:saber/data/defter_strings.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/tools/eraser.dart';
import 'package:saber/data/tools/highlighter.dart';
import 'package:saber/data/tools/pen.dart';
import 'package:saber/data/tools/pen_styles.dart';
import 'package:saber/data/tools/pencil.dart';
import 'package:saber/data/tools/shape_pen.dart';

/// The things the tool ring goes through.
enum FanToolId {
  fountain,
  ballpoint,
  brush,
  calligraphy,
  pencil,
  highlighter,
  shape,
  eraser,
}

/// A round pen button that can be dragged anywhere on the page. Tapping it
/// opens a fan that unfolds cell by cell: tools on the outer ring, colours
/// on the inner ring. Dragging along a ring turns it, so other tools and
/// colours come round.
///
/// Only the button (and, while open, the fan) catches touches; the rest of
/// the page is untouched.
class PenFan extends StatefulWidget {
  const PenFan({super.key, required this.actions});

  final GnActions actions;

  @override
  State<PenFan> createState() => _PenFanState();
}

enum _Ring { tools, colors }

class _Slot {
  const _Slot(this.index, this.position, this.alpha);

  /// Which item of the ring this is.
  final int index;

  /// Where it is, in cells (can be between two cells while turning).
  final double position;

  /// 0 (not shown) to 1.
  final double alpha;
}

/// The items to draw for a ring turned by [offset]: one more than the
/// cells, so something is always coming in at the edge. [reveal] (0-1) is
/// how far the fan has unfolded.
List<_Slot> _slots(int count, int n, double offset, double reveal) {
  final base = offset.floor();
  final frac = offset - base;
  return [
    for (var k = 0; k <= count; k++)
      () {
        final p = k - frac;
        final edge =
            1 - (math.max(-p, p - (count - 1)) / 0.5).clamp(0.0, 1.0);
        final appear = (reveal * count - p).clamp(0.0, 1.0);
        return _Slot(
          FanRing.wrap(base + k, n),
          p,
          math.min(edge, appear),
        );
      }(),
  ];
}

class _PenFanState extends State<PenFan> with TickerProviderStateMixin {
  static const _toolCount = 8;
  static const _colorN = 27; // penFanColors.length

  late final AnimationController _unfold = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 460),
    reverseDuration: const Duration(milliseconds: 170),
  )..addStatusListener((_) => setState(() {}));
  late final AnimationController _snap = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  )..addListener(_onSnap);

  var _open = false;
  Offset? _dragPos; // fractions of the screen while dragging
  var _toolOffset = 0.0;
  var _colorOffset = 0.0;
  _Ring? _turning;
  var _lastAngle = 0.0;
  var _lastRel = Offset.zero;
  var _snapFrom = 0.0;
  var _snapTo = 0.0;
  _Ring? _snapRing;

  @override
  void dispose() {
    _unfold.dispose();
    _snap.dispose();
    super.dispose();
  }

  Offset get _fraction =>
      _dragPos ?? Offset(stows.penFanX.value, stows.penFanY.value);

  Offset _position(Size size) {
    const m = PenFanGeometry.buttonRadius + 8;
    final f = _fraction;
    return Offset(
      (f.dx * size.width).clamp(m, math.max(m, size.width - m)),
      (f.dy * size.height).clamp(m, math.max(m, size.height - m)),
    );
  }

  bool get _animate =>
      EInkScope.maybeOf(context) == null && !MediaQuery.disableAnimationsOf(context);

  // -- what is selected -----------------------------------------------------

  FanToolId get _selectedTool {
    final tool = widget.actions.tool;
    if (tool is Eraser) return FanToolId.eraser;
    if (tool is ShapePen) return FanToolId.shape;
    if (tool is Highlighter) return FanToolId.highlighter;
    if (tool is Pencil) return FanToolId.pencil;
    return switch (PenStyles.of(tool)) {
      PenStyle.ballpoint => FanToolId.ballpoint,
      PenStyle.brush => FanToolId.brush,
      PenStyle.calligraphy => FanToolId.calligraphy,
      _ => FanToolId.fountain,
    };
  }

  int get _selectedColor {
    final tool = widget.actions.tool;
    if (tool is! Pen) return -1;
    final argb = tool.color.withAlpha(255).toARGB32();
    return penFanColors.indexWhere((c) => c.toARGB32() == argb);
  }

  // -- opening and closing --------------------------------------------------

  void _toggle() {
    if (_open) {
      _open = false;
      _animate ? _unfold.reverse() : _unfold.value = 0;
    } else {
      _open = true;
      _toolOffset = FanRing.reveal(
        _toolOffset,
        _toolCount,
        5,
        _selectedTool.index,
      );
      final color = _selectedColor;
      if (color >= 0) {
        _colorOffset = FanRing.reveal(_colorOffset, _colorN, 9, color);
      }
      _animate ? _unfold.forward(from: 0) : _unfold.value = 1;
    }
    setState(() {});
  }

  void _close() {
    if (!_open) return;
    _toggle();
  }

  // -- picking --------------------------------------------------------------

  void _pickTool(FanToolId id) {
    final a = widget.actions;
    switch (id) {
      case FanToolId.pencil:
        a.selectPencil();
      case FanToolId.highlighter:
        a.selectHighlighter();
      case FanToolId.shape:
        if (!a.isShape) a.toggleShape();
      case FanToolId.eraser:
        if (a.tool is! Eraser) a.selectEraser();
      case FanToolId.fountain:
      case FanToolId.ballpoint:
      case FanToolId.brush:
      case FanToolId.calligraphy:
        final style = switch (id) {
          FanToolId.ballpoint => PenStyle.ballpoint,
          FanToolId.brush => PenStyle.brush,
          FanToolId.calligraphy => PenStyle.calligraphy,
          _ => PenStyle.fountain,
        };
        final tool = a.tool;
        final from = tool is Pen && tool is! ShapePen ? tool : a.writingPen;
        final pen = PenStyles.create(style);
        if (from is! Highlighter) {
          pen.color = PenStyles.hasOpacity(style)
              ? from.color
              : from.color.withValues(alpha: 1);
        }
        a.controller.close();
        a.spec.setTool(pen);
    }
    setState(() {});
  }

  void _pickColor(Color color) {
    final a = widget.actions;
    if (a.tool is! Pen) a.selectPen();
    a.spec.setColor(color);
    _close();
  }

  // -- turning a ring -------------------------------------------------------

  static const _cellsOf = {_Ring.tools: 5, _Ring.colors: 9};

  double _offsetOf(_Ring ring) =>
      ring == _Ring.tools ? _toolOffset : _colorOffset;

  void _setOffset(_Ring ring, double v) {
    if (ring == _Ring.tools) {
      _toolOffset = v;
    } else {
      _colorOffset = v;
    }
  }

  void _onSnap() {
    final ring = _snapRing;
    if (ring == null) return;
    final t = Curves.easeOutCubic.transform(_snap.value);
    setState(() => _setOffset(ring, _snapFrom + (_snapTo - _snapFrom) * t));
  }

  void _panStart(Offset rel, PenFanGeometry g) {
    _snap.stop();
    _snapRing = null;
    _turning = null;
    if (!g.inside(rel)) return;
    _turning = rel.distance >= PenFanGeometry.toolInner - 4
        ? _Ring.tools
        : _Ring.colors;
    _lastAngle = rel.direction;
    _lastRel = rel;
  }

  void _panUpdate(Offset rel) {
    final ring = _turning;
    if (ring == null || rel.distance < 10) return;
    final angle = rel.direction;
    final delta = FanRing.angleDelta(_lastAngle, angle);
    _lastAngle = angle;
    _lastRel = rel;
    setState(
      () => _setOffset(
        ring,
        _offsetOf(ring) +
            FanRing.turnBy(delta, _cellsOf[ring]!, PenFanGeometry.span),
      ),
    );
  }

  void _panEnd(Velocity velocity) {
    final ring = _turning;
    _turning = null;
    if (ring == null) return;
    final r = math.max(_lastRel.distance, 1.0);
    final t = Offset(-math.sin(_lastRel.direction), math.cos(_lastRel.direction));
    final v = velocity.pixelsPerSecond;
    final angular = (v.dx * t.dx + v.dy * t.dy) / r;
    final cellsPerSecond = FanRing.turnBy(
      angular,
      _cellsOf[ring]!,
      PenFanGeometry.span,
    );
    final from = _offsetOf(ring);
    final to = (from + (cellsPerSecond * 0.16).clamp(-8.0, 8.0)).roundToDouble();
    _snapRing = ring;
    _snapFrom = from;
    _snapTo = to;
    if (_animate) {
      _snap.forward(from: 0);
    } else {
      setState(() => _setOffset(ring, to));
    }
  }

  // -- building -------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final home = _position(size);
    // While open the button moves aside if the fan would run off screen.
    final pos = _open ? PenFanGeometry.fitPosition(home, size) : home;
    final scheme = ColorScheme.of(context);
    final tool = widget.actions.tool;
    final current = tool is Pen ? tool.color : null;
    final geometry = PenFanGeometry(
      direction: PenFanGeometry.bestDirection(pos, size),
    );
    final eInk = EInkScope.maybeOf(context) != null;
    final animate = _animate;

    const box = PenFanGeometry.toolOuter + 14;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (_open)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _close,
            ),
          ),
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _unfold,
            builder: (context, _) {
              if (_unfold.value == 0 && !_open) return const SizedBox.shrink();
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: pos.dx - box,
                    top: pos.dy - box,
                    width: box * 2,
                    height: box * 2,
                    child: _FanBody(
                      geometry: geometry,
                      scheme: scheme,
                      eInk: eInk,
                      unfold: _unfold.value,
                      toolOffset: _toolOffset,
                      colorOffset: _colorOffset,
                      selectedTool: _selectedTool.index,
                      selectedColor: _selectedColor,
                      onTap: (rel) {
                        if (_unfold.value < 0.9 || !_open) return;
                        switch (geometry.hit(rel)) {
                          case FanTool(:final index):
                            final item = FanRing.itemAt(
                              _toolOffset,
                              _toolCount,
                              index,
                            );
                            _pickTool(FanToolId.values[item]);
                          case FanColor(:final index):
                            _pickColor(
                              penFanColors[FanRing.itemAt(
                                _colorOffset,
                                _colorN,
                                index,
                              )],
                            );
                          case null:
                            break;
                        }
                      },
                      onPanStart: (rel) => _panStart(rel, geometry),
                      onPanUpdate: _panUpdate,
                      onPanEnd: _panEnd,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        AnimatedPositioned(
          duration: animate ? const Duration(milliseconds: 150) : Duration.zero,
          curve: Curves.easeOutCubic,
          left: pos.dx - PenFanGeometry.buttonRadius,
          top: pos.dy - PenFanGeometry.buttonRadius,
          child: _button(scheme, tool, current),
        ),
      ],
    );
  }

  Widget _button(ColorScheme scheme, Object tool, Color? current) {
    const d = PenFanGeometry.buttonRadius * 2;
    final glow = current ?? scheme.primary;
    return Semantics(
      button: true,
      label: DefterStrings.penFanButton,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggle,
        onPanStart: (_) {
          if (_open) _toggle();
        },
        onPanUpdate: (details) {
          final size = MediaQuery.sizeOf(context);
          final next = _position(size) + details.delta;
          setState(() {
            _dragPos = Offset(
              (next.dx / size.width).clamp(0.0, 1.0),
              (next.dy / size.height).clamp(0.0, 1.0),
            );
          });
        },
        onPanEnd: (_) {
          final p = _dragPos;
          if (p != null) {
            stows.penFanX.value = p.dx;
            stows.penFanY.value = p.dy;
          }
          setState(() => _dragPos = null);
        },
        child: Container(
          width: d,
          height: d,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF1F2430),
            border: Border.all(color: glow, width: 2),
            boxShadow: [
              BoxShadow(
                color: glow.withValues(alpha: 0.35),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          ),
          child: IconTheme(
            data: const IconThemeData(color: Colors.white),
            child: Center(child: _iconOf(_selectedTool, 26)),
          ),
        ),
      ),
    );
  }

  Widget _iconOf(FanToolId id, double size) => switch (id) {
    FanToolId.fountain => UniIcon(Pen.fountainPenIcon, size: size),
    FanToolId.ballpoint => UniIcon(Pen.ballpointPenIcon, size: size),
    FanToolId.brush => UniIcon(Pen.brushPenIcon, size: size),
    FanToolId.calligraphy => UniIcon(Pen.calligraphyPenIcon, size: size),
    FanToolId.pencil => Icon(Pencil.pencilIcon, size: size),
    FanToolId.highlighter => Icon(Highlighter.highlighterIcon, size: size),
    FanToolId.shape => Icon(ShapePen.shapePenIcon, size: size),
    FanToolId.eraser => Icon(Symbols.ink_eraser_rounded, size: size),
  };
}

class _FanBody extends StatelessWidget {
  const _FanBody({
    required this.geometry,
    required this.scheme,
    required this.eInk,
    required this.unfold,
    required this.toolOffset,
    required this.colorOffset,
    required this.selectedTool,
    required this.selectedColor,
    required this.onTap,
    required this.onPanStart,
    required this.onPanUpdate,
    required this.onPanEnd,
  });

  final PenFanGeometry geometry;
  final ColorScheme scheme;
  final bool eInk;
  final double unfold;
  final double toolOffset;
  final double colorOffset;
  final int selectedTool;
  final int selectedColor;
  final ValueChanged<Offset> onTap;
  final ValueChanged<Offset> onPanStart;
  final ValueChanged<Offset> onPanUpdate;
  final ValueChanged<Velocity> onPanEnd;

  Widget _icon(FanToolId id, Color color) {
    const s = 30.0;
    return IconTheme(
      data: IconThemeData(color: color),
      child: switch (id) {
        FanToolId.fountain => UniIcon(Pen.fountainPenIcon, size: s),
        FanToolId.ballpoint => UniIcon(Pen.ballpointPenIcon, size: s),
        FanToolId.brush => UniIcon(Pen.brushPenIcon, size: s),
        FanToolId.calligraphy => UniIcon(Pen.calligraphyPenIcon, size: s),
        FanToolId.pencil => const Icon(Pencil.pencilIcon, size: s),
        FanToolId.highlighter => const Icon(
          Highlighter.highlighterIcon,
          size: s,
        ),
        FanToolId.shape => const Icon(ShapePen.shapePenIcon, size: s),
        FanToolId.eraser => const Icon(Symbols.ink_eraser_rounded, size: s),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final center = Offset(
      PenFanGeometry.toolOuter + 14,
      PenFanGeometry.toolOuter + 14,
    );
    final toolReveal = Curves.easeOutCubic.transform(
      ((unfold - 0.25) / 0.55).clamp(0.0, 1.0),
    );
    final tools = _slots(
      geometry.toolCount,
      FanToolId.values.length,
      toolOffset,
      toolReveal,
    );
    final painter = _FanPainter(
      geometry: geometry,
      scheme: scheme,
      eInk: eInk,
      unfold: unfold,
      toolOffset: toolOffset,
      colorOffset: colorOffset,
      selectedTool: selectedTool,
      selectedColor: selectedColor,
    );
    return GestureDetector(
      behavior: HitTestBehavior.deferToChild,
      onTapUp: (d) => onTap(d.localPosition - center),
      onPanStart: (d) => onPanStart(d.localPosition - center),
      onPanUpdate: (d) => onPanUpdate(d.localPosition - center),
      onPanEnd: (d) => onPanEnd(d.velocity),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: CustomPaint(painter: painter),
          ),
          for (final s in tools)
            if (s.alpha > 0.01)
              Positioned(
                left: center.dx + geometry.toolAt(s.position).dx - 18,
                top: center.dy + geometry.toolAt(s.position).dy - 18,
                width: 36,
                height: 36,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: s.alpha,
                    child: Transform.scale(
                      scale: 0.5 + 0.5 * s.alpha,
                      child: Center(
                        child: _icon(
                          FanToolId.values[s.index],
                          s.index == selectedTool
                              ? scheme.onSurface
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _FanPainter extends CustomPainter {
  _FanPainter({
    required this.geometry,
    required this.scheme,
    required this.eInk,
    required this.unfold,
    required this.toolOffset,
    required this.colorOffset,
    required this.selectedTool,
    required this.selectedColor,
  });

  final PenFanGeometry geometry;
  final ColorScheme scheme;
  final bool eInk;
  final double unfold;
  final double toolOffset;
  final double colorOffset;
  final int selectedTool;
  final int selectedColor;

  Offset _center(Size size) => Offset(size.width / 2, size.height / 2);

  @override
  bool? hitTest(Offset position) {
    // Only the fan itself takes touches; the rest of the box lets them
    // through to the page (and the "tap outside" layer).
    const c = PenFanGeometry.toolOuter + 14;
    return geometry.inside(position - const Offset(c, c));
  }

  Path _sector(Offset c, double r0, double r1, double a0, double sweep) {
    final outer = Rect.fromCircle(center: c, radius: r1);
    final inner = Rect.fromCircle(center: c, radius: r0);
    return Path()
      ..moveTo(c.dx + r1 * math.cos(a0), c.dy + r1 * math.sin(a0))
      ..arcTo(outer, a0, sweep, false)
      ..lineTo(
        c.dx + r0 * math.cos(a0 + sweep),
        c.dy + r0 * math.sin(a0 + sweep),
      )
      ..arcTo(inner, a0 + sweep, -sweep, false)
      ..close();
  }

  void _ringBackground(Canvas canvas, Path path) {
    if (!eInk) {
      canvas.drawShadow(path, Colors.black.withValues(alpha: 0.5), 8, true);
    }
    canvas.drawPath(path, Paint()..color = scheme.surface);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = eInk ? 1.5 : 1
        ..color = scheme.outlineVariant,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = _center(size);
    final g = geometry;
    final colorReveal = Curves.easeOutCubic.transform(
      (unfold / 0.55).clamp(0.0, 1.0),
    );
    final toolReveal = Curves.easeOutCubic.transform(
      ((unfold - 0.25) / 0.55).clamp(0.0, 1.0),
    );

    // colour ring
    if (colorReveal > 0.001) {
      final ring = _sector(
        c,
        PenFanGeometry.colorInner,
        PenFanGeometry.colorOuter,
        g.start,
        PenFanGeometry.span * colorReveal,
      );
      _ringBackground(canvas, ring);
      for (final s in _slots(g.colorCount, penFanColors.length, colorOffset, colorReveal)) {
        if (s.alpha <= 0.01) continue;
        final p = c + g.colorAt(s.position);
        canvas.drawCircle(
          p,
          10.5 * (0.5 + 0.5 * s.alpha),
          Paint()..color = penFanColors[s.index].withValues(alpha: s.alpha),
        );
        if (s.index == selectedColor) {
          canvas.drawCircle(
            p,
            15.5,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.5
              ..color = scheme.primary.withValues(alpha: s.alpha),
          );
        }
      }
    }

    // tool ring
    if (toolReveal > 0.001) {
      final ring = _sector(
        c,
        PenFanGeometry.toolInner,
        PenFanGeometry.toolOuter,
        g.start,
        PenFanGeometry.span * toolReveal,
      );
      _ringBackground(canvas, ring);
      final cell = PenFanGeometry.span / g.toolCount;
      for (final s in _slots(g.toolCount, FanToolId.values.length, toolOffset, toolReveal)) {
        if (s.alpha <= 0.01 || s.index != selectedTool) continue;
        canvas.save();
        canvas.clipPath(ring);
        canvas.drawPath(
          _sector(
            c,
            PenFanGeometry.toolInner,
            PenFanGeometry.toolOuter,
            g.start + cell * s.position,
            cell,
          ),
          Paint()..color = scheme.primary.withValues(alpha: 0.16 * s.alpha),
        );
        canvas.restore();
        final under =
            c +
            Offset.fromDirection(
              g.start + cell * (s.position + 0.5),
              (PenFanGeometry.toolInner + PenFanGeometry.toolOuter) / 2 - 28,
            );
        canvas.drawCircle(
          under,
          2.5,
          Paint()..color = scheme.primary.withValues(alpha: s.alpha),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_FanPainter old) =>
      old.geometry.direction != geometry.direction ||
      old.unfold != unfold ||
      old.toolOffset != toolOffset ||
      old.colorOffset != colorOffset ||
      old.selectedTool != selectedTool ||
      old.selectedColor != selectedColor ||
      old.eInk != eInk ||
      old.scheme != scheme;
}
