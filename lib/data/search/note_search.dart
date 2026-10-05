import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:saber/data/editor/editor_core_info.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/search/handwriting_text.dart';

/// One note's searchable text.
class NoteSearchEntry {
  const NoteSearchEntry({
    required this.path,
    required this.modifiedMs,
    required this.text,
    this.handwriting = const [],
  });

  /// Without extension, like everywhere else in the library.
  final String path;
  final int modifiedMs;

  /// The typed text of all pages, as written (not folded).
  final String text;

  /// Text read from the handwriting, one per page (see [HandwritingTexts]).
  /// Not saved with the index; it is filled in from its own file.
  final List<String> handwriting;

  /// Everything searchable in the note: typed text, then handwriting.
  String get fullText {
    final written = handwriting.where((t) => t.trim().isNotEmpty).join('\n');
    if (written.isEmpty) return text;
    return text.isEmpty ? written : '$text\n$written';
  }

  NoteSearchEntry withHandwriting(List<String> pages) => NoteSearchEntry(
    path: path,
    modifiedMs: modifiedMs,
    text: text,
    handwriting: pages,
  );

  Map<String, dynamic> toJson() => {'p': path, 'm': modifiedMs, 't': text};

  factory NoteSearchEntry.fromJson(Map<String, dynamic> json) =>
      NoteSearchEntry(
        path: json['p'] as String,
        modifiedMs: json['m'] as int,
        text: json['t'] as String,
      );

  String get name => path.substring(path.lastIndexOf('/') + 1);
}

class NoteSearchResult {
  const NoteSearchResult({
    required this.path,
    required this.nameMatches,
    this.snippet,
    this.page,
  });

  final String path;

  /// Whether the query matched the note's name (these rank first).
  final bool nameMatches;

  /// Text around the first match in the note's content, if it matched there.
  final String? snippet;

  /// The page (counting from 1) whose handwriting matched, when the match is
  /// in handwriting and not in typed text.
  final int? page;
}

/// Finds notes by name and by the text typed in them.
///
/// The index lives next to (not inside) the notes folder, so it is never
/// synced, and is updated incrementally: only notes that changed since the
/// last run are read again.
class NoteSearchIndex {
  NoteSearchIndex({this.storageFile});

  static final log = Logger('NoteSearchIndex');

  /// The index the app uses, kept for as long as the app runs.
  static NoteSearchIndex get shared => _shared ??= NoteSearchIndex(
    storageFile: File(
      '${Directory(FileManager.documentsDirectory).parent.path}'
      '/note_search_index.json',
    ),
  );
  static NoteSearchIndex? _shared;

  /// Where the index is kept between runs. Null keeps it in memory only.
  final File? storageFile;

  final Map<String, NoteSearchEntry> _entries = {};

  int get length => _entries.length;

  Iterable<NoteSearchEntry> get entries => _entries.values;

  /// Makes Turkish (and other) letters comparable regardless of how the
  /// person types: `İ`, `I`, `ı` all become `i`, and `ş ğ ü ö ç` lose their
  /// marks.
  static String fold(String text) {
    const map = {
      'İ': 'i', 'I': 'i', 'ı': 'i',
      'Ş': 's', 'ş': 's',
      'Ğ': 'g', 'ğ': 'g',
      'Ü': 'u', 'ü': 'u',
      'Ö': 'o', 'ö': 'o',
      'Ç': 'c', 'ç': 'c',
      'Â': 'a', 'â': 'a', 'Î': 'i', 'î': 'i', 'Û': 'u', 'û': 'u',
    };
    final buffer = StringBuffer();
    for (final rune in text.runes) {
      final char = String.fromCharCode(rune);
      buffer.write(map[char] ?? char.toLowerCase());
    }
    return buffer.toString();
  }

  /// Adds or replaces a note's entry.
  void put(NoteSearchEntry entry) => _entries[entry.path] = entry;

  void remove(String path) => _entries.remove(path);

  /// Loads the index saved by an earlier run, if there is one.
  Future<void> load() async {
    await HandwritingTexts.load();
    final file = storageFile;
    if (file != null && file.existsSync()) await _loadEntries(file);
    _applyHandwriting();
  }

  /// Gives every entry the handwriting text kept for its note.
  void _applyHandwriting() {
    for (final path in _entries.keys.toList()) {
      final pages = HandwritingTexts.of(path)?.pages ?? const <String>[];
      final entry = _entries[path]!;
      if (entry.handwriting != pages) _entries[path] = entry.withHandwriting(pages);
    }
  }

  /// A note's handwriting was read (or forgotten): search it at once.
  void setHandwriting(String path, List<String> pages) {
    final entry = _entries[path];
    if (entry != null) _entries[path] = entry.withHandwriting(pages);
  }

