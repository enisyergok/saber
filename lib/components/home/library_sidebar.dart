import 'package:flutter/material.dart';
import 'package:saber/components/home/library_glyph.dart';
import 'package:saber/components/theming/defter_design.dart';
import 'package:saber/data/defter_strings.dart';

enum LibraryDestination {
  home,
  documents,
  flashcards,
  favorites,
  search,
  shared,
  templates,
}

/// The same navigation geometry on every library destination.
class LibrarySidebar extends StatelessWidget {
  const LibrarySidebar({
    super.key,
    required this.selected,
    required this.onSelected,
    required this.width,
    required this.onHide,
  });

  final LibraryDestination? selected;
  final ValueChanged<LibraryDestination> onSelected;
  final double width;
  final VoidCallback onHide;

  @override
  Widget build(BuildContext context) {
    final entries = <(LibraryDestination, IconData, String)>[
      (LibraryDestination.home, Icons.home_outlined, DefterStrings.navHome),
      (LibraryDestination.documents, Icons.description_outlined, 'Belgeler'),
      (
        LibraryDestination.flashcards,
        Icons.style_outlined,
        DefterStrings.navFlashcards,
      ),
      (LibraryDestination.favorites, Icons.bookmark_border, 'Favoriler'),
      (LibraryDestination.search, Icons.search, 'Ara'),
      (LibraryDestination.shared, Icons.people_outline, 'Paylaşılanlar'),
      (LibraryDestination.templates, Icons.storefront_outlined, 'Şablonlar'),
    ];
    return SizedBox(
      width: width,
      child: ColoredBox(
        color: DefterDesign.gnLibraryRail,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 0, 0),
                child: IconButton(
                  tooltip: 'Kenar çubuğunu gizle',
                  onPressed: onHide,
                  icon: const LibraryGlyph(
                    Icons.space_dashboard_outlined,
                    color: DefterDesign.gnBlue,
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 10, 14, 5),
              child: Text(
                'Noteva',
                style: TextStyle(
                  fontSize: 29,
                  fontWeight: FontWeight.w400,
                  letterSpacing: -1,
                  color: DefterDesign.gnText,
                ),
              ),
            ),
            for (final (destination, icon, label) in entries)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Material(
                  color: selected == destination
                      ? DefterDesign.gnSelectedSurface
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  child: ListTile(
                    key: ValueKey('library-nav-$label'),
                    minTileHeight: 41,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 9),
                    horizontalTitleGap: 10,
                    leading: LibraryGlyph(
                      icon,
                      size: 22,
                      color: DefterDesign.gnText,
                    ),
                    title: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 16,
                        color: DefterDesign.gnText,
                      ),
                    ),
                    onTap: () => onSelected(destination),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
