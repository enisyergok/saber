import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';

/// Links from the text of one note to another note.
///
/// They are ordinary links in the text, with an address of the form
/// `defter://note?path=%2FFolder%2FName`, so they survive export and sync.
abstract class NoteLink {
  static const scheme = 'defter';

  /// The link address of a note (its path without extension).
  static String encode(String notePath) =>
      Uri(scheme: scheme, host: 'note', queryParameters: {'path': notePath})
          .toString();

  /// The note path inside [url], or null if it isn't a note link.
  static String? decode(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != scheme || uri.host != 'note') return null;
    final path = uri.queryParameters['path'];
    return (path == null || path.isEmpty) ? null : path;
  }

  /// The note's name as shown in the text.
  static String nameOf(String notePath) =>
      notePath.substring(notePath.lastIndexOf('/') + 1);

  /// Links the selected text to the note, or, with nothing selected, inserts
  /// the note's name as a link.
  static void apply(QuillController controller, String notePath) {
    final url = encode(notePath);
    final selection = controller.selection;
    if (!selection.isCollapsed) {
      controller.formatSelection(LinkAttribute(url));
      return;
    }

    final name = nameOf(notePath);
    final index = selection.baseOffset < 0 ? 0 : selection.baseOffset;
    controller.replaceText(
      index,
      0,
      name,
      TextSelection.collapsed(offset: index + name.length),
    );
    controller.formatText(index, name.length, LinkAttribute(url));
  }
}
