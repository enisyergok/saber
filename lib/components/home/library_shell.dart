import 'package:flutter/material.dart';
import 'package:saber/components/home/library_sidebar.dart';
import 'package:saber/components/home/library_screen.dart';
import 'package:saber/components/theming/defter_design.dart';

/// One navigation rail survives all changes between library sections.
class LibraryShell extends StatefulWidget {
  const LibraryShell({super.key, required this.selected, required this.child});
  final LibraryDestination? selected;
  final Widget child;

  @override
  State<LibraryShell> createState() => _LibraryShellState();
}

class _LibraryShellState extends State<LibraryShell> {
  bool _shown = true;

  @override
  Widget build(BuildContext context) => Theme(
    data: DefterDesign.libraryTheme(Theme.of(context)),
    child: Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 700;
            final shown = wide && _shown;
            void toggle() {
              if (wide) {
                setState(() => _shown = !_shown);
              } else {
                showModalBottomSheet<void>(
                  context: context,
                  builder: (sheetContext) => LibrarySidebar(
                    selected: widget.selected,
                    width: constraints.maxWidth,
                    onHide: () => Navigator.pop(sheetContext),
                    onSelected: (destination) {
                      Navigator.pop(sheetContext);
                      LibraryScreen.navigate(context, destination);
                    },
                  ),
                );
              }
            }

            return Row(
              children: [
                if (shown) ...[
                  LibrarySidebar(
                    width: (constraints.maxWidth * .271).clamp(220.0, 300.0),
                    selected: widget.selected,
                    onHide: toggle,
                    onSelected: (destination) =>
                        LibraryScreen.navigate(context, destination),
                  ),
                  const VerticalDivider(
                    width: 1,
                    color: DefterDesign.gnDivider,
                  ),
                ],
                Expanded(
                  child: LibraryShellScope(
                    wide: wide,
                    shown: shown,
                    toggle: toggle,
                    child: widget.child,
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

class LibraryShellScope extends InheritedWidget {
  const LibraryShellScope({
    super.key,
    required this.wide,
    required this.shown,
    required this.toggle,
    required super.child,
  });
  final bool wide, shown;
  final VoidCallback toggle;
  static LibraryShellScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LibraryShellScope>();
  @override
  bool updateShouldNotify(LibraryShellScope oldWidget) =>
      wide != oldWidget.wide || shown != oldWidget.shown;
}
