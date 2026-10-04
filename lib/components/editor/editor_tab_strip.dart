import 'package:flutter/material.dart';

/// The row of open notebooks shown under the editor's app bar.
class EditorTabStrip extends StatelessWidget implements PreferredSizeWidget {
  const EditorTabStrip({
    super.key,
    required this.paths,
    required this.currentPath,
    required this.onSelect,
    required this.onClose,
  });

  /// Note paths without the file extension, in tab order.
  final List<String> paths;
  final String? currentPath;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onClose;

  static const height = 40.0;

  @override
  Size get preferredSize => const Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: paths.length,
        separatorBuilder: (_, _) => const SizedBox(width: 4),
        itemBuilder: (context, index) {
          final path = paths[index];
          final selected = path == currentPath;
          final name = path.substring(path.lastIndexOf('/') + 1);
          final foreground = selected
              ? colorScheme.onSecondaryContainer
              : colorScheme.onSurfaceVariant;
          return Material(
            color: selected
                ? colorScheme.secondaryContainer
                : colorScheme.onSurface.withValues(alpha: 0.05),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(10),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: selected ? null : () => onSelect(path),
              child: Padding(
                padding: const EdgeInsetsDirectional.only(start: 14, end: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 190),
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: foreground,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                    IconButton(
                      iconSize: 16,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: 30,
                        height: 30,
                      ),
                      color: foreground,
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).closeButtonTooltip,
                      onPressed: () => onClose(path),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
