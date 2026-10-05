import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:saber/components/home/paper_thumb.dart';
import 'package:saber/data/covers/cover_designs.dart';
import 'package:saber/data/defter_strings.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/notebooks/notebook_spec.dart';
import 'package:saber/data/notebooks/paper_templates.dart';
import 'package:saber/data/routes.dart';

/// Making a notebook in six steps: paper, cover, size and colour, name,
/// folder, and a last look before it is made.
///
/// Returns what was chosen as a [NotebookSpec]; [NotebookCreator.open]
/// then makes the note and opens it.
class NewNotebookWizard extends StatefulWidget {
  const NewNotebookWizard({
    super.key,
    this.initial,
    this.startAt = 0,
    this.loadFolders = NotebookCreator.allFolders,
  });

  /// What is already chosen (a template picked in a gallery, the folder
  /// the person is in).
  final NotebookSpec? initial;

  /// The step to open on, 0..5.
  final int startAt;

  /// Lists the folders to choose from, "/" not included.
  final Future<List<String>> Function() loadFolders;

  static const stepCount = 6;

  static Future<NotebookSpec?> show(
    BuildContext context, {
    NotebookSpec? initial,
    int startAt = 0,
  }) {
    return showDialog<NotebookSpec>(
      context: context,
      builder: (context) =>
          NewNotebookWizard(initial: initial, startAt: startAt),
    );
  }

  @override
  State<NewNotebookWizard> createState() => _NewNotebookWizardState();
}

class _NewNotebookWizardState extends State<NewNotebookWizard> {
  late final NotebookSpec _spec = widget.initial ?? NotebookSpec();
  late int _step = widget.startAt.clamp(0, NewNotebookWizard.stepCount - 1);
  late final _nameController = TextEditingController(text: _spec.name);
  String? _nameError;

  PaperGroup? _paperGroup;
  String? _coverGroup;
  List<String>? _folders;

  static List<String> get _stepNames => [
    DefterStrings.stepTemplate,
    DefterStrings.stepCover,
    DefterStrings.stepSize,
    DefterStrings.stepName,
    DefterStrings.stepFolder,
    DefterStrings.stepCreate,
  ];

