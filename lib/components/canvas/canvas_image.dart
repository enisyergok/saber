import 'dart:math';

import 'package:defer_pointer/defer_pointer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:saber/components/canvas/canvas_image_dialog.dart';
import 'package:saber/components/canvas/image/editor_image.dart';
import 'package:saber/components/eink/eink_image_filter.dart';
import 'package:saber/components/theming/adaptive_alert_dialog.dart';
import 'package:saber/data/defter_strings.dart';
import 'package:saber/data/extensions/change_notifier_extensions.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/i18n/strings.g.dart';

class CanvasImage extends StatefulHookWidget {
  new({
    required this.filePath,
    required this.image,
    this.overrideBoxFit,
    required this.pageSize,
    required this.setAsBackground,
    this.isBackground = false,
    this.readOnly = false,
    this.selected = false,
  }) : super(key: Key('CanvasImage$filePath/${image.id}'));

  /// The path to the note that this image is in.
  final String filePath;
  final EditorImage image;
  final BoxFit? overrideBoxFit;
  final Size pageSize;
  final void Function(EditorImage image)? setAsBackground;
  final bool isBackground;
  final bool readOnly;
  final bool selected;

  /// When notified, all [CanvasImages] will have their [active] property set to false.
  static var activeListener = ChangeNotifier();

  /// Set to a picture to make it the active one (with its frame, handles
  /// and action buttons), as a tap on it does.
  static final requestActive = ValueNotifier<EditorImage?>(null);

  /// The size on screen of one of the small buttons that an active picture
  /// shows (delete, turn, more), in logical pixels.
  static const actionButtonSize = 40.0;

  /// The minimum size of the interactive area for the image.
  static double minInteractiveSize = 50;

  /// The minimum size of the image itself, inside of the interactive area.
  static double minImageSize = 10;

  @override
  State<CanvasImage> createState() => _CanvasImageState();
}

class _CanvasImageState extends State<CanvasImage> {
  var _active = false;

  /// Whether this image can be dragged
  bool get active => _active;
  set active(bool value) {
    if (active == value) return;

    if (value) {
      CanvasImage.activeListener
          .notifyListenersPlease(); // de-activate all other images
    }

    _active = value;

    if (mounted) {
      try {
        setState(() {});
      } catch (e) {
        // setState throws error if widget is currently building
      }
    }
  }

  Brightness imageBrightness = .light;

  Rect panStartRect = .zero;
  Offset panStartPosition = .zero;

  @override
  void initState() {
    widget.image.loadIn();

    if (widget.image.newImage) {
      // if the image is new, make it [active]
      active = true;
      widget.image.newImage = false;
    }

    CanvasImage.activeListener.addListener(disableActive);
    CanvasImage.requestActive.addListener(_onRequestActive);

    super.initState();
  }

  void disableActive() {
    active = false;
  }

  void _onRequestActive() {
    if (!identical(CanvasImage.requestActive.value, widget.image)) return;
    CanvasImage.requestActive.value = null;
    active = true;
  }

  /// How many pixels on screen one unit of the page is (the page is
  /// fitted to the screen and can be zoomed), so that the action buttons
  /// keep the size of a fingertip whatever the zoom. Measured after each
  /// frame while the picture is active, when everything has been laid out.
  double _unitsToPixels = 1;
  bool _followingScale = false;

