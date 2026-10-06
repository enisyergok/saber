import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:saber/data/defter_strings.dart';
import 'package:saber/data/pdf/pdf_pick.dart';

/// How a part of a page is marked.
enum PdfPickTool { rectangle, lasso }

/// Turns marked parts of PDF pages into pictures and text.
abstract class PdfPickReader {
  /// Draws the part of [page] that [region] marks as a PNG. With a freely
  /// drawn region, what is outside the line is see-through.
  static Future<PdfPickImage> image(PdfPage page, PdfRegion region) async {
    final bounds = region.bounds;
    final size = PdfClip.pixelsFor(
      page.width * bounds.width,
      page.height * bounds.height,
    );
    final fullWidth = page.width * size.scale;
    final fullHeight = page.height * size.scale;
    final x = (bounds.left * fullWidth).floor();
    final y = (bounds.top * fullHeight).floor();
    final width = math.max(1, math.min(size.width, fullWidth.ceil() - x));
    final height = math.max(1, math.min(size.height, fullHeight.ceil() - y));

    final rendered = await page.render(
      x: x,
      y: y,
      width: width,
      height: height,
      fullWidth: fullWidth,
      fullHeight: fullHeight,
      backgroundColor: 0xffffffff,
    );
    if (rendered == null) {
      throw StateError('The page could not be drawn');
    }
    ui.Image image;
    try {
      image = await rendered.createImage();
    } finally {
      rendered.dispose();
    }

    if (!region.isRectangle) {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas
        ..translate(-x.toDouble(), -y.toDouble())
        ..clipPath(region.pathIn(Size(fullWidth, fullHeight)))
        ..drawImage(
          image,
          Offset(x.toDouble(), y.toDouble()),
          Paint()..filterQuality = FilterQuality.none,
        );
      final picture = recorder.endRecording();
      try {
        final clipped = await picture.toImage(width, height);
        image.dispose();
        image = clipped;
      } finally {
        picture.dispose();
      }
    }

    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('The picture could not be made');
      return PdfPickImage(
        png: data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        pixelSize: Size(width.toDouble(), height.toDouble()),
        fractionOfPage: Size(bounds.width, bounds.height),
      );
    } finally {
      image.dispose();
    }
  }

  /// The text of [page] with the place of each character in fractions of
  /// the page. A page without text (a scan) has an empty text.
  static Future<({String fullText, List<Rect?> charRects})> textOf(
    PdfPage page,
  ) async {
    final text = await page.loadStructuredText();
    final width = page.width, height = page.height;
    return (
      fullText: text.fullText,
      charRects: [
        for (final rect in text.charRects)
          if (rect.isEmpty || width <= 0 || height <= 0)
            null
          else
            () {
              final onPage = rect.toRect(page: page);
              return Rect.fromLTRB(
                onPage.left / width,
                onPage.top / height,
                onPage.right / width,
                onPage.bottom / height,
              );
            }(),
      ],
    );
  }

  /// The text inside [region] on [page].
  static Future<String> text(PdfPage page, PdfRegion region) async {
    final text = await textOf(page);
    return PdfTextPicker.textIn(
      fullText: text.fullText,
      charRects: text.charRects,
      contains: region.contains,
    );
  }
}

/// A window that shows a PDF before any of it is put into the note: its
/// pages can be leafed through, pages can be ticked to become pages of the
/// note, and a part of a page can be marked with the pen to be taken as a
/// picture or as text.
///
/// Pops with the [PdfPick] that was made, or with nothing.
class PdfPickerDialog extends StatefulWidget {
  const new({
    super.key,
    required this.document,
    required this.name,
    this.initialPage = 0,
    this.onPageChanged,
  });

  final PdfDocument document;

  /// The name of the PDF, for the title.
  final String name;

  /// The page that is shown first (the first page is 0).
  final int initialPage;

  /// Told which page is shown, so that the window can be opened there again.
  final ValueChanged<int>? onPageChanged;

  @override
  State<PdfPickerDialog> createState() => PdfPickerDialogState();
}

@visibleForTesting
class PdfPickerDialogState extends State<PdfPickerDialog> {
  static final log = Logger('PdfPickerDialog');

  late int _page = widget.initialPage.clamp(0, _pageCount - 1).toInt();
  final _chosenPages = <int>{};
  var _tool = PdfPickTool.rectangle;

  /// What is marked on the page that is shown.
  PdfRegion? _region;

  /// The text inside [_region]: null while it is being read.
  String? _regionText;
  int _regionSerial = 0;

  /// The line being drawn, in fractions of the page.
  List<Offset>? _drawing;
  int? _drawingPointer;
  int _pointersDown = 0;

