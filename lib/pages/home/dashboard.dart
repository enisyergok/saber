import 'dart:async';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:saber/components/home/notebook_cover.dart';
import 'package:saber/components/home/preview_card.dart';
import 'package:saber/components/navbar/home_sidebar.dart';
import 'package:saber/data/defter_strings.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/notebooks/paper_templates.dart';
import 'package:saber/data/routes.dart';
import 'package:saber/pages/ask_notes.dart';
import 'package:saber/pages/editor/editor.dart';
import 'package:saber/pages/home/home.dart';
import 'package:saber/pages/home/new_notebook_wizard.dart';
import 'package:saber/pages/home/template_gallery.dart';
import 'package:saber/pages/search.dart';

/// What the home screen shows of the notes: the latest ones and the top
/// folders with how much is in each.
class DashboardData {
  const DashboardData({this.recent = const [], this.folders = const {}});

  /// The paths of the notes last opened, newest first.
  final List<String> recent;

  /// The folders at the top, with the number of notes and folders inside.
  final Map<String, int> folders;

  static Future<DashboardData> load() async {
    final recent = await FileManager.getRecentlyAccessed();
    final root = await FileManager.getChildrenOfDirectory('/');
    final folders = <String, int>{};
    for (final folder in root?.directories ?? const <String>[]) {
      final inside = await FileManager.getChildrenOfDirectory('/$folder');
      folders[folder] =
          (inside?.files.length ?? 0) + (inside?.directories.length ?? 0);
    }
    return DashboardData(recent: recent, folders: folders);
  }
}

