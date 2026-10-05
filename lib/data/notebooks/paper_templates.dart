import 'package:saber/data/defter_strings.dart';
import 'package:saber/i18n/extensions/canvas_background_pattern_localized.dart';
import 'package:sbn/canvas_background_pattern.dart';

/// The kinds of paper, as the tabs of the new notebook screen show them.
enum PaperGroup {
  blank,
  lined,
  squared,
  dotted,
  planner,
  diagram,
  engineering,
  academic,
  special;

  String get label => switch (this) {
    PaperGroup.blank => DefterStrings.groupBlank,
    PaperGroup.lined => DefterStrings.groupLined,
    PaperGroup.squared => DefterStrings.groupSquared,
    PaperGroup.dotted => DefterStrings.groupDotted,
    PaperGroup.planner => DefterStrings.groupPlanner,
    PaperGroup.diagram => DefterStrings.groupDiagram,
    PaperGroup.engineering => DefterStrings.groupEngineering,
    PaperGroup.academic => DefterStrings.groupAcademic,
    PaperGroup.special => DefterStrings.groupSpecial,
  };
}

/// The narrower kinds inside the planner, engineering and diagram
/// galleries.
enum PaperTopic {
  // planners
  yearly,
  monthly,
  weekly,
  daily,
  finance,
  health,
  school,
  project,
  food,
  travel,
  // engineering
  technical,
  electronics,
  mechanical,
  architecture,
  computing,
  // diagrams
  flow,
  mindMap,
  organisation,
  analysis,
  maths,
  // whatever fits nowhere else
  other;

  String get label => switch (this) {
    PaperTopic.yearly => DefterStrings.topicYearly,
    PaperTopic.monthly => DefterStrings.topicMonthly,
    PaperTopic.weekly => DefterStrings.topicWeekly,
    PaperTopic.daily => DefterStrings.topicDaily,
    PaperTopic.finance => DefterStrings.topicFinance,
    PaperTopic.health => DefterStrings.topicHealth,
    PaperTopic.school => DefterStrings.topicSchool,
    PaperTopic.project => DefterStrings.topicProject,
    PaperTopic.food => DefterStrings.topicFood,
    PaperTopic.travel => DefterStrings.topicTravel,
    PaperTopic.technical => DefterStrings.topicTechnical,
    PaperTopic.electronics => DefterStrings.topicElectronics,
    PaperTopic.mechanical => DefterStrings.topicMechanical,
    PaperTopic.architecture => DefterStrings.topicArchitecture,
    PaperTopic.computing => DefterStrings.topicComputing,
    PaperTopic.flow => DefterStrings.topicFlow,
    PaperTopic.mindMap => DefterStrings.topicMindMap,
    PaperTopic.organisation => DefterStrings.topicOrganisation,
    PaperTopic.analysis => DefterStrings.topicAnalysis,
    PaperTopic.maths => DefterStrings.topicMaths,
    PaperTopic.other => DefterStrings.topicOther,
  };
}

/// A paper to start a notebook with: a background pattern, and for plain
/// ruled papers how far apart its lines are.
class PaperTemplate {
  const PaperTemplate(
    this.id,
    this.pattern, {
    required this.groups,
    this.topics = const {},
    this.lineHeight = defaultLineHeight,
    this.spacing,
  });

  /// The line height of every paper that doesn't say otherwise.
  static const defaultLineHeight = 40;

  final String id;
  final CanvasBackgroundPattern pattern;

  /// The tabs this paper is listed under.
  final Set<PaperGroup> groups;
  final Set<PaperTopic> topics;

  /// The distance between lines (or squares, or dots), in page units.
  final int lineHeight;

  /// For papers that come in several line spacings: which one this is.
  final PaperSpacing? spacing;

  String get name => switch (spacing) {
    null => pattern.localizedName,
    final spacing => switch (pattern) {
      CanvasBackgroundPattern.lined => spacing.lined,
      CanvasBackgroundPattern.grid => spacing.squared,
      CanvasBackgroundPattern.dots => spacing.dotted,
      _ => pattern.localizedName,
    },
  };
}

enum PaperSpacing {
  narrow,
  medium,
  wide;

