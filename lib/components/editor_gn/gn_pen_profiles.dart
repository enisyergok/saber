import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:perfect_freehand/perfect_freehand.dart';
import 'package:saber/components/theming/uni_icon.dart';
import 'package:saber/data/defter_strings.dart';
import 'package:saber/data/tools/pen.dart';
import 'package:saber/data/tools/pen_feel.dart';
import 'package:saber/data/tools/pen_styles.dart';

/// The list of pen profiles of the pen panel: tap one to draw with it,
/// the plus saves the pen in use as a new one.
class GnPenProfiles extends StatelessWidget {
  const GnPenProfiles({
    super.key,
    required this.profiles,
    required this.current,
    required this.onApply,
    required this.onAdd,
    required this.onUpdate,
    required this.onRename,
    required this.onDelete,
  });

  final List<PenProfile> profiles;

  /// The pen in use, to mark the profile it is set to.
  final Pen current;
  final ValueChanged<PenProfile> onApply;
  final VoidCallback onAdd;
  final ValueChanged<PenProfile> onUpdate;
  final ValueChanged<PenProfile> onRename;
  final ValueChanged<PenProfile> onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = ColorScheme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                DefterStrings.penProfiles,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              tooltip: DefterStrings.addProfile,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.add),
              onPressed: onAdd,
            ),
          ],
        ),
        for (final profile in profiles)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: _row(context, profile, colors),
          ),
      ],
    );
  }

  Widget _row(BuildContext context, PenProfile profile, ColorScheme colors) {
    final selected = profile.matches(current);
    return Material(
      color: selected ? colors.primary.withValues(alpha: 0.14) : colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: selected ? colors.primary : Colors.transparent,
          width: 1.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onApply(profile),
        child: Padding(
          padding: const EdgeInsets.only(left: 10, top: 6, bottom: 6),
          child: Row(
            children: [
              UniIcon(
                PenStyles.icon(profile.style),
                size: 16,
                color: selected ? colors.primary : colors.onSurface,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      profile.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 46,
                height: 22,
                child: CustomPaint(
                  painter: PenProfilePainter(
                    profile: profile,
                    color: colors.onSurface,
                  ),
                ),
              ),
              PopupMenuButton<int>(
                tooltip: '',
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.more_vert, size: 18),
                onSelected: (value) {
                  switch (value) {
                    case 0:
                      onUpdate(profile);
                    case 1:
                      onRename(profile);
                    case 2:
                      onDelete(profile);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 0,
                    child: Text(DefterStrings.profileUpdate),
                  ),
                  PopupMenuItem(
                    value: 1,
                    child: Text(DefterStrings.profileRename),
                  ),
                  PopupMenuItem(
                    value: 2,
                    child: Text(DefterStrings.profileDelete),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small line showing how thick and how pointed a profile's pen draws.
class PenProfilePainter extends CustomPainter {
  const PenProfilePainter({required this.profile, required this.color});

  final PenProfile profile;
  final Color color;

  /// The options the little line is drawn with: the profile's own, with
  /// the size brought down to fit.
  @visibleForTesting
  static StrokeOptions optionsFor(PenProfile profile) {
    // Sizes run from hairlines to 100 for the marker: the square root
    // keeps them apart without the thick ones filling the box.
    final size = (math.sqrt(profile.size) * 1.6).clamp(1.5, 9.0);
    final base = StrokeOptions(
      size: size,
      thinning: profile.sensitivity,
      streamline: 0,
    );
    final kind = switch (profile.style) {
      PenStyle.fountain => PenKind.fountain,
      PenStyle.ballpoint => PenKind.ballpoint,
      PenStyle.brush => PenKind.brush,
      PenStyle.calligraphy => PenKind.calligraphy,
      PenStyle.pencil || PenStyle.marker => null,
    };
    return kind == null
        ? base
        : PenFeel.apply(kind, base, sharpness: profile.sharpness);
  }

  @override
  void paint(Canvas canvas, Size size) {
    const n = 24;
    final nib = profile.style == PenStyle.calligraphy;
    Offset at(int i) => Offset(
      size.width * (0.06 + 0.88 * i / (n - 1)),
      size.height * (0.55 - 0.3 * math.sin(i / (n - 1) * math.pi)),
    );
    final points = [
      for (var i = 0; i < n; i++)
        PointVector(
          at(i).dx,
          at(i).dy,
          nib
              ? PenFeel.nibPressure(
                  (at(math.min(i + 1, n - 1)) - at(math.max(i - 1, 0)))
                      .direction,
                )
              : 0.3 + 0.6 * math.sin(i / (n - 1) * math.pi),
        ),
    ];
    final polygon = getStroke(
      points,
      options: optionsFor(profile).copyWith(
        isComplete: true,
        simulatePressure: false,
      ),
    );
    if (polygon.length < 3) return;
    canvas.drawPath(
      Path()..addPolygon(polygon, true),
      Paint()
        ..color = profile.style == PenStyle.marker
            ? color.withValues(alpha: 0.4)
            : color.withValues(alpha: profile.opacity.clamp(0.2, 1.0)),
    );
  }

  @override
  bool shouldRepaint(PenProfilePainter old) => true;
}
