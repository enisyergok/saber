import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:path_to_regexp/path_to_regexp.dart';
import 'package:saber/components/theming/adaptive_icon.dart';
import 'package:saber/i18n/strings.g.dart';
import 'package:saber/pages/home/home.dart';

// workaround to assign strings as enum values
abstract class RoutePaths {
  static const home = '$prefixOfHome/:subpage';
  static const edit = '/edit';
  static const login = '/login';
  static const logs = '/logs';

  static const prefixOfHome = '/home';

  static String editFilePath(String filePath) {
    return '$edit?path=${Uri.encodeQueryComponent(filePath)}';
  }

  static String editImportPdf(String filePath, String pdfPath) {
    return '$edit'
        '?path=${Uri.encodeQueryComponent(filePath)}'
        '&pdfPath=${Uri.encodeQueryComponent(pdfPath)}';
  }

  /// A new note at [filePath] that starts with the picture at [imagePath].
  static String editWithImage(String filePath, String imagePath) {
    return '$edit'
        '?path=${Uri.encodeQueryComponent(filePath)}'
        '&imagePath=${Uri.encodeQueryComponent(imagePath)}';
  }

  /// The home screen with the sidebar: recent notes, folders, templates.
  static final dashboard = '$prefixOfHome/${HomePage.dashboardSubpage}';
}

abstract class HomeRoutes {
  static String browseFilePath(String? filePath) {
    var path = routes[0].path;
    if (filePath != '/' && filePath != '' && filePath != null) {
      path += '?path=${Uri.encodeQueryComponent(filePath)}';
    }
    return path;
  }

  static final PathFunction _homeFunction = pathToFunction(RoutePaths.home);

  static List<HomeRoute> get routes => <HomeRoute>[
    HomeRoute._(
      _homeFunction({'subpage': HomePage.browseSubpage}),
      destination: NavigationDestination(
        label: t.home.tabs.browse,
        icon: const AdaptiveIcon(
          icon: Symbols.auto_stories_rounded,
          cupertinoIcon: CupertinoIcons.book_fill,
        ),
      ),
    ),
    HomeRoute._(
      _homeFunction({'subpage': HomePage.recentSubpage}),
      destination: NavigationDestination(
        label: t.home.tabs.home,
        icon: const AdaptiveIcon(
          icon: Symbols.schedule_rounded,
          cupertinoIcon: CupertinoIcons.clock_fill,
        ),
      ),
    ),
    HomeRoute._(
      _homeFunction({'subpage': HomePage.whiteboardSubpage}),
      destination: NavigationDestination(
        label: t.home.tabs.whiteboard,
        icon: const AdaptiveIcon(
          icon: Symbols.draw_rounded,
          cupertinoIcon: CupertinoIcons.pencil_outline,
        ),
      ),
    ),
    HomeRoute._(
      _homeFunction({'subpage': HomePage.settingsSubpage}),
      destination: NavigationDestination(
        label: t.home.tabs.settings,
        icon: const AdaptiveIcon(
          icon: Symbols.settings_rounded,
          cupertinoIcon: CupertinoIcons.settings_solid,
        ),
      ),
    ),
  ];
}

class const HomeRoute._(
  final String path, {
  required final NavigationDestination destination,
});
