import 'package:saber/components/editor_gn/gn_controller.dart';
import 'package:saber/components/toolbar/toolbar.dart';
import 'package:saber/data/tools/_tool.dart';
import 'package:saber/data/tools/eraser.dart';
import 'package:saber/data/tools/highlighter.dart';
import 'package:saber/data/tools/laser_pointer.dart';
import 'package:saber/data/tools/pen.dart';
import 'package:saber/data/tools/pencil.dart';
import 'package:saber/data/tools/select.dart';
import 'package:saber/data/tools/shape_pen.dart';

/// What the tool buttons do. [spec] is the editor's [Toolbar] description
/// (its tool callbacks and current tool); it is never put on screen, the
/// top bar just uses what it carries.
class GnActions {
  const GnActions(this.spec, this.controller);

  final Toolbar spec;
  final GnController controller;

  Tool get tool => spec.currentTool;

  /// Any of the pens: pen, pencil, highlighter or shape pen.
  bool get isDrawing => tool is Pen;

  bool get isPen => tool == Pen.currentPen && tool is! ShapePen;
  bool get isPencil => tool == Pencil.currentPencil;
  bool get isHighlighter => tool == Highlighter.currentHighlighter;
  bool get isShape => tool is ShapePen;

  /// The pen the pen button stands for: never the shape pen.
  Pen get writingPen => Pen.currentPen is ShapePen
      ? (controller.penBeforeShape ?? Pen.fountainPen())
      : Pen.currentPen;

  /// The pen button of the top bar: picks the pen, or opens its settings
  /// when a pen is already in use.
  void tapPenButton() {
    if (isDrawing) {
      controller.toggle(GnPanel.penSettings);
    } else {
      controller.close();
      spec.setTool(writingPen);
    }
  }

  void selectPen() {
    controller.close();
    spec.setTool(writingPen);
  }

  void selectPencil() {
    controller.close();
    spec.setTool(Pencil.currentPencil);
  }

  void selectHighlighter() {
    controller.close();
    spec.setTool(Highlighter.currentHighlighter);
  }

  void toggleShape() {
    controller.close();
    if (isShape) {
      spec.setTool(writingPen);
    } else {
      if (Pen.currentPen is! ShapePen) controller.penBeforeShape = Pen.currentPen;
      spec.setTool(ShapePen());
    }
  }

  void selectEraser() {
    controller.close();
    spec.setTool(Eraser()); // this toggles the eraser
  }

  void selectLasso() {
    controller.close();
    spec.setTool(Select.currentSelect);
  }

  void selectLaser() {
    controller.close();
    spec.setTool(LaserPointer.currentLaserPointer);
  }
}
