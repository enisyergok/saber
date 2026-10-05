import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:perfect_freehand/perfect_freehand.dart';
import 'package:saber/components/editor_gn/gn_pen_profiles.dart';
import 'package:saber/components/settings/stylus_test_dialog.dart';
import 'package:saber/components/theming/uni_icon.dart';
import 'package:saber/data/defter_strings.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/tools/_tool.dart';
import 'package:saber/data/tools/highlighter.dart';
import 'package:saber/data/tools/pen.dart';
import 'package:saber/data/tools/pen_assist.dart';
import 'package:saber/data/tools/pen_feel.dart';
import 'package:saber/data/tools/pen_styles.dart';
import 'package:saber/data/tools/pressure_curve.dart';
import 'package:saber/data/tools/stylus_action.dart';
import 'package:stow/stow.dart';

/// The pen settings panel: the six pens, a live preview of the line, the
/// basic settings, the pressure curve, colours, the technical drawing
/// helpers and the pen profiles.
///
/// Nothing here is for show: every control changes how the pen really
/// draws (the preview uses the same code as the page).
class GnPenSettings extends StatefulWidget {
  const GnPenSettings({
    super.key,
    required this.getTool,
    required this.setTool,
    this.setColor,
    this.onClose,
    this.openColorPicker,
    this.toggleGrid,
    this.gridOn = false,
    this.maxHeight = 640,
  });

  final Tool Function() getTool;
  final void Function(Pen) setTool;

  /// Sets the colour of the pen in use.
  final ValueChanged<Color>? setColor;
  final VoidCallback? onClose;

  /// Opens the full colour picker.
  final VoidCallback? openColorPicker;

  /// Switches the page's squared paper on and off.
  final VoidCallback? toggleGrid;
  final bool gridOn;

  /// The most room the panel may take from top to bottom.
  final double maxHeight;

  /// The width of the settings and of the list of profiles next to it.
  static const width = 560.0;
  static const profilesWidth = 250.0;
  static const gap = 10.0;

  /// The colours offered in the panel; the first row, then the rest.
  static const colors = <Color>[
    Color(0xFF111827),
    Color(0xFF9CA3AF),
    Color(0xFF6B7280),
    Color(0xFF2563EB),
    Color(0xFFDC2626),
    Color(0xFFF97316),
    Color(0xFFFBBF24),
    Color(0xFF84CC16),
    Color(0xFF14B8A6),
    Color(0xFFC4B5FD),
    Color(0xFFF9A8D4),
  ];
  static const moreColors = <Color>[
    Color(0xFF7C2D12),
    Color(0xFF1E3A8A),
    Color(0xFF166534),
    Color(0xFF7E22CE),
    Color(0xFF0891B2),
    Color(0xFFBE185D),
    Color(0xFF854D0E),
    Color(0xFF475569),
    Color(0xFF000000),
    Color(0xFFFFFFFF),
    Color(0xFFFDE047),
  ];

  @override
  State<GnPenSettings> createState() => _GnPenSettingsState();
}

class _GnPenSettingsState extends State<GnPenSettings> {
  var _moreColors = false;
  late List<PenProfile> _profiles = PenProfiles.load();

  @override
  void initState() {
    super.initState();
    PenFeel.curve = PressureCurve.parse(stows.pressureCurve.value);
  }

  void _save() {
    // Pen options are changed in place, so listeners are told by hand.
    stows.lastFountainPenOptions.notifyListeners();
    stows.lastBallpointPenOptions.notifyListeners();
    stows.lastBrushPenOptions.notifyListeners();
    stows.lastCalligraphyPenOptions.notifyListeners();
    stows.lastHighlighterOptions.notifyListeners();
    stows.lastPencilOptions.notifyListeners();
  }

