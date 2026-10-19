import 'package:flutter/material.dart';
import 'package:saber/data/defter_strings.dart';

/// Shared library hierarchy on both phones and tablets.
class LibraryHeader extends StatelessWidget {
  const LibraryHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onSearch,
    this.actions = const [],
    this.bottom,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onSearch;
  final List<Widget> actions;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final colors = ColorScheme.of(context);
    return Material(
      color: colors.surface,
      child: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontal = constraints.maxWidth >= 700 ? 32.0 : 20.0;
            return Padding(
              padding: EdgeInsets.fromLTRB(horizontal, 20, horizontal, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextTheme.of(context).headlineMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.8,
                          ),
                        ),
                      ),
                      if (actions.isNotEmpty)
                        IconButtonTheme(
                          data: IconButtonThemeData(
                            style: IconButton.styleFrom(
                              foregroundColor: colors.onSurface,
                              backgroundColor: colors.surfaceContainerLow,
                              shape: const CircleBorder(),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: actions,
                          ),
                        ),
                    ],
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      subtitle!,
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                  ],
                  if (onSearch != null) ...[
                    const SizedBox(height: 18),
                    InkWell(
                      onTap: onSearch,
                      borderRadius: BorderRadius.circular(14),
                      child: Ink(
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: colors.outlineVariant),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.search,
                              size: 21,
                              color: colors.onSurfaceVariant,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                DefterStrings.searchNotes,
                                style: TextStyle(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (bottom != null) ...[const SizedBox(height: 16), bottom!],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
