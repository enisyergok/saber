import 'package:flutter/material.dart';
import 'package:saber/components/canvas/canvas_background_preview.dart';
import 'package:saber/data/defter_strings.dart';
import 'package:saber/data/editor/page.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/i18n/extensions/canvas_background_pattern_localized.dart';
import 'package:saber/i18n/strings.g.dart';
import 'package:sbn/canvas_background_pattern.dart';

/// Asks for the name and paper of a new notebook.
///
/// The chosen paper is stored as the last-used background pattern,
/// which is what new notes start with.
class NewNotebookDialog extends StatefulWidget {
  const NewNotebookDialog({super.key});

  /// Returns the name the user typed (empty to use the default name),
  /// or null if the dialog was dismissed.
  static Future<String?> show(BuildContext context) {
    return showDialog<String>(
      context: context,
      builder: (context) => const NewNotebookDialog(),
    );
  }

  /// The papers offered, most common first.
  static const papers = <CanvasBackgroundPattern>[
    CanvasBackgroundPattern.none,
    CanvasBackgroundPattern.lined,
    CanvasBackgroundPattern.collegeLtr,
    CanvasBackgroundPattern.grid,
    CanvasBackgroundPattern.dots,
    CanvasBackgroundPattern.cornell,
    CanvasBackgroundPattern.isometric,
    CanvasBackgroundPattern.engineering,
    CanvasBackgroundPattern.writing,
    CanvasBackgroundPattern.todo,
    CanvasBackgroundPattern.weekly,
    CanvasBackgroundPattern.daily,
    CanvasBackgroundPattern.monthly,
    CanvasBackgroundPattern.meeting,
    CanvasBackgroundPattern.storyboard,
    CanvasBackgroundPattern.table,
    CanvasBackgroundPattern.twoColumns,
    CanvasBackgroundPattern.threeColumns,
    CanvasBackgroundPattern.fourColumns,
    CanvasBackgroundPattern.sideSplit,
    CanvasBackgroundPattern.topBottom,
    CanvasBackgroundPattern.verticalSplit,
    CanvasBackgroundPattern.squareSplit,
    CanvasBackgroundPattern.titled,
    CanvasBackgroundPattern.bullets,
    CanvasBackgroundPattern.numbered,
    CanvasBackgroundPattern.legal,
    CanvasBackgroundPattern.hexagon,
    CanvasBackgroundPattern.diamond,
  ];

  @override
  State<NewNotebookDialog> createState() => _NewNotebookDialogState();
}

class _NewNotebookDialogState extends State<NewNotebookDialog> {
  final _nameController = TextEditingController();
  CanvasBackgroundPattern _paper = stows.lastBackgroundPattern.value;
  String? _nameError;

  static const _previewWidth = 88.0;
  static const _previewHeight =
      _previewWidth * EditorPage.defaultHeight / EditorPage.defaultWidth;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _create() {
    final name = _nameController.text.trim();
    if (name.isNotEmpty) {
      final error = FileManager.validateFilename(name);
      if (error != null) {
        setState(() => _nameError = error);
        return;
      }
    }
    stows.lastBackgroundPattern.value = _paper;
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    final textTheme = TextTheme.of(context);

    return AlertDialog(
      title: Text(t.home.create.newNote),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: DefterStrings.notebookName,
                  helperText: DefterStrings.nameOptional,
                  errorText: _nameError,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) {
                  if (_nameError != null) setState(() => _nameError = null);
                },
                onSubmitted: (_) => _create(),
              ),
              const SizedBox(height: 20),
              Text(DefterStrings.paper, style: textTheme.titleSmall),
              const SizedBox(height: 10),
              SizedBox(
                height: _previewHeight + 30,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: NewNotebookDialog.papers.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final paper = NewNotebookDialog.papers[index];
                    final selected = paper == _paper;
                    return InkWell(
                      borderRadius: const BorderRadius.all(Radius.circular(8)),
                      onTap: () => setState(() => _paper = paper),
                      child: SizedBox(
                        width: _previewWidth,
                        child: Column(
                          children: [
                            SizedBox(
                              width: _previewWidth,
                              height: _previewHeight,
                              child: FittedBox(
                                child: CanvasBackgroundPreview(
                                  selected: selected,
                                  invert: false,
                                  backgroundColor: null,
                                  backgroundPattern: paper,
                                  backgroundImage: null,
                                  pageSize: EditorPage.defaultSize,
                                  lineHeight: stows.lastLineHeight.value,
                                  lineThickness: stows.lastLineThickness.value,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              paper.localizedName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.bodySmall?.copyWith(
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                                color: selected
                                    ? colorScheme.primary
                                    : colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.common.cancel),
        ),
        FilledButton(
          onPressed: _create,
          child: Text(t.home.newFolder.create),
        ),
      ],
    );
  }
}