  /// Switches to the pen of [style], keeping the colour in use where the
  /// pens share one (the marker has its own).
  Pen _switchTo(PenStyle style, Pen from) {
    final pen = PenStyles.create(style);
    if (style != PenStyle.marker && from is! Highlighter) {
      pen.color = PenStyles.hasOpacity(style)
          ? from.color
          : from.color.withValues(alpha: 1);
    }
    widget.setTool(pen);
    return pen;
  }

  void _setColor(Pen pen, Color color) {
    if (widget.setColor != null) {
      widget.setColor!(color);
    } else if (pen is Highlighter) {
      pen.color = color.withAlpha(Highlighter.alpha);
    } else {
      pen.color = color;
    }
  }

  void _resetPen(Pen pen, PenStyle style) {
    PenStyles.defaults(style).applyTo(pen);
    if (PenStyles.hasOpacity(style)) _setColor(pen, pen.color);
    PenFeel.curve = PressureCurve.standard;
    stows.pressureCurve.value = '';
    _save();
  }

  void _applyProfile(PenProfile profile, Pen from) {
    final pen = _switchTo(profile.style, from);
    profile.applyTo(pen);
    if (PenStyles.hasOpacity(profile.style)) _setColor(pen, pen.color);
    _save();
  }

  void _storeProfiles() => PenProfiles.save(_profiles);

