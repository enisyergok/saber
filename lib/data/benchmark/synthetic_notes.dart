import 'dart:math';

import 'package:flutter/material.dart';
import 'package:saber/components/canvas/_stroke.dart';
import 'package:saber/data/editor/editor_core_info.dart';
import 'package:saber/data/editor/page.dart';
import 'package:saber/data/tools/pen.dart';
import 'package:sbn/tool_id.dart';

/// Builds deterministic, handwriting-like notes for benchmarks.
///
/// The same seed always produces the same note, so measurements taken
/// before and after a change are comparable.
abstract class SyntheticNotes {
  /// Points in one synthetic stroke: roughly one handwritten letter.
  static const pointsPerStroke = 24;

  /// Where on a page the Nth letter goes. Letters fill the page in rows,
  /// then start over on top of the earlier ones with a small offset.
  static Offset letterOrigin(int index) {
    const columns = 36;
    const rows = 33;
    final cell = index % (columns * rows);
    final pass = index ~/ (columns * rows);
    return Offset(
      40.0 + (cell % columns) * 25.5 + (pass % 5) * 3,
      60.0 + (cell ~/ columns) * 40 + (pass % 7) * 2,
    );
  }

  /// The position and pressure of point [i] of a letter drawn at [origin].
  static (Offset position, double pressure) letterPoint({
    required Offset origin,
    required int i,
    required int points,
    required double width,
    required double height,
    required double phase,
  }) {
    final t = i / (points - 1);
    final angle = t * 2 * pi * 1.25 + phase;
    return (
      Offset(
        origin.dx + t * width + cos(angle) * width * 0.35,
        origin.dy + sin(angle) * height * 0.5,
      ),
      0.35 + 0.4 * sin(t * pi),
    );
  }

  /// An unfinished fountain pen stroke on [page] with no points yet.
  static Stroke emptyStroke({required EditorPage page, int pageIndex = 0}) {
    return Stroke(
      color: Colors.black,
      pressureEnabled: true,
      options: Pen.fountainPenOptions,
      pageIndex: pageIndex,
      page: page,
      toolId: ToolId.fountainPen,
    );
  }

  /// A finished stroke shaped like a small cursive letter.
  static Stroke letter({
    required EditorPage page,
    required int pageIndex,
    required int index,
    required Random random,
    int points = pointsPerStroke,
  }) {
    final stroke = emptyStroke(page: page, pageIndex: pageIndex);
    final origin = letterOrigin(index);
    final width = 14 + random.nextDouble() * 8;
    final height = 18 + random.nextDouble() * 10;
    final phase = random.nextDouble() * pi;
    for (var i = 0; i < points; i++) {
      final (position, pressure) = letterPoint(
        origin: origin,
        i: i,
        points: points,
        width: width,
        height: height,
        phase: phase,
      );
      stroke.addPoint(position, pressure);
    }
    stroke.options.isComplete = true;
    return stroke;
  }

  /// A note with [strokes] strokes spread evenly over [pages] pages.
  static EditorCoreInfo note({
    required int strokes,
    int pages = 1,
    int seed = 1,
    String filePath = '/_benchmark',
  }) {
    final random = Random(seed);
    // The public constructor is the simplest way to get an empty, editable
    // note without touching the disk.
    // ignore: invalid_use_of_visible_for_testing_member
    final coreInfo = EditorCoreInfo(filePath: filePath);
    final perPage = (strokes / pages).ceil();
    var remaining = strokes;
    for (var pageIndex = 0; pageIndex < pages; pageIndex++) {
      final page = EditorPage();
      final count = min(perPage, remaining);
      for (var i = 0; i < count; i++) {
        page.strokes.add(
          letter(page: page, pageIndex: pageIndex, index: i, random: random),
        );
      }
      remaining -= count;
      coreInfo.pages.add(page);
    }
    return coreInfo;
  }
}
