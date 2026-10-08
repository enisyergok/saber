import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:saber/components/canvas/_stroke.dart';
import 'package:saber/components/canvas/image/editor_image.dart';
import 'package:saber/data/editor/page.dart';
import 'package:saber/data/pdf/pdf_removal.dart';
import 'package:saber/data/tools/ink_eraser.dart';
import 'package:sbn/canvas_background_pattern.dart';
import 'package:sbn/change.dart';

class EditorHistory {
  static const maxHistoryLength = 100;

  /// A stack of the changes that have been made in the editor.
  /// The last element is used when undoing.
  ///
  /// See also: [_future]
  final List<EditorHistoryItem> _past = [];

  /// A stack of the changes that have been undone in the editor.
  /// The last element is used when redoing.
  ///
  /// See also: [_past]
  final List<EditorHistoryItem> _future = [];

  /// The last saved state in the history.
  /// This is used to determine whether an autosave is needed.
  EditorHistoryItem? _lastSaved;

  /// True if redo is possible.
  /// We don't directly clear [_future] because we sometimes need to
  /// reject strokes (i.e. accidental strokes when zooming).
  var _isRedoPossible = false;

  /// Removes an element from the [_past] stack,
  /// adds it to the [_future] stack, and returns it.
  ///
  /// Please check [canUndo] first: this method will
  /// throw an exception if there is nothing to undo.
  EditorHistoryItem undo() {
    if (_past.isEmpty) throw Exception('Nothing to undo');
    final item = _past.removeLast();
    _future.add(item);
    return item;
  }

  /// Removes an element from the [_future] stack,
  /// adds it to the [_past] stack, and returns it.
  ///
  /// Please check [canRedo] first: this method will
  /// throw an exception if there is nothing to redo.
  EditorHistoryItem redo() {
    if (_future.isEmpty) throw Exception('Nothing to redo');
    final item = _future.removeLast();
    _past.add(item);
    return item;
  }

  /// Allows you to see the last item in the [_past] stack
  /// without removing it.
  ///
  /// Please check [canUndo] first: this method will
  /// throw an exception if there is nothing to undo.
  EditorHistoryItem peekUndo() {
    if (_past.isEmpty) throw Exception('Nothing to undo');
    return _past.last;
  }

  /// Allows you to see the last item in the [_future] stack
  /// without removing it.
  ///
  /// Please check [canRedo] first: this method will
  /// throw an exception if there is nothing to redo.
  EditorHistoryItem peekRedo() {
    if (_future.isEmpty) throw Exception('Nothing to redo');
    return _future.last;
  }

  /// Adds an item to the [_past] stack.
  void recordChange(EditorHistoryItem item) {
    assert(
      item.type != .quillUndoneChange,
      'EditorHistoryItemType.quillUndoneChange is just a hack to make undoing quill changes easier. It should just be recorded as a quill change.',
    );

    _past.add(item);
    if (_past.length > maxHistoryLength) _past.removeAt(0);
    _isRedoPossible = false;
  }

  /// Marks the last change as saved to disk.
  /// This does not modify the history stacks, but allows us to know
  /// whether the current state is saved or not.
  void markLastChangeAsSaved() {
    _lastSaved = _past.lastOrNull;
    _changedOutsideHistory = false;
  }

  /// Whether something was changed that is not one of the steps that can
  /// be undone (the notebook's cover, a bookmark): it has to be saved all
  /// the same.
  var _changedOutsideHistory = false;

  /// Says that the note was changed in a way undo knows nothing about, so
  /// that it is saved (see [isCurrentStateSaved]).
  void markUnsaved() => _changedOutsideHistory = true;

  /// Whether the current state is saved to disk.
  ///
  /// Note that this explicitly checks the last change in the history,
  /// not whether _past is empty. This is because _past items can be discarded
  /// if the history exceeds [maxHistoryLength].
  bool get isCurrentStateSaved {
    return !_changedOutsideHistory && _past.lastOrNull == _lastSaved;
  }

  /// Removes the last history item due to a rejected stroke.
  /// This does essentially the opposite of [recordChange].
  EditorHistoryItem? removeAccidentalStroke() {
    _isRedoPossible = true;
    if (_past.isEmpty) return null;
    assert(_past.last.type == .draw, 'Accidental stroke is not a draw');
    assert(
      _past.last.strokes.length == 1,
      'Accidental strokes should be single-stroke',
    );
    assert(
      _past.last.images.isEmpty,
      'Accidental strokes should not contain images',
    );
    return _past.removeLast();
  }

  /// Returns true if there is something to undo.
  bool get canUndo {
    return _past.isNotEmpty;
  }

  /// Returns true if there is something to redo.
  bool get canRedo {
    return _isRedoPossible && _future.isNotEmpty;
  }

  set canRedo(bool isRedoPossible) {
    _isRedoPossible = isRedoPossible;
  }

  void clearRedo() {
    _future.clear();
  }

  /// The pictures and PDF pages that are not in the note now but that
  /// undoing or redoing could bring back. Their files must stay on disk
  /// for as long as the note is open.
  Iterable<EditorImage> get imagesKept sync* {
    for (final item in [..._past, ..._future]) {
      yield* item.images;
      final page = item.page;
      if (page != null) yield* [?page.backgroundImage, ...page.images];
      final removal = item.pdfRemoval;
      if (removal != null) yield* removal.images;
    }
  }
}

