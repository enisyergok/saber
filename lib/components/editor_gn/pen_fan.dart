import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:saber/components/editor_gn/gn_actions.dart';
import 'package:saber/components/editor_gn/pen_fan_geometry.dart';
import 'package:saber/components/theming/uni_icon.dart';
import 'package:saber/components/eink/eink_scope.dart';
import 'package:saber/data/defter_strings.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/tools/eraser.dart';
import 'package:saber/data/tools/highlighter.dart';
import 'package:saber/data/tools/pen.dart';
import 'package:saber/data/tools/pencil.dart';
import 'package:saber/data/tools/shape_pen.dart';
import 'package:saber/i18n/strings.g.dart';

/// A round pen button that can be dragged anywhere on the page. Tapping it
/// opens a fan: tools on the outer ring, colours on the inner ring.
///
/// Only the button (and, while open, the fan) catches touches; the rest of
/// the page is untouched.
class PenFan extends StatefulWidget {
  const PenFan({super.key, required this.actions});

  final GnActions actions;

  /// The colours of the inner ring.
  static const colors = <Color>[
    Color(0xFF111827),
    Color(0xFF6B7280),
    Color(0xFFDC2626),
    Color(0xFFF97316),
    Color(0xFFFBBF24),
    Color(0xFF16A34A),
    Color(0xFF2563EB),
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
  ];

  @override
  State<PenFan> createState() => _PenFanState();
}

class _PenFanState extends State<PenFan> {
  var _open = false;
  Offset? _dragPos; // fractions of the screen while dragging

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

  void _pickTool(int i) {
    final a = widget.actions;
    switch (i) {
      case 0:
        a.selectPen();
      case 1:
        a.selectPencil();
      case 2:
        a.selectHighlighter();
      case 3:
        a.toggleShape();
      default:
        if (a.tool is! Eraser) a.selectEraser();
    }
    setState(() {});
  }

  bool _toolSelected(int i) {
    final a = widget.actions;
    return switch (i) {
      0 => a.isPen,
      1 => a.isPencil,
      2 => a.isHighlighter,
      3 => a.isShape,
      _ => a.tool is Eraser,
    };
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final home = _position(size);
    // While open the button moves aside if the fan would run off screen.
    final pos = _open ? PenFanGeometry.fitPosition(home, size) : home;
    final colors = ColorScheme.of(context);
    final tool = widget.actions.tool;
    final current = tool is Pen ? tool.color : null;
    final geometry = PenFanGeometry(
      direction: PenFanGeometry.bestDirection(pos, size),
    );
    final eInk = EInkScope.maybeOf(context) != null;
    final animate = !eInk && !MediaQuery.disableAnimationsOf(context);

    const box = PenFanGeometry.toolOuter + 12;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (_open)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => setState(() => _open = false),
            ),
          ),
        if (_open)
          Positioned(
            left: pos.dx - box,
            top: pos.dy - box,
            width: box * 2,
            height: box * 2,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: animate ? 0 : 1, end: 1),
              duration: const Duration(milliseconds: 170),
              curve: Curves.easeOutCubic,
              builder: (context, t, child) => Opacity(
                opacity: t,
                child: Transform.scale(scale: 0.6 + 0.4 * t, child: child),
              ),
              child: _FanBody(
                geometry: geometry,
                colorScheme: colors,
                eInk: eInk,
                selectedColor: current,
                toolSelected: _toolSelected,
                icons: _toolIcons(),
                onHit: (hit) {
                  switch (hit) {
                    case FanTool(:final index):
                      _pickTool(index);
                    case FanColor(:final index):
                      if (tool is! Pen) widget.actions.selectPen();
                      widget.actions.spec.setColor(PenFan.colors[index]);
                      setState(() => _open = false);
                  }
                },
              ),
            ),
          ),
        AnimatedPositioned(
          duration: animate ? const Duration(milliseconds: 150) : Duration.zero,
          curve: Curves.easeOutCubic,
          left: pos.dx - PenFanGeometry.buttonRadius,
          top: pos.dy - PenFanGeometry.buttonRadius,
          child: _button(colors, tool, current),
        ),
      ],
    );
  }

  List<Widget> _toolIcons() {
    final a = widget.actions;
    return [
      UniIcon(a.writingPen.icon, size: 30),
      const Icon(Pencil.pencilIcon, size: 30),
      const Icon(Highlighter.highlighterIcon, size: 30),
      const Icon(ShapePen.shapePenIcon, size: 30),
      const Icon(Symbols.ink_eraser_rounded, size: 30),
    ];
  }

  Widget _button(ColorScheme colors, Object tool, Color? current) {
    const d = PenFanGeometry.buttonRadius * 2;
    final Widget icon = tool is Eraser
        ? const Icon(Symbols.ink_eraser_rounded, size: 26)
        : tool is Highlighter
        ? const Icon(Highlighter.highlighterIcon, size: 26)
        : tool is Pencil
        ? const Icon(Pencil.pencilIcon, size: 26)
        : tool is ShapePen
        ? const Icon(ShapePen.shapePenIcon, size: 26)
        : UniIcon(widget.actions.writingPen.icon, size: 26);
    final glow = current ?? colors.primary;
    return Semantics(
      button: true,
      label: DefterStrings.penFanButton,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _open = !_open),
        onPanStart: (_) => setState(() => _open = false),
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
            child: Center(child: icon),
          ),
        ),
      ),
    );
  }
}

