import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:saber/components/canvas/canvas_preview.dart';
import 'package:saber/components/editor/page_menu.dart';
import 'package:saber/data/editor/editor_core_info.dart';

/// A strip of page thumbnails beside the editor, for seeing where you are in
/// the notebook and jumping to another page. Shown on wide screens only.
class PageSidebar extends StatelessWidget {
  const PageSidebar({
    super.key,
    required this.coreInfo,
    required this.currentPage,
    required this.onPageSelected,
    this.onPageAction,
    this.canDeletePage,
  });

  /// Copies or deletes a page. Null if the note is read-only.
  final void Function(int pageIndex, PageAction action)? onPageAction;

  /// Whether the page at an index can be deleted (all can, if this is
  /// not given).
  final bool Function(int pageIndex)? canDeletePage;

  final EditorCoreInfo coreInfo;

  /// The index of the page that is on screen.
  final ValueListenable<int> currentPage;
  final ValueChanged<int> onPageSelected;

  /// How wide the sidebar is, including its edge line.
  static const width = 132.0;

  /// The sidebar is only shown on screens at least this wide, so the page
  /// itself keeps enough room.
  static const minScreenWidth = 840.0;

  static const _radius = BorderRadius.all(Radius.circular(6));

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    final pages = coreInfo.pages;

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(right: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: ValueListenableBuilder<int>(
        valueListenable: currentPage,
        builder: (context, current, _) {
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            itemCount: pages.length,
            itemBuilder: (context, index) {
              final page = pages[index];
              final isCurrent = index == current;
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: InkWell(
                  borderRadius: _radius,
                  onTap: () => onPageSelected(index),
                  child: Column(
                    children: [
                      AspectRatio(
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
                                  pageIndex: index,
                                  height: null,
                                  coreInfo: coreInfo,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isCurrent
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isCurrent ? colorScheme.primary : null,
                            ),
                          ),
                          if (page.bookmarked)
                            Padding(
                              padding: const EdgeInsets.only(left: 2),
                              child: Icon(
                                Icons.bookmark_rounded,
                                size: 14,
                                color: colorScheme.primary,
                              ),
                            ),
                          if (onPageAction != null)
                            SizedBox(
                              width: 32,
                              height: 24,
                              child: PageMenuButton(
                                pageIndex: index,
                                iconSize: 16,
                                canDelete: canDeletePage?.call(index) ?? true,
                                onAction: (action) =>
                                    onPageAction!(index, action),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