  bool _busy = false;
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  final _zoom = TransformationController();
  final _thumbnails = ScrollController();

  int get _pageCount => widget.document.pages.length;
  PdfPage get _pdfPage => widget.document.pages[_page];

  @visibleForTesting
  PdfRegion? get region => _region;

  @visibleForTesting
  String? get regionText => _regionText;

  @visibleForTesting
  int get page => _page;

  @override
  void dispose() {
    _zoom.dispose();
    _thumbnails.dispose();
    super.dispose();
  }

  void _goTo(int page) {
    final target = page.clamp(0, _pageCount - 1).toInt();
    if (target == _page) return;
    setState(() {
      _page = target;
      _region = null;
      _regionText = null;
      _drawing = null;
      _zoom.value = Matrix4.identity();
    });
    widget.onPageChanged?.call(target);
  }

  void _togglePage(int page) => setState(() {
    if (!_chosenPages.remove(page)) _chosenPages.add(page);
  });

  void _clearRegion() => setState(() {
    _region = null;
    _regionText = null;
  });

  /// Marks [region] on the page and reads the text inside it.
  @visibleForTesting
  void setRegion(PdfRegion region) {
    final serial = ++_regionSerial;
    final page = _pdfPage;
    setState(() {
      _region = region;
      _regionText = null;
    });
    PdfPickReader.text(page, region).then(
      (text) {
        if (!mounted || serial != _regionSerial) return;
        setState(() => _regionText = text);
      },
      onError: (Object e, StackTrace st) {
        log.warning('Could not read the text of the page: $e', e, st);
        if (!mounted || serial != _regionSerial) return;
        setState(() => _regionText = '');
      },
    );
  }

  // -- marking with the pen --------------------------------------------------

  Offset _fraction(Offset local, Size size) => Offset(
    (local.dx / size.width).clamp(0.0, 1.0),
    (local.dy / size.height).clamp(0.0, 1.0),
  );

  void _onDown(PointerDownEvent event, Size size) {
    _pointersDown++;
    if (_busy) return;
    if (_pointersDown > 1) {
      // Two fingers zoom: what was being drawn was not meant.
      setState(() {
        _drawing = null;
        _drawingPointer = null;
      });
      return;
    }
    _drawingPointer = event.pointer;
    setState(() => _drawing = [_fraction(event.localPosition, size)]);
  }

  void _onMove(PointerMoveEvent event, Size size) {
    final drawing = _drawing;
    if (drawing == null || event.pointer != _drawingPointer) return;
    final point = _fraction(event.localPosition, size);
    setState(() {
      if (_tool == PdfPickTool.rectangle) {
        _drawing = [drawing.first, point];
      } else {
        drawing.add(point);
      }
    });
  }

  void _onUp(PointerEvent event, Size size) {
    _pointersDown = math.max(0, _pointersDown - 1);
    final drawing = _drawing;
    if (drawing == null || event.pointer != _drawingPointer) return;
    _drawingPointer = null;
    final region = _regionOf(drawing);
    setState(() => _drawing = null);
    if (event is PointerCancelEvent || region == null) return;
    if (!region.isLargeEnough(size)) return;
    setRegion(region);
  }

  PdfRegion? _regionOf(List<Offset> points) {
    if (points.length < 2) return null;
    return _tool == PdfPickTool.rectangle
        ? PdfRegion.rectangle(points.first, points.last)
        : PdfRegion.lasso(points);
  }

  // -- what is taken ---------------------------------------------------------

  void _takePages(List<int> pages) =>
      Navigator.of(context).pop<PdfPick>(PdfPickPages(pages.toList()..sort()));

  Future<void> _takeImage() async {
    final region = _region;
    if (region == null || _busy) return;
    setState(() => _busy = true);
    try {
      final image = await PdfPickReader.image(_pdfPage, region);
      if (!mounted) return;
      Navigator.of(context).pop<PdfPick>(image);
    } catch (e, st) {
      log.severe('Could not take a part of the page as a picture: $e', e, st);
      if (!mounted) return;
      setState(() => _busy = false);
      _messenger.currentState?.showSnackBar(
        SnackBar(content: Text(DefterStrings.pdfPickImageFailed)),
      );
    }
  }

  void _takeText() {
    final text = _regionText;
    if (text == null || text.trim().isEmpty) return;
    Navigator.of(context).pop<PdfPick>(PdfPickText(text));
  }

