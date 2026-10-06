import 'dart:math' as math;
import 'dart:ui';

import 'package:saber/components/canvas/_stroke.dart';
import 'package:saber/data/prefs.dart';

import 'package:saber/data/tools/_tool.dart';
import 'package:saber/data/tools/ink_eraser.dart';
import 'package:sbn/tool_id.dart';

double square(double x) => x * x;
double sqrDistanceBetween(Offset p1, Offset p2) =>
    square(p1.dx - p2.dx) + square(p1.dy - p2.dy);

class Eraser extends Tool {
  /// The radius of the eraser. Can be changed while the tool is in use.
  double size;
  double get sqrSize => square(size);

  /// How far from a stroke's bounding box the eraser can still touch it.
  /// The extra 1 keeps points exactly on the edge from being missed.
  double get _reach => math.sqrt(sqrSize) + 1;

  /// The sizes offered by the toolbar, smallest first. The smallest is for
  /// taking a single letter or part of a line out of dense writing.
  static const sizePresets = <double>[4, 10, 25, 50];

  List<Stroke> _erased = [];

  /// Whether the eraser rubs out only what it passes over (the default) or
  /// takes away every stroke it touches as a whole.
  static bool get precise => stows.eraserPrecise.value;

  final _ink = InkEraser();

  /// Begins a drag of the precise eraser over [strokes], the page's own
  /// list.
  void beginPrecise(List<Stroke> strokes) => _ink.begin(strokes);

  /// Moves the precise eraser to [position], rubbing out what it passes
  /// over in [strokes] (which is changed in place). Returns whether
  /// anything was rubbed out.
  bool erasePrecise(Offset position, List<Stroke> strokes) =>
      _ink.moveTo(position, size, strokes);

  /// Ends a drag of the precise eraser: what became of each stroke it
  /// touched.
  List<StrokeReplacement> endPrecise() => _ink.finish();

  /// Uses the person's last chosen size unless [size] is given.
  new({double? size}) : size = size ?? stows.eraserSize.value;

  @override
  ToolId get toolId => .eraser;

  /// Returns any [strokes] that are close to the given [eraserPos].
  List<Stroke> checkForOverlappingStrokes(
    Offset eraserPos,
    List<Stroke> strokes,
  ) {
    final List<Stroke> overlapping = [];
    for (int i = 0; i < strokes.length; i++) {
      final stroke = strokes[i];
      // Most strokes are far from the eraser: skip them without looking at
      // their vertices.
      if (!stroke.bounds.inflate(_reach).contains(eraserPos)) continue;
      if (_shouldStrokeBeErased(eraserPos, stroke, sqrSize)) {
        overlapping.add(stroke);
        _erased.add(stroke);
      }
    }
    return overlapping;
  }

  /// Returns the strokes that have been erased during this drag.
  List<Stroke> onDragEnd() {
    final List<Stroke> erased = _erased;
    _erased = [];
    return erased;
  }

  static bool _shouldStrokeBeErased(
    Offset eraserPos,
    Stroke stroke,
    double sqrSize,
  ) {
    if (stroke.length <= 3) {
      if (stroke.lowQualityPath.contains(eraserPos)) return true;
    }

    /// skip checking every few vertices for performance
    final int verticesToSkip = switch (stroke.lowQualityPolygon.length) {
      < 100 => 0,
      < 1000 => 1,
      _ => 2,
    };

    for (
      int i = 0;
      i < stroke.lowQualityPolygon.length;
      i += verticesToSkip + 1
    ) {
      final Offset strokeVertex = stroke.lowQualityPolygon[i];
      if (sqrDistanceBetween(strokeVertex, eraserPos) <= sqrSize) return true;
    }
    return false;
  }
}
