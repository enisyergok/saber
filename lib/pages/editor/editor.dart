import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:collapsible/collapsible.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as flutter_quill;
import 'package:go_router/go_router.dart';
import 'package:keybinder/keybinder.dart';
import 'package:logging/logging.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';
import 'package:saber/components/canvas/_asset_cache.dart';
import 'package:saber/components/canvas/_stroke.dart';
import 'package:saber/components/canvas/canvas.dart';
import 'package:saber/components/canvas/canvas_gesture_detector.dart';
import 'package:saber/components/canvas/canvas_image.dart';
import 'package:saber/components/canvas/image/editor_image.dart';
import 'package:saber/components/canvas/save_indicator.dart';
import 'package:saber/components/editor/editor_tab_strip.dart';
import 'package:saber/components/editor/page_menu.dart';
import 'package:saber/components/editor/page_sidebar.dart';
import 'package:saber/components/editor/read_only_banner.dart';
import 'package:saber/components/theming/adaptive_alert_dialog.dart';
import 'package:saber/components/theming/adaptive_icon.dart';
import 'package:saber/components/theming/dynamic_material_app.dart';
import 'package:saber/components/theming/saber_theme.dart';
import 'package:saber/components/toolbar/color_bar.dart';
import 'package:saber/components/toolbar/editor_bottom_sheet.dart';
import 'package:saber/components/toolbar/editor_page_grid.dart';
import 'package:saber/components/toolbar/editor_page_manager.dart';
import 'package:saber/components/toolbar/toolbar.dart';
import 'package:saber/data/benchmark/pen_latency_probe.dart';
import 'package:saber/data/covers/cover_designs.dart';
import 'package:saber/data/defter_strings.dart';
import 'package:saber/data/editor/editor_core_info.dart';
import 'package:saber/data/editor/editor_exporter.dart';
import 'package:saber/data/editor/editor_history.dart';
import 'package:saber/data/editor/page.dart';
import 'package:saber/data/extensions/change_notifier_extensions.dart';
import 'package:saber/data/extensions/list_extensions.dart';
import 'package:saber/data/extensions/matrix4_extensions.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/notebooks/notebook_spec.dart';
import 'package:saber/data/nextcloud/saber_syncer.dart';
import 'package:saber/data/open_tabs.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/routes.dart';
import 'package:saber/data/tools/_tool.dart';
import 'package:saber/data/versions/note_versions.dart';
import 'package:saber/data/tools/eraser.dart';
import 'package:saber/data/tools/ink_eraser.dart';
import 'package:saber/data/tools/highlighter.dart';
import 'package:saber/data/tools/laser_pointer.dart';
import 'package:saber/data/tools/pen.dart';
import 'package:saber/data/tools/pen_assist.dart';
import 'package:saber/data/tools/pen_boost.dart';
import 'package:saber/data/tools/pencil.dart';
import 'package:saber/components/editor/pen_latency_dialog.dart';
import 'package:saber/components/eink/eink_refresh.dart';
import 'package:saber/components/canvas/eraser_cursor.dart';
import 'package:saber/components/canvas/measure_readout.dart';
import 'package:saber/components/toolbar/pdf_crop_dialog.dart';
import 'package:saber/components/toolbar/note_versions_dialog.dart';
import 'package:saber/components/toolbar/pdf_tools_dialog.dart';
import 'package:saber/components/editor_gn/gn_bar.dart';
import 'package:saber/components/editor_gn/gn_controller.dart';
import 'package:saber/components/editor_gn/gn_overlay.dart';
import 'package:saber/components/toolbar/recognize_dialog.dart';
import 'package:saber/pages/ask_notes.dart';
import 'package:saber/components/toolbar/recordings_dialog.dart';
import 'package:saber/data/pdf/pdf_import.dart';
import 'package:saber/data/pdf/pdf_note_text.dart';
import 'package:saber/data/pdf/pdf_removal.dart';
import 'package:saber/data/pdf/pdf_pick.dart';
import 'package:saber/components/toolbar/pdf_picker_dialog.dart';
import 'package:saber/components/toolbar/pdf_remove_dialog.dart';
import 'package:saber/data/device_camera.dart';
import 'package:saber/data/editor/note_assets.dart';
import 'package:saber/data/editor/note_cover.dart';
import 'package:saber/data/tools/select.dart';
import 'package:saber/data/tools/stylus_action.dart';
import 'package:saber/data/tools/selection_transform.dart';
import 'package:saber/data/tools/shape_pen.dart';
import 'package:saber/data/tools/shape_snap.dart';
import 'package:saber/i18n/strings.g.dart';
import 'package:saber/pages/home/whiteboard.dart';
import 'package:sbn/canvas_background_pattern.dart';
import 'package:sbn/change.dart';
import 'package:super_clipboard/super_clipboard.dart';

typedef _PhotoInfo = ({Uint8List bytes, String extension});

class Editor extends StatefulWidget {
  new({
    super.key,
    String? path,
    this.customTitle,
    this.pdfPath,
    this.imagePath,
  })
    : initialPath = path != null
          ? Future.value(path)
          : FileManager.newFilePath('/'),
      needsNaming = path == null;

  final Future<String> initialPath;
  final bool needsNaming;

  final String? customTitle;
  final String? pdfPath;

  /// An image file to put on the note once it is open (a note started
  /// from a picture).
  final String? imagePath;

  /// The file extension used by the app.
  /// Files with this extension are
  /// encoded in BSON format.
  static const extension = '.sbn2';

  /// The old file extension used by the app.
  /// Files with this extension are
  /// encoded in JSON format.
  static const extensionOldJson = '.sbn';

  static const double gapBetweenPages = 16;

  /// Returns true if [path] belongs to a hidden file
  /// used by other functions of the app
  static bool isReservedPath(String path) {
    return _reservedFilePaths.any((regex) => regex.hasMatch(path));
  }

  static final _reservedFilePaths = <RegExp>[
    RegExp(RegExp.escape(Whiteboard.filePath)),
  ];

  /// Whether the platform can rasterize a pdf
  static var canRasterPdf = true;

  @override
  State<Editor> createState() => EditorState();
}

class EditorState extends State<Editor> {
  final log = Logger('EditorState');

  late var coreInfo = EditorCoreInfo.placeholder;

  final _canvasGestureDetectorKey = GlobalKey<CanvasGestureDetectorState>();
  final _transformationController = TransformationController();
  double get scrollY {
    final transformation = _transformationController.value;
    final scale = transformation.approxScale;
    final translation = transformation.getTranslation();
    final gestureDetector = _canvasGestureDetectorKey.currentState;

    if (gestureDetector == null) {
      log.warning('scrollY: Could not find CanvasGestureDetectorState');
      return translation.y / scale;
    } else {
      final middle = gestureDetector.containerBounds.maxHeight / 2;
      return (translation.y - middle) / scale + middle;
    }
  }

  var history = EditorHistory();

  late bool needsNaming = widget.needsNaming && stows.editorPromptRename.value;

  late Tool _currentTool = () {
    switch (stows.lastTool.value) {
      case .fountainPen:
        if (Pen.currentPen.toolId != stows.lastTool.value ||
            Pen.currentPen.variant.index != stows.lastPenVariant.value) {
          Pen.currentPen = switch (stows.lastPenVariant.value) {
            1 => Pen.brushPen(),
            2 => Pen.calligraphyPen(),
            _ => Pen.fountainPen(),
          };
        }
        return Pen.currentPen;
      case .ballpointPen:
        if (Pen.currentPen.toolId != stows.lastTool.value) {
          Pen.currentPen = Pen.ballpointPen();
        }
        return Pen.currentPen;
      case .shapePen:
        if (Pen.currentPen.toolId != stows.lastTool.value) {
          Pen.currentPen = ShapePen();
        }
        return Pen.currentPen;
      case .highlighter:
        return Highlighter.currentHighlighter;
      case .pencil:
        return Pencil.currentPencil;
      case .eraser:
        return Eraser();
      case .select:
        return Select.currentSelect;
      case .textEditing:
        return Tool.textEditing;
      case .laserPointer:
        return LaserPointer.currentLaserPointer;
    }
  }();
  Tool get currentTool => _currentTool;
  set currentTool(Tool tool) {
    _toolBeforeImageTap = null;
    if (!identical(tool, _currentTool)) _previousTool = _currentTool;
    _currentTool = tool;
    if (tool is! Eraser) _lastNonEraserTool = tool;
    stows.lastTool.value = tool.toolId;
    if (tool is Pen && tool.toolId == .fountainPen) {
      stows.lastPenVariant.value = tool.variant.index;
    }
  }

  ValueNotifier<SavingState> savingState = ValueNotifier(SavingState.saved);
  Timer? _delayedSaveTimer;
  Timer? _watchServerTimer;

  // used to prevent accidentally drawing when pinch zooming
  var lastSeenPointerCount = 0;
  Timer? _lastSeenPointerCountTimer;

  ValueNotifier<QuillStruct?> quillFocus = ValueNotifier(null);

  /// The tool that was in use before [currentTool].
  Tool? _previousTool;

  final _stylusTaps = StylusTapCounter();
  final _stylusClock = Stopwatch()..start();
  StreamSubscription<void>? _nativeStylusSub;
  int _lastNativeStylusMs = -100000;

  /// The pen's double tap arrived from the Android side (see
  /// [NativeStylusPress]). Quick repeats count as one.
  void _onNativeStylusPress(void _) {
    if (!mounted || ModalRoute.of(context)?.isCurrent == false) return;
    final now = _stylusClock.elapsedMilliseconds;
    final isRepeat = now - _lastNativeStylusMs < NativeStylusPress.mergeMs;
    _lastNativeStylusMs = now;
    if (isRepeat) return;
    final action = StylusAction.fromIndex(stows.stylusAction.value);
    if (action == StylusAction.none) return;
    performStylusAction(action);
  }

  /// The last non-Eraser [currentTool] value.
  late Tool _lastNonEraserTool = Pen.currentPen;

  /// If the stylus button is pressed, or was pressed, during the current draw gesture.
  ///
  /// For now, this also includes when an [PointerDeviceKind.inverseStylus] is
  /// used since the stylus rear-end and stylus button currently act the same.
  /// If we add customized button bindings, we may have to separate this again.
  var stylusButtonWasPressed = false;

  @override
  void initState() {
    DynamicMaterialApp.addFullscreenListener(_setState);
    _transformationController.addListener(_scheduleVisiblePageUpdate);
    OpenTabs.paths.addListener(_setState);
    stows.editorPageSidebar.addListener(_setState);
    stows.penProbe.addListener(_setState);
    _visiblePageIndex.addListener(_onVisiblePageChanged);
    EInkRefresh.isWriting = () => Pen.currentStroke != null;

    _initAsync();
    _assignKeybindings();
    HardwareKeyboard.instance.addHandler(_handleStylusKey);
    NativeStylusPress.init();
    _nativeStylusSub = NativeStylusPress.presses.listen(_onNativeStylusPress);

    super.initState();
  }

  void _initAsync() async {
    final filePath = await widget.initialPath;
    filenameTextEditingController.text = p.basename(filePath);

    if (_usesTabs) {
      _tabPath = filePath;
      OpenTabs.open(filePath);
    }

    if (needsNaming) {
      filenameTextEditingController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: filenameTextEditingController.text.length,
      );
    }

    await _loadCoreInfo(filePath);
    // The note as it was found, so that it can be brought back whatever is
    // done to it now.
    unawaited(NoteVersions.snapshot(filePath, reason: NoteVersion.reasonOpen));
    // Opening a note scrolls to its page: that is not a page turn.
    _eInkPageTurnsFrom = DateTime.now().add(const Duration(milliseconds: 1500));

    // Notes of earlier versions hold a copy of a PDF for each of its
    // pages: they are found here and given up with the next save.
    unawaited(_sharePdfCopies(coreInfo));

    // A notebook that was just made in the new notebook screen.
    final spec = PendingNotebook.take(filePath);
    if (spec != null) await applyNotebookSpec(spec);

