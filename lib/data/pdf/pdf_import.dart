import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:saber/components/canvas/image/pdf_document_cache.dart';

/// Why a PDF could not be put into a note.
enum PdfImportFailure {
  /// The picked file is not there (any more).
  missing,

  /// The file has nothing in it.
  empty,

  /// The file is not a PDF.
  notPdf,

  /// The PDF is locked with a password.
  locked,

  /// The PDF could not be read: it is damaged, or the part of the app that
  /// reads PDFs could not be started.
  unreadable,
}

class PdfImportException implements Exception {
  const new(this.failure, [this.detail]);

  final PdfImportFailure failure;

  /// What the device said, for whoever looks into it.
  final String? detail;

  @override
  String toString() =>
      'PdfImportException(${failure.name}${detail == null ? '' : ': $detail'})';
}

/// Getting a PDF ready to be put into a note.
abstract class PdfImport {
  /// How much of the start of a file is searched for the mark of a PDF.
  /// PDF readers accept the mark anywhere in the first 1024 bytes.
  static const headLength = 1024;

  /// Whether [head], the start of a file, is the start of a PDF.
  static bool looksLikePdf(List<int> head) {
    const mark = [0x25, 0x50, 0x44, 0x46, 0x2d]; // %PDF-
    final end = math.min(head.length, headLength) - mark.length;
    for (var i = 0; i <= end; i++) {
      var found = true;
      for (var j = 0; j < mark.length; j++) {
        if (head[i + j] != mark[j]) {
          found = false;
          break;
        }
      }
      if (found) return true;
    }
    return false;
  }

  /// Throws if the file at [path] is plainly not a PDF that can be read.
  /// Nothing is changed in the note before this has passed.
  static Future<void> check(String path) async {
    final file = File(path);
    final int length;
    try {
      if (!await file.exists()) {
        throw PdfImportException(.missing, path);
      }
      length = await file.length();
    } on FileSystemException catch (e) {
      throw PdfImportException(.missing, '$e');
    }
    if (length == 0) throw PdfImportException(.empty, path);

    final head = BytesBuilder(copy: false);
    try {
      await for (final piece in file.openRead(
        0,
        math.min(length, headLength),
      )) {
        head.add(piece);
      }
    } on FileSystemException catch (e) {
      throw PdfImportException(.unreadable, '$e');
    }
    if (!looksLikePdf(head.takeBytes())) {
      throw PdfImportException(.notPdf, p.basename(path));
    }
  }

  /// A name that is safe as the name of a file in a folder of the app.
  static String safeName(String name) {
    var safe = p.basename(name.replaceAll('\\', '/')).trim();
    safe = safe.replaceAll(RegExp(r'[\x00-\x1f/:*?"<>|]'), '_');
    if (safe.isEmpty || safe == '.' || safe == '..') safe = 'document.pdf';
    if (safe.length > 120) {
      final extension = p.extension(safe);
      safe = safe.substring(0, 120 - extension.length) + extension;
    }
    return safe;
  }

  /// The longest name given to a note that is made from a PDF. File
  /// systems allow about 255 bytes for a name, and a note's files add
  /// endings of their own to it.
  static const maxNoteNameLength = 80;

  /// A name for the note that is made from the PDF called [pdfName]: its
  /// name without what a note's name can't have, and not too long.
  static String noteNameFor(String pdfName) {
    var name = p.basename(pdfName.replaceAll('\\', '/'));
    if (name.toLowerCase().endsWith('.pdf')) {
      name = name.substring(0, name.length - 4);
    }
    name = name
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    // A name can't be only dots, or end with one on some systems.
    name = name.replaceAll(RegExp(r'^\.+|[. ]+$'), '');
    final letters = name.runes.toList();
    if (letters.length > maxNoteNameLength) {
      name = String.fromCharCodes(
        letters.sublist(0, maxNoteNameLength),
      ).trim();
    }
    return name.isEmpty ? 'PDF' : name;
  }

  /// A file on this device with the content of a picked file.
  ///
  /// Pickers usually hand over a copy of the file ([path]). Some only give
  /// the content: it is then written to a file of the app, in [folder]
  /// (the temporary folder by default).
  static Future<String> localPath({
    required String? path,
    required String name,
    required Future<Uint8List> Function() readBytes,
    Directory? folder,
  }) async {
    if (path != null && path.isNotEmpty && await File(path).exists()) {
      return path;
    }
    final Uint8List bytes;
    try {
      bytes = await readBytes();
    } catch (e) {
      throw PdfImportException(.missing, '$e');
    }
    try {
      final parent = folder ?? await getTemporaryDirectory();
      final into = await Directory(
        p.join(parent.path, 'pdf_import'),
      ).create(recursive: true);
      final unique = await into.createTemp('pdf');
      final file = File(p.join(unique.path, safeName(name)));
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } on FileSystemException catch (e) {
      throw PdfImportException(.unreadable, '$e');
    }
  }

  /// Opens the PDF at [path] and reads the size of each of its pages.
  ///
  /// Throws a [PdfImportException] that says what is wrong if it can't.
  static Future<PdfDocument> open(PdfDocumentCache cache, String path) async {
    await check(path);
    final PdfDocument document;
    try {
      document = await cache.load(path);
      // Pages can have different sizes: each one's own is needed.
      await cache.allPagesRead(path);
    } on PdfPasswordException catch (e) {
      throw PdfImportException(.locked, '$e');
    } catch (e) {
      throw PdfImportException(.unreadable, '$e');
    }
    if (document.pages.isEmpty) {
      throw PdfImportException(.empty, p.basename(path));
    }
    return document;
  }
}
