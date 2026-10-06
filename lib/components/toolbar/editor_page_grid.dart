import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:saber/components/canvas/canvas_preview.dart';
import 'package:saber/data/defter_strings.dart';
import 'package:saber/data/editor/editor_core_info.dart';

/// A dialog showing every page of the notebook as a thumbnail,
/// for jumping between pages and managing bookmarks.
class EditorPageGrid extends StatefulWidget {
  const EditorPageGrid({
    super.key,
    required this.coreInfo,
    required this.currentPageIndex,
    required this.onPageSelected,
    required this.toggleBookmark,
    required this.openPageManager,
  });

  final EditorCoreInfo coreInfo;
  final int currentPageIndex;
  final ValueChanged<int> onPageSelected;

  /// Toggles the bookmark of a page. Null if the note is read-only.
  final ValueChanged<int>? toggleBookmark;

  /// Opens the list view where pages can be reordered, duplicated or deleted.
  final VoidCallback openPageManager;

  @override
  State<EditorPageGrid> createState() => _EditorPageGridState();
}

class _EditorPageGridState extends State<EditorPageGrid> {
  var _bookmarksOnly = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    final textTheme = TextTheme.of(context);
    final pages = widget.coreInfo.pages;
    final pageIndices = <int>[
      for (var i = 0; i < pages.length; i++)
        if (!_bookmarksOnly || pages[i].bookmarked) i,
    ];
    final toggleBookmark = widget.toggleBookmark;

    return Dialog(
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 920, maxHeight: 700),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      DefterStrings.pages,
                      style: textTheme.titleLarge,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SegmentedButton<bool>(
                    segments: [
                      ButtonSegment(
                        value: false,
                        label: Text(DefterStrings.allPages),
                      ),
                      ButtonSegment(
                        value: true,
                        icon: const Icon(Icons.bookmark_rounded),
                        label: Text(DefterStrings.bookmarks),
                      ),
                    ],
                    selected: {_bookmarksOnly},
                    showSelectedIcon: false,
                    onSelectionChanged: (selection) {
                      setState(() => _bookmarksOnly = selection.first);
                    },
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: DefterStrings.editPages,
                    icon: const Icon(Symbols.reorder_rounded),
                    onPressed: widget.openPageManager,
                  ),
                  IconButton(
                    tooltip: MaterialLocalizations.of(context).closeButtonLabel,
                    icon: const Icon(Symbols.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: pageIndices.isEmpty
                  ? Center(
                      child: Text(
                        DefterStrings.noBookmarks,
                        style: textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 170,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 16,
                            childAspectRatio: 0.6,
                          ),
                      itemCount: pageIndices.length,
                      itemBuilder: (context, index) {
                        final pageIndex = pageIndices[index];
                        return _PageTile(
                          coreInfo: widget.coreInfo,
                          pageIndex: pageIndex,
                          isCurrent: pageIndex == widget.currentPageIndex,
                          onTap: () => widget.onPageSelected(pageIndex),
                          toggleBookmark: toggleBookmark == null
                              ? null
                              : () => setState(() {
                                  toggleBookmark(pageIndex);
                                }),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageTile extends StatelessWidget {
  const _PageTile({
    required this.coreInfo,
    required this.pageIndex,
    required this.isCurrent,
    required this.onTap,
    required this.toggleBookmark,
  });

  final EditorCoreInfo coreInfo;
  final int pageIndex;
  final bool isCurrent;
  final VoidCallback onTap;
  final VoidCallback? toggleBookmark;

  static const _radius = BorderRadius.all(Radius.circular(6));

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    final page = coreInfo.pages[pageIndex];

    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.all(Radius.circular(10)),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: page.size.width / page.size.height,
                child: DecoratedBox(
                  position: DecorationPosition.foreground,
                  decoration: BoxDecoration(
                    borderRadius: _radius,
                    border: Border.all(
                      color: isCurrent
                          ? colorScheme.primary
                          : colorScheme.outlineVariant,
                      width: isCurrent ? 3 : 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: _radius,
                    child: FittedBox(
                      child: IgnorePointer(
                        child: CanvasPreview(
                          pageIndex: pageIndex,
                          height: null,
                          coreInfo: coreInfo,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 36,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${pageIndex + 1}',
                  style: TextStyle(
                    fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                    color: isCurrent ? colorScheme.primary : null,
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  iconSize: 18,
                  tooltip: DefterStrings.bookmark,
                  onPressed: toggleBookmark,
                  icon: Icon(
                    page.bookmarked ? Icons.bookmark_rounded : Symbols.bookmark_rounded,
                    color: page.bookmarked ? colorScheme.primary : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
