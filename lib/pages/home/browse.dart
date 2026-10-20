import 'dart:async';

import 'package:collapsible/collapsible.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:path/path.dart' as p;
import 'package:saber/components/home/delete_note_button.dart';
import 'package:saber/components/home/library_header.dart';
import 'package:saber/components/home/library_screen.dart';
import 'package:saber/components/home/library_sidebar.dart';
import 'package:saber/components/home/noteva_library.dart';
import 'package:saber/components/home/favorite_note_button.dart';
import 'package:saber/data/defter_strings.dart';
import 'package:saber/pages/ask_notes.dart';
import 'package:saber/pages/favorites.dart';
import 'package:saber/pages/home/new_notebook_wizard.dart';
import 'package:saber/pages/home/template_gallery.dart';
import 'package:saber/pages/search.dart';
import 'package:saber/components/home/export_note_button.dart';
import 'package:saber/components/home/grid_folders.dart';
import 'package:saber/components/home/masonry_files.dart';
import 'package:saber/components/home/move_note_button.dart';
import 'package:saber/components/home/new_note_button.dart';
import 'package:saber/components/home/new_notebook_dialog.dart';
import 'package:saber/components/navbar/home_sidebar.dart';
import 'package:saber/components/home/notebook_cover.dart';
import 'package:saber/components/home/path_components.dart';
import 'package:saber/components/home/rename_note_button.dart';
import 'package:saber/components/home/sort_button.dart';
import 'package:saber/components/home/syncing_button.dart';
import 'package:saber/components/theming/saber_theme.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/routes.dart';
import 'package:saber/i18n/strings.g.dart';

class BrowsePage extends StatefulHookWidget {
  const new({super.key, String? path}) : initialPath = path;

  final String? initialPath;

  @visibleForTesting
  static DirectoryChildren? overrideChildren;

  @override
  State<BrowsePage> createState() => _BrowsePageState();
}

class _BrowsePageState extends State<BrowsePage> {
  DirectoryChildren? children;
  int _listingRequest = 0;

  String? path;

  final ValueNotifier<List<String>> selectedFiles = ValueNotifier([]);

  @override
  void initState() {
    path = widget.initialPath;

    findChildrenOfPath();
    fileWriteSubscription = FileManager.fileWriteStream.stream.listen(
      fileWriteListener,
    );
    selectedFiles.addListener(_setState);

    super.initState();
  }

  @override
  void didUpdateWidget(BrowsePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Another folder was chosen from outside (the sidebar).
    if (widget.initialPath != oldWidget.initialPath &&
        widget.initialPath != path) {
      selectedFiles.value = [];
      path = widget.initialPath;
      findChildrenOfPath();
    }
  }

  @override
  void dispose() {
    selectedFiles.removeListener(_setState);
    fileWriteSubscription?.cancel();
    super.dispose();
  }

  StreamSubscription? fileWriteSubscription;
  void fileWriteListener(FileOperation event) {
    if (!event.filePath.startsWith(path ?? '/')) return;
    findChildrenOfPath(fromFileListener: true);
  }

  void _setState() => setState(() {});

  Future findChildrenOfPath({bool fromFileListener = false}) async {
    if (!mounted) return;

    if (fromFileListener) {
      // don't refresh if we're not on the home page
      final location = GoRouterState.of(context).uri.toString();
      if (!location.startsWith(RoutePaths.prefixOfHome)) return;
    }

    final request = ++_listingRequest;
    final requestedPath = path;
    final result =
        BrowsePage.overrideChildren ??
        await FileManager.getChildrenOfDirectory(
          path ?? '/',
          sortMetric: stows.browseSortMetric.value,
        );

    if (!mounted || request != _listingRequest || requestedPath != path) return;
    setState(() => children = result);
  }

  void onDirectoryTap(String folder) {
    selectedFiles.value = [];
    if (folder == '..') {
      path = p.dirname(path ?? '/');
      if (path == '/') path = null;
    } else {
      path = p.join(path ?? '/', folder);
    }
    context.go(HomeRoutes.browseFilePath(path ?? '/'));
    findChildrenOfPath();
  }

  void onPathComponentTap(String? newPath) {
    selectedFiles.value = [];
    if (newPath == null || newPath.isEmpty || newPath == '/') {
      newPath = null;
    }
    path = newPath;
    // Remove the previous folder's cards immediately. Otherwise they can be
    // tapped again while the new directory listing is still loading.
    setState(() => children = null);
    context.go(HomeRoutes.browseFilePath(path ?? '/'));
    findChildrenOfPath();
  }

  Future<void> createNote() async {
    if (stows.homeDashboard.value) {
      return NotebookCreator.start(context, folder: path);
    }
    final name = await NewNotebookDialog.show(context);
    if (name == null || !mounted) return;

    final folder = '${path ?? ''}/';
    final newFilePath = name.isEmpty
        ? await FileManager.newFilePath(folder)
        : await FileManager.suffixFilePathToMakeItUnique('$folder$name');
    if (!mounted) return;
    context.push(RoutePaths.editFilePath(newFilePath));
  }

  Future<void> createFolder(String folderName) async {
    final folderPath = '${path ?? ''}/$folderName';
    await FileManager.createFolder(folderPath);
    findChildrenOfPath();
  }