  String get lined => switch (this) {
    PaperSpacing.narrow => DefterStrings.linedNarrow,
    PaperSpacing.medium => DefterStrings.linedMedium,
    PaperSpacing.wide => DefterStrings.linedWide,
  };
  String get squared => switch (this) {
    PaperSpacing.narrow => DefterStrings.squaredSmall,
    PaperSpacing.medium => DefterStrings.squaredMedium,
    PaperSpacing.wide => DefterStrings.squaredLarge,
  };
  String get dotted => switch (this) {
    PaperSpacing.narrow => DefterStrings.dottedDense,
    PaperSpacing.medium => DefterStrings.dottedMedium,
    PaperSpacing.wide => DefterStrings.dottedWide,
  };
}

/// Every paper the app has, sorted into the tabs of the new notebook
/// screen and of the template galleries.
abstract class PaperTemplates {
  static const _p = CanvasBackgroundPattern.values;

  static const all = <PaperTemplate>[
    PaperTemplate('blank', CanvasBackgroundPattern.none, groups: {PaperGroup.blank}),

    // -- lined --------------------------------------------------------------
    PaperTemplate(
      'lined-narrow',
      CanvasBackgroundPattern.lined,
      groups: {PaperGroup.lined},
      lineHeight: 30,
      spacing: PaperSpacing.narrow,
    ),
    PaperTemplate(
      'lined',
      CanvasBackgroundPattern.lined,
      groups: {PaperGroup.lined},
      spacing: PaperSpacing.medium,
    ),
    PaperTemplate(
      'lined-wide',
      CanvasBackgroundPattern.lined,
      groups: {PaperGroup.lined},
      lineHeight: 52,
      spacing: PaperSpacing.wide,
    ),
    PaperTemplate('college', CanvasBackgroundPattern.collegeLtr, groups: {PaperGroup.lined}),
    PaperTemplate('college-rtl', CanvasBackgroundPattern.collegeRtl, groups: {PaperGroup.lined}),
    PaperTemplate('legal', CanvasBackgroundPattern.legal, groups: {PaperGroup.lined}),
    PaperTemplate('titled', CanvasBackgroundPattern.titled, groups: {PaperGroup.lined}),
    PaperTemplate('bullets', CanvasBackgroundPattern.bullets, groups: {PaperGroup.lined}),
    PaperTemplate('numbered', CanvasBackgroundPattern.numbered, groups: {PaperGroup.lined}),
    PaperTemplate(
      'writing',
      CanvasBackgroundPattern.writing,
      groups: {PaperGroup.lined, PaperGroup.academic},
    ),

    // -- squared ------------------------------------------------------------
    PaperTemplate(
      'grid-small',
      CanvasBackgroundPattern.grid,
      groups: {PaperGroup.squared},
      lineHeight: 25,
      spacing: PaperSpacing.narrow,
    ),
    PaperTemplate(
      'grid',
      CanvasBackgroundPattern.grid,
      groups: {PaperGroup.squared},
      spacing: PaperSpacing.medium,
    ),
    PaperTemplate(
      'grid-large',
      CanvasBackgroundPattern.grid,
      groups: {PaperGroup.squared},
      lineHeight: 55,
      spacing: PaperSpacing.wide,
    ),
    PaperTemplate(
      'engineering',
      CanvasBackgroundPattern.engineering,
      groups: {PaperGroup.squared, PaperGroup.engineering},
      topics: {PaperTopic.technical, PaperTopic.mechanical, PaperTopic.architecture},
    ),
    PaperTemplate(
      'millimetre',
      CanvasBackgroundPattern.millimetre,
      groups: {PaperGroup.squared, PaperGroup.engineering},
      topics: {PaperTopic.technical, PaperTopic.mechanical},
    ),
    PaperTemplate(
      'diamond',
      CanvasBackgroundPattern.diamond,
      groups: {PaperGroup.squared, PaperGroup.engineering},
      topics: {PaperTopic.other},
    ),
    PaperTemplate(
      'hexagon',
      CanvasBackgroundPattern.hexagon,
      groups: {PaperGroup.squared, PaperGroup.engineering},
      topics: {PaperTopic.technical, PaperTopic.other},
    ),

    // -- dotted -------------------------------------------------------------
    PaperTemplate(
      'dots-dense',
      CanvasBackgroundPattern.dots,
      groups: {PaperGroup.dotted},
      lineHeight: 25,
      spacing: PaperSpacing.narrow,
    ),
    PaperTemplate(
      'dots',
      CanvasBackgroundPattern.dots,
      groups: {PaperGroup.dotted},
      spacing: PaperSpacing.medium,
    ),
    PaperTemplate(
      'dots-wide',
      CanvasBackgroundPattern.dots,
      groups: {PaperGroup.dotted},
      lineHeight: 55,
      spacing: PaperSpacing.wide,
    ),
    PaperTemplate(
      'isometric',
      CanvasBackgroundPattern.isometric,
      groups: {PaperGroup.dotted, PaperGroup.engineering},
      topics: {PaperTopic.technical, PaperTopic.architecture},
    ),

    // -- planners -----------------------------------------------------------
    PaperTemplate('yearly', CanvasBackgroundPattern.yearly, groups: {PaperGroup.planner}, topics: {PaperTopic.yearly}),
    PaperTemplate('monthly', CanvasBackgroundPattern.monthly, groups: {PaperGroup.planner}, topics: {PaperTopic.monthly}),
    PaperTemplate('weekly', CanvasBackgroundPattern.weekly, groups: {PaperGroup.planner}, topics: {PaperTopic.weekly}),
    PaperTemplate('daily', CanvasBackgroundPattern.daily, groups: {PaperGroup.planner}, topics: {PaperTopic.daily}),
    PaperTemplate(
      'academic-planner',
      CanvasBackgroundPattern.academicPlanner,
      groups: {PaperGroup.planner, PaperGroup.academic},
      topics: {PaperTopic.school, PaperTopic.weekly},
    ),
    PaperTemplate('goal-planner', CanvasBackgroundPattern.goalPlanner, groups: {PaperGroup.planner}, topics: {PaperTopic.other}),
    PaperTemplate('finance-planner', CanvasBackgroundPattern.financePlanner, groups: {PaperGroup.planner}, topics: {PaperTopic.finance, PaperTopic.yearly}),
    PaperTemplate('budget', CanvasBackgroundPattern.budget, groups: {PaperGroup.planner}, topics: {PaperTopic.finance}),
    PaperTemplate('ledger', CanvasBackgroundPattern.ledger, groups: {PaperGroup.planner, PaperGroup.special}, topics: {PaperTopic.finance}),
    PaperTemplate('meals', CanvasBackgroundPattern.meals, groups: {PaperGroup.planner}, topics: {PaperTopic.food, PaperTopic.weekly}),
    PaperTemplate('travel', CanvasBackgroundPattern.travel, groups: {PaperGroup.planner}, topics: {PaperTopic.travel}),
    PaperTemplate('project', CanvasBackgroundPattern.project, groups: {PaperGroup.planner}, topics: {PaperTopic.project}),
    PaperTemplate(
      'gantt',
      CanvasBackgroundPattern.gantt,
      groups: {PaperGroup.planner, PaperGroup.engineering},
      topics: {PaperTopic.project, PaperTopic.other},
    ),
    PaperTemplate('habits', CanvasBackgroundPattern.habits, groups: {PaperGroup.planner}, topics: {PaperTopic.health}),
    PaperTemplate('mood-tracker', CanvasBackgroundPattern.moodTracker, groups: {PaperGroup.planner}, topics: {PaperTopic.health, PaperTopic.monthly}),
    PaperTemplate('water', CanvasBackgroundPattern.water, groups: {PaperGroup.planner}, topics: {PaperTopic.health}),
    PaperTemplate(
      'student-planner',
      CanvasBackgroundPattern.studentPlanner,
      groups: {PaperGroup.planner, PaperGroup.academic},
      topics: {PaperTopic.school},
    ),
    PaperTemplate(
      'class-schedule',
      CanvasBackgroundPattern.classSchedule,
      groups: {PaperGroup.planner, PaperGroup.academic},
      topics: {PaperTopic.school, PaperTopic.weekly},
    ),
    PaperTemplate('meeting', CanvasBackgroundPattern.meeting, groups: {PaperGroup.planner}, topics: {PaperTopic.other, PaperTopic.project}),
    PaperTemplate('todo', CanvasBackgroundPattern.todo, groups: {PaperGroup.planner}, topics: {PaperTopic.other, PaperTopic.daily}),
    PaperTemplate('shopping', CanvasBackgroundPattern.shopping, groups: {PaperGroup.planner}, topics: {PaperTopic.food}),
    PaperTemplate('recipe', CanvasBackgroundPattern.recipe, groups: {PaperGroup.planner, PaperGroup.special}, topics: {PaperTopic.food}),
    PaperTemplate('reading', CanvasBackgroundPattern.reading, groups: {PaperGroup.planner, PaperGroup.academic}, topics: {PaperTopic.other}),

    // -- diagrams -----------------------------------------------------------
    PaperTemplate('mind-map', CanvasBackgroundPattern.mindMap, groups: {PaperGroup.diagram}, topics: {PaperTopic.mindMap}),
    PaperTemplate('concept-map', CanvasBackgroundPattern.conceptMap, groups: {PaperGroup.diagram}, topics: {PaperTopic.mindMap}),
    PaperTemplate(
      'flowchart',
      CanvasBackgroundPattern.flowchart,
      groups: {PaperGroup.diagram, PaperGroup.engineering},
      topics: {PaperTopic.flow, PaperTopic.computing},
    ),
    PaperTemplate('decision-tree', CanvasBackgroundPattern.decisionTree, groups: {PaperGroup.diagram}, topics: {PaperTopic.flow, PaperTopic.analysis}),
    PaperTemplate('arrow-diagram', CanvasBackgroundPattern.arrowDiagram, groups: {PaperGroup.diagram}, topics: {PaperTopic.flow}),
    PaperTemplate(
      'block-diagram',
      CanvasBackgroundPattern.blockDiagram,
      groups: {PaperGroup.diagram, PaperGroup.engineering},
      topics: {PaperTopic.flow, PaperTopic.computing, PaperTopic.electronics},
    ),
    PaperTemplate(
      'fishbone',
      CanvasBackgroundPattern.fishbone,
      groups: {PaperGroup.diagram, PaperGroup.engineering},
      topics: {PaperTopic.analysis, PaperTopic.mechanical},
    ),
    PaperTemplate('venn', CanvasBackgroundPattern.venn, groups: {PaperGroup.diagram}, topics: {PaperTopic.analysis, PaperTopic.maths}),
    PaperTemplate('org-chart', CanvasBackgroundPattern.orgChart, groups: {PaperGroup.diagram}, topics: {PaperTopic.organisation}),
    PaperTemplate('relation-diagram', CanvasBackgroundPattern.relationDiagram, groups: {PaperGroup.diagram}, topics: {PaperTopic.organisation}),
    PaperTemplate('cycle', CanvasBackgroundPattern.cycle, groups: {PaperGroup.diagram}, topics: {PaperTopic.flow, PaperTopic.other}),
    PaperTemplate('swot', CanvasBackgroundPattern.swot, groups: {PaperGroup.diagram}, topics: {PaperTopic.analysis}),
    PaperTemplate('pyramid', CanvasBackgroundPattern.pyramid, groups: {PaperGroup.diagram}, topics: {PaperTopic.analysis, PaperTopic.organisation}),
    PaperTemplate('timeline', CanvasBackgroundPattern.timeline, groups: {PaperGroup.diagram}, topics: {PaperTopic.other, PaperTopic.analysis}),
    PaperTemplate('rings', CanvasBackgroundPattern.rings, groups: {PaperGroup.diagram}, topics: {PaperTopic.other}),
    PaperTemplate('wheel', CanvasBackgroundPattern.wheel, groups: {PaperGroup.diagram}, topics: {PaperTopic.other, PaperTopic.analysis}),
    PaperTemplate(
      'math',
      CanvasBackgroundPattern.math,
      groups: {PaperGroup.diagram, PaperGroup.academic},
      topics: {PaperTopic.maths},
    ),

    // -- engineering --------------------------------------------------------
    PaperTemplate('circuit', CanvasBackgroundPattern.circuit, groups: {PaperGroup.engineering}, topics: {PaperTopic.electronics, PaperTopic.technical}),
    PaperTemplate('pcb', CanvasBackgroundPattern.pcb, groups: {PaperGroup.engineering}, topics: {PaperTopic.electronics}),
    PaperTemplate('measure-table', CanvasBackgroundPattern.measureTable, groups: {PaperGroup.engineering}, topics: {PaperTopic.mechanical, PaperTopic.technical}),
    PaperTemplate(
      'table',
      CanvasBackgroundPattern.table,
      groups: {PaperGroup.engineering, PaperGroup.special},
      topics: {PaperTopic.other},
    ),
    PaperTemplate(
      'wireframe',
      CanvasBackgroundPattern.wireframe,
      groups: {PaperGroup.engineering, PaperGroup.special},
      topics: {PaperTopic.computing},
    ),

    // -- academic -----------------------------------------------------------
    PaperTemplate('cornell', CanvasBackgroundPattern.cornell, groups: {PaperGroup.academic}),
    PaperTemplate('side-split', CanvasBackgroundPattern.sideSplit, groups: {PaperGroup.academic}),
    PaperTemplate('columns2', CanvasBackgroundPattern.twoColumns, groups: {PaperGroup.academic, PaperGroup.special}),
    PaperTemplate('columns3', CanvasBackgroundPattern.threeColumns, groups: {PaperGroup.academic, PaperGroup.special}),
    PaperTemplate('columns4', CanvasBackgroundPattern.fourColumns, groups: {PaperGroup.special}),

    // -- special ------------------------------------------------------------
    PaperTemplate('storyboard', CanvasBackgroundPattern.storyboard, groups: {PaperGroup.special}),
    PaperTemplate('top-bottom', CanvasBackgroundPattern.topBottom, groups: {PaperGroup.special}),
    PaperTemplate('vertical-split', CanvasBackgroundPattern.verticalSplit, groups: {PaperGroup.special}),
    PaperTemplate('square-split', CanvasBackgroundPattern.squareSplit, groups: {PaperGroup.special}),
    PaperTemplate('staffs', CanvasBackgroundPattern.staffs, groups: {PaperGroup.special}),
    PaperTemplate('tablature', CanvasBackgroundPattern.tablature, groups: {PaperGroup.special}),
  ];

