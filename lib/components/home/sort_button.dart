import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/i18n/strings.g.dart';
import 'package:stow_codecs/stow_codecs.dart';

class const BrowseSortButton({super.key}) extends HookWidget {
  void _openDialog(BuildContext context) async {
    final selection = await showDialog<SortMetric>(
      context: context,
      builder: (context) => _SortDialog(selected: stows.browseSortMetric.value),
    );
    if (selection == null) return;
    stows.browseSortMetric.value = selection;
  }

  @override
  Widget build(BuildContext context) {
    final sortMetric = useValueListenable(stows.browseSortMetric);
    return IconButton(
      padding: const .all(4),
      constraints: const BoxConstraints(
        minWidth: kMinInteractiveDimension,
        minHeight: kMinInteractiveDimension,
      ),
      onPressed: () => _openDialog(context),
      icon: sortMetric.icon,
    );
  }
}

class _SortDialog extends StatelessWidget {
  const new({required this.selected});

  final SortMetric selected;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      alignment: .topEnd,
      insetPadding: const .all(8),
      title: Text(t.home.sort.sortBy),
      content: Column(
        mainAxisSize: .min,
        children: [
          for (final option in SortMetric.values)
            _SortDialogOption(sortMetric: option, selected: option == selected),
        ],
      ),
    );
  }
}

class _SortDialogOption extends StatelessWidget {
  const new({required this.sortMetric, required this.selected});

  final SortMetric sortMetric;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () {
        context.pop(sortMetric);
      },
      leading: sortMetric.icon,
      title: Text(switch (sortMetric) {
        .nameAToZ => t.home.sort.nameAToZ,
        .nameZToA => t.home.sort.nameZToA,
        .lastModifiedNewToOld => t.home.sort.lastModifiedNewToOld,
        .lastModifiedOldToNew => t.home.sort.lastModifiedOldToNew,
      }),
      trailing: selected ? const Icon(Symbols.check_rounded) : null,
      selected: selected,
      selectedTileColor: Colors.transparent,
    );
  }
}

enum SortMetric {
  nameAToZ,
  nameZToA,
  lastModifiedNewToOld,
  lastModifiedOldToNew;

  static const codec = EnumCodec(values);

  Widget get icon => switch (this) {
    .nameAToZ => const _NameOrderIcon(Symbols.arrow_downward_alt_rounded),
    .nameZToA => const _NameOrderIcon(Symbols.arrow_upward_alt_rounded),
    .lastModifiedNewToOld => const Icon(Symbols.clock_arrow_down_rounded),
    .lastModifiedOldToNew => const Icon(Symbols.clock_arrow_up_rounded),
  };
}

/// "By name" with the direction next to it, in the manner of the clock
/// with an arrow that stands for "by date".
class _NameOrderIcon extends StatelessWidget {
  const new(this.arrow);

  final IconData arrow;

  @override
  Widget build(BuildContext context) {
    final size = IconTheme.of(context).size ?? 24;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: -size * 0.12,
            top: size * 0.08,
            child: Icon(Symbols.match_case_rounded, size: size * 0.84),
          ),
          Positioned(
            right: -size * 0.24,
            top: size * 0.14,
            child: Icon(arrow, size: size * 0.72),
          ),
        ],
      ),
    );
  }
}
