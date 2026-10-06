import 'dart:math' as math;

import 'package:saber/components/canvas/image/editor_image.dart';
import 'package:saber/data/editor/editor_core_info.dart';
import 'package:saber/data/editor/page.dart';

/// Which of a note's PDF pages are taken out.
enum PdfRemovalScope {
  /// The page that is open.
  page,

  /// Every page of the PDF the open page comes from.
  document,

  /// Every PDF page in the note.
  all,
}

/// What taking PDF pages out of a note did, so that it can be undone.
class PdfRemoval {
  new({required this.removed, required this.stripped});

  /// The pages that left the note (PDF pages with nothing written on
  /// them), each with the place it had, in the order of those places.
  final List<({int index, EditorPage page})> removed;

  /// The pages that stayed because they were written on, each with the
  /// PDF page that was behind the writing.
  final List<({EditorPage page, EditorImage background})> stripped;

  /// Every picture and PDF page that undoing would bring back.
  Iterable<EditorImage> get images sync* {
    for (final entry in removed) {
      yield* [?entry.page.backgroundImage, ...entry.page.images];
    }
    for (final entry in stripped) {
      yield entry.background;
    }
  }
}

/// Takes a PDF out of a note without taking what was written on it.
///
/// A PDF page that was written on stays as a page with the writing (only
/// the PDF behind it goes); a PDF page with nothing on it leaves the note.
abstract class PdfRemover {
  /// What tells the PDFs of a note apart: the file a page is read from.
  static Object? sourceOf(PdfEditorImage image) =>
      image.pdfFile?.absolute.path ?? image.pdfBytes;

  /// Whether anything was put on [page] besides its background.
  static bool isWrittenOn(EditorPage page) =>
      page.strokes.isNotEmpty ||
      page.images.isNotEmpty ||
      !page.quill.controller.document.isEmpty();

  /// The places in the note of the PDF pages that [scope] means, seen from
  /// the page at [currentPageIndex].
  static List<int> pagesIn(
    EditorCoreInfo coreInfo,
    PdfRemovalScope scope,
    int currentPageIndex,
  ) {
    PdfEditorImage? pdfAt(int index) {
      if (index < 0 || index >= coreInfo.pages.length) return null;
      final background = coreInfo.pages[index].backgroundImage;
      return background is PdfEditorImage ? background : null;
    }

    final current = pdfAt(currentPageIndex);
    final source = current == null ? null : sourceOf(current);
    return [
      for (var i = 0; i < coreInfo.pages.length; i++)
        if (pdfAt(i) case final pdf?)
          if (switch (scope) {
            PdfRemovalScope.all => true,
            PdfRemovalScope.page => i == currentPageIndex,
            PdfRemovalScope.document =>
              current != null &&
                  (identical(pdf, current) ||
                      (source != null && sourceOf(pdf) == source)),
          })
            i,
    ];
  }

  /// How many of the pages at [pageIndexes] were written on.
  static int writtenOn(EditorCoreInfo coreInfo, List<int> pageIndexes) => [
    for (final i in pageIndexes)
      if (isWrittenOn(coreInfo.pages[i])) i,
  ].length;

  /// Takes the PDF out of the pages at [pageIndexes]. Returns what was
  /// done, or null if none of them was a PDF page.
  ///
  /// The note may be left without an empty last page: that is for the
  /// caller to add.
  static PdfRemoval? remove(EditorCoreInfo coreInfo, List<int> pageIndexes) {
    final removed = <({int index, EditorPage page})>[];
    final stripped = <({EditorPage page, EditorImage background})>[];
    for (final i in pageIndexes.toSet().toList()..sort()) {
      if (i < 0 || i >= coreInfo.pages.length) continue;
      final page = coreInfo.pages[i];
      final background = page.backgroundImage;
      if (background is! PdfEditorImage) continue;
      if (isWrittenOn(page)) {
        stripped.add((page: page, background: background));
      } else {
        removed.add((index: i, page: page));
      }
    }
    if (removed.isEmpty && stripped.isEmpty) return null;
    final removal = PdfRemoval(removed: removed, stripped: stripped);
    redo(coreInfo, removal);
    return removal;
  }

  /// Does [removal] (again).
  static void redo(EditorCoreInfo coreInfo, PdfRemoval removal) {
    for (final entry in removal.stripped) {
      entry.page.backgroundImage = null;
    }
    for (final entry in removal.removed) {
      coreInfo.pages.removeWhere((page) => identical(page, entry.page));
    }
    _renumber(coreInfo);
  }

  /// Puts back what [removal] took: the pages where they were and the PDF
  /// behind the pages that stayed.
  static void undo(EditorCoreInfo coreInfo, PdfRemoval removal) {
    for (final entry in removal.stripped) {
      entry.page.backgroundImage = entry.background;
    }
    for (final entry in removal.removed) {
      if (coreInfo.pages.any((page) => identical(page, entry.page))) continue;
      coreInfo.pages.insert(
        math.min(entry.index, coreInfo.pages.length),
        entry.page,
      );
    }
    _renumber(coreInfo);
  }

  /// What is on a page knows which page it is on.
  static void _renumber(EditorCoreInfo coreInfo) {
    for (var i = 0; i < coreInfo.pages.length; i++) {
      coreInfo.pages[i].updatePageIndex(i);
    }
  }
}