    if (widget.pdfPath != null) {
      await openPdfWindow(widget.pdfPath!);
    }
    if (widget.imagePath != null) {
      await _addImageFromPath(widget.imagePath!);
    }
  }

  Future<void> _sharePdfCopies(EditorCoreInfo loaded) async {
    if (loaded.readOnly) return;
    try {
      await NoteAssets.shareIdenticalPdfs(loaded);
    } catch (e, st) {
      // The note works as it is; it only takes more room.
      log.warning('Could not look for copies of PDFs: $e', e, st);
    }
  }

  /// Gives a new, still empty note the paper, size, colour and cover that
  /// were chosen for it. A note that already has something on it is left
  /// as it is.
  Future<void> applyNotebookSpec(NotebookSpec spec) async {
    if (coreInfo.readOnly || !mounted) return;
    if (coreInfo.pages.any((page) => !page.isEmpty)) return;

    final size = spec.pageSize;
    for (final page in coreInfo.pages) {
      page.dispose();
    }
    coreInfo.pages.clear();
    final page = EditorPage(size: size);
    coreInfo.pages.add(page);
    listenToQuillChanges(page.quill, 0);
    coreInfo
      ..backgroundPattern = spec.template.pattern
      ..lineHeight = spec.template.lineHeight
      ..backgroundColor = spec.paperColor;
    // New notes start on the paper that was last chosen.
    stows.lastBackgroundPattern.value = spec.template.pattern;
    stows.lastLineHeight.value = spec.template.lineHeight;

    final cover = spec.cover;
    if (cover != null) {
      // A notebook without a name of its own gets a cover without one.
      coreInfo.cover = NoteCover(designId: cover.id, title: spec.name.trim());
      // A notebook with a cover is one already, before anything is written.
      history.markUnsaved();
    }
    if (mounted) {
      setState(() {});
      autosaveAfterDelay();
    }
  }

  Future<void> _addImageFromPath(String imagePath) async {
    try {
      final bytes = await File(imagePath).readAsBytes();
      if (!mounted) return;
      await _pickPhotos([(bytes: bytes, extension: p.extension(imagePath))]);
    } on FileSystemException catch (e) {
      log.warning('Could not read the image at $imagePath', e);
    }
  }

  Future _loadCoreInfo(String filePath) async {
    final loaded = await EditorCoreInfo.loadFromFilePath(filePath);
    // A notebook from when the cover was its first page: the cover goes
    // onto the card, where it belongs, before the pages are shown.
    final adoptedCover = await NoteCover.adoptCoverPage(loaded);
    coreInfo = loaded;
    _coverPictureWritten = null;
    if (adoptedCover) {
      log.info('Took the cover out of the pages of $filePath');
      history.markUnsaved();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && identical(coreInfo, loaded)) autosaveAfterDelay();
      });
    }
    if (coreInfo.readOnly) {
      log.info('Loaded file as read-only: ${coreInfo.readOnlyReason}');
    }

    for (int pageIndex = 0; pageIndex < coreInfo.pages.length; pageIndex++) {
      listenToQuillChanges(coreInfo.pages[pageIndex].quill, pageIndex);
    }

    if (coreInfo.isEmpty) {
      createPage(-1);
    } else {
      for (final page in coreInfo.pages) {
        page.backgroundImage?.onMoveImage = onMoveImage;
        page.backgroundImage?.onDeleteImage = onDeleteImage;
        page.backgroundImage?.onMiscChange = autosaveAfterDelay;
        for (final image in page.images) {
          image.onMoveImage = onMoveImage;
          image.onDeleteImage = onDeleteImage;
          image.onMiscChange = autosaveAfterDelay;
        }
      }
    }

    if (currentTool == Tool.textEditing) {
      int pageIndex;
      if (coreInfo.initialPageIndex != null) {
        pageIndex = coreInfo.initialPageIndex!;
      } else {
        pageIndex = 0;
      }
      assert(pageIndex < coreInfo.pages.length);

      quillFocus.value = coreInfo.pages[pageIndex].quill
        ..focusNode.requestFocus();
    }

    if (coreInfo.filePath == Whiteboard.filePath &&
        stows.autoClearWhiteboardOnExit.value &&
        Whiteboard.needsToAutoClearWhiteboard) {
      // clear whiteboard (and add to history)
      clearAllPages();

      // save cleared whiteboard
      await saveToFile();
      Whiteboard.needsToAutoClearWhiteboard = false;
    } else {
      setState(() {});
    }
  }

  void _setState() => setState(() {});

  Keybinding? _ctrlZ, _ctrlY, _ctrlShiftZ;
  void _assignKeybindings() {
    _ctrlZ = Keybinding([
      KeyCode.ctrl,
      KeyCode.from(LogicalKeyboardKey.keyZ),
    ], inclusive: true);
    _ctrlY = Keybinding([
      KeyCode.ctrl,
      KeyCode.from(LogicalKeyboardKey.keyY),
    ], inclusive: true);
    _ctrlShiftZ = Keybinding([
      KeyCode.ctrl,
      KeyCode.shift,
      KeyCode.from(LogicalKeyboardKey.keyZ),
    ], inclusive: true);
    Keybinder.bind(_ctrlZ!, undo);
    Keybinder.bind(_ctrlY!, redo);
    Keybinder.bind(_ctrlShiftZ!, redo);
  }

  /// Stylus button key events (Android sends the pen's button or double tap
  /// this way) run the action chosen in the settings.
  bool _handleStylusKey(KeyEvent event) {
    if (!StylusKeys.isStylusKey(event.logicalKey.keyId)) return false;
    if (!mounted || ModalRoute.of(context)?.isCurrent == false) return false;
    if (event is! KeyDownEvent) return true;

    final action = StylusAction.fromIndex(stows.stylusAction.value);
    if (action == StylusAction.none) return false;
    final triggered = _stylusTaps.press(
      _stylusClock.elapsedMilliseconds,
      needed: stows.stylusTapsNeeded.value,
    );
    if (triggered) performStylusAction(action);
    return true;
  }

  /// Runs [action], unless a stroke is being drawn right now.
  void performStylusAction(StylusAction action) {
    if (Pen.currentStroke != null) return;

    switch (action) {
      case .none:
        return;
      case .toggleEraser:
        _toggleTool(Eraser(), (tool) => tool is Eraser);
      case .lasso:
        _toggleTool(Select.currentSelect, (tool) => tool is Select);
      case .highlighter:
        _toggleTool(
          Highlighter.currentHighlighter,
          (tool) => tool is Highlighter,
        );
      case .previousTool:
        final previous = _previousTool;
        if (previous != null) currentTool = previous;
      case .undo:
        if (!coreInfo.readOnly) undo();
      case .redo:
        if (!coreInfo.readOnly) redo();
    }
    if (mounted) setState(() {});
  }

  /// Switches to [target], or back to the tool used before it if
  /// [isTarget] says it is already in use.
  void _toggleTool(Tool target, bool Function(Tool) isTarget) {
    if (!isTarget(currentTool)) {
      currentTool = target;
      return;
    }
    final previous = _previousTool;
    if (previous != null && !isTarget(previous)) {
      currentTool = previous;
    } else if (!isTarget(_lastNonEraserTool)) {
      currentTool = _lastNonEraserTool;
    } else {
      currentTool = Pen.currentPen;
    }
  }

  void _removeKeybindings() {
    if (_ctrlZ != null) Keybinder.remove(_ctrlZ!);
    if (_ctrlY != null) Keybinder.remove(_ctrlY!);
    if (_ctrlShiftZ != null) Keybinder.remove(_ctrlShiftZ!);
  }

  /// Creates pages until the given page index exists,
  /// plus an extra blank page
  void createPage(int pageIndex) {
    while (pageIndex >= coreInfo.pages.length - 1) {
      final page = EditorPage(size: _sizeForPageAfter(coreInfo.pages.length - 1));
      coreInfo.pages.add(page);
      listenToQuillChanges(page.quill, coreInfo.pages.length - 1);
    }
  }

  /// The size of a page added after the page at [index]: the same as that
  /// page, so a notebook keeps the format it was made in. Pages of an
  /// imported PDF have sizes of their own, so the page after one of those
  /// (and the first page of a note) gets the usual size.
  Size _sizeForPageAfter(int index) {
    final before = coreInfo.pages.getOrNull(index);
    if (before == null || before.backgroundImage is PdfEditorImage) {
      return EditorPage.defaultSize;
    }
    return before.size;
  }

  void removeExcessPages() {
    bool removedAPage = false;

    // remove excess pages if all pages >= this one are empty
    for (int i = coreInfo.pages.length - 1; i >= 1; --i) {
      final thisPage = coreInfo.pages[i];
      final prevPage = coreInfo.pages[i - 1];
      if (thisPage.isEmpty && prevPage.isEmpty) {
        final page = coreInfo.pages.removeAt(i);
        page.dispose();
        removedAPage = true;
      } else {
        break;
      }
    }

    if (removedAPage) {
      // scroll to the last page (only if we're below the last page)

      final scrollY = this.scrollY;
      late final topOfLastPage = -CanvasGestureDetector.getTopOfPage(
        pageIndex: coreInfo.pages.length - 1,
        pages: coreInfo.pages,
        screenWidth: _viewportWidth,
      );
      final bottomOfLastPage = -CanvasGestureDetector.getTopOfPage(
        pageIndex: coreInfo.pages.length,
        pages: coreInfo.pages,
        screenWidth: _viewportWidth,
      );

      if (scrollY < bottomOfLastPage) {
        _transformationController.value = Matrix4.translationValues(
          0,
          // Slight upwards offset so that the page is not flush with the top of the screen
          topOfLastPage + 50,
          0,
        );
      }
    }
  }

  void undo([EditorHistoryItem? item]) {
    if (item == null) {
      if (!history.canUndo) return;

      // if we disabled redo, re-enable it
      if (!history.canRedo) {
        // no redo is possible, so clear the redo stack
        history.clearRedo();
        // don't disable redoing anymore
        history.canRedo = true;
      }

      item = history.undo();
    }

    setState(() {
      switch (item!.type) {
        case .draw:
          for (final stroke in item.strokes) {
            coreInfo.pages[stroke.pageIndex].strokes.remove(stroke);
          }
          for (final image in item.images) {
            coreInfo.pages[image.pageIndex].images.remove(image);
          }
          removeExcessPages();

        case .erase:
          for (final stroke in item.strokes) {
            createPage(stroke.pageIndex);
            coreInfo.pages[stroke.pageIndex].insertStroke(stroke);
          }
          for (final image in item.images) {
            createPage(image.pageIndex);
            coreInfo.pages[image.pageIndex].images.add(image);
            image.newImage = true;
          }

        case .deletePage:
          // make sure we already have a (blank/otherwise) page at this index
          createPage(item.pageIndex - 1);

          // insert the page at the correct index
          coreInfo.pages.insert(item.pageIndex, item.page!);

          // every page from here on has moved one place
          _renumberPages();

        case .insertPage:
          // remove the page at the given index
          coreInfo.pages.removeAt(item.pageIndex);
          // (a notebook is never without a page)
          createPage(-1);

          // every page from here on has moved one place
          _renumberPages();

        case .move:
          for (final stroke in item.strokes) {
            stroke.shift(Offset(-item.offset!.left, -item.offset!.top));
          }
          final select = Select.currentSelect;
          if (select.doneSelecting) {
            select.selectResult.path = select.selectResult.path.shift(
              Offset(-item.offset!.left, -item.offset!.top),
            );
          }
          for (final image in item.images) {
            final turns = item.imageTurns;
            if (turns != null) image.quarterTurns -= turns;
            image.dstRect = .fromLTRB(
              image.dstRect.left - item.offset!.left,
              image.dstRect.top - item.offset!.top,
              image.dstRect.right - item.offset!.right,
              image.dstRect.bottom - item.offset!.bottom,
            );
          }

        case .transform:
          final inverse = SelectionTransform.inverse(item.transform!);
          for (final stroke in item.strokes) {
            stroke.transform(inverse);
          }
          if (!SelectionTransform.hasRotation(inverse)) {
            for (final image in item.images) {
              image.dstRect = Rect.fromPoints(
                MatrixUtils.transformPoint(inverse, image.dstRect.topLeft),
                MatrixUtils.transformPoint(inverse, image.dstRect.bottomRight),
              );
            }
          }
          final select = Select.currentSelect;
          if (select.doneSelecting) {
            select.selectResult.path = select.selectResult.path.transform(
              inverse.storage,
            );
          }

        case .reshape:
          item.reshapeChange!.forEach((stroke, change) {
            stroke.setVertexHandles(change.previous);
          });

        case .quillChange:
          final quill = coreInfo.pages[item.pageIndex].quill;
          quill.controller.undo();

        case .quillUndoneChange:
          final quill = coreInfo.pages[item.pageIndex].quill;
          quill.controller.redo();

        case .changeColor:
          for (final stroke in item.strokes) {
            stroke.color = item.colorChange![stroke]!.previous;
          }

        case .backgroundPattern:
          coreInfo.backgroundPattern = item.backgroundPatternChange!.previous;

        case .replace:
          // Last to first: each stroke goes back in front of the one that
          // followed it, which is back already.
          for (final change in item.replacements!.reversed) {
            createPage(change.before.pageIndex);
            final page = coreInfo.pages[change.before.pageIndex];
            final strokes = page.strokes;
            change.after.forEach(strokes.remove);
            final next = change.next;
            final at = next == null ? -1 : strokes.indexOf(next);
            if (at >= 0) {
              strokes.insert(at, change.before);
            } else if (next == null) {
              strokes.add(change.before);
            } else {
              page.insertStroke(change.before);
            }
          }

        case .replaceRedone:
          for (final change in item.replacements!) {
            final strokes = coreInfo.pages[change.before.pageIndex].strokes;
            final at = strokes.indexOf(change.before);
            if (at < 0) continue;
            strokes
              ..removeAt(at)
              ..insertAll(at, change.after);
          }
          removeExcessPages();

        case .removePdf:
          PdfRemover.undo(coreInfo, item.pdfRemoval!);
          _endWithAnEmptyPage();
          removeExcessPages();

        case .removePdfRedone:
          PdfRemover.redo(coreInfo, item.pdfRemoval!);
          _endWithAnEmptyPage();
      }

      if (item.type != .move && item.type != .transform) {
        Select.currentSelect.unselect();
      }
    });

    autosaveAfterDelay();
  }

  void redo() {
    if (!history.canRedo) return;
    final item = history.redo();

    switch (item.type) {
      case .draw:
        undo(item.copyWith(type: .erase));
      case .erase:
        undo(item.copyWith(type: .draw));
      case .deletePage:
        undo(item.copyWith(type: .insertPage));
      case .insertPage:
        undo(item.copyWith(type: .deletePage));
      case .move:
        undo(
          item.copyWith(
            offset: .fromLTRB(
              -item.offset!.left,
              -item.offset!.top,
              -item.offset!.right,
              -item.offset!.bottom,
            ),
            imageTurns: item.imageTurns == null ? null : -item.imageTurns!,
          ),
        );
      case .transform:
        undo(
          item.copyWith(
            transform: SelectionTransform.inverse(item.transform!),
          ),
        );
      case .reshape:
        undo(
          item.copyWith(
            reshapeChange: item.reshapeChange!.map(
              (key, value) => MapEntry(key, value.reverse()),
            ),
          ),
        );
      case .quillChange:
        undo(item.copyWith(type: .quillUndoneChange));
      case .quillUndoneChange: // this will never happen
        throw Exception('history should not contain quillUndoneChange items');
      case .changeColor:
        undo(
          item.copyWith(
            colorChange: item.colorChange!.map(
              (key, value) => MapEntry(key, value.reverse()),
            ),
          ),
        );
      case .backgroundPattern:
        undo(
          item.copyWith(
            backgroundPatternChange: item.backgroundPatternChange!.reverse(),
          ),
        );
      case .replace:
        undo(item.copyWith(type: .replaceRedone));
      case .replaceRedone: // this will never happen
        throw Exception('history should not contain replaceRedone items');
      case .removePdf:
        undo(item.copyWith(type: .removePdfRedone));
      case .removePdfRedone: // this will never happen
        throw Exception('history should not contain removePdfRedone items');
    }
  }

  /// Whether the eraser drag under way rubs out only what it passes over.
  /// Decided when the drag begins, so that changing the setting half way
  /// through doesn't leave it half done.
  bool _erasingPrecisely = false;

  /// Shows the eraser's footprint where it is on screen.
  void _showEraserAt(Offset focalPoint, Eraser eraser, EditorPage page) {
    final box = page.renderBox;
    if (box == null) return;
    // How large the eraser is on screen: its size is in page units.
    final radius =
        (box.localToGlobal(Offset(eraser.size, 0)) -
                box.localToGlobal(Offset.zero))
            .distance;
    EraserCursor.at.value = (centre: focalPoint, radius: radius);
  }

  int? onWhichPageIsFocalPoint(Offset focalPoint) {
    for (int i = 0; i < coreInfo.pages.length; ++i) {
      if (coreInfo.pages[i].renderBox == null) continue;
      final pageBounds = Offset.zero & coreInfo.pages[i].size;
      if (pageBounds.contains(
        coreInfo.pages[i].renderBox!.globalToLocal(focalPoint),
      ))
        return i;
    }
    return null;
  }

  /// The position of the previous draw gesture event.
  /// Used to move a selection.
  Offset previousPosition = .zero;

  /// The total offset of the current move gesture.
  /// Used to record a move in the history.
  Offset moveOffset = .zero;

  var isHovering = true;
  int? dragPageIndex;
  PointerDeviceKind? currentPointerKind;
  double? currentPressure;
  /// The tool that was in use when a picture was tapped with a finger
  /// (which switches to the Select tool so that the picture can be moved
  /// and its buttons used). It is taken up again as soon as anything else
  /// is done on the page, so that the pen writes as before.
  Tool? _toolBeforeImageTap;

  /// A finger that just went down where it does not draw: if it comes up
  /// again at once without having moved the page, it was a tap.
  ({Offset at, Stopwatch since, Matrix4 view})? _fingerDown;

  /// How long a finger may stay down for a tap.
  static const _tapTime = Duration(milliseconds: 350);

  /// The picture at [globalPosition], the topmost if several overlap.
  EditorImage? imageAt(Offset globalPosition) {
    final pageIndex = onWhichPageIsFocalPoint(globalPosition);
    if (pageIndex == null) return null;
    final page = coreInfo.pages[pageIndex];
    final position = page.renderBox!.globalToLocal(globalPosition);
    for (final image in page.images.reversed) {
      if (image.dstRect.contains(position)) return image;
    }
    return null;
  }

  /// A finger tapped the page while a tool other than Select was in use:
  /// if it tapped a picture, that picture becomes the active one.
  void _onFingerTap(Offset globalPosition) {
    if (coreInfo.readOnly || !mounted) return;
    final image = imageAt(globalPosition);
    if (image == null) return;
    final before = currentTool;
    setState(() {
      currentTool = Select.currentSelect;
      _toolBeforeImageTap = before;
    });
    // Once the picture has been built for the Select tool.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) CanvasImage.requestActive.value = image;
    });
  }

  bool isDrawGesture(ScaleStartDetails details) {
    if (coreInfo.readOnly) return false;

    CanvasImage.activeListener
        .notifyListenersPlease(); // un-select active image

    _fingerDown = null;
    // The picture that was tapped is let go: back to the tool from before.
    final toolBefore = _toolBeforeImageTap;
    if (toolBefore != null) {
      _toolBeforeImageTap = null;
      if (currentTool is Select && !Select.currentSelect.doneSelecting) {
        setState(() => currentTool = toolBefore);
      }
    }

    _lastSeenPointerCountTimer?.cancel();
    if (lastSeenPointerCount >= 2) {
      // was a zoom gesture, ignore
      lastSeenPointerCount = lastSeenPointerCount;
      return false;
    } else if (details.pointerCount >= 2) {
      // is a zoom gesture, remove accidental stroke
      if (lastSeenPointerCount == 1 &&
          stows.editorFingerDrawing.value &&
          (currentTool is Pen || currentTool is Eraser)) {
        final item = history.removeAccidentalStroke();
        if (item != null) undo(item);
      }
      lastSeenPointerCount = details.pointerCount;
      return false;
    } else {
      // is a stroke
      lastSeenPointerCount = details.pointerCount;
    }

    dragPageIndex = onWhichPageIsFocalPoint(details.focalPoint);
    if (dragPageIndex == null) return false;

    if (currentTool == Tool.textEditing) {
      return false;
    } else if (stows.editorFingerDrawing.value ||
        currentPointerKind == PointerDeviceKind.stylus ||
        currentPointerKind == PointerDeviceKind.invertedStylus ||
        currentPressure != null) {
      return true;
    } else {
      log.fine('Non-stylus found, rejected stroke');
      // A finger that does not draw may be tapping a picture.
      if (details.pointerCount == 1 && currentTool is! Select) {
        _fingerDown = (
          at: details.focalPoint,
          since: Stopwatch()..start(),
          view: _transformationController.value.clone(),
        );
      }
      return false;
    }
  }

  void onDrawStart(ScaleStartDetails details) {
    final page = coreInfo.pages[dragPageIndex!];
    final position = page.renderBox!.globalToLocal(details.focalPoint);
    history.canRedo = false;

    if (currentTool is Pen) {
      unawaited(PenBoost.start());
      ShapeSnap.redraw = page.redrawLiveInk;
      PenAssist.readoutAt.value = details.focalPoint;
      (currentTool as Pen).onDragStart(
        position,
        page,
        dragPageIndex!,
        currentPressure,
        at: details.sourceTimeStamp,
      );
    } else if (currentTool is Eraser) {
      final eraser = currentTool as Eraser;
      _showEraserAt(details.focalPoint, eraser, page);
      if (Eraser.precise) {
        _erasingPrecisely = true;
        eraser
          ..beginPrecise(page.strokes)
          ..erasePrecise(position, page.strokes);
      } else {
        _erasingPrecisely = false;
        for (final stroke in eraser.checkForOverlappingStrokes(
          position,
          page.strokes,
        )) {
          page.strokes.remove(stroke);
        }
      }
      removeExcessPages();
    } else if (currentTool is Select) {
      final select = currentTool as Select;
      _activeHandle = null;
      _transformTotal = null;
      _activeVertex = null;
      _vertexBefore = null;
      if (select.doneSelecting &&
          select.selectResult.pageIndex == dragPageIndex! &&
          (_activeVertex = SelectionTransform.vertexAt(
                select.selectResult,
                position,
                _transformationController.value.approxScale,
              )) !=
              null) {
        _vertexBefore = select.selectResult.strokes.first.vertexHandles;
      } else if (select.doneSelecting &&
          select.selectResult.pageIndex == dragPageIndex! &&
          (_activeHandle = SelectionTransform.handleAt(
                select.selectResult,
                position,
                _transformationController.value.approxScale,
              )) !=
              null) {
        final bounds = SelectionTransform.contentBounds(select.selectResult)!;
        _transformCenter = bounds.center;
        _transformAnchor = bounds.topLeft;
        _transformTotal = Matrix4.identity();
        _transformScale = 1;
      } else if (select.doneSelecting &&
          select.selectResult.pageIndex == dragPageIndex! &&
          select.selectResult.path.contains(position)) {
        // drag selection in onDrawUpdate
      } else {
        select.onDragStart(position, dragPageIndex!);
        history.canRedo = true; // selection doesn't affect history
      }
    } else if (currentTool is LaserPointer) {
      (currentTool as LaserPointer).onDragStart(position, page, dragPageIndex!);
    }

    previousPosition = position;
    moveOffset = .zero;

    if (currentTool is! Select) {
      Select.currentSelect.unselect();
    }

    // setState to let canvas know about currentStroke
    setState(() {});
  }

  SelectHandle? _activeHandle;

  /// The corner of a selected shape being dragged, and the corners before.
  int? _activeVertex;
  List<Offset>? _vertexBefore;
  Matrix4? _transformTotal;
  Offset _transformCenter = .zero;
  Offset _transformAnchor = .zero;
  double _transformScale = 1;

  void onDrawUpdate(ScaleUpdateDetails details) {
    final page = coreInfo.pages[dragPageIndex!];
    final position = page.renderBox!.globalToLocal(details.focalPoint);
    final offset = position - previousPosition;

    if (currentTool is Pen) {
      if (stows.measureMode.value || stows.angleGuide.value) {
        PenAssist.readoutAt.value = details.focalPoint;
      }
      (currentTool as Pen).onDragUpdate(
        position,
        currentPressure,
        at: details.sourceTimeStamp,
      );
      page.redrawLiveInk();
    } else if (currentTool is Eraser) {
      final eraser = currentTool as Eraser;
      _showEraserAt(details.focalPoint, eraser, page);
      if (_erasingPrecisely) {
        eraser.erasePrecise(position, page.strokes);
      } else {
        for (final stroke in eraser.checkForOverlappingStrokes(
          position,
          page.strokes,
        )) {
          page.strokes.remove(stroke);
        }
      }
      page.redrawStrokes();
      removeExcessPages();
    } else if (currentTool is Select) {
      final select = currentTool as Select;
      if (select.doneSelecting && _activeVertex != null) {
        final stroke = select.selectResult.strokes.first;
        final vertices = stroke.vertexHandles;
        if (vertices != null && _activeVertex! < vertices.length) {
          vertices[_activeVertex!] = position;
          stroke.setVertexHandles(vertices);
          select.selectResult.path = Path()
            ..addRect(stroke.bounds.inflate(12));
        }
        page.redrawStrokes();
      } else if (select.doneSelecting && _activeHandle != null) {
        final step = _activeHandle == SelectHandle.scale
            ? SelectionTransform.scaleStep(
                anchor: _transformAnchor,
                previous: previousPosition,
                current: position,
                totalScaleSoFar: _transformScale,
              )
            : SelectionTransform.rotateStep(
                center: _transformCenter,
                previous: previousPosition,
                current: position,
              );
        if (step != null) {
          SelectionTransform.apply(select.selectResult, step);
          _transformTotal = step * _transformTotal!;
          _transformScale *= SelectionTransform.scaleOf(step);
        }
        page.redrawStrokes();
      } else if (select.doneSelecting) {
        for (final stroke in select.selectResult.strokes) {
          stroke.shift(offset);
        }
        for (final image in select.selectResult.images) {
          image.dstRect = image.dstRect.shift(offset);
        }
        select.selectResult.path = select.selectResult.path.shift(offset);
      } else {
        select.onDragUpdate(position);
      }
      page.redrawStrokes();
    } else if (currentTool is LaserPointer) {
      (currentTool as LaserPointer).onDragUpdate(position);
      page.redrawLiveInk();
    }
    previousPosition = position;
    moveOffset += offset;
  }

  void onDrawEnd(ScaleEndDetails details) {
    final page = coreInfo.pages[dragPageIndex!];
    bool shouldSave = true;
    EraserCursor.at.value = null;
    unawaited(PenBoost.stop());
    setState(() {
      if (currentTool is Pen) {
        final pen = currentTool as Pen;
        var newStroke = pen.onDragEnd();
        if (newStroke == null || newStroke.isEmpty) {
          PenAssist.showReadout(null);
          return;
        }

        final recognise = pen.usesAssists && !ShapeSnap.lastWasSnapped;
        // The angle guide and dimensions are for straight lines, so with
        // either of them on a line drawn straight is made straight, whether
        // or not lines are straightened otherwise; dimensions are for
        // circles and rectangles too, so those are recognised with them.
        final technical =
            stows.angleGuide.value || stows.dimensionMode.value;
        if (recognise &&
            ((stows.autoStraightenLines.value || technical) &&
                    newStroke.isStraightLine() ||
                technical && PenAssist.isLine(newStroke))) {
          newStroke.convertToLine();
        } else if (recognise &&
            (stows.autoShapes.value || stows.dimensionMode.value)) {
          newStroke = PenAssist.autoShape(
            newStroke,
            tidy: stows.shapeAutoCorrect.value,
          );
        }
        // The angle guide, measuring and dimensions of the pen panel.
        final extras = pen.usesAssists
            ? PenAssist.finish(
                newStroke,
                angleGuide: stows.angleGuide.value,
                dimensions: stows.dimensionMode.value,
                measure: stows.measureMode.value,
              )
            : const <Stroke>[];
        if (stows.shapeSnapEndpoints.value) {
          ShapeSnap.snapToEndpoints(newStroke, page.strokes);
        }

        createPage(newStroke.pageIndex);
        page.insertStroke(newStroke);
        for (final extra in extras) {
          page.insertStroke(extra);
        }
        history.recordChange(
          EditorHistoryItem(
            type: .draw,
            pageIndex: dragPageIndex!,
            strokes: [newStroke, ...extras],
            images: [],
          ),
        );
      } else if (currentTool is Eraser) {
        final eraser = currentTool as Eraser;
        final erased = eraser.onDragEnd();
        final replaced = _erasingPrecisely
            ? eraser.endPrecise()
            : const <StrokeReplacement>[];
        _erasingPrecisely = false;
        EraserCursor.at.value = null;
        if (stylusButtonWasPressed || stows.disableEraserAfterUse.value) {
          // restore previous tool
          stylusButtonWasPressed = false;
          currentTool = _lastNonEraserTool;
        }
        if (replaced.isNotEmpty) {
          // What the eraser passed over is gone; what is left of each
          // stroke took the stroke's place.
          history.recordChange(
            EditorHistoryItem(
              type: .replace,
              pageIndex: dragPageIndex!,
              strokes: [for (final change in replaced) change.before],
              images: [],
              replacements: replaced,
            ),
          );
          return;
        }
        if (erased.isEmpty) return;
        history.recordChange(
          EditorHistoryItem(
            type: .erase,
            pageIndex: dragPageIndex!,
            strokes: erased,
            images: [],
          ),
        );
      } else if (currentTool is Select) {
        final select = currentTool as Select;
        if (_activeVertex != null) {
          final before = _vertexBefore;
          _activeVertex = null;
          _vertexBefore = null;
          if (select.selectResult.strokes.isEmpty) return;
          final stroke = select.selectResult.strokes.first;
          if (stows.shapeSnapEndpoints.value) {
            final others = page.strokes;
            ShapeSnap.snapToEndpoints(stroke, others);
            select.selectResult.path = Path()
              ..addRect(stroke.bounds.inflate(12));
          }
          final after = stroke.vertexHandles;
          if (before == null || after == null) return;
          var same = before.length == after.length;
          for (var i = 0; same && i < before.length; i++) {
            same = before[i] == after[i];
          }
          if (same) return;
          history.recordChange(
            EditorHistoryItem(
              type: .reshape,
              pageIndex: dragPageIndex!,
              strokes: [stroke],
              images: const [],
              reshapeChange: {
                stroke: Change(previous: before, current: after),
              },
            ),
          );
          return;
        }
        if (_activeHandle != null) {
          final total = _transformTotal;
          _activeHandle = null;
          _transformTotal = null;
          if (total == null || total.isIdentity()) return;
          history.recordChange(
            EditorHistoryItem(
              type: .transform,
              pageIndex: dragPageIndex!,
              strokes: List.of(select.selectResult.strokes),
              images: List.of(select.selectResult.images),
              transform: total,
            ),
          );
          return;
        }
        if (moveOffset == .zero) return;
        if (select.doneSelecting) {
          history.recordChange(
            EditorHistoryItem(
              type: .move,
              pageIndex: dragPageIndex!,
              strokes: select.selectResult.strokes,
              images: select.selectResult.images,
              offset: .fromLTRB(
                moveOffset.dx,
                moveOffset.dy,
                moveOffset.dx,
                moveOffset.dy,
              ),
            ),
          );
        } else {
          shouldSave = false;
          select.onDragEnd(page.strokes, page.images);

          if (select.selectResult.isEmpty) {
            Select.currentSelect.unselect();
          }
        }
      } else if (currentTool is LaserPointer) {
        shouldSave = false;
        final newStroke = (currentTool as LaserPointer).onDragEnd(
          page.redrawLiveInk,
          (Stroke stroke) {
            page.laserStrokes.remove(stroke);
          },
        );
        if (newStroke != null) page.laserStrokes.add(newStroke);
      }
    });

    if (shouldSave) autosaveAfterDelay();
  }

  void onInteractionEnd(ScaleEndDetails details) {
    final finger = _fingerDown;
    _fingerDown = null;
    if (finger != null && finger.since.elapsed <= _tapTime) {
      final now = _transformationController.value;
      final moved =
          (now.getTranslation() - finger.view.getTranslation()).length;
      final zoomed = (now.entry(0, 0) - finger.view.entry(0, 0)).abs();
      if (moved < 6 && zoomed < 0.001) _onFingerTap(finger.at);
    }

    // reset after 1ms to keep track of the same gesture only
    _lastSeenPointerCountTimer?.cancel();
    _lastSeenPointerCountTimer = Timer(const Duration(milliseconds: 10), () {
      lastSeenPointerCount = 0;
    });
  }

  void updatePointerData(PointerDeviceKind kind, double? pressure) {
    currentPointerKind = kind;
    currentPressure = pressure;
  }

  void onHovering() {
    isHovering = true;
  }

  void onHoveringEnd() {
    isHovering = false;
  }

  void onStylusButtonChanged(bool buttonIsPressed) {
    stylusButtonWasPressed |= buttonIsPressed;

    if (!isHovering) return;
    if (buttonIsPressed) {
      // button pressed while hovering, switch to Eraser
      if (currentTool is! Eraser) {
        currentTool = Eraser();
      }
    } else {
      // button was released while hovering, switch back to non-Eraser
      if (currentTool is Eraser) {
        currentTool = _lastNonEraserTool;
      }
    }

    if (mounted) setState(() {});
  }

  void onMoveImage(EditorImage image, Rect offset) {
    // A picture that was turned was given a new box as well.
    final turns = image.takeUnreportedTurns();
    history.recordChange(
      EditorHistoryItem(
        type: .move,
        pageIndex: image.pageIndex,
        strokes: [],
        images: [image],
        offset: offset,
        imageTurns: turns == 0 ? null : turns,
      ),
    );
    // setState to update undo button
    setState(() {});
    autosaveAfterDelay();
  }

  void onDeleteImage(EditorImage image) {
    history.recordChange(
      EditorHistoryItem(
        type: .erase,
        pageIndex: image.pageIndex,
        strokes: [],
        images: [image],
      ),
    );
    setState(() {
      coreInfo.pages[image.pageIndex].images.remove(image);
    });
    autosaveAfterDelay();
  }

  void listenToQuillChanges(QuillStruct quill, int pageIndex) {
    quill.changeSubscription?.cancel();
    quill.changeSubscription = quill.controller.changes.listen((event) {
      final undoRedoButtonsNeedUpdating = !history.canUndo || history.canRedo;
      _addQuillChangeToHistory(
        quill: quill,
        pageIndex: pageIndex,
        event: event,
      );
      createPage(pageIndex); // create empty last page
      if (undoRedoButtonsNeedUpdating) {
        setState(() {});
      }
      autosaveAfterDelay();
    });
    quill.focusNode
      ..removeListener(_onQuillFocusChange)
      ..addListener(_onQuillFocusChange);
  }

  /// Gives every page its place again after pages were put in, taken out
  /// or moved: the page number its strokes and pictures carry (undo goes
  /// by it), and the page its text reports changes for.
  void _renumberPages() {
    for (var i = 0; i < coreInfo.pages.length; i++) {
      final page = coreInfo.pages[i];
      page.updatePageIndex(i);
      listenToQuillChanges(page.quill, i);
    }
  }

  void _onQuillFocusChange() {
    for (final page in coreInfo.pages) {
      if (!page.quill.focusNode.hasFocus) continue;
      quillFocus.value = page.quill;
    }
  }

  void _addQuillChangeToHistory({
    required QuillStruct quill,
    required int pageIndex,
    required flutter_quill.DocChange event,
  }) {
    final eventWasUndo = quill.controller.hasRedo;
    if (eventWasUndo) return;

    // the change subscription sometimes fires multiple times for the same change
    // so compare the "before" of each change to merge them
    if (history.canUndo && !history.canRedo) {
      final lastChange = history.peekUndo();
      if (lastChange.type == .quillChange &&
          lastChange.pageIndex == pageIndex &&
          lastChange.quillChange!.before == event.before) {
        history.undo(); // remove the last change, to be replaced
      }
    }

    history.recordChange(
      EditorHistoryItem(
        type: .quillChange,
        pageIndex: pageIndex,
        strokes: const [],
        images: const [],
        quillChange: event,
      ),
    );
  }

  void _refreshCurrentNote() async {
    if (coreInfo.readOnlyReason != .watchingServer) return;
    if (!stows.loggedIn) return;

    final relativeFilePath = coreInfo.filePath;
    assert(relativeFilePath.isNotEmpty, 'Cannot refresh unnamed file');
    final syncFile = await SaberSyncFile.relative(
      relativeFilePath + Editor.extension,
    );

    final bestFile = await SaberSyncInterface.getBestFile(
      syncFile,
      onLocalFileNotFound: .local,
      onEqualFiles: .local,
      preferCache: false,
    );
    if (bestFile != .remote) return;

    late final StreamSubscription<SaberSyncFile> subscription;
    void listener(SaberSyncFile transferred) {
      if (transferred != syncFile) return;
      subscription.cancel();
      _loadCoreInfo(relativeFilePath)
          .then((_) => coreInfo.readOnlyReason = .watchingServer);
    }

    subscription = syncer.downloader.transferStream.listen(listener);

    await syncer.downloader.enqueue(syncFile: syncFile);
    syncer.downloader.bringToFront(syncFile);
  }

  void autosaveAfterDelay() {
    if (history.isCurrentStateSaved) return cancelAutosaveAndMarkSaved();

    late final void Function() callback;

    void startTimer() {
      _delayedSaveTimer?.cancel();
      if (stows.autosaveDelay.value < 0) return;
      _delayedSaveTimer = Timer(
        Duration(milliseconds: stows.autosaveDelay.value),
        callback,
      );
    }

    callback = () {
      if (Pen.currentStroke != null) {
        // don't save yet if the pen is currently drawing
        startTimer();
        return;
      }
      saveToFile();
    };

    savingState.value = .waitingToSave;
    startTimer();
  }

  void cancelAutosaveAndMarkSaved() {
    _delayedSaveTimer?.cancel();
    savingState.value = .saved;
    history.markLastChangeAsSaved();
  }

  Future<void> saveToFile() async {
    if (coreInfo.readOnly) return;

    switch (savingState.value) {
      case .saved:
        // avoid saving if nothing has changed
        return;
      case .saving:
        // avoid saving if already saving
        log.warning('saveToFile() called while already saving');
        return;
      case .waitingToSave:
        // continue
        _delayedSaveTimer?.cancel();
        savingState.value = .saving;
    }
    if (history.isCurrentStateSaved) return cancelAutosaveAndMarkSaved();

    await _renameFileNow();

    final filePath = coreInfo.filePath + Editor.extension;
    // A version of the note is never read while its files are half written.
    final endSave = await NoteVersions.beginSave(filePath);
    try {
      final Uint8List bson;
      final OrderedAssetCache assets;
      coreInfo.assetCache.allowRemovingAssets = false;
      try {
        (bson, assets) = coreInfo.saveToBinary(
          currentPageIndex: currentPageIndex,
        );
      } finally {
        coreInfo.assetCache.allowRemovingAssets = true;
      }
      // What undo could bring back (a PDF that was removed, a picture
      // that was deleted) keeps its file for as long as the note is open:
      // it is saved after the assets the note uses, and goes when the
      // note is closed.
      if (mounted) {
        final used = assets.length;
        for (final image in history.imagesKept) {
          final file = image.assetFile;
          if (file != null) assets.add(file, owner: image);
        }
        if (assets.length > used) _keptAssetsForUndo = true;
      }
      try {
        // The pictures and PDFs first, so that the note never points at
        // one that is not there yet. Those that are already in place are
        // not written again.
        final written = await NoteAssets.write(filePath, assets);
        // What was drawn is saved even if a picture could not be.
        await FileManager.writeFile(filePath, bson, awaitWrite: true);
        if (!written.ok) throw written.errors.first;
        // Only now does nothing point at the assets that are left over.
        await FileManager.removeUnusedAssets(
          filePath,
          numAssets: assets.length,
        );
        savingState.value = .saved;
        history.markLastChangeAsSaved();
      } catch (e, st) {
        log.severe('Failed to save file: $e', e, st);
        savingState.value = .waitingToSave;
        if (kDebugMode) rethrow;
        return;
      }
    } finally {
      endSave();
    }

    if (!mounted) {
      // The note was left while it was being saved.
      unawaited(
        NoteVersions.snapshot(filePath, reason: NoteVersion.reasonClose),
      );
      return;
    }
    try {
      // A notebook with a cover shows its cover; any other note its
      // first page.
      final cover = coreInfo.cover;
      if (cover != null && cover.isUsable) {
        if (_coverPictureWritten != cover.signature) {
          final signature = cover.signature;
          final picture = await cover.render();
          if (picture != null) {
            await FileManager.writeFile(
              '$filePath.p',
              picture,
              awaitWrite: true,
            );
            _coverPictureWritten = signature;
          }
        }
        return;
      }
      _coverPictureWritten = null;
      final page = coreInfo.pages.first;
      final previewHeight = page.previewHeight(lineHeight: coreInfo.lineHeight);
      final thumbnailSize = Size(720, 720 * previewHeight / page.size.width);
      final thumbnail = await EditorExporter.screenshotPage(
        coreInfo: coreInfo,
        pageIndex: 0,
        rasterizeAllStrokes: true,
        targetSize: thumbnailSize,
        cropHeight: previewHeight,
        pixelRatio: 1,
      );
      final thumbnailPng = await thumbnail.toByteData(format: .png);
      thumbnail.dispose();
      await FileManager.writeFile(
        // Note that this ends with .sbn2.p
        '$filePath.p',
        thumbnailPng!.buffer.asUint8List(),
        awaitWrite: true,
      );
    } finally {
      // Every few minutes of writing leaves a version behind.
      unawaited(NoteVersions.snapshotIfDue(filePath));
    }
  }

  /// Whether a save of this editor kept files next to the note only
  /// because undo could still need them.
  bool _keptAssetsForUndo = false;

  /// Removes the files that were only kept for undo, once the note is
  /// closed. Only when the note is saved as it is: the files it uses are
  /// then exactly the ones it would save now.
  Future<void> _removeAssetsKeptForUndo() async {
    if (!_keptAssetsForUndo || coreInfo.readOnly) return;
    if (savingState.value != .saved) return;
    final (_, assets) = coreInfo.saveToBinary(currentPageIndex: null);
    await FileManager.removeUnusedAssets(
      coreInfo.filePath + Editor.extension,
      numAssets: assets.length,
    );
  }

  /// Shows the versions kept of this note, to bring one back.
  void showVersions() {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (context) => NoteVersionsDialog(
        notePath: coreInfo.filePath,
        restore: restoreVersion,
      ),
    );
  }

  /// Completes when what is on screen is on disk; false if it could not be
  /// saved.
  Future<bool> _saveNow() async {
    for (var attempt = 0; attempt < 200; attempt++) {
      switch (savingState.value) {
        case .saved:
          {
            return true;
          }
        case .waitingToSave:
          {
            await saveToFile();
            if (savingState.value == .waitingToSave) return false;
          }
        case .saving:
          {
            await Future<void>.delayed(const Duration(milliseconds: 50));
          }
      }
    }
    return false;
  }

  /// Brings an earlier [version] of this note back and shows it.
  ///
  /// What is on screen now is saved and kept as a version first, so nothing
  /// is lost. Throws if the version can't be brought back; the note is then
  /// as it was.
  Future<void> restoreVersion(NoteVersion version) async {
    if (coreInfo.readOnlyReason == .watchingServer) {
      throw StateError('A note that follows the server is not restored');
    }
    Select.currentSelect.unselect();
    if (!await _saveNow()) throw StateError('Could not save the note first');

    final path = coreInfo.filePath;
    await NoteVersions.restore(path + Editor.extension, version);
    if (!mounted) return;

    _delayedSaveTimer?.cancel();
    history = EditorHistory();
    await _loadCoreInfo(path);
    savingState.value = .saved;
    if (mounted) setState(() {});
  }

  late final _filenameFormKey = GlobalKey<FormState>();
  late final filenameTextEditingController = TextEditingController();
  Timer? _renameTimer;
  void renameFile([String? _]) {
    _renameTimer?.cancel();
    _renameTimer = Timer(const Duration(seconds: 5), _renameFileNow);
  }

  Future<void> _renameFileNow() async {
    final newName = filenameTextEditingController.text.trim();
    if (newName == coreInfo.fileName) return;

    if (_filenameFormKey.currentState?.validate() ??
        _validateFilenameTextField(newName) == null) {
      final oldPath = coreInfo.filePath;
      final oldTabIndex = OpenTabs.paths.value.indexOf(oldPath);
      coreInfo.filePath = await FileManager.moveFile(
        coreInfo.filePath + Editor.extension,
        newName.trim() + Editor.extension,
      );
      coreInfo.filePath = coreInfo.filePath.substring(
        0,
        coreInfo.filePath.lastIndexOf(Editor.extension),
      );
      // The pictures are read from where the note's files are now.
      NoteAssets.moved(
        coreInfo,
        oldPath + Editor.extension,
        coreInfo.filePath + Editor.extension,
      );
      // A cover that carries the notebook's name carries the new one.
      final cover = coreInfo.cover;
      if (cover != null &&
          cover.design != null &&
          (cover.title.isNotEmpty || needsNaming)) {
        cover.title = coreInfo.fileName;
        history.markUnsaved();
        // (when this is part of a save, the save takes it along)
        if (savingState.value != .saving) autosaveAfterDelay();
      }
      needsNaming = false;

      if (_usesTabs && coreInfo.filePath != oldPath) {
        _tabPath = coreInfo.filePath;
        OpenTabs.rename(
          oldPath,
          coreInfo.filePath,
          index: oldTabIndex < 0 ? null : oldTabIndex,
        );
      }
    }

    final actualName = coreInfo.fileName;
    if (actualName != newName) {
      // update text field if renamed differently
      filenameTextEditingController.value = filenameTextEditingController.value
          .copyWith(
            text: actualName,
            selection: TextSelection.fromPosition(
              TextPosition(offset: actualName.length),
            ),
            composing: TextRange.empty,
          );
    }
  }

  String? _validateFilenameTextField(String? newName) {
    if (newName == null) return null;
    return FileManager.validateFilename(newName);
  }

  void updateColorBar(Color color) {
    if (stows.recentColorsDontSavePresets.value) {
      if (ColorBar.colorPresets.any(
        (colorPreset) => colorPreset.color == color,
      )) {
        return;
      }
    }

    final newColorString = color.toARGB32().toString();

    // migrate from old pref format
    if (stows.recentColorsChronological.value.length !=
        stows.recentColorsPositioned.value.length) {
      log.info(
        'MIGRATING recentColors: ${stows.recentColorsChronological.value.length} vs ${stows.recentColorsPositioned.value.length}',
      );
      stows.recentColorsChronological.value = List.of(
        stows.recentColorsPositioned.value,
      );
    }

    if (stows.pinnedColors.value.contains(newColorString)) {
      // do nothing, color is already pinned
    } else if (stows.recentColorsPositioned.value.contains(newColorString)) {
      // if it's already a recent color, move it to the top
      stows.recentColorsChronological.value.remove(newColorString);
      stows.recentColorsChronological.value.add(newColorString);
      stows.recentColorsChronological.notifyListeners();
    } else {
      if (stows.recentColorsPositioned.value.length >=
          stows.recentColorsLength.value) {
        // if full, replace the oldest color with the new one
        final removedColorString = stows.recentColorsChronological.value
            .removeAt(0);
        stows.recentColorsChronological.value.add(newColorString);
        final int removedColorPosition = stows.recentColorsPositioned.value
            .indexOf(removedColorString);
        stows.recentColorsPositioned.value[removedColorPosition] =
            newColorString;
      } else {
        // if not full, add the new color to the end
        stows.recentColorsChronological.value.add(newColorString);
        stows.recentColorsPositioned.value.insert(0, newColorString);
      }
      stows.recentColorsChronological.notifyListeners();
      stows.recentColorsPositioned.notifyListeners();
    }
  }

  /// Prompts the user to pick photos from their device.
  /// Returns the number of photos picked.
  ///
  /// If [photoInfos] is provided, it will be used instead of the file picker.
  Future<int> _pickPhotos([List<_PhotoInfo>? photoInfos]) async {
    if (coreInfo.readOnly) return 0;

    final currentPageIndex = this.currentPageIndex;

    photoInfos ??= await _pickPhotosWithFilePicker();
    if (photoInfos.isEmpty) return 0;

    // use the Select tool so that the user can move the new image
    currentTool = Select.currentSelect;

    final images = [
      for (final _PhotoInfo photoInfo in photoInfos)
        if (photoInfo.extension == '.svg')
          SvgEditorImage(
            id: coreInfo.nextImageId++,
            svgString: utf8.decode(photoInfo.bytes),
            svgFile: null,
            pageIndex: currentPageIndex,
            pageSize: coreInfo.pages[currentPageIndex].size,
            onMoveImage: onMoveImage,
            onDeleteImage: onDeleteImage,
            onMiscChange: autosaveAfterDelay,
            onLoad: () => setState(() {}),
            assetCache: coreInfo.assetCache,
          )
        else
          PngEditorImage(
            id: coreInfo.nextImageId++,
            extension: photoInfo.extension,
            imageProvider: MemoryImage(photoInfo.bytes),
            pageIndex: currentPageIndex,
            pageSize: coreInfo.pages[currentPageIndex].size,
            onMoveImage: onMoveImage,
            onDeleteImage: onDeleteImage,
            onMiscChange: autosaveAfterDelay,
            onLoad: () => setState(() {}),
            assetCache: coreInfo.assetCache,
          ),
    ];

    history.recordChange(
      EditorHistoryItem(
        type: .draw,
        pageIndex: currentPageIndex,
        strokes: [],
        images: images,
      ),
    );
    createPage(currentPageIndex);
    coreInfo.pages[currentPageIndex].images.addAll(images);
    autosaveAfterDelay();

    return images.length;
  }

  Future<List<_PhotoInfo>> _pickPhotosWithFilePicker() async {
    final List<PlatformFile> files = await FilePicker.pickFiles(
      type: FileType.custom,
      // Taken from
      // https://github.com/brendan-duncan/image/blob/main/doc/formats.md
      // (plus .svg)
      allowedExtensions: [
        'jpg',
        'jpeg',
        'png',
        'gif',
        'tiff',
        'bmp',
        'tga',
        'ico',
        'pvrtc',
        'svg',
        'webp',
        'psd',
        'exr',
      ],
    );
    if (files.isEmpty) return const [];

    return Future.wait([
      for (final file in files)
        () async {
          final extension = p.extension(file.path ?? file.name);
          if (extension.isEmpty) return null;
          final bytes = await file.readAsBytes();
          return (bytes: bytes, extension: extension);
        }(),
    ]).then((list) => list.nonNulls.toList());
  }

  /// Prompts the user to pick a PDF to import.
  /// Returns whether a PDF was imported.
  Future<bool> importPdf() async {
    if (coreInfo.readOnly) return false;
    if (!Editor.canRasterPdf) return false;

    final String path;
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (file == null) return false;
      path = await PdfImport.localPath(
        path: file.path,
        name: file.name,
        readBytes: file.readAsBytes,
      );
    } on PdfImportException catch (e, st) {
      log.severe('Could not get the picked PDF: $e', e, st);
      _showPdfImportError(e);
      return false;
    } catch (e, st) {
      log.severe('Could not pick a PDF: $e', e, st);
      _showPdfImportError(PdfImportException(.missing, '$e'));
      return false;
    }

    return openPdfWindow(path);
  }

  /// The PDF whose window was last open in this editor, and the page it
  /// showed, so that more can be taken from it without picking it again.
  ({String path, String name, int page})? _lastPdfWindow;

  /// The name of the PDF that [reopenPdfWindow] would show, if any.
  String? get lastPdfWindowName {
    final last = _lastPdfWindow;
    if (last == null || !File(last.path).existsSync()) return null;
    return last.name;
  }

  /// Shows the PDF that was last looked at again, where it was left.
  Future<bool> reopenPdfWindow() async {
    final last = _lastPdfWindow;
    if (last == null) return false;
    return openPdfWindow(last.path, initialPage: last.page);
  }

  /// Shows the PDF at [path] in a window before anything of it is put into
  /// the note, and puts in what is chosen there: whole pages, a marked
  /// part of a page as a picture, or its text.
  ///
  /// Returns whether anything was put into the note.
  Future<bool> openPdfWindow(String path, {int initialPage = 0}) async {
    if (coreInfo.readOnly) return false;

    final PdfDocument document;
    try {
      document = await PdfImport.open(
        coreInfo.assetCache.pdfDocumentCache,
        path,
      );
    } on PdfImportException catch (e, st) {
      log.severe('Could not open the PDF at $path: $e', e, st);
      _showPdfImportError(e);
      return false;
    }
    if (!mounted) return false;

    final name = p.basename(path);
    _lastPdfWindow = (path: path, name: name, page: initialPage);
    final pick = await showDialog<PdfPick>(
      context: context,
      builder: (context) => PdfPickerDialog(
        document: document,
        name: name,
        initialPage: initialPage,
        onPageChanged: (page) =>
            _lastPdfWindow = (path: path, name: name, page: page),
      ),
    );
    if (pick == null || !mounted) return false;
    return applyPdfPick(path, pick);
  }

  /// Puts what was chosen from the PDF at [path] into the note.
  Future<bool> applyPdfPick(String path, PdfPick pick) async {
    switch (pick) {
      case PdfPickPages(:final pages):
        {
          return importPdfFromFilePath(path, pages: pages);
        }
      case PdfPickImage():
        {
          return _addPdfPiece(pick);
        }
      case PdfPickText(:final text):
        {
          return _addPdfText(text);
        }
    }
  }

  /// Puts a piece of a PDF page on the page that is open, as large as it
  /// was on its own page, where it can be moved and resized like a photo.
  bool _addPdfPiece(PdfPickImage piece) {
    if (coreInfo.readOnly) return false;
    final pageIndex = currentPageIndex;
    createPage(pageIndex);
    final page = coreInfo.pages[pageIndex];

    // The top of what is on screen, in the page's own units.
    final fitted = page.size.width < _viewportWidth
        ? 1.0
        : page.size.width / _viewportWidth;
    final topOfPage = CanvasGestureDetector.getTopOfPage(
      pageIndex: pageIndex,
      pages: coreInfo.pages,
      screenWidth: _viewportWidth,
    );
    final visibleTop = (-scrollY - topOfPage) * fitted;

    final image = PngEditorImage(
      id: coreInfo.nextImageId++,
      extension: '.png',
      imageProvider: MemoryImage(piece.png),
      pageIndex: pageIndex,
      pageSize: page.size,
      naturalSize: piece.pixelSize,
      srcRect: Offset.zero & piece.pixelSize,
      dstRect: PdfClip.placeOn(
        pageSize: page.size,
        fractionOfPage: piece.fractionOfPage,
        pixelSize: piece.pixelSize,
        top: visibleTop + page.size.height * 0.04,
      ),
      onMoveImage: onMoveImage,
      onDeleteImage: onDeleteImage,
      onMiscChange: autosaveAfterDelay,
      onLoad: () => setState(() {}),
      assetCache: coreInfo.assetCache,
    );

    setState(() {
      // The Select tool, so that the piece can be moved at once.
      currentTool = Select.currentSelect;
      history.recordChange(
        EditorHistoryItem(
          type: .draw,
          pageIndex: pageIndex,
          strokes: [],
          images: [image],
        ),
      );
      page.images.add(image);
    });
    autosaveAfterDelay();
    return true;
  }

  /// Adds [text] to what is typed on the page that is open.
  bool _addPdfText(String text) {
    if (coreInfo.readOnly) return false;
    final cleaned = text.trim();
    if (cleaned.isEmpty) return false;
    final pageIndex = currentPageIndex;
    createPage(pageIndex);
    final controller = coreInfo.pages[pageIndex].quill.controller;
    // A document always ends with a line break: the text goes before it,
    // on a line of its own if something is typed already.
    final end = math.max(0, controller.document.length - 1);
    final lead = controller.document.isEmpty() ? '' : '\n';
    controller.replaceText(
      end,
      0,
      '$lead$cleaned',
      TextSelection.collapsed(offset: end + lead.length + cleaned.length),
    );
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(DefterStrings.pdfPickTextAdded)),
      );
    }
    return true;
  }

  /// Puts pages of the PDF at [path] into this note, each as a page of its
  /// own: all of them, or only [pages] (the first page of the PDF is 0).
  /// Returns whether it did; if it could not, the note is left as it was
  /// and the reason is shown.
  Future<bool> importPdfFromFilePath(String path, {List<int>? pages}) async {
    if (coreInfo.readOnly) return false;

    final PdfDocument pdfDocument;
    try {
      pdfDocument = await PdfImport.open(
        coreInfo.assetCache.pdfDocumentCache,
        path,
      );
    } on PdfImportException catch (e, st) {
      log.severe('Could not import the PDF at $path: $e', e, st);
      _showPdfImportError(e);
      return false;
    }
    if (!mounted) return false;

    // The empty page a note ends with goes after the PDF's pages.
    final EditorPage? emptyPage =
        coreInfo.pages.isNotEmpty && coreInfo.pages.last.isEmpty
        ? coreInfo.pages.removeLast()
        : null;

    // One file for all the pages: it is saved once.
    final pdfFile = File(path);
    final wanted = pages?.toSet();
    for (final pdfPage in pdfDocument.pages) {
      assert(pdfPage.pageNumber >= 1, 'pdfrx page numbers start at 1');
      if (pdfPage.width <= 0 || pdfPage.height <= 0) continue;
      if (wanted != null && !wanted.contains(pdfPage.pageNumber - 1)) continue;

      // resize to [defaultWidth] to keep pen sizes consistent
      final pageSize = Size(
        EditorPage.defaultWidth,
        EditorPage.defaultWidth * pdfPage.height / pdfPage.width,
      );

      final page = EditorPage(
        size: pageSize,
        backgroundImage: PdfEditorImage(
          id: coreInfo.nextImageId++,
          pdfBytes: null,
          pdfFile: pdfFile,
          pdfPage: pdfPage.pageNumber - 1,
          pageIndex: coreInfo.pages.length,
          pageSize: pageSize,
          naturalSize: pdfPage.size,
          onMoveImage: onMoveImage,
          onDeleteImage: onDeleteImage,
          onMiscChange: autosaveAfterDelay,
          onLoad: () => setState(() {}),
          assetCache: coreInfo.assetCache,
        ),
      );
      coreInfo.pages.add(page);
      listenToQuillChanges(page.quill, coreInfo.pages.length - 1);
      // TODO(adil192): Group multiple pages into one atomic change
      history.recordChange(
        EditorHistoryItem(
          type: .insertPage,
          pageIndex: coreInfo.pages.length - 1,
          strokes: const [],
          images: const [],
          page: page,
        ),
      );
    }

    if (emptyPage != null) {
      coreInfo.pages.add(emptyPage);
      // It has another place in the note now.
      listenToQuillChanges(emptyPage.quill, coreInfo.pages.length - 1);
    } else {
      createPage(coreInfo.pages.length - 1);
    }
    if (mounted) setState(() {});

    autosaveAfterDelay();

    return true;
  }

  /// A note always ends with a page that has nothing on it.
  void _endWithAnEmptyPage() {
    if (coreInfo.pages.isEmpty || !coreInfo.pages.last.isEmpty) {
      createPage(coreInfo.pages.length - 1);
    }
  }

  /// Takes the PDF out of the pages that [scope] means. A page that was
  /// written on stays with its writing (only the PDF behind it goes); a
  /// PDF page with nothing on it leaves the note. One undo brings
  /// everything back.
  ///
  /// Returns what was done, or null if there was nothing to take out.
  PdfRemoval? removePdf(PdfRemovalScope scope) {
    if (coreInfo.readOnly) return null;
    final at = currentPageIndex;
    final indexes = PdfRemover.pagesIn(coreInfo, scope, at);
    if (indexes.isEmpty) return null;

    PdfRemoval? removal;
    setState(() {
      Select.currentSelect.unselect();
      removal = PdfRemover.remove(coreInfo, indexes);
      if (removal == null) return;
      _endWithAnEmptyPage();
      history.recordChange(
        EditorHistoryItem(
          type: .removePdf,
          pageIndex: at,
          strokes: const [],
          images: const [],
          pdfRemoval: removal,
        ),
      );
    });
    final done = removal;
    if (done == null) return null;

    if (done.removed.isNotEmpty) {
      // Stay where the reader was: as many pages down as are still there.
      final before = done.removed.where((entry) => entry.index < at).length;
      final target = (at - before).clamp(0, coreInfo.pages.length - 1).toInt();
      CanvasGestureDetector.scrollToPage(
        pageIndex: target,
        pages: coreInfo.pages,
        screenWidth: _viewportWidth,
        transformationController: _transformationController,
      );
    }
    autosaveAfterDelay();
    return done;
  }

  /// Asks which PDF pages to take out of the note, and takes them out.
  Future<void> showRemovePdf() async {
    if (coreInfo.readOnly || !mounted) return;
    final scope = await showDialog<PdfRemovalScope>(
      context: context,
      builder: (context) => PdfRemoveDialog(
        coreInfo: coreInfo,
        currentPageIndex: currentPageIndex,
      ),
    );
    if (scope == null || !mounted) return;
    final removal = removePdf(scope);
    if (removal == null || !mounted) return;
    ScaffoldMessenger.maybeOf(context)
      ?..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            DefterStrings.pdfRemoved(
              removed: removal.removed.length,
              kept: removal.stripped.length,
            ),
          ),
          action: SnackBarAction(
            label: DefterStrings.undoAction,
            onPressed: () {
              // Only if nothing was done since.
              if (history.canUndo &&
                  identical(history.peekUndo().pdfRemoval, removal)) {
                undo();
              }
            },
          ),
        ),
      );
  }

  /// Says why a PDF could not be imported, with what the device reported
  /// underneath (so that it can be passed on when asking for help).
  void _showPdfImportError(PdfImportException error) {
    if (!mounted) return;
    final detail = error.detail;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('pdfImportError'),
        title: Text(DefterStrings.pdfImportFailed),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(DefterStrings.pdfImportReason(error.failure.name)),
              if (detail != null && detail.isNotEmpty) ...[
                const SizedBox(height: 12),
                SelectableText(
                  detail.length > 400 ? '${detail.substring(0, 400)}…' : detail,
                  style: TextTheme.of(context).bodySmall,
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(DefterStrings.close),
          ),
        ],
      ),
    );
  }

  /// Takes a photo with the device's camera and puts it on the page.
  /// Returns the number of photos added.
  Future<int> takePhoto() async {
    if (coreInfo.readOnly) return 0;

    // The camera takes the screen: what was written is put away first, in
    // case the system closes this app while it is in the background.
    unawaited(saveToFile());

    final DevicePhoto? photo;
    try {
      photo = await DeviceCamera.takePhoto();
    } on DeviceCameraException catch (e, st) {
      log.warning('Could not take a photo: $e', e, st);
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(DefterStrings.cameraFailed(e.failure.name))),
        );
      }
      return 0;
    }
    if (photo == null || !mounted) return 0;
    return _pickPhotos([(bytes: photo.bytes, extension: photo.extension)]);
  }

  Future paste() async {
    /// Maps image formats to their file extension.
    const Map<SimpleFileFormat, String> formats = {
      Formats.jpeg: '.jpeg',
      Formats.png: '.png',
      Formats.gif: '.gif',
      Formats.tiff: '.tiff',
      Formats.bmp: '.bmp',
      Formats.ico: '.ico',
      Formats.svg: '.svg',
      Formats.webp: '.webp',
    };

    final reader = await SystemClipboard.instance?.read();
    if (reader == null) return;

    final List<_PhotoInfo> photoInfos = [];
    final List<ReadProgress> progresses = [];

    for (final format in formats.keys) {
      if (!reader.canProvide(format)) continue;
      final progress = reader.getFile(format, (file) async {
        final stream = file.getStream();
        final List<int> bytes = [];
        await for (final chunk in stream) {
          bytes.addAll(chunk);
        }
        if (bytes.isEmpty) {
          log.warning('Pasted empty file: $file (${formats[format]})');
          return;
        }

        String extension;
        if (file.fileName != null) {
          extension = file.fileName!.substring(file.fileName!.lastIndexOf('.'));
        } else {
          extension = formats[format]!;
        }

        photoInfos.add((
          bytes: Uint8List.fromList(bytes),
          extension: extension,
        ));
      });
      if (progress != null) progresses.add(progress);
    }

    while (progresses.isNotEmpty) {
      progresses.removeWhere((progress) => progress.fraction.value == 1);
      await Future.delayed(const Duration(milliseconds: 50));
    }

    await _pickPhotos(photoInfos);
  }

  Future exportAsPdf(BuildContext context) async {
    final pdf = await EditorExporter.generatePdf(
      coreInfo,
      context,
      eInk: EditorExporter.eInkStyleForExport(),
    );
    final bytes = await pdf.save();
    if (!context.mounted) return;
    await FileManager.exportFile(
      '${coreInfo.fileName}.pdf',
      bytes,
      context: context,
    );
  }

  /// Exports the current note as an SBA (Saber Archive) file.
  Future exportAsSba(BuildContext context) async {
    final sba = await coreInfo.saveToSba(currentPageIndex: currentPageIndex);
    if (!context.mounted) return;
    await FileManager.exportFile(
      '${coreInfo.fileName}.sba',
      Uint8List.fromList(sba),
      context: context,
    );
  }

  /// Exports the current page as a PNG image file.
  ///
  /// This captures the canvas natively via [EditorExporter.screenshotPage],
  /// which guarantees the correct background color and omits UI elements
  /// like selection bounds or the text cursor. It computes a dynamic [pixelRatio]
  /// to ensure high quality while averting Out-Of-Memory exceptions on large canvases.
  Future exportAsPng(BuildContext context) async {
    final page = coreInfo.pages[currentPageIndex];

    const maxRasterizableSize = 3000.0;
    var targetPixelRatio = maxRasterizableSize / page.size.longestSide;
    if (targetPixelRatio > 1) targetPixelRatio = 1;

    try {
      final image = await EditorExporter.screenshotPage(
        coreInfo: coreInfo,
        pageIndex: currentPageIndex,
        rasterizeAllStrokes: true,
        pixelRatio: targetPixelRatio,
        eInk: EditorExporter.eInkStyleForExport(),
      );
      final pngBytes = await image.toByteData(format: .png);
      image.dispose();

      if (!context.mounted) return;
      await FileManager.exportFile(
        '${coreInfo.fileName}_page_${currentPageIndex + 1}.png',
        pngBytes!.buffer.asUint8List(),
        isImage: true,
        context: context,
      );
    } catch (e, st) {
      log.severe('Failed to export PNG', e, st);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    final platform = Theme.of(context).platform;
    final isToolbarVertical =
        stows.editorToolbarAlignment.value == AxisDirection.left ||
        stows.editorToolbarAlignment.value == AxisDirection.right;

    final Widget pageArea = CanvasGestureDetector(
      key: _canvasGestureDetectorKey,
      filePath: coreInfo.filePath,
      isDrawGesture: isDrawGesture,
      onInteractionEnd: onInteractionEnd,
      onDrawStart: onDrawStart,
      onDrawUpdate: onDrawUpdate,
      onDrawEnd: onDrawEnd,
      onHovering: onHovering,
      onHoveringEnd: onHoveringEnd,
      onStylusButtonChanged: onStylusButtonChanged,
      updatePointerData: updatePointerData,
      undo: undo,
      redo: redo,
      pages: coreInfo.pages,
      initialPageIndex: coreInfo.initialPageIndex,
      pageBuilder: pageBuilder,
      isTextEditing: () => currentTool == Tool.textEditing,
      placeholderPageBuilder: (BuildContext context, int pageIndex) {
        return Canvas(
          path: coreInfo.filePath,
          page: coreInfo.pages[pageIndex],
          pageIndex: 0,
          textEditing: false,
          coreInfo: EditorCoreInfo.placeholder,
          currentStroke: null,
          currentStrokeDetectedShape: null,
          currentSelection: null,
          placeholder: true,
          setAsBackground: null,
          currentTool: currentTool,
          currentScale: double.minPositive,
        );
      },
      transformationController: _transformationController,
    );
    // The page, with what the measuring tools read shown over it.
    final Widget canvas = Stack(
      children: [
        Positioned.fill(child: pageArea),
        const Positioned.fill(child: IgnorePointer(child: EraserCursor())),
        const Positioned.fill(child: IgnorePointer(child: MeasureReadout())),
      ],
    );

    final readonlyBanner = ReadOnlyBanner(
      coreInfo.readOnlyReason,
      action: coreInfo.readOnlyReason == .versionTooNew
          ? showVersionTooNewDialog
          : null,
    );

    final Toolbar toolbarSpec = Toolbar(
          readOnly: coreInfo.readOnly,
          setTool: (tool) {
            if (tool is Eraser && currentTool is Eraser) {
              // setTool(Eraser) is a special case to toggle the eraser on/off
              tool = _lastNonEraserTool;
            }

            currentTool = tool;

            if (tool is Highlighter) {
              Highlighter.currentHighlighter = tool;
            } else if (tool is Pencil) {
              Pencil.currentPencil = tool;
            } else if (tool is Pen) {
              Pen.currentPen = tool;
            }

            if (mounted) setState(() {});
          },
          currentTool: currentTool,
          duplicateSelection: () {
            final select = currentTool as Select;
            if (!select.doneSelecting) return;

            setState(() {
              final page = coreInfo.pages[select.selectResult.pageIndex];
              final strokes = select.selectResult.strokes;
              final images = select.selectResult.images;

              const duplicationFeedbackOffset = Offset(25, -25);

              final duplicatedStrokes = strokes.map((stroke) {
                return stroke.copy()..shift(duplicationFeedbackOffset);
              }).toList();

              final duplicatedImages = images.map((image) {
                return image.copy()
                  ..id = coreInfo.nextImageId++
                  ..dstRect.shift(duplicationFeedbackOffset);
              }).toList();

              page.strokes.addAll(duplicatedStrokes);
              page.images.addAll(duplicatedImages);

              select.selectResult = select.selectResult.copyWith(
                strokes: duplicatedStrokes,
                images: duplicatedImages,
                path: select.selectResult.path.shift(duplicationFeedbackOffset),
              );

              history.recordChange(
                EditorHistoryItem(
                  type: .draw,
                  pageIndex: select.selectResult.pageIndex,
                  strokes: duplicatedStrokes,
                  images: duplicatedImages,
                ),
              );
              autosaveAfterDelay();
            });
          },
          currentNotePath: coreInfo.filePath,
          recognizeSelection: () {
            final select = currentTool as Select;
            if (!select.doneSelecting) return;
            if (stows.openRouterApiKey.value.trim().isEmpty) {
              ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                SnackBar(content: Text(DefterStrings.recognizeNoKey)),
              );
              return;
            }
            RecognizeDialog.show(context, List.of(select.selectResult.strokes));
          },
          deleteSelection: () {
            final select = currentTool as Select;
            if (!select.doneSelecting) {
              return;
            }

            setState(() {
              final page = coreInfo.pages[select.selectResult.pageIndex];
              final strokes = select.selectResult.strokes;
              final images = select.selectResult.images;

              for (final stroke in strokes) {
                page.strokes.remove(stroke);
              }
              for (final image in images) {
                page.images.remove(image);
              }

              select.unselect();

              history.recordChange(
                EditorHistoryItem(
                  type: .erase,
                  pageIndex: strokes.first.pageIndex,
                  strokes: strokes,
                  images: images,
                ),
              );
              autosaveAfterDelay();
            });
          },
          setColor: (color) {
            setState(() {
              updateColorBar(color);

              if (currentTool is Highlighter) {
                (currentTool as Highlighter).color = color.withAlpha(
                  Highlighter.alpha,
                );
              } else if (currentTool is Pen) {
                (currentTool as Pen).color = color;
              } else if (currentTool is Select) {
                // Changes color of selected strokes
                final select = currentTool as Select;
                if (select.doneSelecting) {
                  final strokes = select.selectResult.strokes;

                  final colorChange = <Stroke, Change<Color>>{};
                  for (final stroke in strokes) {
                    colorChange[stroke] = Change(
                      previous: stroke.color,
                      current: color,
                    );
                    stroke.color = color;
                  }

                  history.recordChange(
                    EditorHistoryItem(
                      type: .changeColor,
                      pageIndex: strokes.first.pageIndex,
                      strokes: strokes,
                      colorChange: colorChange,
                      images: [],
                    ),
                  );
                  autosaveAfterDelay();
                }
              }
            });
          },
          quillFocus: quillFocus,
          textEditing: currentTool == Tool.textEditing,
          toggleTextEditing: () => setState(() {
            if (currentTool == Tool.textEditing) {
              currentTool = Pen.currentPen;
              for (final page in coreInfo.pages) {
                // unselect text, but maintain cursor position
                page.quill.controller.moveCursorToPosition(
                  page.quill.controller.selection.extentOffset,
                );
                page.quill.focusNode.unfocus();
              }
            } else {
              currentTool = Tool.textEditing;
              quillFocus.value = coreInfo.pages[currentPageIndex].quill
                ..focusNode.requestFocus();
            }
          }),
          undo: undo,
          isUndoPossible: history.canUndo,
          redo: redo,
          isRedoPossible: history.canRedo,
          toggleFingerDrawing: () {
            stows.editorFingerDrawing.value = !stows.editorFingerDrawing.value;
            lastSeenPointerCount = 0;
          },
          pickPhoto: _pickPhotos,
          takePhoto: DeviceCamera.isAvailable ? takePhoto : null,
          paste: paste,
          exportAsSba: exportAsSba,
          exportAsPdf: exportAsPdf,
          exportAsPng: exportAsPng,
          toggleGrid: coreInfo.readOnly ? null : toggleGrid,
          gridOn: coreInfo.backgroundPattern == CanvasBackgroundPattern.grid,
    );

    final Widget toolbar = Collapsible(
      axis: isToolbarVertical
          ? CollapsibleAxis.horizontal
          : CollapsibleAxis.vertical,
      collapsed:
          DynamicMaterialApp.isFullscreen &&
          !stows.editorToolbarShowInFullscreen.value,
      maintainState: true,
      child: SafeArea(
        bottom: stows.editorToolbarAlignment.value != AxisDirection.up,
        child: toolbarSpec,
      ),
    );

    final useGn = stows.editorGnLayout.value;

    final Widget body;
    if (useGn) {
      body = GnOverlay(
        controller: _gn,
        spec: toolbarSpec,
        child: Column(
          children: [
            Expanded(child: canvas),
            readonlyBanner,
          ],
        ),
      );
    } else if (isToolbarVertical) {
      body = Row(
        textDirection: stows.editorToolbarAlignment.value == AxisDirection.left
            ? .ltr
            : .rtl,
        children: [
          toolbar,
          Expanded(
            child: Column(
              children: [
                Expanded(child: canvas),
                readonlyBanner,
              ],
            ),
          ),
        ],
      );
    } else {
      body = Column(
        verticalDirection:
            stows.editorToolbarAlignment.value == AxisDirection.up
            ? VerticalDirection.up
            : VerticalDirection.down,
        children: [
          Expanded(child: canvas),
          toolbar,
          readonlyBanner,
        ],
      );
    }

    return ValueListenableBuilder(
      valueListenable: savingState,
      builder: (context, savingState, child) {
        // don't allow user to go back until saving is done
        return PopScope(
          canPop: savingState == .saved,
          onPopInvokedWithResult: (didPop, _) {
            switch (savingState) {
              case .waitingToSave:
                assert(!didPop);
                saveToFile(); // trigger save now
                snackBarNeedsToSaveBeforeExiting();
              case .saving:
                assert(!didPop);
                snackBarNeedsToSaveBeforeExiting();
              case .saved:
                break;
            }
          },
          child: child!,
        );
      },
      child: Scaffold(
        appBar: DynamicMaterialApp.isFullscreen
            ? null
            : useGn
            ? _gnBar(toolbarSpec)
            : AppBar(
                toolbarHeight: kToolbarHeight,
                bottom: _usesTabs && OpenTabs.paths.value.length > 1
                    ? EditorTabStrip(
                        paths: OpenTabs.paths.value,
                        currentPath: _tabPath,
                        onSelect: switchToTab,
                        onClose: closeTab,
                      )
                    : null,
                title: widget.customTitle != null
                    ? Text(widget.customTitle!)
                    : Form(
                        key: _filenameFormKey,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        child: TextFormField(
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                          ),
                          controller: filenameTextEditingController,
                          onChanged: renameFile,
                          autofocus: needsNaming,
                          validator: _validateFilenameTextField,
                        ),
                      ),
                leading: SaveIndicator(
                  savingState: savingState,
                  triggerSave: saveToFile,
                ),
                actions: [
                  if (MediaQuery.sizeOf(context).width >=
                      PageSidebar.minScreenWidth)
                    ValueListenableBuilder(
                      valueListenable: stows.editorPageSidebar,
                      builder: (context, shown, _) => IconButton(
                        icon: const Icon(Symbols.view_sidebar_rounded),
                        selectedIcon: const Icon(Icons.view_sidebar_rounded),
                        isSelected: shown,
                        tooltip: DefterStrings.pageSidebar,
                        onPressed: () =>
                            stows.editorPageSidebar.value = !shown,
                      ),
                    ),
                  ValueListenableBuilder(
                    valueListenable: _visiblePageIndex,
                    builder: (context, pageIndex, _) {
                      final shown = (pageIndex < 0 ? 0 : pageIndex) + 1;
                      return Tooltip(
                        message: t.editor.pages,
                        child: TextButton(
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: showPageGrid,
                          child: Text('$shown / ${coreInfo.pages.length}'),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: const AdaptiveIcon(
                      icon: Symbols.insert_page_break_rounded,
                      cupertinoIcon: CupertinoIcons.add,
                    ),
                    tooltip: t.editor.menu.insertPage,
                    onPressed: () => setState(() {
                      final currentPageIndex = this.currentPageIndex;
                      insertPageAfter(currentPageIndex);
                      CanvasGestureDetector.scrollToPage(
                        pageIndex: currentPageIndex + 1,
                        pages: coreInfo.pages,
                        screenWidth: _viewportWidth,
                        transformationController: _transformationController,
                      );
                    }),
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: PenLatencyProbe.instance.recording,
                    builder: (context, recording, _) {
                      if (!stows.penProbe.value && !recording) {
                        return const SizedBox.shrink();
                      }
                      return IconButton(
                        icon: Icon(
                          recording ? Icons.stop_circle_rounded : Symbols.speed_rounded,
                          color: recording ? Colors.red : null,
                        ),
                        tooltip: recording
                            ? DefterStrings.penProbeStop
                            : DefterStrings.penProbeStart,
                        onPressed: _togglePenProbe,
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Symbols.mic_rounded),
                    tooltip: DefterStrings.recordings,
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) =>
                          RecordingsDialog(notePath: coreInfo.filePath),
                    ),
                  ),
                  ValueListenableBuilder(
                    valueListenable: _visiblePageIndex,
                    builder: (context, pageIndex, _) {
                      final bookmarked =
                          pageIndex >= 0 &&
                          pageIndex < coreInfo.pages.length &&
                          coreInfo.pages[pageIndex].bookmarked;
                      return IconButton(
                        icon: Icon(
                          bookmarked ? Icons.bookmark_rounded : Symbols.bookmark_rounded,
                        ),
                        tooltip: DefterStrings.bookmark,
                        onPressed: coreInfo.readOnly
                            ? null
                            : () => toggleBookmark(pageIndex),
                      );
                    },
                  ),
                  IconButton(
                    icon: const AdaptiveIcon(
                      icon: Symbols.more_vert_rounded,
                      cupertinoIcon: CupertinoIcons.ellipsis_vertical,
                    ),
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        builder: (context) => bottomSheet(context),
                        isScrollControlled: true,
                        showDragHandle: true,
                        backgroundColor: colorScheme.surface,
                        constraints: const BoxConstraints(maxWidth: 500),
                      );
                    },
                  ),
                ],
              ),
        body: _sidebarVisible
            ? Row(
                children: [
                  PageSidebar(
                    coreInfo: coreInfo,
                    currentPage: _visiblePageIndex,
                    onPageAction: coreInfo.readOnly ? null : onPageAction,
                    canDeletePage: canDeletePage,
                    onPageSelected: (pageIndex) =>
                        CanvasGestureDetector.scrollToPage(
                          pageIndex: pageIndex,
                          pages: coreInfo.pages,
                          screenWidth: _viewportWidth,
                          transformationController: _transformationController,
                        ),
                  ),
                  Expanded(
                    child: MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                        size: Size(
                          _viewportWidth,
                          MediaQuery.sizeOf(context).height,
                        ),
                      ),
                      child: body,
                    ),
                  ),
                ],
              )
            : body,
        floatingActionButton:
            (DynamicMaterialApp.isFullscreen &&
                !stows.editorToolbarShowInFullscreen.value)
            ? FloatingActionButton(
                shape: platform.isCupertino ? const CircleBorder() : null,
                onPressed: () {
                  DynamicMaterialApp.setFullscreen(false, updateSystem: true);
                },
                child: const Icon(Symbols.fullscreen_exit_rounded),
              )
            : null,
      ),
    );
  }

  void snackBarNeedsToSaveBeforeExiting() {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(t.editor.needsToSaveBeforeExiting)));
  }

  Widget bottomSheet(BuildContext context) {
    final Brightness brightness = Theme.brightnessOf(context);
    final invert = stows.editorAutoInvert.value && brightness == .dark;
    final int currentPageIndex = this.currentPageIndex;

    return EditorBottomSheet(
      invert: invert,
      coreInfo: coreInfo,
      currentPageIndex: currentPageIndex,
      setBackgroundPattern: (pattern) => setState(() {
        if (coreInfo.readOnly) return;
        final previous = coreInfo.backgroundPattern;
        coreInfo.backgroundPattern = pattern;
        stows.lastBackgroundPattern.value = pattern;
        history.recordChange(
          EditorHistoryItem(
            type: .backgroundPattern,
            pageIndex: currentPageIndex,
            backgroundPatternChange: Change(
              previous: previous,
              current: pattern,
            ),
            strokes: [],
            images: [],
          ),
        );
        autosaveAfterDelay();
      }),
      setCover: setCover,
      coverDesignId: coreInfo.cover?.designId,
      hasCover: coreInfo.cover != null,
      setBackgroundColor: (color) => setState(() {
        if (coreInfo.readOnly) return;
        coreInfo.backgroundColor = color;
        autosaveAfterDelay();
      }),
      setLineHeight: (lineHeight) => setState(() {
        if (coreInfo.readOnly) return;
        coreInfo.lineHeight = lineHeight;
        stows.lastLineHeight.value = lineHeight;
        autosaveAfterDelay();
      }),
      setLineThickness: (lineThickness) => setState(() {
        if (coreInfo.readOnly) return;
        coreInfo.lineThickness = lineThickness;
        stows.lastLineThickness.value = lineThickness;
        autosaveAfterDelay();
      }),
      removeBackgroundImage: () => setState(() {
        if (coreInfo.readOnly) return;

        final page = coreInfo.pages[currentPageIndex];
        if (page.backgroundImage == null) return;
        page.images.add(page.backgroundImage!);
        page.backgroundImage = null;

        autosaveAfterDelay();
      }),
      redrawImage: () => setState(() {}),
      clearPage: () {
        clearPage(currentPageIndex);
      },
      deletePage: canDeletePage(currentPageIndex)
          ? () => deletePage(currentPageIndex)
          : null,
      clearAllPages: clearAllPages,
      redrawAndSave: () => setState(() {
        if (coreInfo.readOnly) return;
        autosaveAfterDelay();
      }),
      pickPhotos: _pickPhotos,
      takePhoto: DeviceCamera.isAvailable ? takePhoto : null,
      importPdf: importPdf,
      lastPdfName: lastPdfWindowName,
      reopenPdf: reopenPdfWindow,
      canRasterPdf: Editor.canRasterPdf,
      hasPdf: PdfNoteText.hasPdf(coreInfo),
      currentPageHasPdf:
          coreInfo.pages.getOrNull(currentPageIndex)?.backgroundImage
              is PdfEditorImage,
      showPdfTools: showPdfTools,
      removePdf: showRemovePdf,
      cropPdfPage: cropPdfPage,
      showVersions: showVersions,
      getIsWatchingServer: () => _watchServerTimer?.isActive ?? false,
      setIsWatchingServer: (bool watch) {
        if (watch) {
          _watchServerTimer ??= Timer.periodic(
            const Duration(seconds: 5),
            (_) => _refreshCurrentNote(),
          );
          if (coreInfo.readOnlyReason != .watchingServer) {
            assert(coreInfo.readOnlyReason == null);
            coreInfo.readOnlyReason = .watchingServer;
            if (mounted) setState(() {});
          }
        } else {
          _watchServerTimer?.cancel();
          _watchServerTimer = null;
          if (coreInfo.readOnlyReason == .watchingServer) {
            coreInfo.readOnlyReason = null;
            if (mounted) setState(() {});
          }
        }
      },
    );
  }

  Widget pageBuilder(BuildContext context, int pageIndex) {
    final page = coreInfo.pages[pageIndex];
    final currentStroke = Pen.currentStroke?.pageIndex == pageIndex
        ? Pen.currentStroke
        : null;
    return Canvas(
      path: coreInfo.filePath,
      page: page,
      pageIndex: pageIndex,
      textEditing: currentTool == Tool.textEditing,
      coreInfo: coreInfo,
      currentStroke: currentStroke,
      currentStrokeDetectedShape:
          currentTool is ShapePen && currentStroke != null
          ? ShapePen.detectedShape
          : null,
      currentSelection: () {
        if (currentTool is! Select) return null;
        final selectResult = (currentTool as Select).selectResult;
        if (selectResult.pageIndex != pageIndex) return null;
        return selectResult;
      }(),
      setAsBackground: (EditorImage image) {
        if (page.backgroundImage != null) {
          // restore previous background image as normal image
          page.images.add(page.backgroundImage!);
        }
        page.images.remove(image);
        page.backgroundImage = image;

        CanvasImage.activeListener
            .notifyListenersPlease(); // un-select active image

        autosaveAfterDelay();
        setState(() {});
      },
      currentTool: currentTool,
      currentScale: _transformationController.value.approxScale,
    );
  }

  /// The whiteboard is a single fixed note, so it doesn't take part in tabs.
  bool get _usesTabs => widget.customTitle == null;

  final _gn = GnController();

  /// The top bar of the Goodnotes-style layout (see [GnEditorBar]).
  PreferredSizeWidget _gnBar(Toolbar spec) {
    final top = MediaQuery.paddingOf(context).top;
    return PreferredSize(
      preferredSize: Size.fromHeight(GnEditorBar.contentHeight + top),
      child: GnEditorBar(
        controller: _gn,
        spec: spec,
        paths: _usesTabs ? OpenTabs.paths.value : const [],
        currentPath: _tabPath,
        currentName: widget.customTitle ?? coreInfo.fileName,
        onSelectTab: switchToTab,
        onCloseTab: closeTab,
        onNewTab: () => Navigator.of(context).maybePop(),
        onRename: _showRenameDialog,
        savingState: savingState,
        triggerSave: saveToFile,
        sidebarAvailable:
            MediaQuery.sizeOf(context).width >= PageSidebar.minScreenWidth,
        sidebarShown: stows.editorPageSidebar.value,
        onToggleSidebar: () =>
            stows.editorPageSidebar.value = !stows.editorPageSidebar.value,
        onAskNotes: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const AskNotesPage()),
        ),
        onAddPage: () => setState(() {
          final currentPageIndex = this.currentPageIndex;
          insertPageAfter(currentPageIndex);
          CanvasGestureDetector.scrollToPage(
            pageIndex: currentPageIndex + 1,
            pages: coreInfo.pages,
            screenWidth: _viewportWidth,
            transformationController: _transformationController,
          );
        }),
        onRecordings: () => showDialog<void>(
          context: context,
          builder: (_) => RecordingsDialog(notePath: coreInfo.filePath),
        ),
        showPenProbe: stows.penProbe.value,
        onPenProbe: _togglePenProbe,
        onMore: () => showModalBottomSheet(
          context: context,
          builder: (context) => bottomSheet(context),
          isScrollControlled: true,
          showDragHandle: true,
          backgroundColor: ColorScheme.of(context).surface,
          constraints: const BoxConstraints(maxWidth: 500),
        ),
        visiblePage: _visiblePageIndex,
        pageCount: coreInfo.pages.length,
        onPages: showPageGrid,
      ),
    );
  }

  Future<void> _showRenameDialog() async {
    final controller = TextEditingController(
      text: filenameTextEditingController.text,
    );
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(DefterStrings.gnRename),
        content: TextField(
          controller: controller,
          autofocus: true,
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(MaterialLocalizations.of(context).okButtonLabel),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.trim().isEmpty) return;
    filenameTextEditingController.text = name.trim();
    await _renameFileNow();
    if (mounted) setState(() {});
  }

  /// This editor's entry in [OpenTabs], once its path is known.
  String? _tabPath;

  /// Opens another notebook in place of this one.
  ///
  /// This editor saves itself as it's disposed.
  void switchToTab(String path) {
    if (path == _tabPath) return;
    final location = RoutePaths.editFilePath(path);
    if (ModalRoute.of(context)?.settings is Page) {
      // This editor was opened through the router, whose pages
      // can't be replaced with the imperative Navigator API.
      GoRouter.of(context).pushReplacement(location);
    } else {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder<void>(
          settings: RouteSettings(name: location),
          pageBuilder: (context, _, _) => Editor(path: path),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      );
    }
  }

  void closeTab(String path) {
    if (path != _tabPath) {
      OpenTabs.close(path);
      return;
    }

    final index = OpenTabs.paths.value.indexOf(path);
    OpenTabs.close(path);
    final remaining = OpenTabs.paths.value;
    if (remaining.isEmpty) {
      Navigator.of(context).maybePop();
    } else {
      switchToTab(remaining[index.clamp(0, remaining.length - 1)]);
    }
  }

  /// The page currently in view, for widgets that follow scrolling
  /// (e.g. the bookmark button).
  final _visiblePageIndex = ValueNotifier<int>(0);
  var _visiblePageUpdateScheduled = false;

  /// E-ink mode shows its page-turn refresh only after this time.
  DateTime? _eInkPageTurnsFrom;

  void _onVisiblePageChanged() {
    if (!stows.eInkMode.value) return;
    final from = _eInkPageTurnsFrom;
    if (from == null || DateTime.now().isBefore(from)) return;
    EInkRefresh.instance.pageTurn();
  }

  /// The transform can change while the widget tree is building,
  /// so [_visiblePageIndex] is only updated after the frame.
  void _scheduleVisiblePageUpdate() {
    if (_visiblePageUpdateScheduled) return;
    _visiblePageUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _visiblePageUpdateScheduled = false;
      if (!mounted) return;
      _visiblePageIndex.value = currentPageIndex;
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  void toggleBookmark(int pageIndex) {
    if (coreInfo.readOnly) return;
    if (pageIndex < 0 || pageIndex >= coreInfo.pages.length) return;
    setState(() {
      final page = coreInfo.pages[pageIndex];
      page.bookmarked = !page.bookmarked;
    });
    // (a bookmark is not a step that is undone, but it is a change)
    history.markUnsaved();
    autosaveAfterDelay();
  }

  /// Search the PDF text and jump through its table of contents.
  void showPdfTools() {
    showDialog(
      context: context,
      builder: (dialogContext) => PdfToolsDialog(
        coreInfo: coreInfo,
        onPageSelected: (pageIndex) {
          Navigator.of(dialogContext).pop();
          CanvasGestureDetector.scrollToPage(
            pageIndex: pageIndex,
            pages: coreInfo.pages,
            screenWidth: _viewportWidth,
            transformationController: _transformationController,
          );
        },
      ),
    );
  }

  /// Starts a pen latency recording, or stops it and shows the result.
  Future<void> _togglePenProbe() async {
    final probe = PenLatencyProbe.instance;
    if (!probe.recording.value) {
      probe.start();
      return;
    }
    final report = await probe.stop();
    if (report == null || !mounted) return;
    showDialog<void>(
      context: context,
      builder: (_) => PenLatencyDialog(text: report.toText()),
    );
  }

  /// Cuts the edges off the PDF page that is on screen (or off all of the
  /// pages of the same PDF).
  void cropPdfPage() {
    if (coreInfo.readOnly) return;
    final background = coreInfo.pages
        .getOrNull(currentPageIndex)
        ?.backgroundImage;
    if (background is! PdfEditorImage) return;

    bool samePdf(PdfEditorImage other) {
      final path = background.pdfFile?.path;
      if (path != null) return other.pdfFile?.path == path;
      return identical(other.pdfBytes, background.pdfBytes);
    }

    showDialog<void>(
      context: context,
      builder: (_) => PdfCropDialog(
        initial: background.crop,
        pageAspect: background.naturalSize.isEmpty
            ? 0.7
            : background.naturalSize.width / background.naturalSize.height,
        onApply: (crop, allPages) {
          setState(() {
            for (final page in coreInfo.pages) {
              final image = page.backgroundImage;
              if (image is! PdfEditorImage) continue;
              if (!identical(image, background) &&
                  !(allPages && samePdf(image))) {
                continue;
              }
              image.crop = crop;
            }
          });
          autosaveAfterDelay();
        },
      ),
    );
  }

  /// Shows every page as a thumbnail, for jumping around the notebook.
  void showPageGrid() {
    showDialog(
      context: context,
      builder: (dialogContext) => EditorPageGrid(
        coreInfo: coreInfo,
        currentPageIndex: currentPageIndex,
        onPageSelected: (pageIndex) {
          Navigator.of(dialogContext).pop();
          CanvasGestureDetector.scrollToPage(
            pageIndex: pageIndex,
            pages: coreInfo.pages,
            screenWidth: _viewportWidth,
            transformationController: _transformationController,
          );
        },
        toggleBookmark: coreInfo.readOnly ? null : toggleBookmark,
        onPageAction: coreInfo.readOnly ? null : onPageAction,
        canDeletePage: canDeletePage,
        openPageManager: () {
          Navigator.of(dialogContext).pop();
          showDialog(
            context: context,
            builder: (context) => AdaptiveAlertDialog(
              title: Text(t.editor.pages),
              content: pageManager(context),
              actions: const [],
            ),
          );
        },
      ),
    );
  }

  Widget pageManager(BuildContext context) {
    return EditorPageManager(
      coreInfo: coreInfo,
      currentPageIndex: currentPageIndex,
      redrawAndSave: () => setState(() {
        if (coreInfo.readOnly) return;
        autosaveAfterDelay();
      }),
      insertPageAfter: insertPageAfter,
      duplicatePage: duplicatePage,
      clearPage: clearPage,
      deletePage: deletePage,
      transformationController: _transformationController,
    );
  }

  /// Puts a copy of the page at [pageIndex] after it.
  void duplicatePage(int pageIndex) {
    if (coreInfo.readOnly) return;
    if (pageIndex < 0 || pageIndex >= coreInfo.pages.length) return;
    setState(() {
      final page = coreInfo.pages[pageIndex];
      final newPage = page.copyWith(
        strokes: page.strokes.map((stroke) => stroke.copy()).toList(),
        images: page.images.map((image) => image.copy()).toList(),
        quill: QuillStruct(
          controller: flutter_quill.QuillController(
            document: flutter_quill.Document.fromDelta(
              page.quill.controller.document.toDelta(),
            ),
            selection: const TextSelection.collapsed(offset: 0),
          ),
          focusNode: FocusNode(debugLabel: 'Quill Focus Node'),
        ),
        backgroundImage: page.backgroundImage?.copy(),
      );
      coreInfo.pages.insert(pageIndex + 1, newPage);
      _renumberPages();
      history.recordChange(
        EditorHistoryItem(
          type: .insertPage,
          pageIndex: pageIndex + 1,
          strokes: const [],
          images: const [],
          page: newPage,
        ),
      );
      autosaveAfterDelay();
    });
  }

  /// Whether the page at [pageIndex] can be taken out of the notebook:
  /// every page can, except the only page there is while it is empty.
  bool canDeletePage(int pageIndex) =>
      !coreInfo.readOnly &&
      pageIndex >= 0 &&
      pageIndex < coreInfo.pages.length &&
      (coreInfo.pages.length > 1 || coreInfo.pages[pageIndex].isNotEmpty);

  /// Takes the page at [pageIndex] out of the notebook, with everything
  /// on it. Undo puts it back. A notebook always keeps one page: deleting
  /// the last one there is leaves an empty page in its place.
  void deletePage(int pageIndex) {
    if (!canDeletePage(pageIndex)) return;
    Select.currentSelect.unselect();
    CanvasImage.activeListener.notifyListenersPlease();
    setState(() {
      final page = coreInfo.pages.removeAt(pageIndex);
      createPage(-1);
      _renumberPages();
      history.recordChange(
        EditorHistoryItem(
          type: .deletePage,
          pageIndex: pageIndex,
          strokes: const [],
          images: const [],
          page: page,
        ),
      );
      autosaveAfterDelay();
    });
    // Where the page was is now the page after it (or the last one).
    final showing = math.min(pageIndex, coreInfo.pages.length - 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      CanvasGestureDetector.scrollToPage(
        pageIndex: math.min(showing, coreInfo.pages.length - 1),
        pages: coreInfo.pages,
        screenWidth: _viewportWidth,
        transformationController: _transformationController,
      );
    });
    ScaffoldMessenger.maybeOf(context)
      ?..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          key: const ValueKey('pageDeleted'),
          content: Text(DefterStrings.pageDeleted(pageIndex + 1)),
          action: SnackBarAction(
            label: DefterStrings.undoAction,
            onPressed: () {
              if (mounted && history.canUndo) undo();
            },
          ),
        ),
      );
  }

  /// What the "..." under a page's thumbnail does.
  void onPageAction(int pageIndex, PageAction action) {
    switch (action) {
      case PageAction.duplicate:
        duplicatePage(pageIndex);
      case PageAction.delete:
        deletePage(pageIndex);
    }
  }

  void insertPageAfter(int pageIndex) => setState(() {
    if (coreInfo.readOnly) return;
    final page = EditorPage(size: _sizeForPageAfter(pageIndex));
    coreInfo.pages.insert(pageIndex + 1, page);
    _renumberPages();
    history.recordChange(
      EditorHistoryItem(
        type: .insertPage,
        pageIndex: pageIndex + 1,
        strokes: const [],
        images: const [],
        page: page,
      ),
    );
    autosaveAfterDelay();
  });

  CanvasBackgroundPattern? _patternBeforeGrid;

  /// The grid of the pen panel: puts the note on squared paper, or back on
  /// the paper it had before.
  void toggleGrid() => setState(() {
    if (coreInfo.readOnly) return;
    final previous = coreInfo.backgroundPattern;
    final CanvasBackgroundPattern next;
    if (previous == CanvasBackgroundPattern.grid) {
      next = _patternBeforeGrid ?? CanvasBackgroundPattern.none;
    } else {
      _patternBeforeGrid = previous;
      next = CanvasBackgroundPattern.grid;
    }
    coreInfo.backgroundPattern = next;
    history.recordChange(
      EditorHistoryItem(
        type: .backgroundPattern,
        pageIndex: currentPageIndex,
        backgroundPatternChange: Change(previous: previous, current: next),
        strokes: [],
        images: [],
      ),
    );
    autosaveAfterDelay();
  });

  /// Gives the notebook [design] as its cover (none, if null), with the
  /// note's name on it. The cover is what the notebook's card shows; it
  /// is not a page.
  void setCover(CoverDesign? design) {
    if (coreInfo.readOnly) return;
    setState(() {
      coreInfo.cover = design == null
          ? null
          : NoteCover(designId: design.id, title: coreInfo.fileName);
      _coverPictureWritten = null;
    });
    history.markUnsaved();
    autosaveAfterDelay();
    ScaffoldMessenger.maybeOf(context)
      ?..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            design == null
                ? DefterStrings.coverRemoved
                : DefterStrings.coverOnCardOnly,
          ),
        ),
      );
  }

  /// The cover whose picture was last written as this note's preview by
  /// this editor (see [NoteCover.signature]).
  String? _coverPictureWritten;

  void clearPage(int pageIndex) {
    if (coreInfo.readOnly) return;
    final page = coreInfo.pages[pageIndex];
    setState(() {
      final removedStrokes = page.strokes.toList();
      final removedImages = page.images.toList();
      page.strokes.clear();
      page.images.clear();
      removeExcessPages();
      history.recordChange(
        EditorHistoryItem(
          type: .erase,
          pageIndex: pageIndex,
          strokes: removedStrokes,
          images: removedImages,
        ),
      );
      autosaveAfterDelay();
    });
  }

  void clearAllPages() {
    if (coreInfo.readOnly) return;
    setState(() {
      final removedStrokes = <Stroke>[];
      final removedImages = <EditorImage>[];
      for (final page in coreInfo.pages) {
        removedStrokes.addAll(page.strokes);
        removedImages.addAll(page.images);
        page.strokes.clear();
        page.images.clear();
      }
      removeExcessPages();
      history.recordChange(
        EditorHistoryItem(
          type: .erase,
          pageIndex: 0,
          strokes: removedStrokes,
          images: removedImages,
        ),
      );
    });
    autosaveAfterDelay();
  }

  Future<void> showVersionTooNewDialog() async {
    final disableReadOnly =
        await showDialog(
          context: context,
          builder: (context) => AdaptiveAlertDialog(
            title: Text(t.editor.versionTooNew.title),
            content: Text(t.editor.versionTooNew.subtitle),
            actions: [
              CupertinoDialogAction(
                child: Text(t.common.cancel),
                onPressed: () => Navigator.pop(context, false),
              ),
              CupertinoDialogAction(
                child: Text(t.editor.versionTooNew.allowEditing),
                onPressed: () => Navigator.pop(context, true),
              ),
            ],
          ),
        ) ??
        false;

    if (!mounted) return;
    if (!disableReadOnly) return;

    if (coreInfo.readOnlyReason == .versionTooNew) {
      coreInfo.readOnlyReason = null;
      if (mounted) setState(() {});
    }
  }

  /// Whether the page sidebar is showing: switched on, and the screen is
  /// wide enough.
  bool get _sidebarVisible =>
      mounted &&
      stows.editorPageSidebar.value &&
      MediaQuery.sizeOf(context).width >= PageSidebar.minScreenWidth;

  /// How wide the pages can be: the screen, less the sidebar.
  double get _viewportWidth =>
      MediaQuery.sizeOf(context).width -
      (_sidebarVisible ? PageSidebar.width : 0);

  late int _lastCurrentPageIndex = coreInfo.initialPageIndex ?? 0;

  /// The index of the page that is currently centered on screen.
  int get currentPageIndex {
    if (!mounted) return _lastCurrentPageIndex;

    final screenWidth = _viewportWidth;

    return _lastCurrentPageIndex = getPageIndexFromScrollPosition(
      scrollY: -scrollY,
      screenWidth: screenWidth,
      pages: coreInfo.pages,
    );
  }

  @visibleForTesting
  static int getPageIndexFromScrollPosition({
    required double scrollY,
    required double screenWidth,
    required List<EditorPage> pages,
  }) {
    for (int pageIndex = 0; pageIndex < pages.length; pageIndex++) {
      final bottomOfPage = CanvasGestureDetector.getTopOfPage(
        pageIndex: pageIndex + 1, // top of next page
        pages: pages,
        screenWidth: screenWidth,
      );

      if (scrollY < bottomOfPage) {
        return pageIndex;
      }
    }
    // below the last page
    return pages.length - 1;
  }

  @override
  void dispose() {
    unawaited(_cleanUpAsync());

    DynamicMaterialApp.removeFullscreenListener(_setState);
    stows.editorPageSidebar.removeListener(_setState);
    _gn.dispose();
    stows.penProbe.removeListener(_setState);
    _visiblePageIndex.removeListener(_onVisiblePageChanged);
    _transformationController.removeListener(_scheduleVisiblePageUpdate);
    OpenTabs.paths.removeListener(_setState);

    _delayedSaveTimer?.cancel();
    _watchServerTimer?.cancel();
    _lastSeenPointerCountTimer?.cancel();

    _removeKeybindings();
    HardwareKeyboard.instance.removeHandler(_handleStylusKey);
    unawaited(_nativeStylusSub?.cancel());
    unawaited(PenLatencyProbe.instance.stop());

    // manually save pen properties since the listeners don't fire if a property is changed
    stows.lastFountainPenOptions.notifyListeners();
    stows.lastBallpointPenOptions.notifyListeners();
    stows.lastHighlighterOptions.notifyListeners();
    stows.lastPencilOptions.notifyListeners();
    stows.lastShapePenOptions.notifyListeners();
    stows.lastBrushPenOptions.notifyListeners();
    stows.lastCalligraphyPenOptions.notifyListeners();

    super.dispose();
  }

  Future<void> _cleanUpAsync() async {
    try {
      if (_renameTimer?.isActive ?? false) {
        _renameTimer!.cancel();
        await _renameFileNow();
        filenameTextEditingController.dispose();
      }
      await saveToFile();
      await _removeAssetsKeptForUndo();
    } finally {
      // The note as it is left.
      unawaited(
        NoteVersions.snapshot(
          coreInfo.filePath + Editor.extension,
          reason: NoteVersion.reasonClose,
        ),
      );
      coreInfo.dispose();
    }
  }
}
