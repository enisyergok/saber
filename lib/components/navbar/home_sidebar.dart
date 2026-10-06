import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:saber/components/theming/marj_mark.dart';
import 'package:saber/data/defter_strings.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/notebooks/paper_templates.dart';
import 'package:saber/data/routes.dart';
import 'package:saber/pages/favorites.dart';
import 'package:saber/pages/home/home.dart';
import 'package:saber/pages/home/new_notebook_wizard.dart';
import 'package:saber/pages/home/template_gallery.dart';
import 'package:saber/pages/trash.dart';

/// The sidebar of the home screen on a tablet: where the notes are, the
/// folders, and a way to make a new folder.
class HomeSidebar extends StatefulWidget {
  const HomeSidebar({
    super.key,
    required this.subpage,
    required this.path,
    required this.go,
    this.loadFolders = HomeSidebar.rootFolders,
  });

  /// The part of the home screen that is open (see [HomePage]).
  final String subpage;

  /// The folder that is open, when [subpage] is the notes.
  final String? path;

  /// Goes to a route of the home screen.
  final void Function(String route) go;

  /// Lists the folders at the top, and those inside each.
  final Future<Map<String, List<String>>> Function() loadFolders;

  static const width = 236.0;

  /// The folders to show instead of what [loadFolders] finds (real
  /// directory listings never complete inside a widget test).
  @visibleForTesting
  static Map<String, List<String>>? overrideFolders;

  /// The top folders ("Dersler") with the folders inside each.
  static Future<Map<String, List<String>>> rootFolders() async {
    final root = await FileManager.getChildrenOfDirectory('/');
    final result = <String, List<String>>{};
    for (final folder in root?.directories ?? const <String>[]) {
      final inside = await FileManager.getChildrenOfDirectory('/$folder');
      result[folder] = inside?.directories ?? const [];
    }
    return result;
  }

  @override
  State<HomeSidebar> createState() => _HomeSidebarState();
}

class _HomeSidebarState extends State<HomeSidebar> {
  Map<String, List<String>> _folders = const {};
  final _open = <String>{};
  var _foldersShown = true;
  StreamSubscription<FileOperation>? _writes;