  Future<void> createFolderFromLibrary() async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => NewFolderNameDialog(
        existing: (children?.directories ?? const <String>[]).toSet(),
      ),
    );
    if (name != null) await createFolder(name);
  }

  void openLibraryDocument(LibraryDocument document) {
    if (document.folder) {
      onPathComponentTap(document.id);
    } else {
      context.push(RoutePaths.editFilePath(document.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    useOnListenableChange(stows.browseSortMetric, findChildrenOfPath);
    final currentPath = path ?? '/';
    final documents = [
      for (final folder in children?.directories ?? const <String>[])
        LibraryDocument(
          id: p.join(currentPath, folder),
          title: folder,
          subtitle: 'Klasör',
          folder: true,
        ),
      for (final file in children?.files ?? const <String>[])
        LibraryDocument(
          id: p.join(currentPath, file),
          title: p.basenameWithoutExtension(file),
          subtitle: 'Not',
        ),
    ];

    return NotevaLibrary(
      folderPath: currentPath,
      onParentFolder: () => onPathComponentTap(p.posix.dirname(currentPath)),
      loading: children == null,
      documents: documents,
      onOpen: openLibraryDocument,
      onCreate: createNote,
      onFavorite: (document) {
        FavoriteNoteButton.toggle([document.id]);
        findChildrenOfPath();
      },
      onSearch: () => Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => const SearchPage())),
      onFavorites: () => Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => const FavoritesPage())),
      onTemplates: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const TemplateGalleryPage()),
      ),
      onSettings: () => context.go(HomeRoutes.routes[3].path),
      onFlashcards: () =>
          LibraryScreen.navigate(context, LibraryDestination.flashcards),
      onImport: () {},
      onImportPdf: () {},
      onAddImage: () {},
      onNewFolder: createFolderFromLibrary,
      onHome: () => context.go(RoutePaths.dashboard),
      onNotes: () => onPathComponentTap(null),
      notesMode: true,
      onTemplateGroup: (group) => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => TemplateGalleryPage(group: group),
        ),
      ),
    );
  }

  Widget buildLegacy(BuildContext context) {
    final platform = Theme.of(context).platform;
    const crossAxisCount = 2;
    useOnListenableChange(stows.browseSortMetric, findChildrenOfPath);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: LibraryHeader(
              title: path == null || path == '/'
                  ? DefterStrings.navNotes
                  : p.basename(path!),
              onSearch: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SearchPage()),
              ),
              actions: [
                IconButton(
                  tooltip: DefterStrings.askNotes,
                  icon: const Icon(Icons.auto_awesome_rounded),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const AskNotesPage(),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: DefterStrings.favorites,
                  icon: const Icon(Symbols.star_rounded),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const FavoritesPage(),
                    ),
                  ),
                ),
                const SyncingButton(),
              ],
              bottom: Row(
                children: [
                  FilledButton.icon(
                    onPressed: createNote,
                    icon: const Icon(Symbols.add_rounded),
                    label: Text(DefterStrings.actionNewNote),
                  ),
                  const Spacer(),
                  const BrowseSortButton(),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: Divider(height: 1)),
          SliverToBoxAdapter(
            child: PathComponents(path, onPathComponentTap: onPathComponentTap),
          ),
          const SliverPadding(padding: .only(bottom: 16)),
          GridFolders(
            isAtRoot: path == null || path!.isEmpty || path == '/',
            parentPath: path ?? '',
            crossAxisCount: crossAxisCount,
            onTap: onDirectoryTap,
            createFolder: createFolder,
            doesFolderExist: (String folderName) {
              return children?.directories.contains(folderName) ?? false;
            },
            renameFolder: (String oldName, String newName) async {
              final oldPath = '${path ?? ''}/$oldName';
              await FileManager.renameDirectory(oldPath, newName);
              findChildrenOfPath();
            },
            isFolderEmpty: (String folderName) async {
              final folderPath = '${path ?? ''}/$folderName';
              final children = await FileManager.getChildrenOfDirectory(
                folderPath,
              );
              return children?.isEmpty ?? true;
            },
            deleteFolder: (String folderName) async {
              final folderPath = '${path ?? ''}/$folderName';
              await FileManager.moveDirectoryToTrash(folderPath);
              findChildrenOfPath();
            },
            folders: [
              for (final directoryPath in children?.directories ?? const [])
                directoryPath,
            ],
          ),
          if (children == null) ...[
            // loading
          ] else ...[
            SliverSafeArea(
              top: false,
              minimum: const .only(
                top: 8,
                // Allow space for the FloatingActionButton
                bottom: 70,
              ),
              sliver: MasonryFiles(
                leading: NewNotebookTile(
                  label: t.home.create.newNote,
                  onTap: createNote,
                ),
                files: [
                  for (final filePath in children?.files ?? const [])
                    "${path ?? ""}/$filePath",
                ],
                selectedFiles: selectedFiles,
              ),
            ),
          ],
        ],
      ),
      floatingActionButton: NewNoteButton(
        cupertino: platform.isCupertino,
        path: path,
      ),
      persistentFooterButtons: selectedFiles.value.isEmpty
          ? null
          : [
              Collapsible(
                axis: CollapsibleAxis.vertical,
                collapsed: selectedFiles.value.length != 1,
                child: RenameNoteButton(
                  existingPath: selectedFiles.value.isEmpty
                      ? ''
                      : selectedFiles.value.first,
                  unselectNotes: () => selectedFiles.value = [],
                ),
              ),
              MoveNoteButton(
                filesToMove: selectedFiles.value,
                unselectNotes: () => selectedFiles.value = [],
              ),
              FavoriteNoteButton(
                selectedFiles: selectedFiles.value,
                unselectNotes: () => selectedFiles.value = [],
              ),
              DeleteNoteButton(
                filesToDelete: selectedFiles.value,
                unselectNotes: () => selectedFiles.value = [],
              ),
              ExportNoteButton(selectedFiles: selectedFiles.value),
            ],
    );
  }
}