  Future<void> _copyText() async {
    final text = _regionText;
    if (text == null || text.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    _messenger.currentState?.showSnackBar(
      SnackBar(content: Text(DefterStrings.pdfPickCopied)),
    );
  }

  // -- the window ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screen = MediaQuery.sizeOf(context);
    final wide = screen.width >= 720;

    return Dialog(
      clipBehavior: Clip.antiAlias,
      insetPadding: EdgeInsets.symmetric(
        horizontal: wide ? 32 : 8,
        vertical: wide ? 24 : 8,
      ),
      child: ScaffoldMessenger(
        key: _messenger,
        child: Scaffold(
          backgroundColor: colorScheme.surfaceContainerLow,
          body: Column(
            children: [
              _header(theme, wide),
              const Divider(height: 1),
              Expanded(
                child: Row(
                  children: [
                    if (wide) ...[
                      SizedBox(width: 148, child: _thumbnailStrip(theme)),
                      const VerticalDivider(width: 1),
                    ],
                    Expanded(child: _pageArea(theme)),
                  ],
                ),
              ),
              const Divider(height: 1),
              _footer(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(ThemeData theme, bool wide) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
    child: Row(
      children: [
        const Icon(Symbols.picture_as_pdf_rounded),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            widget.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium,
          ),
        ),
        const SizedBox(width: 8),
        SegmentedButton<PdfPickTool>(
          key: const Key('pdfPickTool'),
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
              value: PdfPickTool.rectangle,
              icon: const Icon(Symbols.crop_din_rounded),
              label: wide ? Text(DefterStrings.pdfPickRectangle) : null,
              tooltip: DefterStrings.pdfPickRectangle,
            ),
            ButtonSegment(
              value: PdfPickTool.lasso,
              icon: const Icon(Symbols.gesture_rounded),
              label: wide ? Text(DefterStrings.pdfPickLasso) : null,
              tooltip: DefterStrings.pdfPickLasso,
            ),
          ],
          selected: {_tool},
          onSelectionChanged: (tools) => setState(() => _tool = tools.first),
        ),
        const SizedBox(width: 4),
        IconButton(
          key: const Key('pdfPickClose'),
          tooltip: DefterStrings.close,
          icon: const Icon(Symbols.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    ),
  );

  Widget _thumbnailStrip(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    return ListView.builder(
      controller: _thumbnails,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      itemCount: _pageCount,
      itemBuilder: (context, index) {
        final pdfPage = widget.document.pages[index];
        final current = index == _page;
        final chosen = _chosenPages.contains(index);
        final aspect = pdfPage.height <= 0
            ? 0.7
            : pdfPage.width / pdfPage.height;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            children: [
              InkWell(
                key: Key('pdfPickThumb-$index'),
                onTap: () => _goTo(index),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(
                      color: current
                          ? colorScheme.primary
                          : colorScheme.outlineVariant,
                      width: current ? 3 : 1,
                    ),
                  ),
                  child: AspectRatio(
                    aspectRatio: aspect,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        IgnorePointer(
                          child: PdfPageView(
                            document: widget.document,
                            pageNumber: index + 1,
                            maximumDpi: 72,
                            decoration: const BoxDecoration(),
                          ),
                        ),
                        if (chosen)
                          ColoredBox(
                            color: colorScheme.primary.withValues(alpha: 0.18),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 32,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Checkbox(
                      key: Key('pdfPickPage-$index'),
                      value: chosen,
                      visualDensity: VisualDensity.compact,
                      onChanged: (_) => _togglePage(index),
                    ),
                    Text('${index + 1}', style: theme.textTheme.labelLarge),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _pageArea(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final pdfPage = _pdfPage;
    final aspect = pdfPage.height <= 0 ? 0.7 : pdfPage.width / pdfPage.height;
    return LayoutBuilder(
      builder: (context, constraints) {
        const padding = 16.0;
        final room = Size(
          math.max(40, constraints.maxWidth - 2 * padding),
          math.max(40, constraints.maxHeight - 2 * padding),
        );
        // The whole page, as large as fits.
        var shown = Size(room.width, room.width / aspect);
        if (shown.height > room.height) {
          shown = Size(room.height * aspect, room.height);
        }
        final drawing = _drawing;
        final beingDrawn = drawing == null ? null : _regionOf(drawing);

        return ClipRect(
          child: InteractiveViewer(
            transformationController: _zoom,
            // One finger or the pen marks; two fingers zoom and move.
            panEnabled: false,
            minScale: 1,
            maxScale: 6,
            child: SizedBox(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              child: Center(
                child: SizedBox.fromSize(
                  size: shown,
                  child: Listener(
                    key: const Key('pdfPickPageArea'),
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: (event) => _onDown(event, shown),
                    onPointerMove: (event) => _onMove(event, shown),
                    onPointerUp: (event) => _onUp(event, shown),
                    onPointerCancel: (event) => _onUp(event, shown),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.shadow.withValues(alpha: 0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          PdfPageView(
                            key: ValueKey('pdfPickPageView-$_page'),
                            document: widget.document,
                            pageNumber: _page + 1,
                            decoration: const BoxDecoration(),
                          ),
                          CustomPaint(
                            painter: _RegionPainter(
                              region: beingDrawn ?? _region,
                              settled: beingDrawn == null,
                              color: colorScheme.primary,
                            ),
                          ),
                          if (_busy)
                            const ColoredBox(
                              color: Color(0x66ffffff),
                              child: Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _footer(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final region = _region;
    final text = _regionText;
    final hasText = text != null && text.trim().isNotEmpty;

    final navigation = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: const Key('pdfPickPrevious'),
          tooltip: DefterStrings.pdfPickPrevious,
          icon: const Icon(Symbols.chevron_left_rounded),
          onPressed: _page > 0 ? () => _goTo(_page - 1) : null,
        ),
        Text(
          '${_page + 1} / $_pageCount',
          key: const Key('pdfPickPageNumber'),
          style: theme.textTheme.titleSmall,
        ),
        IconButton(
          key: const Key('pdfPickNext'),
          tooltip: DefterStrings.pdfPickNext,
          icon: const Icon(Symbols.chevron_right_rounded),
          onPressed: _page < _pageCount - 1 ? () => _goTo(_page + 1) : null,
        ),
        const SizedBox(width: 4),
        FilterChip(
          key: const Key('pdfPickThisPage'),
          label: Text(DefterStrings.pdfPickThisPage),
          selected: _chosenPages.contains(_page),
          onSelected: (_) => _togglePage(_page),
        ),
      ],
    );

    final List<Widget> actions;
    final String hint;
    if (region != null) {
      hint = text == null
          ? DefterStrings.pdfPickReadingText
          : hasText
          ? DefterStrings.pdfPickTextFound(
              text.replaceAll(RegExp(r'\s+'), ' ').trim(),
            )
          : DefterStrings.pdfPickNoText;
      actions = [
        TextButton(
          key: const Key('pdfPickClearRegion'),
          onPressed: _busy ? null : _clearRegion,
          child: Text(DefterStrings.pdfPickClear),
        ),
        IconButton(
          key: const Key('pdfPickCopyText'),
          tooltip: DefterStrings.pdfPickCopy,
          icon: const Icon(Symbols.content_copy_rounded),
          onPressed: hasText && !_busy ? _copyText : null,
        ),
        FilledButton.tonalIcon(
          key: const Key('pdfPickAsText'),
          icon: const Icon(Symbols.text_fields_rounded),
          label: Text(DefterStrings.pdfPickAsText),
          onPressed: hasText && !_busy ? _takeText : null,
        ),
        FilledButton.icon(
          key: const Key('pdfPickAsImage'),
          icon: const Icon(Symbols.image_rounded),
          label: Text(DefterStrings.pdfPickAsImage),
          onPressed: _busy ? null : _takeImage,
        ),
      ];
    } else {
      hint = DefterStrings.pdfPickHint;
      final chosen = _chosenPages.length;
      actions = [
        if (chosen > 0)
          TextButton(
            key: const Key('pdfPickNoPages'),
            onPressed: () => setState(_chosenPages.clear),
            child: Text(DefterStrings.pdfPickClearPages),
          ),
        OutlinedButton(
          key: const Key('pdfPickAllPages'),
          onPressed: () =>
              _takePages([for (var i = 0; i < _pageCount; i++) i]),
          child: Text(DefterStrings.pdfPickAllPages(_pageCount)),
        ),
        FilledButton(
          key: const Key('pdfPickChosenPages'),
          onPressed: chosen > 0 ? () => _takePages(_chosenPages.toList()) : null,
          child: Text(DefterStrings.pdfPickChosenPages(chosen)),
        ),
      ];
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Text(
              hint,
              key: const Key('pdfPickHint'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 4,
            children: [
              navigation,
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: actions,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// What is marked on the page: the rest of the page is dimmed a little, so
/// that it is plain what will be taken.
class _RegionPainter extends CustomPainter {
  const _RegionPainter({
    required this.region,
    required this.settled,
    required this.color,
  });

  final PdfRegion? region;

  /// False while the region is still being drawn.
  final bool settled;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final region = this.region;
    if (region == null) return;
    final path = region.pathIn(size);
    if (settled) {
      canvas.drawPath(
        Path.combine(
          PathOperation.difference,
          Path()..addRect(Offset.zero & size),
          path,
        ),
        Paint()..color = const Color(0x55000000),
      );
    } else {
      canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.12));
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_RegionPainter oldDelegate) =>
      oldDelegate.region != region ||
      oldDelegate.settled != settled ||
      oldDelegate.color != color;
}