class EditorHistoryItem {
  new({
    required this.type,
    required this.pageIndex,
    required this.strokes,
    required this.images,
    this.offset,
    this.page,
    this.quillChange,
    this.colorChange,
    this.backgroundPatternChange,
    this.transform,
    this.reshapeChange,
    this.replacements,
    this.pdfRemoval,
    this.imageTurns,
    this.imageCut,
  }) : assert(
         (type != .removePdf && type != .removePdfRedone) ||
             pdfRemoval != null,
         'What was removed must be provided for removePdf',
       ),
       assert(
         type != .move || offset != null,
         'Offset must be provided for move',
       ),
       assert(
         type != .transform || transform != null,
         'Transform must be provided for transform',
       ),
       assert(
         type != .reshape || reshapeChange != null,
         'Reshape change must be provided for reshape',
       ),
       assert(
         type != .deletePage || page != null,
         'Page must be provided for deletePage',
       ),
       assert(
         type != .insertPage || page != null,
         'Page must be provided for insertPage',
       ),
       assert(
         type != .quillChange || quillChange != null,
         'Quill change must be provided for quillChange',
       ),
       assert(
         type != .quillUndoneChange || quillChange != null,
         'Quill change must be provided for quillUndoneChange',
       ),
       assert(
         type != .changeColor || colorChange?.length == strokes.length,
         'colorChange must be provided and contain each of strokes',
       ),
       assert(
         type != .backgroundPattern || backgroundPatternChange != null,
         'Background pattern change must be provided for backgroundPattern',
       ),
       assert(
         (type != .replace && type != .replaceRedone) || replacements != null,
         'Replacements must be provided for replace',
       );

  final EditorHistoryItemType type;
  final int pageIndex;
  final List<Stroke> strokes;
  final List<EditorImage> images;
  final Rect? offset;
  final EditorPage? page;
  final DocChange? quillChange;
  final Map<Stroke, Change<Color>>? colorChange;
  final Change<CanvasBackgroundPattern>? backgroundPatternChange;

  /// For [EditorHistoryItemType.transform]: the matrix that was applied to
  /// [strokes] and [images] (undoing applies its inverse).
  final Matrix4? transform;

  /// For [EditorHistoryItemType.reshape]: the corners of each shape before
  /// and after one of its corners was dragged.
  final Map<Stroke, Change<List<Offset>>>? reshapeChange;

  /// For [EditorHistoryItemType.replace]: what became of each stroke the
  /// precise eraser went over, in the order the strokes were on the page.
  final List<StrokeReplacement>? replacements;

  /// For [EditorHistoryItemType.removePdf]: the pages that left the note
  /// and the pages that lost the PDF behind their writing.
  final PdfRemoval? pdfRemoval;

  /// For [EditorHistoryItemType.move] of pictures: the quarter turns
  /// clockwise they were turned by as well (undoing turns them back).
  final int? imageTurns;

  /// For [EditorHistoryItemType.move] of a picture: the part of it that
  /// was shown before and after it was cut (undoing shows the one before).
  final Change<Rect>? imageCut;

  EditorHistoryItem copyWith({
    EditorHistoryItemType? type,
    int? pageIndex,
    List<Stroke>? strokes,
    List<EditorImage>? images,
    Rect? offset,
    EditorPage? page,
    DocChange? quillChange,
    Map<Stroke, Change<Color>>? colorChange,
    Change<CanvasBackgroundPattern>? backgroundPatternChange,
    Matrix4? transform,
    Map<Stroke, Change<List<Offset>>>? reshapeChange,
    List<StrokeReplacement>? replacements,
    PdfRemoval? pdfRemoval,
    int? imageTurns,
    Change<Rect>? imageCut,
  }) {
    return EditorHistoryItem(
      type: type ?? this.type,
      pageIndex: pageIndex ?? this.pageIndex,
      strokes: strokes ?? this.strokes,
      images: images ?? this.images,
      offset: offset ?? this.offset,
      page: page ?? this.page,
      quillChange: quillChange ?? this.quillChange,
      colorChange: colorChange ?? this.colorChange,
      backgroundPatternChange:
          backgroundPatternChange ?? this.backgroundPatternChange,
      transform: transform ?? this.transform,
      reshapeChange: reshapeChange ?? this.reshapeChange,
      replacements: replacements ?? this.replacements,
      pdfRemoval: pdfRemoval ?? this.pdfRemoval,
      imageTurns: imageTurns ?? this.imageTurns,
      imageCut: imageCut ?? this.imageCut,
    );
  }
}

enum EditorHistoryItemType {
  draw,
  erase,
  deletePage,
  insertPage,
  move,
  transform,
  reshape,
  quillChange,
  quillUndoneChange,
  changeColor,
  backgroundPattern,

  /// Strokes made way for what the precise eraser left of them. Undoing
  /// puts the strokes back as they were.
  replace,

  /// The opposite of [replace], for redoing; never kept in the history.
  replaceRedone,

  /// A PDF was taken out of the note. Undoing puts its pages back.
  removePdf,

  /// The opposite of [removePdf], for redoing; never kept in the history.
  removePdfRedone,
}
