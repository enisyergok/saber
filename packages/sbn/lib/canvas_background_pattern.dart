enum CanvasBackgroundPattern(
  /// The pattern name used for serialization.
  /// Do not display this to the user: instead use [localizedName].
  final String name, {

  /// Whether this pattern has elements along the page edges that may need to be
  /// clipped.
  final bool requiresClipping = false,

  /// Whether this is a structured template (a planner, a form...) rather
  /// than plain ruled paper. Templates may include text labels and are not
  /// bound to the one-line-height rules of plain paper.
  final bool template = false,
}) {
  /// No background pattern
  none(''),

  /// College ruled paper (ltr): horizontal lines with one
  /// vertical line along the left margin
  collegeLtr('college'),

  /// College ruled paper (rtl): horizontal lines with one
  /// vertical line along the right margin
  collegeRtl('college-rtl'),

  /// Horizontal lines. This is the same as college ruled paper
  /// but without the vertical line
  lined('lined'),

  /// A grid of squares
  grid('grid', requiresClipping: true),

  /// A grid of dots. This is the same as "grid" except it has dots on the
  /// corners instead of the whole square border.
  dots('dots', requiresClipping: true),

  /// Music staffs
  staffs('staffs'),

  /// Music tablature
  ///
  /// Like staffs but with 6 lines instead of 5 (and 5 spaces instead of 4).
  tablature('tablature'),

  /// Cornell notes
  cornell('cornell'),

  /// Isometric dot grid (dots on a triangular lattice)
  isometric('isometric', requiresClipping: true, template: true),

  /// Engineering / graph paper: fine grid with every fifth line stronger
  engineering('engineering', requiresClipping: true, template: true),

  /// Handwriting practice: groups of three guide lines
  writing('writing', template: true),

  /// Checklist: a check box and a line on every row
  todo('todo', template: true),

  /// Weekly planner
  weekly('weekly', template: true),

  /// Daily planner with hours and a to-do column
  daily('daily', template: true),

  /// Monthly calendar grid
  monthly('monthly', template: true),

  /// Meeting notes: title, attendees, agenda, notes, action items
  meeting('meeting', template: true),

  /// Storyboard: six frames with caption lines
  storyboard('storyboard', template: true),

  /// Table with a header row
  table('table', template: true),

  /// Two, three or four columns
  twoColumns('columns2', template: true),
  threeColumns('columns3', template: true),
  fourColumns('columns4', template: true),

  /// Narrow cue column on the left, lined notes on the right
  sideSplit('side-split', template: true),

  /// Two boxes, one above the other
  topBottom('top-bottom', template: true),

  /// Two lined halves side by side
  verticalSplit('vertical-split', template: true),

  /// Four boxes
  squareSplit('square-split', template: true),

  /// A title box and lined paper below it
  titled('titled', template: true),

  /// Bullet points with lines
  bullets('bullets', template: true),

  /// Numbered lines
  numbered('numbered', template: true),

  /// Legal pad: lines and a double margin line
  legal('legal', template: true),

  /// Honeycomb (hexagons)
  hexagon('hexagon', requiresClipping: true, template: true),

  /// Diamond grid (diagonal lines)
  diamond('diamond', requiresClipping: true, template: true),

  /// Yearly planner
  yearly('yearly', template: true),

  /// Class schedule
  classSchedule('class-schedule', template: true),

  /// Habit tracker
  habits('habits', template: true),

  /// Budget planner
  budget('budget', template: true),

  /// Meal planner
  meals('meals', template: true),

  /// Travel planner
  travel('travel', template: true),

  /// Project planner
  project('project', template: true),

  /// Water tracker
  water('water', template: true),

  /// Reading log
  reading('reading', template: true),

  /// Shopping list
  shopping('shopping', template: true),

  /// Mind map
  mindMap('mind-map', template: true),

  /// Concept map
  conceptMap('concept-map', template: true),

  /// Flowchart
  flowchart('flowchart', template: true),

  /// Decision tree
  decisionTree('decision-tree', template: true),

  /// Venn diagram
  venn('venn', template: true),

  /// Cycle
  cycle('cycle', template: true),

  /// Pyramid
  pyramid('pyramid', template: true),

  /// Fishbone
  fishbone('fishbone', template: true),

  /// SWOT
  swot('swot', template: true),

  /// Timeline
  timeline('timeline', template: true),

  /// Rings
  rings('rings', template: true),

  /// Wheel
  wheel('wheel', template: true),

  /// Wireframe
  wireframe('wireframe', template: true),

  /// Coordinate plane
  math('math', template: true),

  /// Recipe
  recipe('recipe', template: true),

  /// Millimetre paper: 2 mm squares, every fifth line stronger
  millimetre('millimetre', requiresClipping: true, template: true),

  /// Circuit paper: a fine dot grid and a title block
  circuit('circuit', requiresClipping: true, template: true),

  /// Perfboard style grid of pads with a frame
  pcb('pcb', requiresClipping: true, template: true),

  /// Block diagram
  blockDiagram('block-diagram', template: true),

  /// Gantt chart
  gantt('gantt', template: true),

  /// Measurement table (nominal, tolerance, measured, result)
  measureTable('measure-table', template: true),

  /// Organisation chart
  orgChart('org-chart', template: true),

  /// Process arrows: steps from left to right
  arrowDiagram('arrow-diagram', template: true),

  /// Relationship diagram
  relationDiagram('relation-diagram', template: true),

  /// Academic week planner
  academicPlanner('academic-planner', template: true),

  /// Goal planner
  goalPlanner('goal-planner', template: true),

  /// Finance planner: a year of income, expenses and savings
  financePlanner('finance-planner', template: true),

  /// Mood tracker
  moodTracker('mood-tracker', template: true),

  /// Student planner
  studentPlanner('student-planner', template: true),

  /// Ledger: date, description, debit, credit, balance
  ledger('ledger', template: true);

  static CanvasBackgroundPattern fromName(String? name) {
    return values.firstWhere(
      (pattern) => pattern.name == name,
      orElse: () => CanvasBackgroundPattern.none,
    );
  }
}
