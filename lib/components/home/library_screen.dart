import 'package:flutter/material.dart';
import 'package:saber/components/home/library_glyph.dart';
import 'package:saber/components/home/library_navigation.dart';
import 'package:saber/components/home/library_sidebar.dart';
import 'package:saber/components/theming/defter_design.dart';
import 'package:saber/data/routes.dart';
import 'package:saber/components/home/library_shell.dart';

/// A persistent library rail and document header for secondary screens.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({
    super.key,
    required this.title,
    required this.child,
    this.destination,
    this.actions = const [],
    this.header,
    this.showHeader = true,
  });

  final String title;
  final Widget child;
  final LibraryDestination? destination;
  final List<Widget> actions;
  final Widget? header;
  final bool showHeader;

  static void navigate(BuildContext context, LibraryDestination destination) {
    switch (destination) {
      case LibraryDestination.home:
        LibraryNavigation.go(context, RoutePaths.dashboard);
      case LibraryDestination.documents:
        LibraryNavigation.go(context, HomeRoutes.browseFilePath('/'));
      case LibraryDestination.flashcards:
        LibraryNavigation.go(context, '/home/flashcards');
      case LibraryDestination.favorites:
        LibraryNavigation.go(context, '/home/favorites');
      case LibraryDestination.search:
        LibraryNavigation.go(context, '/home/search');
      case LibraryDestination.templates:
        LibraryNavigation.go(context, '/home/templates');
      case LibraryDestination.shared:
        LibraryNavigation.go(context, '/home/shared');
    }
  }

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  bool _sidebar = true;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: DefterDesign.libraryTheme(Theme.of(context)),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final shell = LibraryShellScope.maybeOf(context);
              final wide = shell?.wide ?? constraints.maxWidth >= 700;
              return Row(
                children: [
                  if (shell == null && wide && _sidebar) ...[
                    LibrarySidebar(
                      width: (constraints.maxWidth * .271).clamp(220.0, 300.0),
                      selected: widget.destination,
                      onHide: () => setState(() => _sidebar = false),
                      onSelected: (destination) {
                        if (destination != widget.destination)
                          LibraryScreen.navigate(context, destination);
                      },
                    ),
                    const VerticalDivider(
                      width: 1,
                      color: DefterDesign.gnDivider,
                    ),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!widget.showHeader && !(shell?.shown ?? _sidebar))
                          Align(
                            alignment: Alignment.centerLeft,
                            child: IconButton(
                              tooltip: 'Kenar çubuğunu göster',
                              onPressed:
                                  shell?.toggle ??
                                  () => setState(() => _sidebar = true),
                              icon: const LibraryGlyph(
                                Icons.space_dashboard_outlined,
                              ),
                            ),
                          ),
                        if (widget.showHeader)
                          SizedBox(
                            height: 64,
                            child: Row(
                              children: [
                                if (shell == null &&
                                    (!wide || Navigator.of(context).canPop()))
                                  BackButton(color: DefterDesign.gnBlue),
                                if (shell != null && !shell.shown ||
                                    shell == null && wide && !_sidebar)
                                  IconButton(
                                    tooltip: 'Kenar çubuğunu göster',
                                    onPressed:
                                        shell?.toggle ??
                                        () => setState(() => _sidebar = true),
                                    icon: const LibraryGlyph(
                                      Icons.space_dashboard_outlined,
                                    ),
                                  ),
                                const Spacer(),
                                ...widget.actions,
                                IconButton(
                                  tooltip: 'Ayarlar',
                                  onPressed: () => LibraryNavigation.go(
                                    context,
                                    HomeRoutes.routes[3].path,
                                  ),
                                  icon: const LibraryGlyph(
                                    Icons.settings_outlined,
                                    color: DefterDesign.gnBlue,
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                            ),
                          ),
                        if (widget.showHeader)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                            child: Text(
                              widget.title,
                              style: const TextStyle(
                                fontSize: 29,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -.7,
                              ),
                            ),
                          ),
                        if (widget.showHeader)
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 14),
                            child: Divider(
                              height: 1,
                              color: DefterDesign.gnDivider,
                            ),
                          ),
                        if (widget.header != null) widget.header!,
                        Expanded(child: widget.child),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
