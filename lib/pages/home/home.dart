import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:saber/components/home/sentry_consent_dialog.dart';
import 'package:saber/components/navbar/home_sidebar.dart';
import 'package:saber/components/navbar/responsive_navbar.dart';
import 'package:saber/components/settings/update_manager.dart';
import 'package:saber/components/theming/dynamic_material_app.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/pages/home/browse.dart';
import 'package:saber/pages/home/dashboard.dart';
import 'package:saber/pages/home/recent_notes.dart';
import 'package:saber/pages/home/settings.dart';
import 'package:saber/pages/home/whiteboard.dart';

class HomePage extends StatefulWidget {
  const new({super.key, required this.subpage, required this.path});

  final String subpage;
  final String? path;

  @override
  State<HomePage> createState() => _HomePageState();

  static const recentSubpage = 'recent';
  static const browseSubpage = 'browse';
  static const whiteboardSubpage = 'whiteboard';
  static const settingsSubpage = 'settings';

  /// The home screen proper (see [DashboardPage]). It is not one of the
  /// tabs of the classic navigation bar.
  static const dashboardSubpage = 'dashboard';
  static const List<String> subpages = [
    browseSubpage,
    recentSubpage,
    whiteboardSubpage,
    settingsSubpage,
  ];
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    DynamicMaterialApp.addFullscreenListener(_setState);
    stows.homeDashboard.addListener(_setState);
    super.initState();
    _showDialogs();
  }

  void _showDialogs() async {
    await null; // initState must be completed before using context
    if (!mounted) return;
    UpdateManager.showUpdateDialog(context);
    SentryConsentDialog.showIfNeeded(context);
  }

  void _setState() {
    if (mounted) setState(() {});
  }

  /// Whether the home screen with the sidebar is in use: it is switched
  /// on, and the screen is wide enough for a sidebar.
  bool get _showsDashboard =>
      stows.homeDashboard.value &&
      switch (stows.layoutSize.value) {
        .auto => MediaQuery.sizeOf(context).width >= 600,
        .phone => false,
        .tablet => true,
      };

  Widget get body {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: KeyedSubtree(
        key: ValueKey(widget.subpage),
        child: switch (widget.subpage) {
          HomePage.browseSubpage => BrowsePage(path: widget.path),
          HomePage.whiteboardSubpage => const Whiteboard(),
          HomePage.settingsSubpage => const SettingsPage(),
          HomePage.recentSubpage => const RecentPage(),
          // On a phone there is no room for it: the notes are the home.
          HomePage.dashboardSubpage =>
            _showsDashboard
                ? const DashboardPage()
                : BrowsePage(path: widget.path),
          _ => BrowsePage(path: widget.path),
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // hide navbar in fullscreen whiteboard
    if (widget.subpage == HomePage.whiteboardSubpage &&
        DynamicMaterialApp.isFullscreen) {
      return body;
    }

    final index = HomePage.subpages.indexOf(widget.subpage);
    return ResponsiveNavbar(
      // the home screen is not a tab: the notes are marked for it
      selectedIndex: index < 0 ? 0 : index,
      sidebarBuilder: _showsDashboard
          ? (go) =>
                HomeSidebar(subpage: widget.subpage, path: widget.path, go: go)
          : null,
      body: body,
    );
  }

  @override
  void dispose() {
    DynamicMaterialApp.removeFullscreenListener(_setState);
    stows.homeDashboard.removeListener(_setState);

    super.dispose();
  }
}
