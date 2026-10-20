import 'package:flutter/material.dart';

import 'catalog_icon.dart';

/// Recovered catalogue artwork; unmapped controls retain their platform icon.
class LibraryGlyph extends StatelessWidget {
  const LibraryGlyph(this.icon, {super.key, this.size = 23, this.color});
  final IconData icon;
  final double size;
  final Color? color;

  static final _assets = <IconData, String>{
    Icons.space_dashboard_outlined: 'sidebar.svg',
    Icons.home_outlined: 'home.svg',
    Icons.description_outlined: 'documents.svg',
    Icons.folder_outlined: 'documents.svg',
    Icons.folder: 'folder-orange.png',
    Icons.bookmark_border: 'bookmark.svg',
    Icons.search: 'search.svg',
    Icons.people_outline: 'users.svg',
    Icons.storefront_outlined: 'marketplace.svg',
    Icons.notifications_none: 'bell.svg',
    Icons.settings_outlined: 'settings.svg',
    Icons.check_circle: 'check-circle.svg',
    Icons.check_circle_outline: 'check-circle.svg',
    Icons.format_list_bulleted: 'list.svg',
    Icons.grid_view: 'grid.svg',
    Icons.star: 'star-active.svg',
    Icons.star_border: 'star.svg',
    Icons.keyboard_arrow_down: 'chevron-down.svg',
    Icons.chevron_left: 'chevron-left.svg',
    Icons.chevron_right: 'chevron-right.svg',
    Icons.add: 'plus.svg',
    Icons.file_download_outlined: 'download.svg',
  };

  @override
  Widget build(BuildContext context) {
    final asset = _assets[icon];
    if (asset == null) return Icon(icon, size: size, color: color);
    return CatalogIcon(
      asset,
      size: size,
      color: color,
      preserveColors:
          icon == Icons.description_outlined ||
          icon == Icons.folder_outlined ||
          icon == Icons.folder,
    );
  }
}
