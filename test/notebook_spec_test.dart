import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:saber/data/flavor_config.dart';
import 'package:saber/data/notebooks/notebook_spec.dart';
import 'package:saber/data/notebooks/paper_templates.dart';
import 'package:saber/data/tools/pen_assist.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlavorConfig.setup();

  tearDown(PendingNotebook.clear);

  test('an A4 page is 1000 units wide, the others as much smaller', () {
    final a4 = PaperFormat.a4.pageSize();
    expect(a4.width, closeTo(1000, 1e-6));
    expect(a4.height, closeTo(1414.29, 0.01));

    final a5 = PaperFormat.a5.pageSize();
    expect(a5.width, closeTo(704.76, 0.01));
    expect(a5.height, closeTo(1000, 1e-6));
    // so a length measured on it is still right
    expect(PenAssist.toMm(a5.width), closeTo(148, 0.01));

    // the page the app always had
    expect(PaperFormat.standard.pageSize(), const Size(1000, 1400));

    final square = PaperFormat.square.pageSize();
    expect(square.width, closeTo(square.height, 1e-9));
  });

  test('landscape turns the sheet', () {
    final upright = PaperFormat.b5.pageSize();
    final turned = PaperFormat.b5.pageSize(landscape: true);
    expect(turned.width, upright.height);
    expect(turned.height, upright.width);
    expect(turned.width, greaterThan(turned.height));

    expect(PaperFormat.a4.describe(), '210 × 297 mm');
    expect(PaperFormat.a4.describe(landscape: true), '297 × 210 mm');
    expect(PaperFormat.letter.describe(), '215,9 × 279,4 mm');
  });

  test('a notebook starts blank, upright, in the top folder', () {
    final spec = NotebookSpec();
    expect(spec.template.id, 'blank');
    expect(spec.cover, isNull);
    expect(spec.paperColor, isNull);
    expect(spec.pageSize, const Size(1000, 1400));
    expect(spec.folderPrefix, '/');

    spec
      ..format = PaperFormat.a5
      ..landscape = true
      ..template = PaperTemplates.byId('gantt');
    expect(spec.pageSize.width, closeTo(1000, 1e-6));
    expect(spec.pageSize.height, closeTo(704.76, 0.01));
  });

  test('the folder is made into the start of a path', () {
    expect(NotebookSpec(folder: '/Dersler').folderPrefix, '/Dersler/');
    expect(NotebookSpec(folder: '/Dersler/').folderPrefix, '/Dersler/');
    expect(NotebookSpec(folder: 'Dersler/Fizik').folderPrefix, '/Dersler/Fizik/');
    expect(NotebookSpec(folder: '').folderPrefix, '/');
  });

  test('a pending notebook is handed to its own note, once', () {
    final spec = NotebookSpec(name: 'Planım');
    PendingNotebook.set('/Planım', spec);
    // another note being opened leaves it waiting
    expect(PendingNotebook.take('/Başka'), isNull);
    expect(PendingNotebook.take('/Planım'), same(spec));
    expect(PendingNotebook.take('/Planım'), isNull);
  });

  test('paper colours have names; white is no colour at all', () {
    final colours = PaperColours.all;
    expect(colours.first.$1, isNull);
    expect(colours.map((c) => c.$2).toSet(), hasLength(colours.length));
    expect(PaperColours.nameOf(null), colours.first.$2);
    expect(PaperColours.nameOf(colours[1].$1), colours[1].$2);
    for (final group in ['minimal', 'gradient', 'pattern', 'classic', 'scene']) {
      expect(CoverGroups.label(group), isNot(group));
    }
  });
}