/// The home screen: a way to start anything at the top, then the latest
/// notes, the folders and the kinds of templates.
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, this.load = DashboardData.load});

  final Future<DashboardData> Function() load;

  /// What to show instead of what [load] finds (real directory listings
  /// never complete inside a widget test).
  @visibleForTesting
  static DashboardData? overrideData;

  /// How many of the latest notes are shown.
  static const recentCount = 8;

  /// The image files a note can be started from.
  static const imageExtensions = ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'];

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  DashboardData? _data;
  StreamSubscription<FileOperation>? _writes;

  @override
  void initState() {
    super.initState();
    _load();
    _writes = FileManager.fileWriteStream.stream.listen((_) {
      if (mounted && (ModalRoute.of(context)?.isCurrent ?? true)) _load();
    });
  }

  @override
  void dispose() {
    _writes?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = DashboardPage.overrideData ?? await widget.load();
      if (mounted) setState(() => _data = data);
    } on Object catch (e) {
      // Show the page without notes rather than nothing at all.
      debugPrint('The notes could not be listed: $e');
      if (mounted && _data == null) {
        setState(() => _data = const DashboardData());
      }
    }
  }

  void _push(Widget page) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => page));

  void _snack(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  // -- the actions ----------------------------------------------------------

  Future<void> _newNote() => NotebookCreator.start(context);

  Future<void> _importPdf() async {
    if (!Editor.canRasterPdf) {
      _snack(DefterStrings.pdfNotSupported);
      return;
    }
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    final path = file?.path;
    if (file == null || path == null) return;
    final name = p.basenameWithoutExtension(file.name);
    final notePath = await FileManager.suffixFilePathToMakeItUnique('/$name');
    if (!mounted) return;
    context.push(RoutePaths.editImportPdf(notePath, path));
  }

  Future<void> _addImage() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: DashboardPage.imageExtensions,
    );
    final path = file?.path;
    if (file == null || path == null) return;
    final notePath = await FileManager.newFilePath('/');
    if (!mounted) return;
    context.push(RoutePaths.editWithImage(notePath, path));
  }

  Future<void> _importNote() async {
    final file = await FilePicker.pickFile(type: FileType.any);
    final path = file?.path;
    if (file == null || path == null) return;
    final lower = path.toLowerCase();
    if (lower.endsWith('.pdf')) {
      if (!Editor.canRasterPdf) {
        _snack(DefterStrings.pdfNotSupported);
        return;
      }
      final name = p.basenameWithoutExtension(file.name);
      final notePath = await FileManager.suffixFilePathToMakeItUnique('/$name');
      if (!mounted) return;
      context.push(RoutePaths.editImportPdf(notePath, path));
      return;
    }
    if (!lower.endsWith('.sbn') &&
        !lower.endsWith('.sbn2') &&
        !lower.endsWith('.sba')) {
      _snack(DefterStrings.invalidNoteFile);
      return;
    }
    final imported = await FileManager.importFile(path, '/');
    if (imported == null || !mounted) return;
    context.push(RoutePaths.editFilePath(imported));
  }

  Future<void> _newFolder() async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => NewFolderNameDialog(
        existing: (_data?.folders.keys ?? const <String>[]).toSet(),
      ),
    );
    if (name == null) return;
    await FileManager.createFolder('/$name');
    await _load();
  }

  // -- the page -------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
          children: [
            _hero(context),
            const SizedBox(height: 10),
            _section(
              context,
              title: DefterStrings.navRecent,
              action: TextButton(
                onPressed: () => context.go(HomeRoutes.routes[1].path),
                child: Text(DefterStrings.seeAll),
              ),
              child: _recent(context, data),
            ),
            const SizedBox(height: 10),
            _section(
              context,
              title: DefterStrings.folders,
              child: _folders(context, data),
            ),
            const SizedBox(height: 10),
            _section(
              context,
              title: DefterStrings.navTemplates,
              child: _templates(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(
    BuildContext context, {
    required String title,
    Widget? action,
    required Widget child,
  }) {
    final colors = ColorScheme.of(context);
    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 40,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (action != null) action,
                ],
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }

  Widget _hero(BuildContext context) {
    final colors = ColorScheme.of(context);
    final dark = Theme.brightnessOf(context) == Brightness.dark;
    final ink = dark ? Colors.white : const Color(0xFF1F2440);

    Widget action(
      IconData icon,
      String label,
      VoidCallback onTap, {
      bool primary = false,
    }) => primary
        ? FilledButton.icon(
            onPressed: onTap,
            icon: Icon(icon, size: 18),
            label: Text(label),
          )
        : FilledButton.tonalIcon(
            style: FilledButton.styleFrom(
              backgroundColor: colors.surface.withValues(alpha: 0.9),
              foregroundColor: colors.onSurface,
            ),
            onPressed: onTap,
            icon: Icon(icon, size: 18),
            label: Text(label),
          );

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: CustomPaint(
        painter: HeroPainter(dark: dark),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 14, 16, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Spacer(),
                  // Tapping the field opens the search page: it searches
                  // names, typed text and handwriting that has been read.
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 300),
                    child: Material(
                      color: colors.surface.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(22),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => _push(const SearchPage()),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 9,
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.search, size: 18, color: colors.onSurfaceVariant),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  DefterStrings.searchNotes,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: colors.onSurfaceVariant),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton.filledTonal(
                    tooltip: DefterStrings.askNotes,
                    style: IconButton.styleFrom(
                      backgroundColor: colors.surface.withValues(alpha: 0.9),
                    ),
                    icon: const Icon(Icons.auto_awesome, size: 20),
                    onPressed: () => _push(const AskNotesPage()),
                  ),
                  IconButton.filledTonal(
                    tooltip: DefterStrings.navSettings,
                    style: IconButton.styleFrom(
                      backgroundColor: colors.surface.withValues(alpha: 0.9),
                    ),
                    icon: const Icon(Icons.settings_outlined, size: 20),
                    onPressed: () => context.go(HomeRoutes.routes[3].path),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                DefterStrings.heroTitle,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                DefterStrings.heroSubtitle,
                style: TextStyle(color: ink.withValues(alpha: 0.8)),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  action(
                    Icons.add_circle,
                    DefterStrings.actionNewNote,
                    _newNote,
                    primary: true,
                  ),
                  action(
                    Icons.dashboard_customize_outlined,
                    DefterStrings.actionFromTemplate,
                    () => _push(const TemplateGalleryPage()),
                  ),
                  action(
                    Icons.picture_as_pdf_outlined,
                    DefterStrings.actionImportPdf,
                    _importPdf,
                  ),
                  action(
                    Icons.image_outlined,
                    DefterStrings.actionAddImage,
                    _addImage,
                  ),
                  action(
                    Icons.create_new_folder_outlined,
                    DefterStrings.actionNewFolder,
                    _newFolder,
                  ),
                  PopupMenuButton<int>(
                    tooltip: DefterStrings.actionMore,
                    onSelected: (value) {
                      switch (value) {
                        case 0:
                          _importNote();
                        case 1:
                          context.go(HomeRoutes.routes[2].path);
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 0,
                        child: Text(DefterStrings.actionImportNote),
                      ),
                      PopupMenuItem(
                        value: 1,
                        child: Text(DefterStrings.navWhiteboard),
                      ),
                    ],
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: colors.surface.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(Icons.more_horiz, color: colors.onSurface),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _recent(BuildContext context, DashboardData? data) {
    final colors = ColorScheme.of(context);
    const coverWidth = 124.0;
    const height = coverWidth / kNotebookCoverAspectRatio + kNotebookCaptionHeight;
    if (data == null) return const SizedBox(height: height);

    final recent = data.recent.take(DashboardPage.recentCount).toList();
    final newTile = SizedBox(
      width: coverWidth,
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: kNotebookCoverAspectRatio,
            child: Material(
              color: colors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: colors.outlineVariant),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: _newNote,
                child: Icon(Icons.add, size: 30, color: colors.primary),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(DefterStrings.newItem),
        ],
      ),
    );

    if (recent.isEmpty) {
      return SizedBox(
        height: height,
        child: Row(
          children: [
            newTile,
            const SizedBox(width: 20),
            Expanded(
              child: Text(
                DefterStrings.noRecentNotes,
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
            ),
          ],
        ),
      );
    }
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: recent.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          if (index == recent.length) return newTile;
          return SizedBox(
            width: coverWidth,
            child: PreviewCard(
              filePath: recent[index],
              selected: false,
              isAnythingSelected: false,
              toggleSelection: (_, _) {},
            ),
          );
        },
      ),
    );
  }

  Widget _folders(BuildContext context, DashboardData? data) {
    final colors = ColorScheme.of(context);
    if (data == null) return const SizedBox(height: 56);

    Widget card({required Widget child, required VoidCallback onTap}) =>
        Material(
          color: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: colors.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(height: 56, child: child),
          ),
        );

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final MapEntry(key: name, value: count) in data.folders.entries)
          SizedBox(
            width: 168,
            child: card(
              onTap: () => context.go(HomeRoutes.browseFilePath('/$name')),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Icon(Icons.folder, size: 30, color: folderColour('/$name')),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            DefterStrings.itemCount(count),
                            style: TextStyle(
                              fontSize: 11,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (data.folders.isEmpty)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Text(
              DefterStrings.noFolders,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          ),
        SizedBox(
          width: 56,
          child: Tooltip(
            message: DefterStrings.actionNewFolder,
            child: card(
              onTap: _newFolder,
              child: Icon(Icons.add, color: colors.primary),
            ),
          ),
        ),
      ],
    );
  }

  Widget _templates(BuildContext context) {
    Widget chip(IconData icon, String label, PaperGroup? group) => ActionChip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      onPressed: () => _push(TemplateGalleryPage(group: group)),
    );
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        chip(Icons.apps, DefterStrings.groupAll, null),
        chip(Icons.reorder, PaperGroup.lined.label, PaperGroup.lined),
        chip(Icons.grid_4x4, PaperGroup.squared.label, PaperGroup.squared),
        chip(Icons.blur_on, PaperGroup.dotted.label, PaperGroup.dotted),
        chip(
          Icons.calendar_month_outlined,
          PaperGroup.planner.label,
          PaperGroup.planner,
        ),
        chip(Icons.account_tree_outlined, PaperGroup.diagram.label, PaperGroup.diagram),
        chip(
          Icons.architecture,
          PaperGroup.engineering.label,
          PaperGroup.engineering,
        ),
        chip(Icons.school_outlined, PaperGroup.academic.label, PaperGroup.academic),
        chip(Icons.star_outline, PaperGroup.special.label, PaperGroup.special),
      ],
    );
  }
}

