import 'dart:async';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:saber/components/home/noteva_library.dart';
import 'package:saber/components/home/favorite_note_button.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/pages/favorites.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:saber/components/home/notebook_cover.dart';
import 'package:saber/components/home/library_header.dart';
import 'package:saber/components/home/preview_card.dart';
import 'package:saber/components/navbar/home_sidebar.dart';
import 'package:saber/components/theming/defter_design.dart';
import 'package:saber/data/defter_strings.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/notebooks/paper_templates.dart';
import 'package:saber/data/pdf/pdf_import.dart';
import 'package:saber/data/routes.dart';
import 'package:saber/pages/ask_notes.dart';
import 'package:saber/pages/editor/editor.dart';
import 'package:saber/pages/home/new_notebook_wizard.dart';
import 'package:saber/pages/home/template_gallery.dart';
import 'package:saber/pages/search.dart';

/// What the home screen shows of the notes: the latest ones and the top
/// folders with how much is in each.
class DashboardData {
  const DashboardData({
    this.recent = const [],
    this.folders = const {},
    this.documents = const [],
  });
  final List<LibraryDocument> documents;

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
    final documents = <LibraryDocument>[];
    for (final name in root?.files ?? const <String>[]) {
      final path = '/$name';
      final file = FileManager.getFile('$path${Editor.extension}');
      final thumbnail = FileManager.getFile('$path${Editor.extension}.p');
      final modified = file.existsSync() ? file.lastModifiedSync() : null;
      documents.add(
        LibraryDocument(
          id: path,
          title: path.split('/').last,
          modified: modified,
          cover: thumbnail.existsSync()
              ? Image.file(
                  thumbnail,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) =>
                      const Icon(Icons.description_outlined),
                )
              : null,
          subtitle: modified == null
              ? ''
              : '${modified.day}.${modified.month}.${modified.year}',
          favorite: stows.favoriteFiles.value.contains(
            '$path${Editor.extension}',
          ),
        ),
      );
    }
    for (final entry in folders.entries) {
      documents.add(
        LibraryDocument(
          id: '/${entry.key}',
          title: entry.key,
          folder: true,
          subtitle: DefterStrings.itemCount(entry.value),
        ),
      );
    }
    return DashboardData(
      recent: recent,
      folders: folders,
      documents: documents,
    );
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
  StreamSubscription<String>? _folderChanges;

  @override
  void initState() {
    super.initState();
    _load();
    _writes = FileManager.fileWriteStream.stream.listen((_) {
      if (mounted && (ModalRoute.of(context)?.isCurrent ?? true)) _load();
    });
    // A folder made, renamed or removed is shown at once, also while the
    // dialog that did it is still closing over this page.
    _folderChanges = FileManager.folderChanges.stream.listen((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _writes?.cancel();
    _folderChanges?.cancel();
    super.dispose();
  }

  /// Counts the listings begun, so that one that was begun earlier and
  /// comes back later cannot put back what has changed since.
  var _loads = 0;

  Future<void> _load() async {
    final load = ++_loads;
    try {
      final data = DashboardPage.overrideData ?? await widget.load();
      if (mounted && load == _loads) setState(() => _data = data);
    } on Object catch (e) {
      // Show the page without notes rather than nothing at all.
      debugPrint('The notes could not be listed: $e');
      if (mounted && _data == null) {
        setState(() => _data = const DashboardData());
      }
    }
  }

  void _push(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  void _snack(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  // -- the actions ----------------------------------------------------------

  Future<void> _newNote() => NotebookCreator.start(context);

  Future<void> _importPdf() async {
    if (!Editor.canRasterPdf) {
      _snack(DefterStrings.pdfNotSupported);
      return;
    }
    final String path, name;
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
      );
      if (file == null) return;
      name = file.name;
      path = await PdfImport.localPath(
        path: file.path,
        name: name,
        readBytes: file.readAsBytes,
      );
    } on PdfImportException catch (e) {
      if (mounted) _snack(DefterStrings.pdfImportReason(e.failure.name));
      return;
    }
    await _openPdfAsNote(path, name);
  }

  /// Makes a note from the PDF at [path], named after it. A file that
  /// plainly is no PDF is refused here, before an empty note is made.
  Future<void> _openPdfAsNote(String path, String name) async {
    try {
      await PdfImport.check(path);
    } on PdfImportException catch (e) {
      if (mounted) _snack(DefterStrings.pdfImportReason(e.failure.name));
      return;
    }
    final notePath = await FileManager.suffixFilePathToMakeItUnique(
      '/${PdfImport.noteNameFor(name)}',
    );
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
      await _openPdfAsNote(path, file.name);
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
    return NotevaLibrary(
      loading: _data == null,
      documents: _data?.documents ?? const [],
      onOpen: (doc) => doc.folder
          ? context.go(HomeRoutes.browseFilePath(doc.id))
          : context.push(RoutePaths.editFilePath(doc.id)),
      onCreate: _newNote,
      onImport: _importNote,
      onSearch: () => _push(const SearchPage()),
      onFavorites: () => _push(const FavoritesPage()),
      onTemplates: () => _push(const TemplateGalleryPage()),
      onSettings: () => context.go(HomeRoutes.routes[3].path),
      onFavorite: (doc) {
        FavoriteNoteButton.toggle([doc.id]);
        _load();
      },
      onImportPdf: _importPdf,
      onNewFolder: _newFolder,
    );
  }

  // Retained during the first-screen approval so the previous layout remains
  // reviewable. The live entry point above uses NotevaLibrary.
  Widget buildPreviousLibrary(BuildContext context) {
    final data = _data;
    return Scaffold(
      body: Column(
        children: [
          _libraryHeader(context),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                _section(
                  context,
                  title: DefterStrings.folders,
                  action: TextButton.icon(
                    onPressed: _newFolder,
                    icon: const Icon(
                      Symbols.create_new_folder_rounded,
                      size: 18,
                    ),
                    label: Text(DefterStrings.actionNewFolder),
                  ),
                  child: _folders(context, data),
                ),
                const SizedBox(height: 28),
                _section(
                  context,
                  title: DefterStrings.navRecent,
                  action: TextButton(
                    onPressed: () => context.go(HomeRoutes.routes[1].path),
                    child: Text(DefterStrings.seeAll),
                  ),
                  child: _recent(context, data),
                ),
                const SizedBox(height: 28),
                _section(
                  context,
                  title: DefterStrings.navTemplates,
                  child: _templates(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(
    BuildContext context, {
    required String title,
    Widget? action,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 36,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.1,
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
    );
  }

  Widget _libraryHeader(BuildContext context) => LibraryHeader(
    title: DefterStrings.navNotes,
    onSearch: () => _push(const SearchPage()),
    actions: [
      IconButton(
        tooltip: DefterStrings.askNotes,
        icon: const Icon(Icons.auto_awesome_rounded),
        onPressed: () => _push(const AskNotesPage()),
      ),
      PopupMenuButton<int>(
        key: const Key('libraryCreateMenu'),
        tooltip: DefterStrings.newItem,
        icon: const Icon(Symbols.add_circle_rounded),
        onSelected: (value) {
          switch (value) {
            case 0:
              _newNote();
            case 1:
              _push(const TemplateGalleryPage());
            case 2:
              _importPdf();
            case 3:
              _addImage();
            case 4:
              _newFolder();
            case 5:
              _importNote();
          }
        },
        itemBuilder: (_) => [
          PopupMenuItem(value: 0, child: Text(DefterStrings.actionNewNote)),
          PopupMenuItem(
            value: 1,
            child: Text(DefterStrings.actionFromTemplate),
          ),
          PopupMenuItem(value: 2, child: Text(DefterStrings.actionImportPdf)),
          PopupMenuItem(value: 3, child: Text(DefterStrings.actionAddImage)),
          PopupMenuItem(value: 4, child: Text(DefterStrings.actionNewFolder)),
          PopupMenuItem(value: 5, child: Text(DefterStrings.actionImportNote)),
        ],
      ),
    ],
    bottom: Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.icon(
          onPressed: _newNote,
          icon: const Icon(Symbols.add_rounded, size: 18),
          label: Text(DefterStrings.actionNewNote),
        ),
        TextButton.icon(
          onPressed: () => _push(const TemplateGalleryPage()),
          icon: const Icon(Symbols.dashboard_customize_rounded, size: 18),
          label: Text(DefterStrings.actionFromTemplate),
        ),
        TextButton.icon(
          onPressed: _importPdf,
          icon: const Icon(Symbols.file_upload_rounded, size: 18),
          label: Text(DefterStrings.actionImportPdf),
        ),
      ],
    ),
  );

  Widget _recent(BuildContext context, DashboardData? data) {
    final colors = ColorScheme.of(context);
    const coverWidth = 156.0;
    const height =
        coverWidth / kNotebookCoverAspectRatio + kNotebookCaptionHeight;
    if (data == null) return const SizedBox(height: height);

    final recent = data.recent.take(DashboardPage.recentCount).toList();
    final newTile = SizedBox(
      width: coverWidth,
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: kNotebookCoverAspectRatio,
            child: PressScale(
              child: Material(
                color: colors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: colors.outlineVariant),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: _newNote,
                  child: Icon(
                    Symbols.add_rounded,
                    size: 30,
                    color: colors.primary,
                  ),
                ),
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
    if (data == null) return const LinearProgressIndicator();
    if (data.folders.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          DefterStrings.noFolders,
          style: TextStyle(color: colors.onSurfaceVariant),
        ),
      );
    }
    return Wrap(
      spacing: 24,
      runSpacing: 16,
      children: [
        for (final MapEntry(key: name, value: count) in data.folders.entries)
          SizedBox(
            width: 176,
            child: Material(
              color: colors.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: colors.outlineVariant),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => context.go(HomeRoutes.browseFilePath('/$name')),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                  child: Column(
                    children: [
                      Icon(
                        Icons.folder_rounded,
                        size: 42,
                        color: folderColour('/$name'),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          DefterStrings.itemCount(count),
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
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
        chip(Symbols.apps_rounded, DefterStrings.groupAll, null),
        chip(Symbols.reorder_rounded, PaperGroup.lined.label, PaperGroup.lined),
        chip(
          Symbols.grid_4x4_rounded,
          PaperGroup.squared.label,
          PaperGroup.squared,
        ),
        chip(
          Symbols.blur_on_rounded,
          PaperGroup.dotted.label,
          PaperGroup.dotted,
        ),
        chip(
          Symbols.calendar_month_rounded,
          PaperGroup.planner.label,
          PaperGroup.planner,
        ),
        chip(
          Symbols.account_tree_rounded,
          PaperGroup.diagram.label,
          PaperGroup.diagram,
        ),
        chip(
          Symbols.architecture_rounded,
          PaperGroup.engineering.label,
          PaperGroup.engineering,
        ),
        chip(
          Symbols.school_rounded,
          PaperGroup.academic.label,
          PaperGroup.academic,
        ),
        chip(
          Symbols.star_rounded,
          PaperGroup.special.label,
          PaperGroup.special,
        ),
      ],
    );
  }
}

/// The picture behind the top of the home screen: a pale sky and three
/// ranges of hills, drawn here so that it fits any width.
class HeroPainter extends CustomPainter {
  const HeroPainter({required this.dark, required this.accent});

  final bool dark;

  /// The app's accent: the sky and the hills are tints of it, so the
  /// picture always goes with the buttons in front of it.
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final paper = dark ? const Color(0xFF111216) : Colors.white;
    Color tint(double amount) => Color.lerp(paper, accent, amount)!;
    final sky = dark ? [tint(0.18), tint(0.30)] : [tint(0.07), tint(0.17)];
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
        ? [tint(0.42), tint(0.34), tint(0.26)]
        : [tint(0.22), tint(0.30), tint(0.38)];
    for (var i = 0; i < ranges.length; i++) {
      final base = size.height * (0.52 + i * 0.16);
      final rise = size.height * (0.3 - i * 0.06);
      final path = Path()..moveTo(size.width * 0.3, size.height);
      for (var x = size.width * 0.3; x <= size.width; x += 6) {
        final u = x / size.width;
        final crest =
            base -
            rise *
                (0.55 * math.sin(u * (7 + i * 3) + i * 1.7) +
                        0.45 * math.sin(u * (15 + i * 5) + i))
                    .abs();
        // The hills rise out of the bottom edge: nothing of them is left
        // under the text on the left.
        final fade = Curves.easeOut.transform(
          ((u - 0.3) / 0.45).clamp(0.0, 1.0),
        );
        path.lineTo(x, size.height + (crest - size.height) * fade);
      }
      path
        ..lineTo(size.width, size.height)
        ..close();
      canvas.drawPath(path, Paint()..color = ranges[i]);
    }
  }

  @override
  bool shouldRepaint(HeroPainter old) =>
      old.dark != dark || old.accent != accent;
}
