import 'package:flutter/material.dart';
import 'package:saber/components/home/paper_thumb.dart';
import 'package:saber/data/defter_strings.dart';
import 'package:saber/data/notebooks/paper_templates.dart';
import 'package:saber/pages/home/new_notebook_wizard.dart';

/// The papers of the catalogue to browse and start a notebook from: all
/// of them by kind, or one kind (planners, engineering, diagrams) by
/// topic.
class TemplateGalleryPage extends StatefulWidget {
  const TemplateGalleryPage({super.key, this.group, this.folder});

  /// The kind of paper shown; null for all kinds, with a tab for each.
  final PaperGroup? group;

  /// The folder a notebook made from here goes into.
  final String? folder;

  @override
  State<TemplateGalleryPage> createState() => _TemplateGalleryPageState();
}

class _TemplateGalleryPageState extends State<TemplateGalleryPage> {
  late PaperGroup? _group = widget.group;
  PaperTopic? _topic;

  @override
  Widget build(BuildContext context) {
    final fixed = widget.group;
    final topics = _group == null
        ? const <PaperTopic>[]
        : PaperTemplates.topicsOf(_group!);
    final templates = _group == null
        ? PaperTemplates.inGroup(null)
        : PaperTemplates.about(_group!, _topic);

    Widget chip(String label, bool selected, VoidCallback onTap) => Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        onSelected: (_) => onTap(),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          fixed == null
              ? DefterStrings.navTemplates
              : DefterStrings.templatesOf(fixed.label),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // every kind, unless the page was opened for one kind
          if (fixed == null)
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  chip(
                    DefterStrings.groupAll,
                    _group == null,
                    () => setState(() {
                      _group = null;
                      _topic = null;
                    }),
                  ),
                  for (final group in PaperGroup.values)
                    chip(
                      group.label,
                      _group == group,
                      () => setState(() {
                        _group = group;
                        _topic = null;
                      }),
                    ),
                ],
              ),
            ),
          if (topics.isNotEmpty)
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  chip(
                    DefterStrings.groupAll,
                    _topic == null,
                    () => setState(() => _topic = null),
                  ),
                  for (final topic in topics)
                    chip(
                      topic.label,
                      _topic == topic,
                      () => setState(() => _topic = topic),
                    ),
                ],
              ),
            ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 132,
                mainAxisExtent: 186,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: templates.length,
              itemBuilder: (context, index) {
                final template = templates[index];
                return PaperThumb(
                  template: template,
                  // the paper is chosen: the wizard opens on the cover
                  onTap: () => NotebookCreator.start(
                    context,
                    folder: widget.folder,
                    template: template,
                    startAt: 1,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
