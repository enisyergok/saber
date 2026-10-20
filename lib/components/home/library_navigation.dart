import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Library pages can be opened over a router page with Navigator.push.
/// Remove those overlays explicitly, including when the URL is unchanged.
abstract final class LibraryNavigation {
  static void go(BuildContext context, String location) {
    final router = GoRouter.of(context);
    Navigator.of(context)
        .popUntil((route) => route.settings is Page || route.isFirst);
    router.go(location);
  }

  /// Preserve the router-owned page beneath the library destination.
  static void open(BuildContext context, Widget page) {
    final navigator = Navigator.of(context);
    navigator.popUntil((route) => route.settings is Page || route.isFirst);
    navigator.push<void>(MaterialPageRoute<void>(builder: (_) => page));
  }
}
