import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
import 'package:saber/data/tools/eraser.dart';
import 'package:saber/data/tools/highlighter.dart';
import 'package:saber/data/tools/laser_pointer.dart';
import 'package:saber/data/tools/pen.dart';
import 'package:saber/data/tools/pen_assist.dart';
import 'package:saber/data/tools/pencil.dart';
import 'package:saber/components/editor/pen_latency_dialog.dart';
import 'package:saber/components/eink/eink_refresh.dart';
import 'package:saber/components/toolbar/pdf_crop_dialog.dart';
import 'package:saber/components/toolbar/pdf_tools_dialog.dart';
import 'package:saber/components/editor_gn/gn_bar.dart';
import 'package:saber/components/editor_gn/gn_controller.dart';
import 'package:saber/components/editor_gn/gn_overlay.dart';
import 'package:saber/components/toolbar/recognize_dialog.dart';
import 'package:saber/pages/ask_notes.dart';
import 'package:saber/components/toolbar/recordings_dialog.dart';
import 'package:saber/data/pdf/pdf_note_text.dart';
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
    // Opening a note scrolls to its page: that is not a page turn.
    _eInkPageTurnsFrom = DateTime.now().add(const Duration(milliseconds: 1500));

    // A notebook that was just made in the new notebook screen.
    final spec = PendingNotebook.take(filePath);
    if (spec != null) await applyNotebookSpec(spec);

    if (widget.pdfPath != null) {
      await importPdfFromFilePath(widget.pdfPath!);
    }
    if (widget.imagePath != null) {
      await _addImageFromPath(widget.imagePath!);
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
      await insertCover(cover);
    } else if (mounted) {
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
    coreInfo = await EditorCoreInfo.loadFromFilePath(filePath);
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

          // fix the page indices of all pages after this one
          for (int i = item.pageIndex + 1; i < coreInfo.pages.length; ++i) {
            final page = coreInfo.pages[i];
            page.updatePageIndex(i);
          }

        case .insertPage:
          // remove the page at the given index
          coreInfo.pages.removeAt(item.pageIndex);

          // fix the page indices of all pages after this one
          for (int i = item.pageIndex; i < coreInfo.pages.length; ++i) {
            final page = coreInfo.pages[i];
            page.updatePageIndex(i);
          }

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
    }
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
  bool isDrawGesture(ScaleStartDetails details) {
    if (coreInfo.readOnly) return false;

    CanvasImage.activeListener
        .notifyListenersPlease(); // un-select active image

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
      return false;
    }
  }

  void onDrawStart(ScaleStartDetails details) {
    final page = coreInfo.pages[dragPageIndex!];
    final position = page.renderBox!.globalToLocal(details.focalPoint);
    history.canRedo = false;

    if (currentTool is Pen) {
      ShapeSnap.redraw = page.redrawLiveInk;
      (currentTool as Pen).onDragStart(
        position,
        page,
        dragPageIndex!,
        currentPressure,
      );
    } else if (currentTool is Eraser) {
      for (final stroke in (currentTool as Eraser).checkForOverlappingStrokes(
        position,
        page.strokes,
      )) {
        page.strokes.remove(stroke);
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
      (currentTool as Pen).onDragUpdate(position, currentPressure);
      page.redrawLiveInk();
    } else if (currentTool is Eraser) {
      for (final stroke in (currentTool as Eraser).checkForOverlappingStrokes(
        position,
        page.strokes,
      )) {
        page.strokes.remove(stroke);
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
    setState(() {
      if (currentTool is Pen) {
        final pen = currentTool as Pen;
        var newStroke = pen.onDragEnd();
        if (newStroke == null) return;
        if (newStroke.isEmpty) return;

        final recognise = pen.usesAssists && !ShapeSnap.lastWasSnapped;
        if (stows.autoStraightenLines.value &&
            recognise &&
            newStroke.isStraightLine()) {
          newStroke.convertToLine();
        } else if (stows.autoShapes.value && recognise) {
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
        final erased = (currentTool as Eraser).onDragEnd();
        if (stylusButtonWasPressed || stows.disableEraserAfterUse.value) {
          // restore previous tool
          stylusButtonWasPressed = false;
          currentTool = _lastNonEraserTool;
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
    history.recordChange(
      EditorHistoryItem(
        type: .move,
        pageIndex: image.pageIndex,
        strokes: [],
        images: [image],
        offset: offset,
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
    quill.focusNode.addListener(_onQuillFocusChange);
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
    try {
      await Future.wait([
        FileManager.writeFile(filePath, bson, awaitWrite: true),
        for (int i = 0; i < assets.length; ++i)
          assets
              .getBytes(i)
              .then(
                (bytes) => FileManager.writeFile(
                  '$filePath.$i',
                  bytes,
                  awaitWrite: true,
                ),
              ),
        FileManager.removeUnusedAssets(filePath, numAssets: assets.length),
      ]);
      savingState.value = .saved;
      history.markLastChangeAsSaved();
    } catch (e, st) {
      log.severe('Failed to save file: $e', e, st);
      savingState.value = .waitingToSave;
      if (kDebugMode) rethrow;
      return;
    }

    if (!mounted) return;
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
  /// Returns whether a PDF was picked.
  Future<bool> importPdf() async {
    if (coreInfo.readOnly) return false;
    if (!Editor.canRasterPdf) return false;

    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (file == null) return false;

    return importPdfFromFilePath(file.path!);
  }

  Future<bool> importPdfFromFilePath(String path) async {
    final pdfDocument = await coreInfo.assetCache.pdfDocumentCache.load(path);

    final emptyPage = coreInfo.pages.removeLast();
    assert(emptyPage.isEmpty);

    for (final pdfPage in pdfDocument.pages) {
      assert(pdfPage.pageNumber >= 1, 'pdfrx page numbers start at 1');

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
          pdfFile: File(path),
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

    coreInfo.pages.add(emptyPage);
    if (mounted) setState(() {});

    autosaveAfterDelay();

    return true;
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

    final Widget canvas = CanvasGestureDetector(
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
                        icon: const Icon(Icons.view_sidebar_outlined),
                        selectedIcon: const Icon(Icons.view_sidebar),
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
                      icon: Icons.insert_page_break,
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
                          recording ? Icons.stop_circle : Icons.speed,
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
                    icon: const Icon(Icons.mic_none),
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
                          bookmarked ? Icons.bookmark : Icons.bookmark_border,
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
                      icon: Icons.more_vert,
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
                child: const Icon(Icons.fullscreen_exit),
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
      insertCover: insertCover,
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
      clearAllPages: clearAllPages,
      redrawAndSave: () => setState(() {
        if (coreInfo.readOnly) return;
        autosaveAfterDelay();
      }),
      pickPhotos: _pickPhotos,
      importPdf: importPdf,
      canRasterPdf: Editor.canRasterPdf,
      hasPdf: PdfNoteText.hasPdf(coreInfo),
      currentPageHasPdf:
          coreInfo.pages.getOrNull(currentPageIndex)?.backgroundImage
              is PdfEditorImage,
      showPdfTools: showPdfTools,
      cropPdfPage: cropPdfPage,
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
      duplicatePage: (int pageIndex) => setState(() {
        if (coreInfo.readOnly) return;
        final page = coreInfo.pages[pageIndex];
        final newPage = page.copyWith(
          strokes: page.strokes
              .map((stroke) => stroke.copy()..pageIndex += 1)
              .toList(),
          images: page.images
              .map((image) => image.copy()..pageIndex += 1)
              .toList(),
          quill: QuillStruct(
            controller: flutter_quill.QuillController(
              document: flutter_quill.Document.fromDelta(
                page.quill.controller.document.toDelta(),
              ),
              selection: const TextSelection.collapsed(offset: 0),
            ),
            focusNode: FocusNode(debugLabel: 'Quill Focus Node'),
          ),
          backgroundImage: page.backgroundImage?.copy()?..pageIndex += 1,
        );
        coreInfo.pages.insert(pageIndex + 1, newPage);
        listenToQuillChanges(newPage.quill, pageIndex + 1);
        history.recordChange(
          EditorHistoryItem(
            type: .insertPage,
            pageIndex: pageIndex,
            strokes: const [],
            images: const [],
            page: newPage,
          ),
        );
        autosaveAfterDelay();
      }),
      clearPage: clearPage,
      deletePage: (int pageIndex) => setState(() {
        if (coreInfo.readOnly) return;
        final page = coreInfo.pages.removeAt(pageIndex);
        createPage(pageIndex - 1);
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
      }),
      transformationController: _transformationController,
    );
  }

  void insertPageAfter(int pageIndex) => setState(() {
    if (coreInfo.readOnly) return;
    final page = EditorPage(size: _sizeForPageAfter(pageIndex));
    coreInfo.pages.insert(pageIndex + 1, page);
    listenToQuillChanges(page.quill, pageIndex + 1);
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

  /// Inserts [design] as a new first page, with the note's name as title.
  Future<void> insertCover(CoverDesign design) async {
    if (coreInfo.readOnly) return;
    // As big as the notebook's own pages.
    final first = coreInfo.pages.firstOrNull;
    final size = first == null || first.backgroundImage is PdfEditorImage
        ? EditorPage.defaultSize
        : first.size;
    final bytes = await design.renderPng(size, title: coreInfo.fileName);
    if (!mounted) return;
    setState(() {
      final page = EditorPage(
        size: size,
        backgroundImage: PngEditorImage(
          id: coreInfo.nextImageId++,
          extension: '.png',
          imageProvider: MemoryImage(bytes),
          pageIndex: 0,
          pageSize: size,
          invertible: false,
          onMoveImage: onMoveImage,
          onDeleteImage: onDeleteImage,
          onMiscChange: autosaveAfterDelay,
          onLoad: () => setState(() {}),
          assetCache: coreInfo.assetCache,
        ),
      );
      coreInfo.pages.insert(0, page);
      listenToQuillChanges(page.quill, 0);
      history.recordChange(
        EditorHistoryItem(
          type: .insertPage,
          pageIndex: 0,
          strokes: const [],
          images: const [],
          page: page,
        ),
      );
      autosaveAfterDelay();
    });
  }

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
    } finally {
      coreInfo.dispose();
    }
  }
}