class _FanBody extends StatelessWidget {
  const _FanBody({
    required this.geometry,
    required this.colorScheme,
    required this.eInk,
    required this.selectedColor,
    required this.toolSelected,
    required this.icons,
    required this.onHit,
  });

  final PenFanGeometry geometry;
  final ColorScheme colorScheme;
  final bool eInk;
  final Color? selectedColor;
  final bool Function(int) toolSelected;
  final List<Widget> icons;
  final ValueChanged<FanHit> onHit;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final center = Offset(c.maxWidth / 2, c.maxHeight / 2);
        final painter = _FanPainter(
          geometry: geometry,
          scheme: colorScheme,
          eInk: eInk,
          selectedColor: selectedColor,
          selectedTool: [
            for (var i = 0; i < geometry.toolCount; i++) toolSelected(i),
          ],
        );
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) {
            final hit = geometry.hit(d.localPosition - center);
            if (hit != null) onHit(hit);
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: CustomPaint(painter: painter),
              ),
              for (var i = 0; i < geometry.toolCount; i++)
                Positioned(
                  left: center.dx + geometry.toolCenter(i).dx - 18,
                  top: center.dy + geometry.toolCenter(i).dy - 18,
                  width: 36,
                  height: 36,
                  child: IgnorePointer(
                    child: IconTheme(
                      data: IconThemeData(
                        color: toolSelected(i)
                            ? colorScheme.onSurface
                            : colorScheme.onSurfaceVariant,
                      ),
                      child: Center(child: icons[i]),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _FanPainter extends CustomPainter {
  _FanPainter({
    required this.geometry,
    required this.scheme,
    required this.eInk,
    required this.selectedColor,
    required this.selectedTool,
  });

  final PenFanGeometry geometry;
  final ColorScheme scheme;
  final bool eInk;
  final Color? selectedColor;
  final List<bool> selectedTool;

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

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final g = geometry;
    final surface = Color.alphaBlend(
      Colors.white.withValues(alpha: 0.0),
      scheme.surface,
    );
    final tools = _sector(
      c,
      PenFanGeometry.toolInner,
      PenFanGeometry.toolOuter,
      g.start,
      PenFanGeometry.span,
    );
    final colors = _sector(
      c,
      PenFanGeometry.colorInner,
      PenFanGeometry.colorOuter,
      g.start,
      PenFanGeometry.span,
    );
    for (final path in [tools, colors]) {
      if (!eInk) {
        canvas.drawShadow(path, Colors.black.withValues(alpha: 0.55), 8, true);
      }
      canvas.drawPath(path, Paint()..color = surface);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = eInk ? 1.5 : 1
          ..color = scheme.outlineVariant,
      );
    }
    // selected tool: a tinted cell with a small line under the icon
    final cell = PenFanGeometry.span / g.toolCount;
    for (var i = 0; i < g.toolCount; i++) {
      if (!selectedTool[i]) continue;
      canvas.drawPath(
        _sector(
          c,
          PenFanGeometry.toolInner,
          PenFanGeometry.toolOuter,
          g.start + cell * i,
          cell,
        ),
        Paint()..color = scheme.primary.withValues(alpha: 0.16),
      );
      final mid = g.cellAngle(i, g.toolCount);
      final under =
          c +
          Offset.fromDirection(
            mid,
            (PenFanGeometry.toolInner + PenFanGeometry.toolOuter) / 2 - 28,
          );
      canvas.drawCircle(under, 2.5, Paint()..color = scheme.primary);
    }
    // colours
    for (var i = 0; i < g.colorCount; i++) {
      final color = _colorOf(i);
      final p = c + g.colorCenter(i);
      canvas.drawCircle(p, 10.5, Paint()..color = color);
      final chosen =
          selectedColor != null &&
          selectedColor!.withAlpha(255).toARGB32() == color.toARGB32();
      if (chosen) {
        canvas.drawCircle(
          p,
          15.5,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5
            ..color = scheme.primary,
        );
      }
    }
  }

  Color _colorOf(int i) => PenFan.colors[i];

  @override
  bool shouldRepaint(_FanPainter old) =>
      old.geometry.direction != geometry.direction ||
      old.selectedColor != selectedColor ||
      old.eInk != eInk ||
      !_sameList(old.selectedTool, selectedTool) ||
      old.scheme != scheme;

  bool _sameList(List<bool> a, List<bool> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