  @override
  void initState() {
    super.initState();
    widget.loadFolders().then(
      (folders) {
        if (mounted) setState(() => _folders = folders);
      },
      // The folders can't be listed: the top folder is still there.
      onError: (Object _) {
        if (mounted) setState(() => _folders = const []);
      },
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// Checks the name; false (and the name step is shown) if it can't be
  /// a file name.
  bool _checkName() {
    final name = _nameController.text.trim();
    final error = name.isEmpty ? null : FileManager.validateFilename(name);
    setState(() {
      _nameError = error;
      if (error != null) _step = 3;
    });
    if (error == null) _spec.name = name;
    return error == null;
  }

  void _goTo(int step) {
    if (_step == 3 && step != 3 && !_checkName()) return;
    setState(() => _step = step.clamp(0, NewNotebookWizard.stepCount - 1));
  }

  void _create() {
    if (!_checkName()) return;
    Navigator.of(context).pop(_spec);
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final wide = screen.width >= 760;
    final colors = ColorScheme.of(context);

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: switch (_step) {
              0 => _templateStep(context),
              1 => _coverStep(context),
              2 => _sizeStep(context),
              3 => _nameStep(context),
              4 => _folderStep(context),
              _ => _summaryStep(context),
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              if (_step > 0)
                TextButton.icon(
                  onPressed: () => _goTo(_step - 1),
                  icon: const Icon(Icons.chevron_left),
                  label: Text(DefterStrings.back),
                ),
              const Spacer(),
              if (_step < NewNotebookWizard.stepCount - 1) ...[
                // Everything has a sensible default: making the notebook
                // right away is always possible.
                TextButton(
                  onPressed: _create,
                  child: Text(DefterStrings.stepCreate),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () => _goTo(_step + 1),
                  icon: const Icon(Icons.chevron_right),
                  iconAlignment: IconAlignment.end,
                  label: Text(DefterStrings.next),
                ),
              ] else
                FilledButton.icon(
                  onPressed: _create,
                  icon: const Icon(Icons.check),
                  label: Text(DefterStrings.stepCreate),
                ),
            ],
          ),
        ),
      ],
    );

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1040, maxHeight: 660),
        child: wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(width: 216, child: _rail(context, colors)),
                  VerticalDivider(width: 1, color: colors.outlineVariant),
                  Expanded(child: content),
                ],
              )
            : Column(
                children: [
                  _topSteps(context, colors),
                  Expanded(child: content),
                ],
              ),
      ),
    );
  }

  // -- the steps at the side ------------------------------------------------

  Widget _stepDot(ColorScheme colors, int index) {
    final current = index == _step;
    final done = index < _step;
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: current
            ? colors.primary
            : done
            ? colors.primary.withValues(alpha: 0.18)
            : colors.surfaceContainerHighest,
      ),
      child: Text(
        '${index + 1}',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: current ? colors.onPrimary : colors.onSurface,
        ),
      ),
    );
  }

  Widget _rail(BuildContext context, ColorScheme colors) {
    return ColoredBox(
      color: colors.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    DefterStrings.wizardTitle,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            for (var i = 0; i < NewNotebookWizard.stepCount; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Material(
                  color: i == _step
                      ? colors.primary.withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => _goTo(i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 7,
                      ),
                      child: Row(
                        children: [
                          _stepDot(colors, i),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _stepNames[i],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: i == _step ? FontWeight.w700 : null,
                                color: i == _step
                                    ? colors.primary
                                    : colors.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            const Spacer(),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(DefterStrings.cancelWord),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topSteps(BuildContext context, ColorScheme colors) {
    return ColoredBox(
      color: colors.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
        child: Row(
          children: [
            for (var i = 0; i < NewNotebookWizard.stepCount; i++)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => _goTo(i),
                  child: _stepDot(colors, i),
                ),
              ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                _stepNames[_step],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              tooltip: DefterStrings.cancelWord,
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chips<T>({
    required List<T?> values,
    required T? selected,
    required String Function(T? value) label,
    required ValueChanged<T?> onSelected,
  }) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, index) => ChoiceChip(
          label: Text(label(values[index])),
          selected: values[index] == selected,
          showCheckmark: false,
          visualDensity: VisualDensity.compact,
          onSelected: (_) => onSelected(values[index]),
        ),
      ),
    );
  }

  /// [main] with [side] (a preview) next to it where there is room; on a
  /// narrow screen the preview is left out.
  Widget _split({required Widget main, required Widget side}) => LayoutBuilder(
    builder: (context, constraints) => constraints.maxWidth < 520
        ? main
        : Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 3, child: main),
              const SizedBox(width: 16),
              Expanded(flex: 2, child: side),
            ],
          ),
  );

  Widget _heading(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    ),
  );

  // -- 1: the paper ---------------------------------------------------------

  Widget _templateStep(BuildContext context) {
    final templates = PaperTemplates.inGroup(_paperGroup);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _chips<PaperGroup>(
          values: [null, ...PaperGroup.values],
          selected: _paperGroup,
          label: (group) => group?.label ?? DefterStrings.groupAll,
          onSelected: (group) => setState(() => _paperGroup = group),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 104,
              mainAxisExtent: 148,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
            ),
            itemCount: templates.length,
            itemBuilder: (context, index) {
              final template = templates[index];
              return PaperThumb(
                template: template,
                selected: template.id == _spec.template.id,
                onTap: () => setState(() => _spec.template = template),
              );
            },
          ),
        ),
      ],
    );
  }

  // -- 2: the cover ---------------------------------------------------------

  Widget _coverStep(BuildContext context) {
    final designs = _coverGroup == null
        ? CoverDesigns.all
        : CoverDesigns.inGroup(_coverGroup!);
    final title = _nameController.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(context, DefterStrings.coverDesign),
        _chips<String>(
          values: [null, ...CoverDesigns.groups],
          selected: _coverGroup,
          label: (group) =>
              group == null ? DefterStrings.groupAll : CoverGroups.label(group),
          onSelected: (group) => setState(() => _coverGroup = group),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _split(
            main: GridView.builder(
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 92,
                childAspectRatio: _spec.pageSize.width / _spec.pageSize.height,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              // the first tile is "no cover"
              itemCount: designs.length + 1,
              itemBuilder: (context, index) {
                final design = index == 0 ? null : designs[index - 1];
                return Tooltip(
                  message: design?.name ?? DefterStrings.noCover,
                  child: CoverThumb(
                    design: design,
                    pageSize: _spec.pageSize,
                    selected: design?.id == _spec.cover?.id,
                    onTap: () => setState(() => _spec.cover = design),
                  ),
                );
              },
            ),
            // the cover as it will be, with the name on it
            side: Column(
              children: [
                Expanded(
                  child: Center(
                    child: CoverThumb(
                      design: _spec.cover,
                      pageSize: _spec.pageSize,
                      title: title.isEmpty ? null : title,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _spec.cover?.name ?? DefterStrings.noCover,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // -- 3: size, orientation, colour -------------------------------------------

  Widget _sizeStep(BuildContext context) {
    final colors = ColorScheme.of(context);
    Widget formatTile(PaperFormat format) {
      final selected = format == _spec.format;
      final size = format.pageSize(landscape: _spec.landscape);
      return Material(
        color: selected ? colors.primary.withValues(alpha: 0.12) : colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected ? colors.primary : colors.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => setState(() => _spec.format = format),
          child: SizedBox(
            width: 118,
            height: 96,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: 34,
                  child: AspectRatio(
                    aspectRatio: size.width / size.height,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: selected ? colors.primary : colors.onSurface,
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  format.label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: selected ? colors.primary : colors.onSurface,
                  ),
                ),
                Text(
                  format.describe(landscape: _spec.landscape),
                  style: TextStyle(fontSize: 10.5, color: colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return _split(
      side: Center(child: _pagePreview()),
      main: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _heading(context, DefterStrings.stepSize),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final format in PaperFormat.values) formatTile(format),
                  ],
                ),
                const SizedBox(height: 14),
                SegmentedButton<bool>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: false,
                      icon: const Icon(Icons.crop_portrait),
                      label: Text(DefterStrings.orientationPortrait),
                    ),
                    ButtonSegment(
                      value: true,
                      icon: const Icon(Icons.crop_landscape),
                      label: Text(DefterStrings.orientationLandscape),
                    ),
                  ],
                  selected: {_spec.landscape},
                  onSelectionChanged: (selection) =>
                      setState(() => _spec.landscape = selection.first),
                ),
                const SizedBox(height: 16),
                _heading(context, DefterStrings.paperColour),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    for (final (colour, name) in PaperColours.all)
                      _colourTile(colors, colour, name),
                  ],
                ),
              ],
            ),
      ),
    );
  }

  Widget _colourTile(ColorScheme colors, Color? colour, String name) {
    final selected = colour?.toARGB32() == _spec.paperColor?.toARGB32();
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => setState(() => _spec.paperColor = colour),
        child: SizedBox(
          width: 62,
          child: Column(
            children: [
              Container(
                width: 54,
                height: 34,
                decoration: BoxDecoration(
                  color: colour ?? Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: selected ? colors.primary : colors.outlineVariant,
                    width: selected ? 2.5 : 1,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The first page as it will be: the paper on its colour, in its format.
  Widget _pagePreview() => AspectRatio(
    aspectRatio: _spec.pageSize.width / _spec.pageSize.height,
    child: PaperThumb(
      template: _spec.template,
      pageSize: _spec.pageSize,
      paperColor: _spec.paperColor,
      showName: false,
      onTap: null,
    ),
  );

  // -- 4: the name ----------------------------------------------------------

  Widget _nameStep(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(context, DefterStrings.stepName),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: TextField(
            controller: _nameController,
            autofocus: true,
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
            onSubmitted: (_) => _goTo(4),
          ),
        ),
      ],
    );
  }

  // -- 5: the folder --------------------------------------------------------

  Widget _folderStep(BuildContext context) {
    final colors = ColorScheme.of(context);
    final folders = _folders;
    Widget tile(String path, String label, int depth) {
      final selected = _spec.folder == path;
      return ListTile(
        dense: true,
        contentPadding: EdgeInsets.only(left: 8 + depth * 18.0, right: 8),
        leading: Icon(
          path == '/' ? Icons.home_outlined : Icons.folder,
          color: path == '/' ? colors.onSurface : folderColour(path),
        ),
        title: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: selected ? Icon(Icons.check, color: colors.primary) : null,
        selected: selected,
        onTap: () => setState(() => _spec.folder = path),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(context, DefterStrings.stepFolder),
        Expanded(
          child: folders == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  children: [
                    tile('/', DefterStrings.rootFolder, 0),
                    for (final folder in folders)
                      tile(
                        folder,
                        folder.substring(folder.lastIndexOf('/') + 1),
                        '/'.allMatches(folder).length,
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  // -- 6: the summary -------------------------------------------------------

  Widget _summaryStep(BuildContext context) {
    final name = _nameController.text.trim();
    Widget row(String label, String value, int step) => InkWell(
      onTap: () => _goTo(step),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            SizedBox(
              width: 86,
              child: Text(
                label,
                style: TextStyle(
                  color: ColorScheme.of(context).onSurfaceVariant,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const Icon(Icons.edit_outlined, size: 16),
          ],
        ),
      ),
    );

    return _split(
      side: Center(
        child: _spec.cover == null
            ? _pagePreview()
            : CoverThumb(
                design: _spec.cover,
                pageSize: _spec.pageSize,
                title: name.isEmpty ? null : name,
              ),
      ),
      main: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _heading(context, DefterStrings.stepCreate),
                row(DefterStrings.summaryTemplate, _spec.template.name, 0),
                row(
                  DefterStrings.summaryCover,
                  _spec.cover?.name ?? DefterStrings.noCover,
                  1,
                ),
                row(
                  DefterStrings.summarySize,
                  '${_spec.format.label} · '
                  '${_spec.format.describe(landscape: _spec.landscape)} · '
                  '${PaperColours.nameOf(_spec.paperColor)}',
                  2,
                ),
                row(
                  DefterStrings.summaryName,
                  name.isEmpty ? DefterStrings.defaultName : name,
                  3,
                ),
                row(
                  DefterStrings.summaryFolder,
                  _spec.folder == '/' ? DefterStrings.rootFolder : _spec.folder,
                  4,
                ),
              ],
            ),
      ),
    );
  }
}

/// A colour for a folder, always the same for the same folder.
Color folderColour(String path) {
  const palette = [
    Color(0xFF5B9BF0),
    Color(0xFFF59E6B),
    Color(0xFF58B8C4),
    Color(0xFF6BBF73),
    Color(0xFFF2B84B),
    Color(0xFFC792E8),
    Color(0xFFF28BB0),
    Color(0xFF8D99AE),
  ];
  var hash = 0;
  for (final unit in path.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return palette[hash % palette.length];
}

/// Makes the notebooks chosen in the [NewNotebookWizard].
abstract class NotebookCreator {
  /// Every folder there is, "/Dersler", "/Dersler/Fizik", ..., down to
  /// three levels, parents before their children.
  static Future<List<String>> allFolders() async {
    final found = <String>[];
    Future<void> visit(String path, int depth) async {
      final children = await FileManager.getChildrenOfDirectory(
        path.isEmpty ? '/' : path,
      );
      if (children == null) return;
      for (final directory in children.directories) {
        final child = '$path/$directory';
        found.add(child);
        if (depth < 2) await visit(child, depth + 1);
      }
    }

    await visit('', 0);
    return found;
  }

  /// The path of the note that [spec] makes: its name in its folder (with
  /// a number if that is taken), or a dated name if it has none.
  static Future<String> pathFor(NotebookSpec spec) {
    final name = spec.name.trim();
    return name.isEmpty
        ? FileManager.newFilePath(spec.folderPrefix)
        : FileManager.suffixFilePathToMakeItUnique('${spec.folderPrefix}$name');
  }

  /// Makes the notebook of [spec] and opens it in the editor.
  static Future<void> open(BuildContext context, NotebookSpec spec) async {
    final path = await pathFor(spec);
    if (!context.mounted) return;
    PendingNotebook.set(path, spec);
    context.push(RoutePaths.editFilePath(path));
  }

  /// Shows the wizard and makes what was chosen. [folder] is where the
  /// person is; [template] what they picked in a gallery.
  static Future<void> start(
    BuildContext context, {
    String? folder,
    PaperTemplate? template,
    int startAt = 0,
  }) async {
    final spec = await NewNotebookWizard.show(
      context,
      initial: NotebookSpec(
        folder: folder == null || folder.isEmpty ? '/' : folder,
        template: template,
      ),
      startAt: startAt,
    );
    if (spec == null || !context.mounted) return;
    await open(context, spec);
  }
}
