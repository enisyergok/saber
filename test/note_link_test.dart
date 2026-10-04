import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saber/data/links/note_link.dart';

QuillController _controller(String text) => QuillController(
  document: Document()..insert(0, text),
  selection: const TextSelection.collapsed(offset: 0),
);

void main() {
  group('Note links:', () {
    test('a note path survives encoding', () {
      for (final path in ['/Notlar', '/Okul/Fizik 1', '/Ç ş ğ/ü&=?#']) {
        expect(NoteLink.decode(NoteLink.encode(path)), path);
      }
    });

    test('other addresses are not note links', () {
      expect(NoteLink.decode('https://example.com'), isNull);
      expect(NoteLink.decode('defter://other?path=/a'), isNull);
      expect(NoteLink.decode('defter://note'), isNull);
      expect(NoteLink.decode('not a url at all %%'), isNull);
    });

    test('selected text becomes the link', () {
      final controller = _controller('bkz. fizik notu');
      controller.updateSelection(
        const TextSelection(baseOffset: 5, extentOffset: 15),
        ChangeSource.local,
      );
      NoteLink.apply(controller, '/Okul/Fizik');
      final style = controller.document.collectStyle(5, 10);
      expect(NoteLink.decode(style.attributes['link']!.value as String), '/Okul/Fizik');
      expect(controller.document.toPlainText(), 'bkz. fizik notu\n');
    });

    test('with no selection the note name is inserted as a link', () {
      final controller = _controller('');
      NoteLink.apply(controller, '/Okul/Fizik');
      expect(controller.document.toPlainText(), 'Fizik\n');
      final style = controller.document.collectStyle(0, 5);
      expect(NoteLink.decode(style.attributes['link']!.value as String), '/Okul/Fizik');
    });
  });
}
