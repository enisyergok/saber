import 'package:flutter/material.dart';
import 'package:saber/data/defter_strings.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/pages/editor/editor.dart';

/// Marks the selected notes as favourites, or unmarks them if they all are.
class FavoriteNoteButton extends StatelessWidget {
  const FavoriteNoteButton({
    super.key,
    required this.selectedFiles,
    required this.unselectNotes,
  });

  /// Paths without extension.
  final List<String> selectedFiles;
  final VoidCallback unselectNotes;

  /// Toggles [paths]: if all are favourites they are removed,
  /// otherwise the missing ones are added.
  static void toggle(Iterable<String> paths) {
    final favorites = stows.favoriteFiles.value;
    final withExtension = [for (final p in paths) p + Editor.extension];
    if (withExtension.every(favorites.contains)) {
      favorites.removeWhere(withExtension.contains);
    } else {
      for (final path in withExtension) {
        if (!favorites.contains(path)) favorites.add(path);
      }
    }
    stows.favoriteFiles.notifyListeners();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: stows.favoriteFiles,
      builder: (context, _) {
        final allFavorite =
            selectedFiles.isNotEmpty &&
            selectedFiles.every(
              (p) => stows.favoriteFiles.value.contains(p + Editor.extension),
            );
        return IconButton(
          padding: .zero,
          tooltip: allFavorite
              ? DefterStrings.removeFromFavorites
              : DefterStrings.addToFavorites,
          icon: Icon(allFavorite ? Icons.star : Icons.star_outline),
          onPressed: () {
            toggle(selectedFiles);
            unselectNotes();
          },
        );
      },
    );
  }
}
