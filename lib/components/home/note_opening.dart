import 'package:flutter/material.dart';
import 'package:saber/components/editor_gn/gn_bar.dart';
import 'package:saber/components/editor_gn/gn_palette.dart';
import 'package:saber/components/theming/defter_design.dart';
import 'package:saber/components/theming/dynamic_material_app.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/pages/editor/editor.dart';

/// What a note's card opens into.
///
/// While the card is still growing to fill the screen this is only the
/// note as its card showed it: one picture under the editor's bar, which
/// can be scaled sixty or a hundred and twenty times a second without
/// effort. The editor itself (reading the file, building its pages and
/// its tools) is only started once the growing is over, and then fades in
/// over the picture. Built during the growing, it would take the frames
/// the movement needs and the card would open in jerks.
class NoteOpening extends StatefulWidget {
  const new({
    super.key,
    required this.path,
    required this.paper,
    this.picture,
    this.editorBuilder,
  });

  /// The note to open.
  final String path;

  /// The colour of the paper behind the picture.
  final Color paper;

  /// The note's first page as its card shows it, if there is a picture
  /// of it. It is laid out to fill the width of the screen.
  final Widget? picture;

  /// Builds what is shown once the opening is over, if not the editor
  /// of [path].
  @visibleForTesting
  final WidgetBuilder? editorBuilder;

  static const skeletonKey = ValueKey('noteOpeningSkeleton');
  static const editorKey = ValueKey('noteOpeningEditor');

  @override
  State<NoteOpening> createState() => _NoteOpeningState();
}

class _NoteOpeningState extends State<NoteOpening> {
  Animation<double>? _routeAnimation;

  /// Whether the card has finished growing (once true, always true: the
  /// editor stays while the page closes again).
  var _arrived = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animation = ModalRoute.of(context)?.animation;
    if (!identical(animation, _routeAnimation)) {
      _routeAnimation?.removeStatusListener(_onRouteStatus);
      _routeAnimation = animation;
      animation?.addStatusListener(_onRouteStatus);
    }
    if (animation == null ||
        animation.isCompleted ||
        DefterDesign.isStill(context)) {
      _arrived = true;
    }
  }

  void _onRouteStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || _arrived || !mounted) return;
    setState(() => _arrived = true);
  }

  @override
  void dispose() {
    _routeAnimation?.removeStatusListener(_onRouteStatus);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: DefterDesign.fast,
      switchInCurve: Curves.easeOut,
      // The editor fades in over the picture; the picture stays whole
      // under it until it is covered, so the paper never shows through.
      transitionBuilder: (child, animation) =>
          child.key == NoteOpening.skeletonKey
          ? child
          : FadeTransition(opacity: animation, child: child),
      layoutBuilder: (currentChild, previousChildren) => Stack(
        fit: StackFit.expand,
        children: [...previousChildren, ?currentChild],
      ),
      child: _arrived
          ? KeyedSubtree(
              key: NoteOpening.editorKey,
              child:
                  widget.editorBuilder?.call(context) ??
                  Editor(path: widget.path),
            )
          : _NoteSkeleton(
              key: NoteOpening.skeletonKey,
              paper: widget.paper,
              picture: widget.picture,
            ),
    );
  }
}

/// The editor as it will look, without anything of it that costs time:
/// its bar as a band of colour, and the page as the picture of it.
class _NoteSkeleton extends StatelessWidget {
  const new({super.key, required this.paper, required this.picture});

  final Color paper;
  final Widget? picture;

  @override
  Widget build(BuildContext context) {
    final showsBar =
        stows.editorGnLayout.value && !DynamicMaterialApp.isFullscreen;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showsBar)
          ColoredBox(
            color: GnPalette.of(context).header,
            child: SizedBox(
              height:
                  GnEditorBar.contentHeight +
                  MediaQuery.viewPaddingOf(context).top,
            ),
          ),
        Expanded(
          child: ColoredBox(
            color: paper,
            child: picture == null
                ? const SizedBox.expand()
                : SizedBox.expand(child: picture),
          ),
        ),
      ],
    );
  }
}
