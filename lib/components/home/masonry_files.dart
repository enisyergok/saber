import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:saber/components/home/notebook_cover.dart';
import 'package:saber/components/home/preview_card.dart';
import 'package:saber/data/extensions/change_notifier_extensions.dart';

/// The library grid: a uniform grid of notebook covers.
class MasonryFiles extends StatefulWidget {
  const new({
    super.key,
    required this.files,
    required this.selectedFiles,
    this.leading,
  });

  final List<String> files;
  final ValueNotifier<List<String>> selectedFiles;

  /// An optional tile shown before the first file, e.g. a "new" tile.
  final Widget? leading;

  /// Covers are laid out in as many columns as fit at about this width.
  static const targetCoverWidth = 180.0;

  @override
  State<MasonryFiles> createState() => _MasonryFilesState();
}

class _MasonryFilesState extends State<MasonryFiles> {
  final ValueNotifier<bool> isAnythingSelected = ValueNotifier(false);

  void toggleSelection(String filePath, bool selected) {
    if (selected) {
      widget.selectedFiles.value.add(filePath);
    } else {
      widget.selectedFiles.value.remove(filePath);
    }
    isAnythingSelected.value = widget.selectedFiles.value.isNotEmpty;
    widget.selectedFiles.notifyListenersPlease();
  }

  Widget itemBuilder(BuildContext context, int index) {
    if (index >= widget.files.length) {
      return const SizedBox.shrink();
    }

    final file = widget.files[index];
    return ValueListenableBuilder(
      valueListenable: isAnythingSelected,
      builder: (context, isAnythingSelected, _) {
        return PreviewCard(
          filePath: file,
          toggleSelection: toggleSelection,
          selected: widget.selectedFiles.value.contains(file),
          isAnythingSelected: isAnythingSelected,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    isAnythingSelected.value = widget.selectedFiles.value.isNotEmpty;

    const crossAxisSpacing = 20.0;
    final leadingCount = widget.leading == null ? 0 : 1;

    return SliverPadding(
      padding: const .symmetric(horizontal: 24, vertical: 8),
      sliver: SliverLayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.crossAxisExtent;
          final columns = math.max(
            2,
            (width / MasonryFiles.targetCoverWidth).floor(),
          );
          final cellWidth =
              (width - crossAxisSpacing * (columns - 1)) / columns;

          return SliverGrid.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: 12,
              crossAxisSpacing: crossAxisSpacing,
              mainAxisExtent:
                  cellWidth / kNotebookCoverAspectRatio +
                  kNotebookCaptionHeight,
            ),
            itemCount: widget.files.length + leadingCount,
            itemBuilder: (context, index) {
              if (index < leadingCount) return widget.leading!;
              return itemBuilder(context, index - leadingCount);
            },
          );
        },
      ),
    );
  }
}
