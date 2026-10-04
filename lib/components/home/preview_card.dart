import 'dart:async';

import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:saber/components/canvas/_stroke.dart';
import 'package:saber/components/canvas/inner_canvas.dart';
import 'package:saber/components/canvas/invert_widget.dart';
import 'package:saber/components/home/notebook_cover.dart';
import 'package:saber/components/home/sync_indicator.dart';
import 'package:saber/data/extensions/color_extensions.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/is_this_a_test.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/routes.dart';
import 'package:saber/i18n/strings.g.dart';
import 'package:saber/pages/editor/editor.dart';

class PreviewCard extends StatefulWidget {
  new({
    required this.filePath,
    required this.toggleSelection,
    required this.selected,
    required this.isAnythingSelected,
  }) : super(key: ValueKey('PreviewCard$filePath'));

  final String filePath;
  final bool selected;
  final bool isAnythingSelected;
  final void Function(String, bool) toggleSelection;

  @override
  State<PreviewCard> createState() => _PreviewCardState();
}

class _PreviewCardState extends State<PreviewCard> {
  final expanded = ValueNotifier(false);
  final thumbnail = _ThumbnailState();

  /// When the note was last modified, shown under the cover.
  DateTime? _modified;

  @override
  void initState() {
    fileWriteSubscription = FileManager.fileWriteStream.stream.listen(
      fileWriteListener,
    );

    expanded.value = widget.selected;
    _readModified();
    super.initState();
  }

  void _readModified() {
    try {
      final file = FileManager.getFile('${widget.filePath}${Editor.extension}');
      _modified = file.existsSync() ? file.lastModifiedSync() : null;
    } catch (_) {
      _modified = null;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final imageFile = FileManager.getFile(
      '${widget.filePath}${Editor.extension}.p',
    );
    if (isThisATest) {
      // Avoid FileImages in tests
      thumbnail.image = imageFile.existsSync()
          ? MemoryImage(imageFile.readAsBytesSync())
          : null;
    } else {
      thumbnail.image = FileImage(imageFile);
    }
  }

  StreamSubscription? fileWriteSubscription;
  void fileWriteListener(FileOperation event) {
    if (event.filePath != widget.filePath) return;
    if (event.type == .delete) {
      thumbnail.image = null;
    } else if (event.type == .write) {
      thumbnail.image?.evict();
      thumbnail.markAsChanged();
      if (mounted) setState(_readModified);
    } else {
      throw Exception('Unknown file operation type: ${event.type}');
    }
  }

  void _toggleCardSelection() {
    expanded.value = !expanded.value;
    widget.toggleSelection(widget.filePath, expanded.value);
  }

  Timer? _refreshThumbnailTimer;
  void _refreshThumbnailAfterDelay() {
    _refreshThumbnailTimer?.cancel();
    _refreshThumbnailTimer = Timer(const Duration(milliseconds: 500), () {
      thumbnail.image?.evict();
      thumbnail.markAsChanged();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final transitionDuration = Duration(
      milliseconds: disableAnimations ? 0 : 300,
    );
    final invert = theme.brightness == .dark && stows.editorAutoInvert.value;
    final coverRadius = kNotebookCoverRadius.resolve(
      Directionality.of(context),
    );
    final modified = _modified;

    final Widget cover = MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.isAnythingSelected ? _toggleCardSelection : null,
        onSecondaryTap: _toggleCardSelection,
        onLongPress: _toggleCardSelection,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(
              color: InnerCanvas.defaultBackgroundColor.withInversion(invert),
            ),
            ListenableBuilder(
              listenable: thumbnail,
              builder: (context, _) => AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: SizedBox.expand(
                  key: ValueKey(thumbnail.updateCount),
                  child: InvertWidget(
                    invert: invert,
                    child: thumbnail.doesImageExist
                        ? Image(
                            image: thumbnail.image!,
                            alignment: .topCenter,
                            fit: .cover,
                          )
                        : const _FallbackThumbnail(),
                  ),
                ),
              ),
            ),
            const NotebookSpine(),
            ValueListenableBuilder(
              valueListenable: expanded,
              builder: (context, expanded, child) => AnimatedOpacity(
                opacity: expanded ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: IgnorePointer(ignoring: !expanded, child: child!),
              ),
              child: GestureDetector(
                onTap: _toggleCardSelection,
                child: ColoredBox(
                  color: colorScheme.primary.withValues(alpha: 0.18),
                  child: Align(
                    alignment: AlignmentDirectional.topEnd,
                    child: Padding(
                      padding: const .all(8),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Padding(
                          padding: const .all(3),
                          child: Icon(
                            Icons.check,
                            size: 18,
                            color: colorScheme.onPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SyncIndicator(filePath: widget.filePath),
          ],
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: kNotebookCoverAspectRatio,
          child: ValueListenableBuilder(
            valueListenable: expanded,
            builder: (context, expanded, _) {
              return DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: coverRadius,
                  boxShadow: notebookCoverShadow(theme.brightness),
                ),
                child: OpenContainer(
                  clipBehavior: Clip.antiAlias,
                  closedColor: colorScheme.surface,
                  closedShape: RoundedRectangleBorder(
                    side: BorderSide(
                      color: expanded
                          ? colorScheme.primary
                          : colorScheme.onSurface.withValues(alpha: 0.12),
                      width: expanded ? 2.5 : 1,
                    ),
                    borderRadius: coverRadius,
                  ),
                  closedElevation: 0,
                  closedBuilder: (context, action) => cover,
                  openColor: colorScheme.surface,
                  openBuilder: (context, action) =>
                      Editor(path: widget.filePath),
                  transitionDuration: transitionDuration,
                  routeSettings: RouteSettings(
                    name: RoutePaths.editFilePath(widget.filePath),
                  ),
                  onClosed: (_) => _refreshThumbnailAfterDelay(),
                ),
              );
            },
          ),
        ),
        Expanded(
          child: NotebookCaption(
            title: widget.filePath.substring(
              widget.filePath.lastIndexOf('/') + 1,
            ),
            subtitle: modified == null
                ? null
                : MaterialLocalizations.of(context).formatShortDate(modified),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _refreshThumbnailTimer?.cancel();
    fileWriteSubscription?.cancel();
    super.dispose();
  }
}

class const _FallbackThumbnail() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: InnerCanvas.defaultBackgroundColor,
      child: Center(
        child: Text(
          t.home.noPreviewAvailable,
          style: TextTheme.of(context).bodyMedium?.copyWith(
            color: Stroke.defaultColor.withValues(alpha: 0.7),
            fontStyle: FontStyle.italic,
          ),
          textAlign: .center,
        ),
      ),
    );
  }
}

class _ThumbnailState extends ChangeNotifier {
  var updateCount = 0;
  ImageProvider? _image;

  void markAsChanged() {
    ++updateCount;
    notifyListeners();
  }

  ImageProvider? get image => _image;
  set image(ImageProvider? image) {
    _image = image;
    markAsChanged();
  }

  bool get doesImageExist => switch (image) {
    (final FileImage fileImage) => fileImage.file.existsSync(),
    null => false,
    _ => true,
  };
}
