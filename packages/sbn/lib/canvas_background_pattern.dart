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
  storyboard('storyboard', template: true);

  static CanvasBackgroundPattern fromName(String? name) {
    return values.firstWhere(
      (pattern) => pattern.name == name,
      orElse: () => CanvasBackgroundPattern.none,
    );
  }
}