  @override
  void initState() {
    super.initState();
    _load();
    _writes = FileManager.fileWriteStream.stream.listen((_) {
      // Notes saved while the editor is open don't change the folders.
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
      final folders = HomeSidebar.overrideFolders ?? await widget.loadFolders();
      if (mounted) setState(() => _folders = folders);
    } on Object catch (e) {
      // Keep what was shown: the next change to the notes tries again.
      debugPrint('The folders could not be listed: $e');
    }
  }

  void _push(Widget page) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => page));

  Future<void> _newFolder() async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => NewFolderNameDialog(existing: _folders.keys.toSet()),
    );
    if (name == null) return;
    await FileManager.createFolder('/$name');
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final colors = ColorScheme.of(context);
    final browsing = widget.subpage == HomePage.browseSubpage;

    Widget item(
      IconData icon,
      String label, {
      required bool selected,
      required VoidCallback onTap,
    }) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: Material(
        color: selected
            ? colors.primary.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: selected ? colors.primary : colors.onSurface,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: selected ? FontWeight.w700 : null,
                      color: selected ? colors.primary : colors.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    Widget folder(String path, String name, {required bool nested}) {
      final inside = nested ? const <String>[] : _folders[name] ?? const [];
      final selected = browsing && widget.path == path;
      return Padding(
        padding: EdgeInsets.only(left: nested ? 30 : 8, right: 8),
        child: Material(
          color: selected
              ? colors.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => widget.go(HomeRoutes.browseFilePath(path)),
            child: Padding(
              padding: const EdgeInsets.only(left: 10, top: 5, bottom: 5),
              child: Row(
                children: [
                  Icon(Icons.folder_rounded, size: 18, color: folderColour(path)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: selected ? FontWeight.w700 : null,
                      ),
                    ),
                  ),
                  if (inside.isNotEmpty)
                    InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => setState(() {
                        if (!_open.remove(name)) _open.add(name);
                      }),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          _open.contains(name)
                              ? Symbols.expand_less_rounded
                              : Symbols.expand_more_rounded,
                          size: 18,
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 26),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Material(
      color: colors.surfaceContainerLow,
      child: SafeArea(
        right: false,
        child: SizedBox(
          width: HomeSidebar.width,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 12, 12),
                child: Row(
                  children: [
                    const MarjMark(size: 26),
                    const SizedBox(width: 10),
                    Text(
                      DefterStrings.appName,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              item(
                Symbols.home_rounded,
                DefterStrings.navHome,
                selected: widget.subpage == HomePage.dashboardSubpage,
                onTap: () => widget.go(RoutePaths.dashboard),
              ),
              item(
                Symbols.description_rounded,
                DefterStrings.navNotes,
                selected: browsing && (widget.path == null || widget.path!.isEmpty),
                onTap: () => widget.go(HomeRoutes.browseFilePath('/')),
              ),
              item(
                Symbols.calendar_month_rounded,
                DefterStrings.navPlanners,
                selected: false,
                onTap: () =>
                    _push(const TemplateGalleryPage(group: PaperGroup.planner)),
              ),
              item(
                Symbols.dashboard_customize_rounded,
                DefterStrings.navTemplates,
                selected: false,
                onTap: () => _push(const TemplateGalleryPage()),
              ),
              item(
                Symbols.star_rounded,
                DefterStrings.navFavorites,
                selected: false,
                onTap: () => _push(const FavoritesPage()),
              ),
              item(
                Symbols.schedule_rounded,
                DefterStrings.navRecent,
                selected: widget.subpage == HomePage.recentSubpage,
                onTap: () => widget.go(HomeRoutes.routes[1].path),
              ),
              item(
                Symbols.draw_rounded,
                DefterStrings.navWhiteboard,
                selected: widget.subpage == HomePage.whiteboardSubpage,
                onTap: () => widget.go(HomeRoutes.routes[2].path),
              ),
              item(
                Symbols.delete_rounded,
                DefterStrings.navTrash,
                selected: false,
                onTap: () => _push(const TrashPage()),
              ),
              item(
                Symbols.settings_rounded,
                DefterStrings.navSettings,
                selected: widget.subpage == HomePage.settingsSubpage,
                onTap: () => widget.go(HomeRoutes.routes[3].path),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Divider(height: 1),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 8, 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        DefterStrings.folders,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      tooltip: DefterStrings.folders,
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        _foldersShown ? Symbols.expand_less_rounded : Symbols.expand_more_rounded,
                        size: 20,
                      ),
                      onPressed: () =>
                          setState(() => _foldersShown = !_foldersShown),
                    ),
                  ],
                ),
              ),
              if (_foldersShown)
                for (final name in _folders.keys) ...[
                  folder('/$name', name, nested: false),
                  if (_open.contains(name))
                    for (final child in _folders[name]!)
                      folder('/$name/$child', child, nested: true),
                ],
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _newFolder,
                    icon: const Icon(Symbols.add_rounded, size: 18),
                    label: Text(DefterStrings.newFolder),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Asks for the name of a new folder; returns it trimmed, or null.
class NewFolderNameDialog extends StatefulWidget {
  const NewFolderNameDialog({super.key, required this.existing});

  /// The folders there already are next to it: a name can't be used twice.
  final Set<String> existing;

  /// Why [name] can't be a folder next to [existing]; null if it can.
  static String? validate(String name, Set<String> existing) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return DefterStrings.folderNameEmpty;
    if (trimmed.contains('/') || trimmed.contains(r'\')) {
      return DefterStrings.folderNameSlash;
    }
    if (existing.contains(trimmed)) return DefterStrings.folderNameExists;
    return null;
  }

  @override
  State<NewFolderNameDialog> createState() => _NewFolderNameDialogState();
}

class _NewFolderNameDialogState extends State<NewFolderNameDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final error = NewFolderNameDialog.validate(
      _controller.text,
      widget.existing,
    );
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(DefterStrings.newFolder),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: DefterStrings.folderName,
          errorText: _error,
          border: const OutlineInputBorder(),
        ),
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(DefterStrings.cancelWord),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(DefterStrings.stepCreate),
        ),
      ],
    );
  }
}
