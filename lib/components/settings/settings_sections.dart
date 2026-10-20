import 'package:flutter/material.dart';
import 'package:saber/components/settings/settings_subtitle.dart';
import 'package:saber/components/theming/defter_design.dart';

/// A category/detail settings screen on tablets, grouped sections on phones.
class SettingsSections extends StatefulWidget {
  const SettingsSections({
    super.key,
    required this.title,
    required this.children,
    this.actions = const [],
  });
  final String title;
  final List<Widget> children;
  final List<Widget> actions;
  @override
  State<SettingsSections> createState() => _SettingsSectionsState();
}

class _SettingsSectionsState extends State<SettingsSections> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final colors = ColorScheme.of(context);
    final headings = <String>[];
    final groups = <List<Widget>>[];
    final account = <Widget>[];
    for (final child in widget.children) {
      if (child is SettingsSubtitle) {
        headings.add(child.subtitle);
        groups.add([]);
      } else if (groups.isEmpty) {
        account.add(child);
      } else {
        groups.last.add(child);
      }
    }
    Widget group(int index) => Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Material(
        color: colors.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                headings[index],
                style: TextTheme.of(context).titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            for (var i = 0; i < groups[index].length; i++) ...[
              if (i > 0) const Divider(indent: 56, height: 1),
              groups[index][i],
            ],
          ],
        ),
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        return Material(
          color: colors.surface,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 22, 28, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 29,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.7,
                        ),
                      ),
                    ),
                    ...widget.actions,
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (wide)
                      SizedBox(
                        width: 236,
                        child: Material(
                          color: colors.brightness == Brightness.light
                              ? DefterDesign.gnLibraryRail
                              : colors.surfaceContainerLow,
                          child: ListView(
                            padding: const EdgeInsets.all(12),
                            children: [
                              for (var i = 0; i < headings.length; i++)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: ListTile(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    title: Text(
                                      headings[i],
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    trailing: const Icon(
                                      Icons.chevron_right,
                                      size: 18,
                                    ),
                                    selected: _selected == i,
                                    selectedTileColor: const Color(0xffe2ecf8),
                                    selectedColor: const Color(0xff4485bf),
                                    onTap: () => setState(() => _selected = i),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    Expanded(
                      child: ListView(
                        key: ValueKey(wide ? _selected : -1),
                        padding: EdgeInsets.all(wide ? 28 : 16),
                        children: [
                          ...account,
                          const SizedBox(height: 16),
                          if (wide && groups.isNotEmpty)
                            group(_selected.clamp(0, groups.length - 1))
                          else
                            for (var i = 0; i < groups.length; i++) group(i),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
