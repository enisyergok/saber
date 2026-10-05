import 'dart:ui';

import 'package:saber/data/covers/cover_designs.dart';
import 'package:saber/data/defter_strings.dart';
import 'package:saber/data/notebooks/paper_templates.dart';
import 'package:saber/data/tools/pen_assist.dart';

/// The paper sizes a notebook can be made in.
///
/// A page unit is 0.21 mm ([PenAssist.mmPerUnit]), so an A4 page is 1000
/// units wide and the others are as much smaller as the paper is. Pens and
/// line spacing keep their real size on every format.
enum PaperFormat {
  /// The page the app has always used: 1000 by 1400 units, a little
  /// shorter than A4.
  standard(210, 294),
  a4(210, 297),
  a5(148, 210),
  b5(176, 250),
  letter(215.9, 279.4),
  square(210, 210);

  const PaperFormat(this.widthMm, this.heightMm);

  /// The size of an upright sheet, in millimetres.
  final double widthMm, heightMm;

  String get label => switch (this) {
    PaperFormat.standard => DefterStrings.formatStandard,
    PaperFormat.a4 => 'A4',
    PaperFormat.a5 => 'A5',
    PaperFormat.b5 => 'B5',
    PaperFormat.letter => 'Letter',
    PaperFormat.square => DefterStrings.formatSquare,
  };

  /// "210 × 297 mm", the short side first for an upright sheet.
  String describe({bool landscape = false}) {
    String mm(double value) => value == value.roundToDouble()
        ? value.round().toString()
        : value.toStringAsFixed(1).replaceAll('.', ',');
    final (a, b) = landscape ? (heightMm, widthMm) : (widthMm, heightMm);
    return '${mm(a)} × ${mm(b)} mm';
  }

  /// The page size in page units.
  Size pageSize({bool landscape = false}) {
    // to a hundredth of a unit, so that 210 mm is exactly 1000
    double units(double mm) =>
        (mm / PenAssist.mmPerUnit * 100).roundToDouble() / 100;
    final width = units(widthMm), height = units(heightMm);
    return landscape ? Size(height, width) : Size(width, height);
  }
}

/// Everything chosen when a notebook is made: its paper, cover, size and
/// where it goes.
class NotebookSpec {
  NotebookSpec({
    this.name = '',
    this.folder = '/',
    PaperTemplate? template,
    this.cover,
    this.format = PaperFormat.standard,
    this.landscape = false,
    this.paperColor,
  }) : template = template ?? PaperTemplates.all.first;

  /// The name typed for the notebook; empty for a dated default name.
  String name;

  /// The folder it is made in, "/" for the top one.
  String folder;
  PaperTemplate template;

  /// The cover that becomes its first page, if any.
  CoverDesign? cover;
  PaperFormat format;
  bool landscape;

  /// The colour of the paper; null for the usual white.
  Color? paperColor;

  Size get pageSize => format.pageSize(landscape: landscape);

  /// The folder with a slash at each end, as file paths are built.
  String get folderPrefix {
    var path = folder.trim();
    if (!path.startsWith('/')) path = '/$path';
    if (!path.endsWith('/')) path = '$path/';
    return path;
  }
}

/// The notebook that was just made in the new notebook screen, waiting for
/// the editor to open its (still empty) file and set it up.
abstract class PendingNotebook {
  static String? _path;
  static NotebookSpec? _spec;

  /// Remembers that the note at [path] is to be set up as [spec].
  static void set(String path, NotebookSpec spec) {
    _path = path;
    _spec = spec;
  }

  /// The setup waiting for the note at [path], which is then forgotten.
  /// Null for any other note.
  static NotebookSpec? take(String path) {
    if (_path != path) return null;
    final spec = _spec;
    _path = null;
    _spec = null;
    return spec;
  }

  static void clear() {
    _path = null;
    _spec = null;
  }
}

/// The paper colours offered when a notebook is made.
abstract class PaperColours {
  /// Colour (null for the usual white) and its name.
  static List<(Color?, String)> get all => [
    (null, DefterStrings.colourWhite),
    (const Color(0xFFFFF8E7), DefterStrings.colourCream),
    (const Color(0xFFF7F1E3), DefterStrings.colourIvory),
    (const Color(0xFFE5E5E5), DefterStrings.colourGrey),
    (const Color(0xFF1E1E1E), DefterStrings.colourBlack),
    (const Color(0xFFFDE2E4), DefterStrings.colourPink),
    (const Color(0xFFDCEBFA), DefterStrings.colourBlue),
    (const Color(0xFFDDF2E0), DefterStrings.colourGreen),
    (const Color(0xFFE8E0F7), DefterStrings.colourLilac),
    (const Color(0xFFFFF4B8), DefterStrings.colourYellow),
    (const Color(0xFFFFE5D0), DefterStrings.colourPeach),
    (const Color(0xFFD8F5EC), DefterStrings.colourMint),
  ];

  static String nameOf(Color? colour) {
    for (final (value, name) in all) {
      if (value?.toARGB32() == colour?.toARGB32()) return name;
    }
    return DefterStrings.colourWhite;
  }
}

/// The groups of covers, as the tabs of the cover step show them.
abstract class CoverGroups {
  static String label(String group) => switch (group) {
    'minimal' => DefterStrings.coverMinimal,
    'gradient' => DefterStrings.coverColourful,
    'pattern' => DefterStrings.coverPatterned,
    'classic' => DefterStrings.coverClassic,
    'scene' => DefterStrings.coverNature,
    _ => group,
  };
}
