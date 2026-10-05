import 'package:flutter_test/flutter_test.dart';
import 'package:saber/data/flavor_config.dart';
import 'package:saber/data/notebooks/paper_templates.dart';
import 'package:sbn/canvas_background_pattern.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlavorConfig.setup();

  test('every paper the app has is in the catalogue', () {
    expect(PaperTemplates.missing, isEmpty);
  });

  test('ids are unique and every paper has a name and a tab', () {
    final ids = PaperTemplates.all.map((t) => t.id).toSet();
    expect(ids, hasLength(PaperTemplates.all.length));
    for (final template in PaperTemplates.all) {
      expect(template.name, isNotEmpty, reason: template.id);
      expect(template.groups, isNotEmpty, reason: template.id);
      expect(template.lineHeight, inInclusiveRange(20, 60), reason: template.id);
    }
  });

  test('every tab and every topic leads to papers', () {
    for (final group in PaperGroup.values) {
      expect(PaperTemplates.inGroup(group), isNotEmpty, reason: '$group');
      expect(group.label, isNotEmpty);
      for (final topic in PaperTemplates.topicsOf(group)) {
        expect(PaperTemplates.about(group, topic), isNotEmpty, reason: '$topic');
        expect(topic.label, isNotEmpty);
      }
    }
    expect(PaperTemplates.inGroup(null), hasLength(PaperTemplates.all.length));
  });

  test('the galleries have the topics their papers are about', () {
    final planner = PaperTemplates.topicsOf(PaperGroup.planner);
    expect(
      planner,
      containsAll([
        PaperTopic.yearly,
        PaperTopic.monthly,
        PaperTopic.weekly,
        PaperTopic.daily,
        PaperTopic.finance,
        PaperTopic.health,
        PaperTopic.school,
        PaperTopic.project,
        PaperTopic.food,
        PaperTopic.travel,
      ]),
    );
    // "other" comes last
    expect(planner.last, PaperTopic.other);

    expect(
      PaperTemplates.topicsOf(PaperGroup.engineering),
      containsAll([
        PaperTopic.technical,
        PaperTopic.electronics,
        PaperTopic.mechanical,
        PaperTopic.architecture,
        PaperTopic.computing,
      ]),
    );
    expect(
      PaperTemplates.topicsOf(PaperGroup.diagram),
      containsAll([
        PaperTopic.flow,
        PaperTopic.mindMap,
        PaperTopic.organisation,
        PaperTopic.analysis,
        PaperTopic.maths,
      ]),
    );
    // plain papers have no topics, so no second row of tabs
    expect(PaperTemplates.topicsOf(PaperGroup.lined), isEmpty);

    final electronics = PaperTemplates.about(
      PaperGroup.engineering,
      PaperTopic.electronics,
    ).map((t) => t.pattern);
    expect(
      electronics,
      containsAll([CanvasBackgroundPattern.circuit, CanvasBackgroundPattern.pcb]),
    );
    expect(electronics, isNot(contains(CanvasBackgroundPattern.wireframe)));
  });

  test('ruled papers come in three spacings with names of their own', () {
    final lined = PaperTemplates.all
        .where((t) => t.pattern == CanvasBackgroundPattern.lined)
        .toList();
    expect(lined, hasLength(3));
    expect(lined.map((t) => t.name).toSet(), hasLength(3));
    expect(lined.map((t) => t.lineHeight).toSet(), hasLength(3));

    // a note is matched to the nearest spacing
    expect(
      PaperTemplates.of(CanvasBackgroundPattern.lined, 31).id,
      'lined-narrow',
    );
    expect(PaperTemplates.of(CanvasBackgroundPattern.lined, 40).id, 'lined');
    expect(PaperTemplates.of(CanvasBackgroundPattern.grid, 70).id, 'grid-large');
    expect(PaperTemplates.of(CanvasBackgroundPattern.gantt, 40).id, 'gantt');
  });

  test('an unknown id gives blank paper', () {
    expect(PaperTemplates.byId('gantt').pattern, CanvasBackgroundPattern.gantt);
    expect(PaperTemplates.byId('nope').pattern, CanvasBackgroundPattern.none);
    expect(PaperTemplates.byId(null).id, 'blank');
  });
}
