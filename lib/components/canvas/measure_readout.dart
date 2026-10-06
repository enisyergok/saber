import 'dart:async';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:saber/data/tools/pen_assist.dart';

/// What the measuring tool and the angle guide of the pen panel read,
/// shown next to the pen while a line is drawn and for a few seconds after.
///
/// It fills the area it is given (put it over the page) and places the
/// readout itself: above the pen, or below it when there is no room above.
/// Without a known pen position it sits at the top, in the middle.
class MeasureReadout extends StatefulWidget {
  const MeasureReadout({super.key});

  /// How far above the pen's tip the readout floats.
  static const lift = 72.0;

  /// Where a readout of [childSize] goes in an area of [size] when the
  /// pen is at [pen] (in the area's own coordinates).
  static Offset place(Size size, Size childSize, Offset? pen) {
    const margin = 8.0;
    double clampTo(double value, double max) =>
        max <= margin ? margin : value.clamp(margin, max).toDouble();
    if (pen == null) {
      return Offset(
        clampTo((size.width - childSize.width) / 2, size.width),
        margin * 2,
      );
    }
    var top = pen.dy - lift - childSize.height;
    // No room above: below the pen, clear of the hand's shadow.
    if (top < margin) top = pen.dy + lift / 2;
    return Offset(
      clampTo(
        pen.dx - childSize.width / 2,
        size.width - childSize.width - margin,
      ),
      clampTo(top, size.height - childSize.height - margin),
    );
  }

  @override
  State<MeasureReadout> createState() => _MeasureReadoutState();
}

class _MeasureReadoutState extends State<MeasureReadout> {
  Timer? _hide;

  @override
  void initState() {
    super.initState();
    PenAssist.readout.addListener(_changed);
    PenAssist.readoutAt.addListener(_rebuild);
    PenAssist.readoutFinished.addListener(_finished);
  }

  @override
  void dispose() {
    PenAssist.readout.removeListener(_changed);
    PenAssist.readoutAt.removeListener(_rebuild);
    PenAssist.readoutFinished.removeListener(_finished);
    _hide?.cancel();
    super.dispose();
  }

  /// The pen moved: what is shown is being drawn, and stays.
  void _rebuild() {
    _hide?.cancel();
    _hide = null;
    if (mounted && PenAssist.readout.value != null) setState(() {});
  }

  /// Something new is being measured: it stays until it is finished.
  void _changed() {
    _hide?.cancel();
    _hide = null;
    if (mounted) setState(() {});
  }

  /// A finished measurement goes away by itself.
  void _finished() {
    _hide?.cancel();
    _hide = Timer(PenAssist.readoutDuration, () {
      _hide = null;
      PenAssist.readout.value = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = PenAssist.readout.value;
    if (text == null) return const SizedBox.expand();

    final colors = ColorScheme.of(context);
    final box = context.findRenderObject();
    final global = PenAssist.readoutAt.value;
    final pen = global != null && box is RenderBox && box.hasSize
        ? box.globalToLocal(global)
        : null;
    return CustomSingleChildLayout(
      delegate: _NearPen(pen),
      child: Material(
        key: const ValueKey('measureReadout'),
        color: colors.inverseSurface,
        elevation: 4,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Text(
            text,
            style: TextStyle(
              color: colors.onInverseSurface,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
    );
  }
}

class _NearPen extends SingleChildLayoutDelegate {
  const _NearPen(this.pen);

  final Offset? pen;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size childSize) =>
      MeasureReadout.place(size, childSize, pen);

  @override
  bool shouldRelayout(_NearPen oldDelegate) => oldDelegate.pen != pen;
}
