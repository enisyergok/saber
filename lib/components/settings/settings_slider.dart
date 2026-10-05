import 'package:flutter/material.dart';
import 'package:saber/components/theming/uni_icon.dart';
import 'package:saber/pages/home/settings.dart';
import 'package:stow/stow.dart';

/// A setting from 0 to 1 in ten steps, shown as a slider under its title.
/// Long-press resets it, like the other settings.
class SettingsSlider extends StatefulWidget {
  const new({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.pref,
  });

  final String title;
  final String? subtitle;
  final Object icon;
  final Stow<dynamic, double, dynamic> pref;

  @override
  State<SettingsSlider> createState() => _SettingsSliderState();
}

class _SettingsSliderState extends State<SettingsSlider> {
  @override
  void initState() {
    widget.pref.addListener(_onChanged);
    super.initState();
  }

  @override
  void dispose() {
    widget.pref.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.pref.value.clamp(0.0, 1.0);
    return ListTile(
      onLongPress: () => SettingsPage.showResetDialog(
        context: context,
        pref: widget.pref,
        prefTitle: widget.title,
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      leading: UniIcon(widget.icon),
      title: Text(
        widget.title,
        style: TextStyle(
          fontSize: 18,
          fontStyle: value != widget.pref.defaultValue
              ? FontStyle.italic
              : null,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.subtitle != null) Text(widget.subtitle!),
          Slider(
            value: value,
            divisions: 10,
            label: '${(value * 100).round()}%',
            onChanged: (v) => widget.pref.value = v,
          ),
        ],
      ),
    );
  }
}