  Future<void> _loadEntries(File file) async {
    try {
      final json = jsonDecode(await file.readAsString()) as List<dynamic>;
      for (final item in json) {
        put(NoteSearchEntry.fromJson(item as Map<String, dynamic>));
      }
    } catch (e, st) {
      // A damaged index is just rebuilt.
      log.warning('Ignoring unreadable search index: $e', e, st);
      _entries.clear();
    }
  }

  Future<void> save() async {
    final file = storageFile;
    if (file == null) return;
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode([for (final e in _entries.values) e.toJson()]),
    );
  }

  /// Brings the index up to date with the notes on disk: reads notes that are
  /// new or changed, forgets deleted ones. Calls [onProgress] after each note.
  Future<void> refresh({void Function(int done, int total)? onProgress}) async {
    await HandwritingTexts.load();
    final notes = await FileManager.getAllFiles();
    final present = notes.toSet();
    _entries.removeWhere((path, _) => !present.contains(path));

    var done = 0;
    for (final path in notes) {
      final modified = _modifiedMs(path);
      final existing = _entries[path];
      if (existing == null || existing.modifiedMs != modified) {
        try {
          put(
            NoteSearchEntry(
              path: path,
              modifiedMs: modified,
              text: await _readText(path),
            ),
          );
        } catch (e, st) {
          log.warning('Could not index $path: $e', e, st);
        }
      }
      onProgress?.call(++done, notes.length);
      // Let the interface breathe between notes.
      await Future<void>.delayed(Duration.zero);
    }
    _applyHandwriting();
    await save();
  }

  /// When the note was last saved, for telling whether its handwriting text
  /// is out of date.
  static int modifiedMsOf(String path) => _modifiedMs(path);

  static int _modifiedMs(String path) {
    for (final extension in ['.sbn2', '.sbn']) {
      final file = FileManager.getFile('$path$extension');
      if (file.existsSync()) return file.lastModifiedSync().millisecondsSinceEpoch;
    }
    return 0;
  }

  static Future<String> _readText(String path) async {
    final note = await EditorCoreInfo.loadFromFilePath(path);
    try {
      return [
        for (final page in note.pages)
          page.quill.controller.document.toPlainText().trim(),
      ].where((text) => text.isNotEmpty).join('\n');
    } finally {
      note.dispose();
    }
  }

  /// Notes matching every word of [query], notes whose name matches first.
  List<NoteSearchResult> search(String query) {
    final terms = fold(query).split(RegExp(r'\s+')).where((t) => t.isNotEmpty);
    if (terms.isEmpty) return const [];

    final byName = <NoteSearchResult>[];
    final byContent = <NoteSearchResult>[];
    for (final entry in _entries.values) {
      final foldedName = fold(entry.name);
      final foldedText = fold(entry.text);
      final foldedPages = [for (final page in entry.handwriting) fold(page)];
      final foldedAll = [foldedText, ...foldedPages].join('\n');
      final matchesName = terms.every(foldedName.contains);
      final matchesAll = terms.every(
        (t) => foldedName.contains(t) || foldedAll.contains(t),
      );
      if (!matchesAll) continue;

      String? snippet;
      int? page;
      final inText = terms.firstWhere(foldedText.contains, orElse: () => '');
      if (inText.isNotEmpty) {
        snippet = _snippet(entry.text, foldedText.indexOf(inText));
      } else {
        for (var i = 0; i < foldedPages.length && snippet == null; i++) {
          final term = terms.firstWhere(
            foldedPages[i].contains,
            orElse: () => '',
          );
          if (term.isEmpty) continue;
          snippet = _snippet(entry.handwriting[i], foldedPages[i].indexOf(term));
          page = i + 1;
        }
      }
      final result = NoteSearchResult(
        path: entry.path,
        nameMatches: matchesName,
        snippet: snippet,
        page: page,
      );
      (matchesName ? byName : byContent).add(result);
    }
    int compare(NoteSearchResult a, NoteSearchResult b) =>
        a.path.toLowerCase().compareTo(b.path.toLowerCase());
    return [...byName..sort(compare), ...byContent..sort(compare)];
  }

  /// About 80 characters of [text] around [index], on one line.
  /// [index] is into the folded text, which has the same length as [text].
  static String _snippet(String text, int index) {
    final start = (index - 30).clamp(0, text.length);
    final end = (index + 50).clamp(0, text.length);
    final piece = text.substring(start, end).replaceAll(RegExp(r'\s+'), ' ');
    return '${start > 0 ? '…' : ''}$piece${end < text.length ? '…' : ''}';
  }
}