  Future<String?> _askName(String initial) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(DefterStrings.profileName),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 24,
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(DefterStrings.cancelWord),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: Text(DefterStrings.save),
          ),
        ],
      ),
    );
  }

  Future<void> _addProfile(Pen pen) async {
    final name = (await _askName(DefterStrings.myProfile))?.trim();
    if (name == null || name.isEmpty || !mounted) return;
    setState(() {
      _profiles.add(
        PenProfile.capture(
          pen,
          id: PenProfiles.newId(_profiles),
          name: name,
          subtitle: DefterStrings.customProfileHint,
        ),
      );
      _storeProfiles();
    });
  }

  Future<void> _renameProfile(PenProfile profile) async {
    final name = (await _askName(profile.name))?.trim();
    if (name == null || name.isEmpty || !mounted) return;
    setState(() {
      profile.name = name;
      _storeProfiles();
    });
  }

  void _updateProfile(PenProfile profile, Pen pen) => setState(() {
    final index = _profiles.indexOf(profile);
    if (index < 0) return;
    _profiles[index] = PenProfile.capture(
      pen,
      id: profile.id,
      name: profile.name,
      subtitle: profile.subtitle,
    );
    _storeProfiles();
  });

  void _deleteProfile(PenProfile profile) => setState(() {
    _profiles.remove(profile);
    _storeProfiles();
  });

  @override
  Widget build(BuildContext context) {
    final tool = widget.getTool();
    if (tool is! Pen) return const SizedBox.shrink();
    final style = PenStyles.of(tool);
    final screen = MediaQuery.sizeOf(context).width;
    final wide =
        screen >=
        GnPenSettings.width + GnPenSettings.profilesWidth + GnPenSettings.gap + 24;
    final mainWidth = math.min(GnPenSettings.width, screen - 24);

    final profiles = GnPenProfiles(
      profiles: _profiles,
      current: tool,
      onApply: (profile) => setState(() => _applyProfile(profile, tool)),
      onAdd: () => _addProfile(tool),
      onUpdate: (profile) => _updateProfile(profile, tool),
      onRename: _renameProfile,
      onDelete: _deleteProfile,
    );

    final main = _card(
      context,
      width: mainWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(context, tool, style),
          const SizedBox(height: 4),
          _styles(context, tool, style),
          const SizedBox(height: 8),
          _preview(context, tool),
          const SizedBox(height: 6),
          _basics(context, tool, style),
          if (style != null && PenStyles.hasCurve(style)) ...[
            const SizedBox(height: 8),
            _curve(context, tool),
          ],
          const SizedBox(height: 8),
          _colors(context, tool),
          const SizedBox(height: 10),
          _tools(context),
          const SizedBox(height: 10),
          _behaviours(context),
          if (!wide) ...[
            const SizedBox(height: 14),
            profiles,
          ],
        ],
      ),
    );

    if (!wide) return main;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        main,
        const SizedBox(width: GnPenSettings.gap),
        _card(context, width: GnPenSettings.profilesWidth, child: profiles),
      ],
    );
  }

  Widget _card(
    BuildContext context, {
    required double width,
    required Widget child,
  }) {
    return Material(
      color: ColorScheme.of(context).surfaceContainerHigh,
      elevation: 8,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: widget.maxHeight),
        child: SizedBox(
          width: width,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
            child: child,
          ),
        ),
      ),
    );
  }

  TextStyle? _sectionStyle(BuildContext context) => Theme.of(
    context,
  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600);

  // -- header ---------------------------------------------------------------

  Widget _header(BuildContext context, Pen tool, PenStyle? style) {
    return Row(
      children: [
        Expanded(
          child: Text(
            DefterStrings.penSettingsTitle,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        PopupMenuButton<int>(
          tooltip: '',
          icon: const Icon(Icons.more_horiz),
          onSelected: (value) {
            switch (value) {
              case 0:
                if (style != null) setState(() => _resetPen(tool, style));
              case 1:
                setState(() {
                  PenProfiles.restore();
                  _profiles = PenProfiles.load();
                });
              case 2:
                showDialog<void>(
                  context: context,
                  builder: (_) => const StylusTestDialog(),
                );
            }
          },
          itemBuilder: (context) => [
            if (style != null)
              PopupMenuItem(value: 0, child: Text(DefterStrings.resetPen)),
            PopupMenuItem(value: 1, child: Text(DefterStrings.profilesRestore)),
            PopupMenuItem(value: 2, child: Text(DefterStrings.stylusTest)),
          ],
        ),
        if (widget.onClose != null)
          IconButton(
            tooltip: DefterStrings.close,
            icon: const Icon(Icons.close),
            onPressed: widget.onClose,
          ),
      ],
    );
  }

  // -- the six pens ---------------------------------------------------------

  Widget _styles(BuildContext context, Pen tool, PenStyle? current) {
    final colors = ColorScheme.of(context);
    return Row(
      children: [
        for (final style in PenStyle.values)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Material(
                color: style == current
                    ? colors.primary.withValues(alpha: 0.14)
                    : colors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: style == current
                        ? colors.primary
                        : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => setState(() => _switchTo(style, tool)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 2,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        UniIcon(
                          PenStyles.icon(style),
                          size: 20,
                          color: style == current
                              ? colors.primary
                              : colors.onSurface,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          PenStyles.name(style),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: style == current
                                ? FontWeight.w600
                                : null,
                            color: colors.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // -- preview --------------------------------------------------------------

  Widget _preview(BuildContext context, Pen tool) {
    final colors = ColorScheme.of(context);
    return ValueListenableBuilder<bool>(
      valueListenable: stows.penPreviewCollapsed,
      builder: (context, collapsed, _) => Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.only(left: 14, right: 4),
        height: collapsed ? 38 : 60,
        child: Row(
          children: [
            Expanded(
              child: collapsed
                  ? Text(
                      DefterStrings.preview,
                      style: Theme.of(context).textTheme.bodySmall,
                    )
                  : CustomPaint(
                      size: Size.infinite,
                      painter: PenPreviewPainter(
                        options: tool.strokeOptions,
                        color: tool.color,
                        pressure: tool.pressureEnabled,
                        nib: tool.kind == PenKind.calligraphy,
                      ),
                    ),
            ),
            IconButton(
              tooltip: DefterStrings.preview,
              icon: Icon(collapsed ? Icons.expand_more : Icons.expand_less),
              onPressed: () => stows.penPreviewCollapsed.value = !collapsed,
            ),
          ],
        ),
      ),
    );
  }

  // -- basic settings -------------------------------------------------------

  static String _percent(double value) => '${(value * 100).round()}%';

  static String _mm(double size) =>
      '${PenAssist.toMm(size).toStringAsFixed(2).replaceAll('.', ',')} mm';

  Widget _basics(BuildContext context, Pen tool, PenStyle? style) {
    final options = tool.options;
    final sizeSteps = ((tool.sizeMax - tool.sizeMin) * 4).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                DefterStrings.basicSettings,
                style: _sectionStyle(context),
              ),
            ),
            if (style != null)
              TextButton(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => setState(() => _resetPen(tool, style)),
                child: Text(DefterStrings.reset),
              ),
          ],
        ),
        _slider(
          context,
          icon: Icons.edit,
          label: DefterStrings.thickness,
          valueText: _mm(options.size),
          value: options.size.clamp(tool.sizeMin, tool.sizeMax),
          min: tool.sizeMin,
          max: tool.sizeMax,
          divisions: sizeSteps,
          onChanged: (v) => setState(() => options.size = v),
        ),
        if (style != null && PenStyles.hasOpacity(style))
          _slider(
            context,
            icon: Icons.opacity,
            label: DefterStrings.opacityLabel,
            valueText: _percent(tool.color.a),
            value: tool.color.a.clamp(0.1, 1),
            min: 0.1,
            max: 1,
            divisions: 18,
            onChanged: (v) => setState(
              () => _setColor(tool, tool.color.withValues(alpha: v)),
            ),
          ),
        if (style != null && PenStyles.hasSharpness(style))
          _slider(
            context,
            icon: Icons.change_history,
            label: DefterStrings.tipSharpnessLabel,
            valueText: _percent(tool.tipSharpness),
            value: tool.tipSharpness.clamp(0, 1),
            min: 0,
            max: 1,
            divisions: 4,
            onChanged: (v) => setState(() => tool.tipSharpness = v),
          ),
        if (tool.pressureEnabled &&
            (style == null || PenStyles.hasPressure(style)))
          _slider(
            context,
            icon: Icons.compress,
            label: DefterStrings.pressureSensitivityLabel,
            valueText: _percent(options.thinning),
            value: options.thinning.clamp(0, 1),
            min: 0,
            max: 1,
            divisions: 20,
            onChanged: (v) => setState(() => options.thinning = v),
          ),
        _slider(
          context,
          icon: Icons.gesture,
          label: DefterStrings.lineStabilizationLabel,
          valueText: _percent(options.streamline),
          value: options.streamline.clamp(0, 1),
          min: 0,
          max: 1,
          divisions: 20,
          onChanged: (v) => setState(() => options.streamline = v),
        ),
      ],
    );
  }

  Widget _slider(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String valueText,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    final colors = ColorScheme.of(context);
    return SizedBox(
      height: 32,
      child: Row(
        children: [
          Icon(icon, size: 18, color: colors.onSurface),
          const SizedBox(width: 12),
          SizedBox(
            width: 132,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                overlayShape: SliderComponentShape.noOverlay,
                tickMarkShape: SliderTickMarkShape.noTickMark,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              ),
              child: Slider(
                value: value,
                min: min,
                max: max,
                divisions: divisions,
                onChanged: onChanged,
                onChangeEnd: (_) => _save(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 78,
            height: 25,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              valueText,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  // -- pressure curve -------------------------------------------------------

  Widget _curve(BuildContext context, Pen tool) {
    final colors = ColorScheme.of(context);
    Widget sample(String label, double raw) => Expanded(
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: CustomPaint(
              size: Size.infinite,
              painter: PenSamplePainter(
                options: tool.strokeOptions,
                color: colors.onSurface,
                rawPressure: raw,
                curve: PenFeel.curve,
              ),
            ),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(DefterStrings.pressureCurve, style: _sectionStyle(context)),
        const SizedBox(height: 6),
        SizedBox(
          height: 94,
          child: Row(
            children: [
              Expanded(
                flex: 5,
                child: PressureCurveEditor(
                  curve: PenFeel.curve,
                  onChanged: (curve) => setState(() => PenFeel.curve = curve),
                  onChangeEnd: () =>
                      stows.pressureCurve.value = PenFeel.curve.encode(),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 6,
                child: Column(
                  children: [
                    sample(DefterStrings.pressureLight, 0.15),
                    sample(DefterStrings.pressureMedium, 0.4),
                    sample(DefterStrings.pressureFirm, 0.9),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // -- colours --------------------------------------------------------------

  Widget _colors(BuildContext context, Pen tool) {
    final colors = ColorScheme.of(context);
    final current = tool.color.withValues(alpha: 1).toARGB32();
    Widget dot(Color color) {
      final selected = color.toARGB32() == current;
      return Padding(
        padding: const EdgeInsets.all(3),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => setState(() {
            // Keep a see-through setting when picking another colour.
            final alpha = tool is Highlighter ? 1.0 : tool.color.a;
            _setColor(tool, alpha >= 1 ? color : color.withValues(alpha: alpha));
          }),
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? colors.primary : colors.outlineVariant,
                width: selected ? 3 : 1,
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(DefterStrings.colorAndStyle, style: _sectionStyle(context)),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Wrap(
                        children: [
                          for (final color in GnPenSettings.colors) dot(color),
                          if (_moreColors)
                            for (final color in GnPenSettings.moreColors)
                              dot(color),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: DefterStrings.moreColors,
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        _moreColors ? Icons.expand_less : Icons.expand_more,
                      ),
                      onPressed: () =>
                          setState(() => _moreColors = !_moreColors),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (widget.openColorPicker != null) ...[
          const SizedBox(width: 8),
          Material(
            color: colors.surface,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: widget.openColorPicker,
              child: Tooltip(
                message: DefterStrings.colorPicker,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 19,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: SweepGradient(
                            colors: [
                              Color(0xFFEF4444),
                              Color(0xFFF59E0B),
                              Color(0xFF22C55E),
                              Color(0xFF06B6D4),
                              Color(0xFF3B82F6),
                              Color(0xFFA855F7),
                              Color(0xFFEF4444),
                            ],
                          ),
                        ),
                        child: Center(
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: tool.color.withValues(alpha: 1),
                              shape: BoxShape.circle,
                              border: Border.all(color: colors.surface, width: 2),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.expand_more, size: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // -- technical tools ------------------------------------------------------

  Widget _tools(BuildContext context) {
    final tiles = <Widget>[
      _prefTile(
        context,
        pref: stows.autoStraightenLines,
        icon: const Icon(Icons.horizontal_rule),
        title: DefterStrings.toolStraightLine,
        hint: DefterStrings.toolStraightLineHint,
      ),
      _prefTile(
        context,
        pref: stows.autoShapes,
        icon: const Icon(Icons.category_outlined),
        title: DefterStrings.toolShapes,
        hint: DefterStrings.toolShapesHint,
      ),
      _prefTile(
        context,
        pref: stows.angleGuide,
        icon: const Icon(Icons.square_foot),
        title: DefterStrings.toolAngle,
        hint: DefterStrings.toolAngleHint,
      ),
      _prefTile(
        context,
        pref: stows.rulerMode,
        icon: const Icon(Icons.straighten),
        title: DefterStrings.toolRuler,
      ),
      _tile(
        context,
        on: widget.gridOn,
        onTap: widget.toggleGrid,
        icon: const Icon(Icons.grid_on),
        title: DefterStrings.toolGrid,
      ),
      _prefTile(
        context,
        pref: stows.measureMode,
        icon: const RotatedBox(quarterTurns: 1, child: Icon(Icons.height)),
        title: DefterStrings.toolMeasure,
        onChanged: (on) {
          if (!on) PenAssist.showReadout(null);
        },
      ),
      _prefTile(
        context,
        pref: stows.dimensionMode,
        icon: const Icon(Icons.sync_alt),
        title: DefterStrings.toolDimension,
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(DefterStrings.engineeringTools, style: _sectionStyle(context)),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final perRow = constraints.maxWidth >= 500 ? tiles.length : 4;
            const spacing = 6.0;
            final tileWidth =
                (constraints.maxWidth - spacing * (perRow - 1)) / perRow;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (final tile in tiles)
                  SizedBox(width: tileWidth.floorToDouble(), child: tile),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _prefTile(
    BuildContext context, {
    required Stow<dynamic, bool, dynamic> pref,
    required Widget icon,
    required String title,
    String? hint,
    ValueChanged<bool>? onChanged,
  }) {
    return ValueListenableBuilder<bool>(
      valueListenable: pref,
      builder: (context, on, _) => _tile(
        context,
        on: on,
        onTap: () {
          pref.value = !on;
          onChanged?.call(!on);
        },
        icon: icon,
        title: title,
        hint: hint,
      ),
    );
  }

  Widget _tile(
    BuildContext context, {
    required bool on,
    required VoidCallback? onTap,
    required Widget icon,
    required String title,
    String? hint,
  }) {
    final colors = ColorScheme.of(context);
    final foreground = onTap == null
        ? colors.onSurface.withValues(alpha: 0.38)
        : on
        ? colors.primary
        : colors.onSurface;
    return Semantics(
      button: true,
      toggled: on,
      child: Material(
        color: on ? colors.primary.withValues(alpha: 0.14) : colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: on ? colors.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 60,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconTheme.merge(
                    data: IconThemeData(size: 22, color: foreground),
                    child: icon,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: on ? FontWeight.w600 : null,
                      color: foreground,
                    ),
                  ),
                  if (hint != null)
                    Text(
                      hint,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 8.5,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // -- advanced behaviours --------------------------------------------------

  Widget _behaviours(BuildContext context) {
    Widget toggle(
      Stow<dynamic, bool, dynamic> pref,
      IconData icon,
      String label,
    ) {
      return ValueListenableBuilder<bool>(
        valueListenable: pref,
        builder: (context, on, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 6),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            SizedBox(
              height: 30,
              child: FittedBox(
                child: Switch(value: on, onChanged: (v) => pref.value = v),
              ),
            ),
          ],
        ),
      );
    }

    final gestures = Material(
      color: ColorScheme.of(context).surface,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showDialog<void>(
          context: context,
          builder: (context) => const PenGesturesDialog(),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                DefterStrings.penGestures,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right, size: 18),
            ],
          ),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                DefterStrings.advancedBehaviours,
                style: _sectionStyle(context),
              ),
            ),
            gestures,
          ],
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 10,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            toggle(
              stows.shapeHoldToSnap,
              Icons.touch_app_outlined,
              DefterStrings.drawAndHold,
            ),
            toggle(
              stows.shapeAutoCorrect,
              Icons.auto_fix_high,
              DefterStrings.shapeAutoCorrect,
            ),
            toggle(
              stows.shapeSnapEndpoints,
              Icons.join_inner,
              DefterStrings.joinShapes,
            ),
          ],
        ),
      ],
    );
  }
}

/// What the pen's double tap (or side button) does.
class PenGesturesDialog extends StatelessWidget {
  const PenGesturesDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final names = {
      StylusAction.none: DefterStrings.stylusNone,
      StylusAction.toggleEraser: DefterStrings.stylusToggleEraser,
      StylusAction.previousTool: DefterStrings.stylusPreviousTool,
      StylusAction.lasso: DefterStrings.stylusLasso,
      StylusAction.highlighter: DefterStrings.stylusHighlighter,
      StylusAction.undo: DefterStrings.stylusUndo,
      StylusAction.redo: DefterStrings.stylusRedo,
    };
    return ValueListenableBuilder<int>(
      valueListenable: stows.stylusAction,
      builder: (context, current, _) => SimpleDialog(
        title: Text(DefterStrings.stylusAction),
        children: [
          for (final action in StylusAction.values)
            ListTile(
              title: Text(names[action]!),
              trailing: action.index == current
                  ? Icon(Icons.check, color: ColorScheme.of(context).primary)
                  : null,
              onTap: () => stows.stylusAction.value = action.index,
            ),
        ],
      ),
    );
  }
}

/// The pressure curve as a graph whose four points can be dragged up and
/// down: pressure runs from left to right, thickness from bottom to top.
class PressureCurveEditor extends StatefulWidget {
  const PressureCurveEditor({
    super.key,
    required this.curve,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final PressureCurve curve;
  final ValueChanged<PressureCurve> onChanged;
  final VoidCallback onChangeEnd;

  static const padding = 10.0;

  /// Where point [index] of [curve] is drawn in a graph of [size].
  static Offset pointAt(PressureCurve curve, int index, Size size) {
    final width = size.width - 2 * padding;
    final height = size.height - 2 * padding;
    return Offset(
      padding + PressureCurve.xs[index] * width,
      padding + (1 - curve.y(index)) * height,
    );
  }

  /// [curve] after its point nearest [position] (sideways) is dragged to
  /// the height of [position] in a graph of [size].
  static PressureCurve dragged(
    PressureCurve curve,
    Offset position,
    Size size, {
    int? index,
  }) {
    final width = size.width - 2 * padding;
    final height = size.height - 2 * padding;
    final point =
        index ??
        (((position.dx - padding) / width) * 4).round().clamp(1, 4);
    final value = 1 - (position.dy - padding) / height;
    return curve.withPoint(point, value.clamp(0.0, 1.0));
  }

  @override
  State<PressureCurveEditor> createState() => _PressureCurveEditorState();
}

class _PressureCurveEditorState extends State<PressureCurveEditor> {
  int? _index;

  void _down(Offset position, Size size) {
    final width = size.width - 2 * PressureCurveEditor.padding;
    _index = (((position.dx - PressureCurveEditor.padding) / width) * 4)
        .round()
        .clamp(1, 4);
    _move(position, size);
  }

  void _move(Offset position, Size size) {
    if (_index == null) return;
    widget.onChanged(
      PressureCurveEditor.dragged(widget.curve, position, size, index: _index),
    );
  }

  void _up() {
    if (_index == null) return;
    _index = null;
    widget.onChangeEnd();
  }

  @override
  Widget build(BuildContext context) {
    final colors = ColorScheme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        // The drag callbacks keep the panel from scrolling under the pen.
        return GestureDetector(
          onVerticalDragStart: (_) {},
          onVerticalDragUpdate: (_) {},
          onHorizontalDragStart: (_) {},
          onHorizontalDragUpdate: (_) {},
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (event) => _down(event.localPosition, size),
            onPointerMove: (event) => _move(event.localPosition, size),
            onPointerUp: (_) => _up(),
            onPointerCancel: (_) => _up(),
            child: CustomPaint(
              size: size,
              painter: _CurvePainter(
                curve: widget.curve,
                line: colors.primary,
                grid: colors.outlineVariant,
                background: colors.surface,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CurvePainter extends CustomPainter {
  const _CurvePainter({
    required this.curve,
    required this.line,
    required this.grid,
    required this.background,
  });

  final PressureCurve curve;
  final Color line, grid, background;

  @override
  void paint(Canvas canvas, Size size) {
    const padding = PressureCurveEditor.padding;
    final area = Rect.fromLTWH(
      padding,
      padding,
      size.width - 2 * padding,
      size.height - 2 * padding,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(10)),
      Paint()..color = background,
    );
    final gridPaint = Paint()
      ..color = grid.withValues(alpha: 0.6)
      ..strokeWidth = 0.6;
    for (var i = 0; i <= 4; i++) {
      final x = area.left + area.width * i / 4;
      final y = area.top + area.height * i / 4;
      canvas.drawLine(Offset(x, area.top), Offset(x, area.bottom), gridPaint);
      canvas.drawLine(Offset(area.left, y), Offset(area.right, y), gridPaint);
    }

    final points = [
      for (var i = 0; i < 5; i++) PressureCurveEditor.pointAt(curve, i, size),
    ];
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    final fill = Path.from(path)
      ..lineTo(area.right, area.bottom)
      ..lineTo(area.left, area.bottom)
      ..close();
    canvas.drawPath(fill, Paint()..color = line.withValues(alpha: 0.16));
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    for (final p in points.skip(1)) {
      canvas.drawCircle(p, 5, Paint()..color = background);
      canvas.drawCircle(
        p,
        5,
        Paint()
          ..color = line
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_CurvePainter old) =>
      old.curve != curve || old.line != line || old.background != background;
}

Path _polygonPath(List<Offset> polygon) => Path()..addPolygon(polygon, true);

/// A short wavy line drawn with the pen's own options, pressed lightly at
/// the ends and firmly in the middle.
class PenPreviewPainter extends CustomPainter {
  const PenPreviewPainter({
    required this.options,
    required this.color,
    required this.pressure,
    this.nib = false,
  });

  final StrokeOptions options;
  final Color color;
  final bool pressure;

  /// Whether the line is drawn by a flat nib (the calligraphy pen), whose
  /// thickness follows the direction of the line.
  final bool nib;

  /// The points of the sample line in a box of [size].
  @visibleForTesting
  static List<PointVector> samplePoints(
    Size size, {
    required bool pressure,
    bool nib = false,
  }) {
    const n = 60;
    Offset at(int i) {
      final u = i / (n - 1);
      return Offset(
        size.width * (0.06 + 0.88 * u),
        size.height * (0.5 + 0.3 * math.sin(u * math.pi * 1.9 + 0.5)),
      );
    }

    final points = <PointVector>[];
    for (var i = 0; i < n; i++) {
      final u = i / (n - 1);
      final position = at(i);
      double? p;
      if (nib) {
        final next = at(math.min(i + 1, n - 1)), before = at(math.max(i - 1, 0));
        p = PenFeel.nibPressure((next - before).direction);
      } else if (pressure) {
        p = 0.25 + 0.7 * math.sin(u * math.pi);
      }
      points.add(PointVector(position.dx, position.dy, p));
    }
    return points;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final polygon = getStroke(
      samplePoints(size, pressure: pressure, nib: nib),
      options: options.copyWith(isComplete: true, simulatePressure: false),
    );
    if (polygon.length < 3) return;
    canvas.drawPath(_polygonPath(polygon), Paint()..color = color);
  }

  @override
  bool shouldRepaint(PenPreviewPainter old) => true;
}

/// A line drawn at one steady pressure, as the pen would draw it with the
/// pressure curve applied.
class PenSamplePainter extends CustomPainter {
  const PenSamplePainter({
    required this.options,
    required this.color,
    required this.rawPressure,
    required this.curve,
  });

  final StrokeOptions options;
  final Color color;
  final double rawPressure;
  final PressureCurve curve;

  @override
  void paint(Canvas canvas, Size size) {
    const n = 40;
    final pressure = curve.map(rawPressure);
    final points = [
      for (var i = 0; i < n; i++)
        PointVector(
          size.width * (0.04 + 0.92 * i / (n - 1)),
          size.height * (0.5 + 0.22 * math.sin(i / (n - 1) * math.pi * 1.6 + 0.6)),
          pressure,
        ),
    ];
    final polygon = getStroke(
      points,
      options: options.copyWith(isComplete: true, simulatePressure: false),
    );
    if (polygon.length < 3) return;
    canvas.drawPath(_polygonPath(polygon), Paint()..color = color);
  }

  @override
  bool shouldRepaint(PenSamplePainter old) => true;
}
