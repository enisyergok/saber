import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:saber/components/canvas/canvas_background_preview.dart';
import 'package:saber/components/canvas/canvas_image_dialog.dart';
import 'package:saber/components/canvas/inner_canvas.dart';
import 'package:saber/components/eink/eink_refresh.dart';
import 'package:saber/data/covers/cover_designs.dart';
import 'package:saber/data/defter_strings.dart';
import 'package:saber/data/editor/editor_core_info.dart';
import 'package:saber/data/editor/page.dart';
import 'package:saber/data/extensions/list_extensions.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/search/handwriting_text.dart';
import 'package:saber/data/search/note_search.dart';
import 'package:saber/components/toolbar/handwriting_index_dialog.dart';
import 'package:saber/i18n/extensions/box_fit_localized.dart';
import 'package:saber/i18n/extensions/canvas_background_pattern_localized.dart';
import 'package:saber/i18n/strings.g.dart';
import 'package:sbn/canvas_background_pattern.dart';

class EditorBottomSheet extends StatefulWidget {
  const new({
    super.key,
    required this.invert,
    required this.coreInfo,
    required this.currentPageIndex,
    required this.setBackgroundPattern,
    required this.setBackgroundColor,
    required this.insertCover,
    required this.setLineHeight,
    required this.setLineThickness,
    required this.removeBackgroundImage,
    required this.redrawImage,
    required this.clearPage,
    required this.clearAllPages,
    required this.redrawAndSave,
    required this.pickPhotos,
    required this.importPdf,
    required this.canRasterPdf,
    required this.hasPdf,
    required this.currentPageHasPdf,
    required this.showPdfTools,
    required this.cropPdfPage,
    required this.getIsWatchingServer,
    required this.setIsWatchingServer,
    this.showVersions,
  });

  final bool invert;
  final EditorCoreInfo coreInfo;
  final int? currentPageIndex;
  final void Function(CanvasBackgroundPattern) setBackgroundPattern;
  final void Function(Color?) setBackgroundColor;
  final void Function(CoverDesign) insertCover;
  final void Function(int) setLineHeight;
  final void Function(int) setLineThickness;
  final VoidCallback removeBackgroundImage;
  final VoidCallback redrawImage;
  final VoidCallback clearPage;
  final VoidCallback clearAllPages;
  final VoidCallback redrawAndSave;
  final Future<int> Function() pickPhotos;
  final Future<bool> Function() importPdf;
  final bool canRasterPdf;

  /// Whether the note has any PDF pages.
  final bool hasPdf;

  /// Whether the current page is a PDF page (so it can be cropped).
  final bool currentPageHasPdf;
  final VoidCallback showPdfTools;
  final VoidCallback cropPdfPage;
  final bool Function() getIsWatchingServer;
  final void Function(bool) setIsWatchingServer;

  /// Opens the list of the note's earlier versions. The button is left out
  /// when this is null.
  final VoidCallback? showVersions;

  @override
  State<EditorBottomSheet> createState() => _EditorBottomSheetState();
}

class _EditorBottomSheetState extends State<EditorBottomSheet> {
  static const imageBoxFits = <BoxFit>[.fill, .cover, .contain];