/// The picture behind the top of the home screen: a pale sky and three
/// ranges of hills, drawn here so that it fits any width.
class HeroPainter extends CustomPainter {
  const HeroPainter({required this.dark});

  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final sky = dark
        ? const [Color(0xFF232A4D), Color(0xFF3B3566)]
        : const [Color(0xFFE6ECFF), Color(0xFFD9D3F7)];
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: sky,
        ).createShader(Offset.zero & size),
    );
    final ranges = dark
        ? const [Color(0xFF3A437A), Color(0xFF2F3768), Color(0xFF262D57)]
        : const [Color(0xFFC9D2F6), Color(0xFFB3BFEF), Color(0xFF9FADE6)];
    for (var i = 0; i < ranges.length; i++) {
      final base = size.height * (0.52 + i * 0.16);
      final rise = size.height * (0.3 - i * 0.06);
      final path = Path()..moveTo(size.width * 0.3, size.height);
      for (var x = size.width * 0.3; x <= size.width; x += 6) {
        final u = x / size.width;
        final y =
            base -
            rise *
                (0.55 * math.sin(u * (7 + i * 3) + i * 1.7) +
                        0.45 * math.sin(u * (15 + i * 5) + i))
                    .abs() *
                // the hills fade out towards the text on the left
                ((u - 0.3) / 0.7).clamp(0.0, 1.0);
        path.lineTo(x, y);
      }
      path
        ..lineTo(size.width, size.height)
        ..close();
      canvas.drawPath(path, Paint()..color = ranges[i]);
    }
  }

  @override
  bool shouldRepaint(HeroPainter old) => old.dark != dark;
}
