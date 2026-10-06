import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfrx/pdfrx.dart';

/// Where tests found PDFium, the library that reads PDFs (null if they
/// did not). Set by [setUpPdfium].
String? pdfiumPath;

/// Looks for the PDFium library that the build fetched for this computer.
String? findPdfium() {
  final fromEnvironment = Platform.environment['PDFIUM_PATH'];
  if (fromEnvironment != null && File(fromEnvironment).existsSync()) {
    return fromEnvironment;
  }
  final names = Platform.isWindows
      ? const ['pdfium.dll']
      : Platform.isMacOS
      ? const ['libpdfium.dylib']
      : const ['libpdfium.so'];
  final roots = [
    'build',
    '.dart_tool',
    p.join(Platform.environment['HOME'] ?? '', '.pdfrx'),
    p.join(Directory.systemTemp.path, 'pdfrx.cache'),
  ];
  for (final root in roots) {
    final directory = Directory(root);
    if (!directory.existsSync()) continue;
    try {
      for (final entity in directory.listSync(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File && names.contains(p.basename(entity.path))) {
          return entity.absolute.path;
        }
      }
    } on FileSystemException {
      // A folder that can't be listed is not where it is.
    }
  }
  return null;
}

/// Points the app's PDF reader at PDFium. Returns whether PDFs can be read
/// in this test run; what was found is noted in
/// `test/defter_shots/samples/pdfium.txt` either way.
bool setUpPdfium() {
  pdfiumPath ??= findPdfium();
  final found = pdfiumPath;
  if (found != null) Pdfrx.pdfiumModulePath = found;
  Pdfrx.cacheDirectoryPath ??= Directory.systemTemp
      .createTempSync('pdfrx_test_cache')
      .path;
  try {
    final samples = Directory('test/defter_shots/samples')
      ..createSync(recursive: true);
    File(
      '${samples.path}/pdfium.txt',
    ).writeAsStringSync('PDFium for tests: ${found ?? 'NOT FOUND'}\n');
  } on FileSystemException {
    // The note is only for whoever reads the results.
  }
  return found != null;
}

/// A PDF of three pages of different sizes: A4 upright, A4 on its side and
/// A5. Sizes are in points, as PDFs have them.
const samplePdfSizes = [
  (width: 595.28, height: 841.89),
  (width: 841.89, height: 595.28),
  (width: 419.53, height: 595.28),
];

Future<Uint8List> samplePdfBytes({int copies = 1}) async {
  final document = pw.Document();
  for (var copy = 0; copy < copies; copy++) {
    for (var i = 0; i < samplePdfSizes.length; i++) {
      final size = samplePdfSizes[i];
      final number = copy * samplePdfSizes.length + i + 1;
      document.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(size.width, size.height, marginAll: 36),
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Defter PDF', style: const pw.TextStyle(fontSize: 34)),
              pw.SizedBox(height: 8),
              pw.Text('Page $number', style: const pw.TextStyle(fontSize: 22)),
              pw.SizedBox(height: 16),
              pw.Container(
                width: 160 + 40.0 * i,
                height: 60,
                color: const [
                  PdfColors.blue,
                  PdfColors.green,
                  PdfColors.orange,
                ][i],
              ),
              pw.SizedBox(height: 16),
              pw.Text(
                'The quick brown fox jumps over the lazy dog. ' * 6,
                style: const pw.TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }
  }
  return document.save();
}

/// Writes [samplePdfBytes] to [directory] and returns the file.
Future<File> writeSamplePdf(
  Directory directory, {
  String name = 'Ders notlari.pdf',
  int copies = 1,
}) async {
  final file = File(p.join(directory.path, name));
  await file.writeAsBytes(await samplePdfBytes(copies: copies), flush: true);
  return file;
}
