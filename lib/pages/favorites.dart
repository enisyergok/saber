import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:saber/data/defter_strings.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/routes.dart';
import 'package:saber/pages/editor/editor.dart';

/// The notes marked as favourites.
class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key, this.onOpen});

  final void Function(BuildContext context, String path)? onOpen;

  /// A favourite's path as stored (with extension) without the extension.
  static String withoutExtension(String path) {
    for (final extension in [Editor.extension, Editor.extensionOldJson]) {
      if (path.endsWith(extension)) {
        return path.substring(0, path.length - extension.length);
      }
    }
    return path;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(DefterStrings.favorites)),
      body: ListenableBuilder(
        listenable: stows.favoriteFiles,
        builder: (context, _) {
          final favorites = [
            for (final path in stows.favoriteFiles.value)
              withoutExtension(path),
          ];
          if (favorites.isEmpty) {
            return Center(child: Text(DefterStrings.noFavorites));
          }
          return ListView.builder(
            itemCount: favorites.length,
            itemBuilder: (context, i) {
              final path = favorites[i];
              final slash = path.lastIndexOf('/');
              final folder = path.substring(0, slash);
              return ListTile(
                leading: const Icon(Icons.star_rounded, color: Colors.amber),
                title: Text(path.substring(slash + 1)),
                subtitle: folder.isEmpty ? null : Text(folder),
                trailing: IconButton(
                  tooltip: DefterStrings.removeFromFavorites,
                  icon: const Icon(Symbols.star_rounded),
                  onPressed: () {
                    stows.favoriteFiles.value.remove(stows.favoriteFiles.value[i]);
                    stows.favoriteFiles.notifyListeners();
                  },
                ),
                onTap: () {
                  if (onOpen != null) {
                    onOpen!(context, path);
                  } else {
                    context.push(RoutePaths.editFilePath(path));
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}
