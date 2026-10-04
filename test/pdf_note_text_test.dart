import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:saber/data/pdf/pdf_note_text.dart';

void main() {
  group('PDF text search:', () {
    test('finds matches ignoring case and Turkish letters', () {
      expect(PdfNoteText.findMatches('Sınav tarihi: SINAV', 'sinav'), [0, 13]);
      expect(PdfNoteText.findMatches('İstanbul', 'istanbul'), [0]);
      expect(PdfNoteText.findMatches('abc', ''), isEmpty);
      expect(PdfNoteText.findMatches('abc', 'xyz'), isEmpty);
    });

    test('snippets are short, one line and marked when cut', () {
      final text = '${'a ' * 60}HEDEF\n\n${'b ' * 60}';
      final snippet = PdfNoteText.snippetAround(text, text.indexOf('HEDEF'), 5);
      expect(snippet.contains('HEDEF'), isTrue);
      expect(snippet.contains('\n'), isFalse);
      expect(snippet.startsWith('…'), isTrue);
      expect(snippet.endsWith('…'), isTrue);
      expect(snippet.length, lessThan(100));
    });

    test('at most a few snippets per page', () {
      final text = List.filled(10, 'kelime').join(' ');
      expect(PdfNoteText.snippetsFor(text, 'kelime').length, 3);
    });
  });

  group('PDF contents:', () {
    test('flattens nested entries and maps pages', () {
      const outline = [
        PdfOutlineNode(
          title: 'Bölüm 1',
          dest: PdfDest(1, PdfDestCommand.fit, null),
          children: [
            PdfOutlineNode(
              title: 'Alt başlık',
              dest: PdfDest(3, PdfDestCommand.fit, null),
              children: [],
            ),
          ],
        ),
        PdfOutlineNode(
          title: 'Başka PDF',
          dest: PdfDest(99, PdfDestCommand.fit, null),
          children: [],
        ),
        PdfOutlineNode(title: 'Hedefsiz', dest: null, children: []),
      ];
      // Note pages are shifted by 10 relative to PDF page numbers.
      final entries = PdfNoteText.flattenOutline(
        outline,
        (n) => n <= 3 ? n + 10 : null,
      );
      expect(entries.map((e) => e.title), ['Bölüm 1', 'Alt başlık']);
      expect(entries.map((e) => e.depth), [0, 1]);
      expect(entries.map((e) => e.pageIndex), [11, 13]);
    });
  });
}