  void _followScale() {
    if (_followingScale) return;
    _followingScale = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _followingScale = false;
      if (!mounted || !_active) return;
      final box = context.findRenderObject();
      if (box is RenderBox && box.attached && box.hasSize) {
        final scale = box.getTransformTo(null).getMaxScaleOnAxis();
        if (scale.isFinite &&
            scale > 0 &&
            (scale - _unitsToPixels).abs() > _unitsToPixels * 0.02) {
          setState(() => _unitsToPixels = scale);
        }
      }
      _followScale();
    });
  }

  /// Turns the picture a quarter turn and tells the editor, which records
  /// it so that it can be undone.
  void _rotate() {
    final image = widget.image;
    final before = image.dstRect;
    setState(() => image.rotateQuarter());
    final after = image.dstRect;
    image.onMoveImage?.call(
      image,
      .fromLTRB(
        after.left - before.left,
        after.top - before.top,
        after.right - before.right,
        after.bottom - before.bottom,
      ),
    );
  }

  void _delete() {
    widget.image.onDeleteImage?.call(widget.image);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);

    useListenable(widget.image);
    if (widget.readOnly) active = false;
    if (active) _followScale();

    final currentBrightness = widget.image.invertible
        ? Theme.brightnessOf(context)
        : Brightness.light;

    if (stows.editorAutoInvert.value && currentBrightness != imageBrightness) {
      imageBrightness = currentBrightness;
    }

    final Widget unpositioned = IgnorePointer(
      ignoring: widget.readOnly,
      child: Stack(
        fit: StackFit.expand,
        children: [
          MouseRegion(
            cursor: active ? SystemMouseCursors.grab : MouseCursor.defer,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                active = !active;
              },
              onLongPress: active ? showModal : null,
              onSecondaryTap: active ? showModal : null,
              onPanStart: active
                  ? (details) {
                      panStartRect = widget.image.dstRect;
                    }
                  : null,
              onPanUpdate: active
                  ? (details) {
                      setState(() {
                        final fivePercent = min(
                          widget.pageSize.width * 0.05,
                          widget.pageSize.height * 0.05,
                        );
                        widget.image.dstRect = .fromLTWH(
                          (widget.image.dstRect.left + details.delta.dx)
                              .clamp(
                                fivePercent - widget.image.dstRect.width,
                                widget.pageSize.width - fivePercent,
                              )
                              .toDouble(),
                          (widget.image.dstRect.top + details.delta.dy)
                              .clamp(
                                fivePercent - widget.image.dstRect.height,
                                widget.pageSize.height - fivePercent,
                              )
                              .toDouble(),
                          widget.image.dstRect.width,
                          widget.image.dstRect.height,
                        );
                      });
                    }
                  : null,
              onPanEnd: active
                  ? (details) {
                      if (panStartRect == widget.image.dstRect) return;
                      widget.image.onMoveImage?.call(
                        widget.image,
                        .fromLTRB(
                          widget.image.dstRect.left - panStartRect.left,
                          widget.image.dstRect.top - panStartRect.top,
                          widget.image.dstRect.right - panStartRect.right,
                          widget.image.dstRect.bottom - panStartRect.bottom,
                        ),
                      );
                      panStartRect = .zero;
                    }
                  : null,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: active ? colorScheme.onSurface : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: SizedBox(
                    width: widget.isBackground
                        ? widget.pageSize.width
                        : max(
                            widget.image.dstRect.width,
                            CanvasImage.minImageSize,
                          ),
                    height: widget.isBackground
                        ? widget.pageSize.height
                        : max(
                            widget.image.dstRect.height,
                            CanvasImage.minImageSize,
                          ),
                    child: RotatedBox(
                      // A picture that is a page's background is not turned.
                      quarterTurns: widget.isBackground
                          ? 0
                          : widget.image.quarterTurns,
                      child: SizedOverflowBox(
                        size: widget.image.srcRect.size,
                        child: Transform.translate(
                          offset: -widget.image.srcRect.topLeft,
                          child: EInkImageFilter(
                            child: widget.image.buildImageWidget(
                              context: context,
                              overrideBoxFit: widget.overrideBoxFit,
                              isBackground: widget.isBackground,
                              invert: imageBrightness == .dark,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (widget.selected) // tint image if selected
            ColoredBox(color: colorScheme.primary.withValues(alpha: 0.5)),
          if (!widget.readOnly)
            for (double x = -20; x <= 20; x += 20)
              for (double y = -20; y <= 20; y += 20)
                if (x != 0 || y != 0) // ignore (0,0)
                  _CanvasImageResizeHandle(
                    active: active,
                    position: Offset(x, y),
                    image: widget.image,
                    parent: this,
                    afterDrag: () => setState(() {}),
                  ),
          if (active && !widget.readOnly && !widget.isBackground)
            _CanvasImageActions(
              image: widget.image,
              unitsToPixels: _unitsToPixels,
              onRotate: _rotate,
              onDelete: _delete,
              onMore: showModal,
            ),
        ],
      ),
    );

    if (widget.isBackground) {
      return AnimatedPositioned(
        duration: const Duration(milliseconds: 300),
        curve: Curves.fastLinearToSlowEaseIn,
        left: 0,
        top: 0,
        right: 0,
        bottom: 0,
        child: unpositioned,
      );
    }
    return AnimatedPositioned(
      // no animation if the image is being dragged or it's selected
      duration: (panStartRect != .zero || widget.selected)
          ? Duration.zero
          : const Duration(milliseconds: 300),
      curve: Curves.fastLinearToSlowEaseIn,

      left: widget.image.dstRect.left,
      top: widget.image.dstRect.top,
      width: max(widget.image.dstRect.width, CanvasImage.minInteractiveSize),
      height: max(widget.image.dstRect.height, CanvasImage.minInteractiveSize),

      child: unpositioned,
    );
  }

  @override
  void dispose() {
    widget.image.loadOut();
    CanvasImage.activeListener.removeListener(disableActive);
    CanvasImage.requestActive.removeListener(_onRequestActive);
    super.dispose();
  }

  void showModal() {
    showDialog(
      context: context,
      builder: (context) {
        return AdaptiveAlertDialog(
          title: Text(t.editor.imageOptions.title),
          content: CanvasImageDialog(
            filePath: widget.filePath,
            image: widget.image,
            redrawImage: () => setState(() {}),
            isBackground: false,
            toggleAsBackground: () {
              widget.setAsBackground?.call(widget.image);
            },
          ),
          actions: const [],
        );
      },
    );
  }
}

/// The small buttons of the active picture: turn it, delete it, more. They
/// sit just above the picture (below it when there is no room above) and
/// keep the same size on screen however far the page is zoomed.
class _CanvasImageActions extends StatelessWidget {
  const new({
    required this.image,
    required this.unitsToPixels,
    required this.onRotate,
    required this.onDelete,
    required this.onMore,
  });

  final EditorImage image;

  /// Pixels on screen for one unit of the page.
  final double unitsToPixels;
  final VoidCallback onRotate;
  final VoidCallback onDelete;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    // Everything here is measured in units of the page.
    final unit = 1 / unitsToPixels;
    final button = (CanvasImage.actionButtonSize * unit)
        .clamp(16.0, 160.0)
        .toDouble();
    final gap = button * 0.3;
    const count = 3;
    final barWidth = button * count + gap * 0.5 * (count + 1);
    final barHeight = button + gap * 0.5;

    final boxWidth = max(image.dstRect.width, CanvasImage.minInteractiveSize);
    final boxHeight = max(image.dstRect.height, CanvasImage.minInteractiveSize);
    // Above the picture, unless that is off the top of the page.
    final above = image.dstRect.top >= barHeight + gap;

    Widget action(Key key, IconData icon, String label, VoidCallback onTap) =>
        Semantics(
          button: true,
          label: label,
          child: InkResponse(
            key: key,
            onTap: onTap,
            radius: button * 0.5,
            child: SizedBox.square(
              dimension: button,
              child: Icon(
                icon,
                size: button * 0.55,
                color: colorScheme.onSurface,
              ),
            ),
          ),
        );

    return Positioned(
      left: (boxWidth - barWidth) / 2,
      top: above ? -(barHeight + gap) : boxHeight + gap,
      width: barWidth,
      height: barHeight,
      child: DeferPointer(
        paintOnTop: true,
        child: Material(
          key: const Key('imageActions'),
          color: colorScheme.surfaceContainerHigh,
          elevation: 3,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              action(
                const Key('imageRotate'),
                Icons.rotate_90_degrees_cw_outlined,
                DefterStrings.imageRotate,
                onRotate,
              ),
              action(
                const Key('imageDelete'),
                Icons.delete_outline,
                t.editor.imageOptions.delete,
                onDelete,
              ),
              action(
                const Key('imageMore'),
                Icons.more_horiz,
                DefterStrings.imageMore,
                onMore,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CanvasImageResizeHandle extends StatelessWidget {
  const new({
    required this.active,
    required this.position,
    required this.image,
    required this.parent,
    required this.afterDrag,
  });

  final bool active;
  final Offset position;
  final EditorImage image;
  final _CanvasImageState parent;
  final void Function() afterDrag;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    return Positioned(
      left: (position.dx.sign + 1) / 2 * image.dstRect.width - 20,
      top: (position.dy.sign + 1) / 2 * image.dstRect.height - 20,
      child: DeferPointer(
        paintOnTop: true,
        child: MouseRegion(
          cursor: () {
            if (!active) return MouseCursor.defer;

            if (position.dx == 0 && position.dy < 0)
              return SystemMouseCursors.resizeUp;
            if (position.dx == 0 && position.dy > 0)
              return SystemMouseCursors.resizeDown;
            if (position.dx < 0 && position.dy == 0)
              return SystemMouseCursors.resizeLeft;
            if (position.dx > 0 && position.dy == 0)
              return SystemMouseCursors.resizeRight;

            if (position.dx < 0 && position.dy < 0)
              return SystemMouseCursors.resizeUpLeft;
            if (position.dx < 0 && position.dy > 0)
              return SystemMouseCursors.resizeDownLeft;
            if (position.dx > 0 && position.dy < 0)
              return SystemMouseCursors.resizeUpRight;
            if (position.dx > 0 && position.dy > 0)
              return SystemMouseCursors.resizeDownRight;

            return MouseCursor.defer;
          }(),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: active
                ? (details) {
                    parent.panStartRect = parent.widget.image.dstRect;
                    parent.panStartPosition = details.localPosition;
                  }
                : null,
            onPanUpdate: active
                ? (details) {
                    final Offset delta =
                        details.localPosition - parent.panStartPosition;

                    double newWidth;
                    if (position.dx < 0) {
                      newWidth = parent.panStartRect.width - delta.dx;
                    } else if (position.dx > 0) {
                      newWidth = parent.panStartRect.width + delta.dx;
                    } else {
                      newWidth = parent.panStartRect.width;
                    }

                    double newHeight;
                    if (position.dy < 0) {
                      newHeight = parent.panStartRect.height - delta.dy;
                    } else if (position.dy > 0) {
                      newHeight = parent.panStartRect.height + delta.dy;
                    } else {
                      newHeight = parent.panStartRect.height;
                    }

                    if (newWidth <= 0 || newHeight <= 0) return;

                    // preserve aspect ratio if diagonal
                    if (position.dx != 0 && position.dy != 0) {
                      // if diagonal
                      final aspectRatio =
                          image.dstRect.width / image.dstRect.height;
                      if (newWidth / newHeight > aspectRatio) {
                        newHeight = newWidth / aspectRatio;
                      } else {
                        newWidth = newHeight * aspectRatio;
                      }
                    }

                    // resize from the correct corner
                    double left = image.dstRect.left, top = image.dstRect.top;
                    if (position.dx < 0) {
                      left = image.dstRect.right - newWidth;
                    }
                    if (position.dy < 0) {
                      top = image.dstRect.bottom - newHeight;
                    }

                    image.dstRect = .fromLTWH(left, top, newWidth, newHeight);
                    afterDrag();
                  }
                : null,
            onPanEnd: active
                ? (details) {
                    if (parent.panStartRect == image.dstRect) return;
                    image.onMoveImage?.call(
                      image,
                      .fromLTRB(
                        image.dstRect.left - parent.panStartRect.left,
                        image.dstRect.top - parent.panStartRect.top,
                        image.dstRect.right - parent.panStartRect.right,
                        image.dstRect.bottom - parent.panStartRect.bottom,
                      ),
                    );
                    parent.panStartRect = .zero;
                  }
                : null,
            child: AnimatedOpacity(
              opacity: active ? 1 : 0,
              duration: const Duration(milliseconds: 100),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colorScheme.onSurface,
                  shape: .circle,
                  border: Border.all(color: colorScheme.surface, width: 2),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
