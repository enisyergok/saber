import 'dart:async';
import 'dart:typed_data';

import 'package:logging/logging.dart';
import 'package:pdfrx/pdfrx.dart';

class PdfDocumentCache {
  final Map<String, FutureOr<PdfDocument>> _cache = {};
  final Map<String, Future<void>> _allPages = {};

  static final log = Logger('PdfDocumentCache');

  /// Loads a PDF document from [filePath].
  /// If the bytes are provided, they are used instead of reading from disk.
  ///
  /// A document that could not be opened is not remembered, so that it can
  /// be tried again.
  FutureOr<PdfDocument> load(String filePath, {Uint8List? pdfBytes}) {
    return _cache[filePath] ??= _loadCacheMiss(filePath, pdfBytes: pdfBytes);
  }

  Future<PdfDocument> _loadCacheMiss(
    String filePath, {
    Uint8List? pdfBytes,
  }) async {
    final PdfDocument document;
    try {
      document = await (pdfBytes == null
          ? PdfDocument.openFile(filePath, useProgressiveLoading: true)
          : PdfDocument.openData(
              pdfBytes,
              useProgressiveLoading: true,
              sourceName: filePath,
            ));
    } catch (_) {
      _cache.remove(filePath);
      rethrow;
    }
    _cache[filePath] = document;
    // Opening reads the first page only. The others are read here, a few
    // at a time: nothing else asks for them, and whatever waits for a page
    // to be read (its real size, its text) would wait for ever.
    _allPages[filePath] = document.loadPagesProgressively().then(
      (_) {},
      onError: (Object e, StackTrace st) {
        log.warning('Could not read every page of $filePath', e, st);
      },
    );
    return document;
  }

  /// Completes when every page of the document at [filePath] has been read
  /// (so that each page has its own size, not the first page's). The
  /// document is opened with [load] first.
  Future<void> allPagesRead(String filePath) async {
    await _cache[filePath];
    await _allPages[filePath];
  }

  /// Makes the document that was opened from [filePath] the document of
  /// [newFilePath] too: the file was copied or moved there, and what is
  /// open stays in use. Does nothing if the document was never opened.
  void alias(String filePath, String newFilePath) {
    final document = _cache[filePath];
    if (document == null) return;
    _cache[newFilePath] ??= document;
    final pages = _allPages[filePath];
    if (pages != null) _allPages[newFilePath] ??= pages;
  }

  void dispose() {
    // One document can be known under several paths.
    final closed = Set<PdfDocument>.identity();
    for (final documentFuture in _cache.values) {
      Future.value(documentFuture).then(
        (document) {
          if (closed.add(document)) document.dispose();
        },
        // A document that was never opened has nothing to close.
        onError: (Object _) {},
      );
    }
    _cache.clear();
    _allPages.clear();
  }
}
