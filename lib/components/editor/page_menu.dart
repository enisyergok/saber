import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:saber/data/defter_strings.dart';

/// What can be done with a whole page of the notebook.
enum PageAction { duplicate, delete }

/// The small "..." under a page's thumbnail: copy the page, or delete it.
class PageMenuButton extends StatelessWidget {
  const PageMenuButton({
    super.key,
    required this.pageIndex,
    required this.onAction,
    this.canDelete = true,
    this.iconSize = 18,
  });

  final int pageIndex;
  final void Function(PageAction action) onAction;

  /// False for the one page a notebook cannot be without: its only page,
  /// while there is nothing on it.
  final bool canDelete;
  final double iconSize;

  static Key keyFor(int pageIndex) => ValueKey('pageMenu-$pageIndex');
  static const duplicateKey = ValueKey('pageDuplicate');
  static const deleteKey = ValueKey('pageDelete');

  @override
  Widget build(BuildContext context) {
    final colors = ColorScheme.of(context);
    return PopupMenuButton<PageAction>(
      key: keyFor(pageIndex),
      tooltip: DefterStrings.pageActions,
      padding: EdgeInsets.zero,
      iconSize: iconSize,
      constraints: const BoxConstraints(minWidth: 200),
      icon: const Icon(Symbols.more_horiz_rounded),
      onSelected: onAction,
      itemBuilder: (context) => [
        PopupMenuItem(
          key: duplicateKey,
          value: PageAction.duplicate,
          child: Row(
            children: [
              const Icon(Symbols.content_copy_rounded, size: 20),
              const SizedBox(width: 12),
              Text(DefterStrings.duplicatePage),
            ],
          ),
        ),
        PopupMenuItem(
          key: deleteKey,
          value: PageAction.delete,
          enabled: canDelete,
          child: Row(
            children: [
              Icon(
                Symbols.delete_rounded,
                size: 20,
                color: canDelete ? colors.error : null,
              ),
              const SizedBox(width: 12),
              Text(
                DefterStrings.deletePage,
                style: canDelete ? TextStyle(color: colors.error) : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
