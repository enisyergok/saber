import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/tools/pen.dart';
import 'package:saber/i18n/strings.g.dart';

class Pencil extends Pen {
  new()
    : super(
        name: t.editor.pens.pencil,
        sizeMin: 1,
        sizeMax: 15,
        sizeStep: 1,
        icon: pencilIcon,
        options: stows.lastPencilOptions.value,
        pressureEnabled: true,
        color: Color(stows.lastPencilColor.value),
        toolId: .pencil,
      );

  static var currentPencil = Pencil();

  static const pencilIcon = Symbols.edit_rounded;
}
