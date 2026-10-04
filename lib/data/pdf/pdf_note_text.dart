import 'dart:async';

import 'package:pdfrx/pdfrx.dart';
import 'package:saber/components/canvas/image/editor_image.dart';
import 'package:saber/data/editor/editor_core_info.dart';
import 'package:saber/data/search/note_search.dart';

/// One place in a note's PDF pages where the searched text was found.
class PdfSearchHit {
  const new({required this.pageIndex, required this.snippet});

  /// The index of the page in the note (not in the PDF).
  final int pageIndex;
  final String snippet;
}

/// One entry of a PDF's table of contents, flattened.
class PdfContentsEntry {
  const new({
    required this.title,
    required this.depth,
    required this.pageIndex,
  });

  final String title;
  final int depth;

  /// The index of the page in the note (not in the PDF).
  final int pageIndex;
}

/// Searching and navigating the PDF pages of a note.
abstract class PdfNoteText {
  /// How many characters of context a snippet shows around a match.
  static const snippetRadius = 36;

  /// The most matches that are reported for one page.
  static const maxHitsPerPage = 3;

  /// The offsets in [text] where [query] occurs, ignoring case and Turkish
  /// letter variants (so "sinav" finds "Sınav").
  static List<int> findMatches(String text, String query) {
    final needle = NoteSearchIndex.fold(query.trim());
    if (needle.isEmpty) return const [];
    final haystack = NoteSearchIndex.fold(text);
    final result = <int>[];
    var from = 0;
    while (true) {
      final index = haystack.indexOf(needle, from);
      if (index < 0) break;
      result.add(index);
      from = index + needle.length;
    }
    return result;
  }

  /// A one-line piece of [text] around the match at [index].
  static String snippetAround(String text, int index, int length) {
    final start = (index - snippetRadius).clamp(0, text.length);
    final end = (index + length + snippetRadius).clamp(0, text.length);
    final piece = text
        .substring(start, end)
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return '${start > 0 ? '…' : ''}$piece${end < text.length ? '…' : ''}';
  }

  /// Hits for [query] on one page's [text].
  static List<String> snippetsFor(String text, String query) {
    final length = query.trim().length;
    return [
      for (final index in findMatches(text, query).take(maxHitsPerPage))
        snippetAround(text, index, length),
    ];
  }

  /// Flattens an outline into a list, mapping PDF page numbers (starting at
  /// 1) to note pages with [notePageForPdfPage]. Entries whose page isn't in
  /// the note are dropped.
  static List<PdfContentsEntry> flattenOutline(
    List<PdfOutlineNode> nodes,
    int? Function(int pdfPageNumber) notePageForPdfPage, {
    int depth = 0,
  }) {
    final entries = <PdfContentsEntry>[];
    for (final node in nodes) {
      final pdfPage = node.dest?.pageNumber;
      final notePage = pdfPage == null ? null : notePageForPdfPage(pdfPage);
      if (notePage != null && node.title.trim().isNotEmpty) {
        entries.add(
          PdfContentsEntry(
            title: node.title.trim(),
            depth: depth,
            pageIndex: notePage,
          ),
        );
      }
      entries.addAll(
        flattenOutline(
          node.children,
          notePageForPdfPage,
          depth: depth + 1,
        ),
      );
    }
    return entries;
  }

  /// Which PDF a page's background comes from. Pages of the same PDF share
  /// a key, so each PDF is opened once.
  static Object? _sourceKey(PdfEditorImage image) =>
      image.pdfFile?.path ?? image.pdfBytes;

  static FutureOr<PdfDocument> _open(
    EditorCoreInfo coreInfo,
    PdfEditorImage image,
  ) {
    return coreInfo.assetCache.pdfDocumentCache.load(
      image.pdfFile?.path ?? 'inline_pdf_${image.id}.pdf',
      pdfBytes: image.pdfBytes,
    );
  }

  /// The note pages that have a PDF as their background.
  static Iterable<(int, PdfEditorImage)> pdfPages(EditorCoreInfo coreInfo) sync* {
    for (var i = 0; i < coreInfo.pages.length; i++) {
      final background = coreInfo.pages[i].backgroundImage;
      if (background is PdfEditorImage) yield (i, background);
    }
  }

  static bool hasPdf(EditorCoreInfo coreInfo) => pdfPages(coreInfo).isNotEmpty;

  /// Searches the text of every PDF page in the note.
  /// Reports whether any page had text at all, so a scanned PDF can be told
  /// apart from "no match".
  static Future<({List<PdfSearchHit> hits, bool anyText})> search(
    EditorCoreInfo coreInfo,
    String query,
  ) async {
    final hits = <PdfSearchHit>[];
    var anyText = false;
    final documents = <Object?, PdfDocument>{};

    for (final (noteIndex, image) in pdfPages(coreInfo)) {
      final key = _sourceKey(image);
      final document = documents[key] ??= await _open(coreInfo, image);
      if (image.pdfPage < 0 || image.pdfPage >= document.pages.length) continue;

      final page = document.pages[image.pdfPage];
      await page.ensureLoaded();
      final raw = await page.loadText();
      final text = raw?.fullText ?? '';
      if (text.trim().isNotEmpty) anyText = true;

      for (final snippet in snippetsFor(text, query)) {
        hits.add(PdfSearchHit(pageIndex: noteIndex, snippet: snippet));
      }
    }
    return (hits: hits, anyText: anyText);
  }

  /// The table of contents of the PDF(s) in the note.
  static Future<List<PdfContentsEntry>> contents(EditorCoreInfo coreInfo) async {
    final entries = <PdfContentsEntry>[];
    final done = <Object?>{};
    final pages = pdfPages(coreInfo).toList();

    for (final (_, image) in pages) {
      final key = _sourceKey(image);
      if (!done.add(key)) continue;
      final document = await _open(coreInfo, image);
      final outline = await document.loadOutline();

      final sameSource = [
        for (final (noteIndex, other) in pages)
          if (identical(_sourceKey(other), key) || _sourceKey(other) == key)
            (noteIndex, other.pdfPage),
      ];
      entries.addAll(
        flattenOutline(outline, (pdfPageNumber) {
          for (final (noteIndex, pdfIndex) in sameSource) {
            if (pdfIndex == pdfPageNumber - 1) return noteIndex;
          }
          return null;
        }),
      );
    }
    return entries;
  }
}
