import 'package:saber/data/defter_strings.dart';
import 'package:saber/i18n/strings.g.dart';
import 'package:sbn/canvas_background_pattern.dart';

extension CanvasBackgroundPatternLocalized on CanvasBackgroundPattern {
  String get localizedName => switch (this) {
    .none => t.editor.menu.bgPatterns.none,
    .collegeLtr => t.editor.menu.bgPatterns.college,
    .collegeRtl => t.editor.menu.bgPatterns.collegeRtl,
    .lined => t.editor.menu.bgPatterns.lined,
    .grid => t.editor.menu.bgPatterns.grid,
    .dots => t.editor.menu.bgPatterns.dots,
    .staffs => t.editor.menu.bgPatterns.staffs,
    .tablature => t.editor.menu.bgPatterns.tablature,
    .cornell => t.editor.menu.bgPatterns.cornell,
    .isometric => DefterStrings.paperIsometric,
    .engineering => DefterStrings.paperEngineering,
    .writing => DefterStrings.paperWriting,
    .todo => DefterStrings.paperTodo,
    .weekly => DefterStrings.paperWeekly,
    .daily => DefterStrings.paperDaily,
    .monthly => DefterStrings.paperMonthly,
    .meeting => DefterStrings.paperMeeting,
    .storyboard => DefterStrings.paperStoryboard,
  };
}
