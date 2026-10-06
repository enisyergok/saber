import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:saber/components/canvas/canvas_background_preview.dart';
import 'package:saber/data/covers/cover_designs.dart';
import 'package:saber/data/editor/page.dart';
import 'package:saber/data/notebooks/paper_templates.dart';
import 'package:saber/data/prefs.dart';

/// A paper of the catalogue as a small page with its name under it.
class PaperThumb extends StatelessWidget {
  const PaperThumb({
    super.key,
    required this.template,
    required this.onTap,
    this.selected = false,
    this.pageSize = EditorPage.defaultSize,
    this.paperColor,
    this.showName = true,
  });

  final PaperTemplate template;
  final VoidCallback? onTap;
  final bool selected;

  /// The format the paper is shown in.
  final Size pageSize;
  final Color? paperColor;
  final bool showName;

  @override
  Widget build(BuildContext context) {
    final colors = ColorScheme.of(context);
    final page = DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(
          color: selected ? colors.primary : colors.outlineVariant,
          width: selected ? 2.5 : 1,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: FittedBox(
          fit: BoxFit.fill,
          child: CanvasBackgroundPreview(
            selected: false,
            invert: false,
            backgroundColor: paperColor,
            backgroundPattern: template.pattern,
            backgroundImage: null,
            pageSize: pageSize,
            lineHeight: template.lineHeight,
            lineThickness: stows.lastLineThickness.value,
          ),
        ),
      ),
    );
    return Semantics(
      button: onTap != null,
      selected: selected,
      label: template.name,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            children: [
              // as large as the space allows, in the shape of the page
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: pageSize.width / pageSize.height,
                    child: page,
                  ),
                ),
              ),
              if (showName) ...[
                const SizedBox(height: 4),
                ExcludeSemantics(
                  child: Text(
                    template.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: selected ? FontWeight.w700 : null,
                      color: selected ? colors.primary : colors.onSurface,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A cover drawn small, as a bound notebook would show it.
class CoverThumb extends StatelessWidget {
  const CoverThumb({
    super.key,
    required this.design,
    this.title,
    this.pageSize = EditorPage.defaultSize,
    this.selected = false,
    this.onTap,
  });

  /// The cover; null for a notebook without one, shown as a blank page.
  final CoverDesign? design;

  /// The name written on the cover.
  final String? title;
  final Size pageSize;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = ColorScheme.of(context);
    final design = this.design;
    return Semantics(
      button: onTap != null,
      selected: selected,
      label: design?.name,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: AspectRatio(
            aspectRatio: pageSize.width / pageSize.height,
            child: DecoratedBox(
              position: DecorationPosition.foreground,
              decoration: BoxDecoration(
                border: Border.all(
                  color: selected ? colors.primary : colors.outlineVariant,
                  width: selected ? 3 : 1,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: design == null
                    ? ColoredBox(
                        color: colors.surface,
                        child: Center(
                          child: Icon(
                            Symbols.block_rounded,
                            color: colors.outline,
                            size: 20,
                          ),
                        ),
                      )
                    : CustomPaint(
                        painter: CoverPainter(
                          design,
                          pageSize: pageSize,
                          title: title,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Draws a cover at page size, scaled to the space it is given.
class CoverPainter extends CustomPainter {
  const CoverPainter(this.design, {required this.pageSize, this.title});

  final CoverDesign design;
  final Size pageSize;
  final String? title;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / pageSize.width, size.height / pageSize.height);
    design.draw(canvas, pageSize, title: title);
    canvas.restore();
  }

  @override
  bool shouldRepaint(CoverPainter old) =>
      old.design != design || old.pageSize != pageSize || old.title != title;
}