  @override
  Widget build(BuildContext context) {
    final page = widget.coreInfo.pages.getOrNull(widget.currentPageIndex ?? -1);
    final pageSize = page?.size ?? EditorPage.defaultSize;
    final backgroundImage = page?.backgroundImage;

    final previewSize = Size(
      CanvasBackgroundPreview.fixedWidth,
      pageSize.height / pageSize.width * CanvasBackgroundPreview.fixedWidth,
    );

    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(
        // Enable drag scrolling on all devices (including mouse)
        dragDevices: PointerDeviceKind.values.toSet(),
      ),
      child: Padding(
        padding: const .symmetric(horizontal: 16),
        child: ListView(
          shrinkWrap: true,
          children: [
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                ElevatedButton(
                  onPressed: widget.coreInfo.isNotEmpty
                      ? () {
                          widget.clearPage();
                          Navigator.pop(context);
                        }
                      : null,
                  child: Wrap(
                    children: [
                      const Icon(Icons.cleaning_services),
                      const SizedBox(width: 8),
                      Text(
                        t.editor.menu.clearPage(
                          page: widget.currentPageIndex == null
                              ? '?'
                              : widget.currentPageIndex! + 1,
                          totalPages: widget.coreInfo.pages.length,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: widget.coreInfo.isNotEmpty
                      ? () {
                          widget.clearAllPages();
                          Navigator.pop(context);
                        }
                      : null,
                  child: Wrap(
                    children: [
                      const Icon(Icons.cleaning_services),
                      const SizedBox(width: 8),
                      Text(t.editor.menu.clearAllPages),
                    ],
                  ),
                ),
                if (widget.showVersions != null)
                  ElevatedButton(
                    key: const ValueKey('showVersions'),
                    onPressed: () {
                      Navigator.pop(context);
                      widget.showVersions!();
                    },
                    child: Wrap(
                      children: [
                        const Icon(Icons.history),
                        const SizedBox(width: 8),
                        Text(DefterStrings.versionHistory),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (backgroundImage != null) ...[
              Text(
                t.editor.menu.backgroundImageFit,
                style: TextTheme.of(context).titleMedium,
              ),
              SizedBox(
                height: previewSize.height,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: imageBoxFits.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final boxFit = imageBoxFits[index];
                    return InkWell(
                      borderRadius: const .all(.circular(8)),
                      onTap: () => setState(() {
                        backgroundImage.backgroundFit = boxFit;
                        widget.redrawAndSave();
                      }),
                      child: Stack(
                        children: [
                          CanvasBackgroundPreview(
                            selected: backgroundImage.backgroundFit == boxFit,
                            invert: widget.invert,
                            backgroundColor:
                                widget.coreInfo.backgroundColor ??
                                InnerCanvas.defaultBackgroundColor,
                            backgroundPattern:
                                widget.coreInfo.backgroundPattern,
                            backgroundImage: backgroundImage,
                            overrideBoxFit: boxFit,
                            pageSize: pageSize,
                            lineHeight: widget.coreInfo.lineHeight,
                            lineThickness: widget.coreInfo.lineThickness,
                          ),
                          Positioned(
                            bottom: previewSize.height * 0.1,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: _PermanentTooltip(
                                text: boxFit.localizedName,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              CanvasImageDialog(
                filePath: widget.coreInfo.filePath,
                image: backgroundImage,
                redrawImage: () => setState(() {
                  widget.redrawImage();
                }),
                isBackground: true,
                toggleAsBackground: widget.removeBackgroundImage,
                singleRow: true,
              ),
              const SizedBox(height: 16),
            ],
            Text(
              DefterStrings.paperColor,
              style: TextTheme.of(context).titleMedium,
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _paperColors.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final color = _paperColors[index];
                  final selected =
                      widget.coreInfo.backgroundColor?.toARGB32() ==
                      color?.toARGB32();
                  return InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => setState(() {
                      widget.setBackgroundColor(color);
                    }),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color ?? InnerCanvas.defaultBackgroundColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected
                              ? ColorScheme.of(context).primary
                              : ColorScheme.of(context).outlineVariant,
                          width: selected ? 3 : 1,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Text(
              DefterStrings.coverTitle,
              style: TextTheme.of(context).titleMedium,
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 96,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: CoverDesigns.all.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final design = CoverDesigns.all[index];
                  return Tooltip(
                    message: design.name,
                    child: InkWell(
                      onTap: () => widget.insertCover(design),
                      child: AspectRatio(
                        aspectRatio: 1000 / 1400,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: ColorScheme.of(context).outlineVariant,
                            ),
                          ),
                          child: CustomPaint(painter: _CoverPainter(design)),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Text(
              t.editor.menu.backgroundPattern,
              style: TextTheme.of(context).titleMedium,
            ),
            SizedBox(
              height: previewSize.height,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: CanvasBackgroundPattern.values.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final backgroundPattern =
                      CanvasBackgroundPattern.values[index];
                  return InkWell(
                    borderRadius: const .all(.circular(8)),
                    onTap: () => setState(() {
                      widget.setBackgroundPattern(backgroundPattern);
                    }),
                    child: Stack(
                      children: [
                        CanvasBackgroundPreview(
                          selected:
                              widget.coreInfo.backgroundPattern ==
                              backgroundPattern,
                          invert: widget.invert,
                          backgroundColor:
                              widget.coreInfo.backgroundColor ??
                              InnerCanvas.defaultBackgroundColor,
                          backgroundPattern: backgroundPattern,
                          backgroundImage: null, // focus on background pattern
                          pageSize: pageSize,
                          lineHeight: widget.coreInfo.lineHeight,
                          lineThickness: widget.coreInfo.lineThickness,
                        ),
                        Positioned(
                          bottom: previewSize.height * 0.1,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: _PermanentTooltip(
                              text: backgroundPattern.localizedName,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Text(
              t.editor.menu.lineHeight,
              style: TextTheme.of(context).titleMedium,
            ),
            Text(
              t.editor.menu.lineHeightDescription,
              style: TextTheme.of(context).bodyMedium,
            ),
            Row(
              children: [
                Text(widget.coreInfo.lineHeight.toString()),
                Expanded(
                  child: Slider(
                    value: widget.coreInfo.lineHeight.toDouble(),
                    min: 20,
                    max: 100,
                    divisions: 8,
                    onChanged: (double value) => setState(() {
                      widget.setLineHeight(value.toInt());
                    }),
                  ),
                ),
              ],
            ),
            Text(
              t.editor.menu.lineThickness,
              style: TextTheme.of(context).titleMedium,
            ),
            Text(
              t.editor.menu.lineThicknessDescription,
              style: TextTheme.of(context).bodyMedium,
            ),
            Row(
              children: [
                Text(widget.coreInfo.lineThickness.toString()),
                Expanded(
                  child: Slider(
                    value: widget.coreInfo.lineThickness.toDouble(),
                    min: 1,
                    max: 5,
                    divisions: 4,
                    onChanged: (double value) => setState(() {
                      widget.setLineThickness(value.toInt());
                    }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              t.editor.menu.import,
              style: TextTheme.of(context).titleMedium,
            ),
            Wrap(
              spacing: 8,
              children: [
                ElevatedButton(
                  onPressed: () async {
                    final photosPicked = await widget.pickPhotos();
                    if (photosPicked > 0) {
                      if (!context.mounted) return;
                      Navigator.pop(context);
                    }
                  },
                  child: Text(t.editor.toolbar.photo),
                ),
                if (widget.canRasterPdf)
                  ElevatedButton(
                    onPressed: () async {
                      final pdfImported = await widget.importPdf();
                      if (pdfImported) {
                        if (!context.mounted) return;
                        Navigator.pop(context);
                      }
                    },
                    child: const Text('PDF'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (widget.hasPdf) ...[
              Text(
                DefterStrings.pdfSection,
                style: TextTheme.of(context).titleMedium,
              ),
              Wrap(
                spacing: 8,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.manage_search),
                    label: Text(DefterStrings.pdfTools),
                    onPressed: () {
                      Navigator.pop(context);
                      widget.showPdfTools();
                    },
                  ),
                  if (widget.currentPageHasPdf && !widget.coreInfo.readOnly)
                    ElevatedButton.icon(
                      icon: const Icon(Icons.crop),
                      label: Text(DefterStrings.pdfCrop),
                      onPressed: () {
                        Navigator.pop(context);
                        widget.cropPdfPage();
                      },
                    ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            Text(
              DefterStrings.hwSection,
              style: TextTheme.of(context).titleMedium,
            ),
            FutureBuilder<void>(
              future: HandwritingTexts.load(),
              builder: (context, _) {
                final text = HandwritingTexts.of(widget.coreInfo.filePath);
                final outdated =
                    text != null &&
                    HandwritingIndexer.isOutdated(
                      text,
                      NoteSearchIndex.modifiedMsOf(widget.coreInfo.filePath),
                    );
                final status = text == null
                    ? DefterStrings.hwNone
                    : outdated
                    ? DefterStrings.hwOutdated
                    : DefterStrings.hwIndexedOn(
                        MaterialLocalizations.of(context).formatShortDate(
                          DateTime.fromMillisecondsSinceEpoch(text.recognizedMs),
                        ),
                      );
                return Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.manage_search),
                      label: Text(
                        text == null ? DefterStrings.hwAdd : DefterStrings.hwRefresh,
                      ),
                      onPressed: () {
                        final navigator = Navigator.of(context);
                        final messenger = ScaffoldMessenger.maybeOf(context);
                        navigator.pop();
                        Future.delayed(const Duration(milliseconds: 200), () async {
                          final added = await HandwritingIndexDialog.show(
                            navigator.context,
                            widget.coreInfo,
                          );
                          if (added == true) {
                            messenger?.showSnackBar(
                              SnackBar(content: Text(DefterStrings.hwDone)),
                            );
                          }
                        });
                      },
                    ),
                    Text(status),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            if (stows.eInkMode.value && stows.eInkRefreshEffect.value) ...[
              Text(
                DefterStrings.eInkSection,
                style: TextTheme.of(context).titleMedium,
              ),
              Wrap(
                spacing: 8,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: Text(DefterStrings.eInkRefreshPage),
                    onPressed: () {
                      Navigator.pop(context);
                      // once the sheet has gone, so the whole page flashes
                      Future.delayed(
                        const Duration(milliseconds: 250),
                        EInkRefresh.instance.full,
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            if (stows.loggedIn) ...[
              StatefulBuilder(
                builder: (context, setState) {
                  final isWatchingServer = widget.getIsWatchingServer();
                  return CheckboxListTile.adaptive(
                    value: isWatchingServer,
                    title: Text(t.editor.menu.watchServer),
                    subtitle: isWatchingServer
                        ? Text(t.editor.menu.watchServerReadOnly)
                        : null,
                    onChanged: (value) => setState(() {
                      widget.setIsWatchingServer(value!);
                    }),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }
}

/// The paper colours on offer; null is the default white.
const _paperColors = <Color?>[
  null,
  Color(0xFFFFF8E7), // cream
  Color(0xFFF7F1E3), // ivory
  Color(0xFFE5E5E5), // grey
  Color(0xFF1E1E1E), // black
  Color(0xFFFDE2E4), // pink
  Color(0xFFDCEBFA), // blue
  Color(0xFFDDF2E0), // green
  Color(0xFFE8E0F7), // lilac
  Color(0xFFFFF4B8), // yellow
  Color(0xFFFFE5D0), // peach
  Color(0xFFD8F5EC), // mint
];

class _PermanentTooltip extends StatelessWidget {
  const new({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: const .all(.circular(8)),
        color: colorScheme.surface.withValues(alpha: 0.8),
      ),
      child: Padding(
        padding: const .symmetric(horizontal: 8),
        child: Text(
          text,
          textAlign: .center,
          textWidthBasis: TextWidthBasis.longestLine,
          style: TextStyle(color: colorScheme.onSurface),
        ),
      ),
    );
  }
}

class _CoverPainter extends CustomPainter {
  const _CoverPainter(this.design);
  final CoverDesign design;

  @override
  void paint(Canvas canvas, Size size) {
    // draw at page size, scaled down
    canvas.save();
    canvas.scale(size.width / 1000);
    design.draw(canvas, Size(1000, size.height * 1000 / size.width));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CoverPainter old) => old.design != design;
}