  /// The papers under [group]; all of them for null.
  static List<PaperTemplate> inGroup(PaperGroup? group) => [
    for (final template in all)
      if (group == null || template.groups.contains(group)) template,
  ];

  /// The papers of [group] about [topic]; the whole group for null.
  static List<PaperTemplate> about(PaperGroup group, PaperTopic? topic) => [
    for (final template in inGroup(group))
      if (topic == null || template.topics.contains(topic)) template,
  ];

  /// The topics that [group] has papers about, in the order of
  /// [PaperTopic], with "other" last.
  static List<PaperTopic> topicsOf(PaperGroup group) {
    final found = <PaperTopic>{
      for (final template in inGroup(group)) ...template.topics,
    };
    return [
      for (final topic in PaperTopic.values)
        if (found.contains(topic)) topic,
    ];
  }

  static PaperTemplate byId(String? id) {
    for (final template in all) {
      if (template.id == id) return template;
    }
    return all.first;
  }

  /// The paper a note with [pattern] and [lineHeight] is on, as nearly as
  /// the catalogue has it.
  static PaperTemplate of(CanvasBackgroundPattern pattern, int lineHeight) {
    PaperTemplate? best;
    for (final template in all) {
      if (template.pattern != pattern) continue;
      if (best == null ||
          (template.lineHeight - lineHeight).abs() <
              (best.lineHeight - lineHeight).abs()) {
        best = template;
      }
    }
    return best ?? all.first;
  }

  /// Every pattern the catalogue leaves out (none, if it is complete).
  static List<CanvasBackgroundPattern> get missing => [
    for (final pattern in _p)
      if (!all.any((template) => template.pattern == pattern)) pattern,
  ];
}
