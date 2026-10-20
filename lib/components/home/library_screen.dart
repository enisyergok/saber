import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:saber/components/home/library_glyph.dart';
import 'package:saber/components/home/library_sidebar.dart';
import 'package:saber/components/theming/defter_design.dart';
import 'package:saber/data/routes.dart';
import 'package:saber/pages/favorites.dart';
import 'package:saber/pages/home/flashcards.dart';
import 'package:saber/pages/home/template_gallery.dart';
import 'package:saber/pages/search.dart';

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
        context.go(RoutePaths.dashboard);
      case LibraryDestination.documents:
        context.go(HomeRoutes.browseFilePath('/'));
      case LibraryDestination.flashcards:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const FlashcardsPage()),
        );
      case LibraryDestination.favorites:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const FavoritesPage()),
        );
      case LibraryDestination.search:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const SearchPage()),
        );
      case LibraryDestination.templates:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const TemplateGalleryPage()),
        );
      case LibraryDestination.shared:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => const LibraryScreen(
              title: 'Paylaşılanlar',
              destination: LibraryDestination.shared,
              child: Center(
                child: Text('Paylaşılan belge hizmeti henüz bağlı değil.'),
              ),
            ),
          ),
        );
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
              final wide = constraints.maxWidth >= 700;
              return Row(
                children: [
                  if (wide && _sidebar) ...[
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
                        if (!widget.showHeader && !_sidebar)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: IconButton(
                              tooltip: 'Kenar çubuğunu göster',
                              onPressed: () => setState(() => _sidebar = true),
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
                                if (!wide || Navigator.of(context).canPop())
                                  BackButton(color: DefterDesign.gnBlue),
                                if (wide && !_sidebar)
                                  IconButton(
                                    tooltip: 'Kenar çubuğunu göster',
                                    onPressed: () =>
                                        setState(() => _sidebar = true),
                                    icon: const LibraryGlyph(
                                      Icons.space_dashboard_outlined,
                                    ),
                                  ),
                                const Spacer(),
                                ...widget.actions,
                                IconButton(
                                  tooltip: 'Ayarlar',
                                  onPressed: () =>
                                      context.go(HomeRoutes.routes[3].path),
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
