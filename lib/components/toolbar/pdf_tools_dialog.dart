import 'package:flutter/material.dart';
import 'package:saber/data/defter_strings.dart';
import 'package:saber/data/editor/editor_core_info.dart';
import 'package:saber/data/pdf/pdf_note_text.dart';

/// Search the text of a note's PDF pages and jump through its contents.
class PdfToolsDialog extends StatefulWidget {
  const PdfToolsDialog({
    super.key,
    required this.coreInfo,
    required this.onPageSelected,
  });

  final EditorCoreInfo coreInfo;
  final ValueChanged<int> onPageSelected;

  @override
  State<PdfToolsDialog> createState() => _PdfToolsDialogState();
}

class _PdfToolsDialogState extends State<PdfToolsDialog> {
  final _controller = TextEditingController();
  List<PdfSearchHit>? _hits;
  bool _anyText = true;
  bool _searching = false;
  late final Future<List<PdfContentsEntry>> _contents = PdfNoteText.contents(
    widget.coreInfo,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _hits = null);
      return;
    }
    setState(() => _searching = true);
    final result = await PdfNoteText.search(widget.coreInfo, query);
    if (!mounted || _controller.text != query) return;
    setState(() {
      _hits = result.hits;
      _anyText = result.anyText;
      _searching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = TextTheme.of(context);
    return Dialog(
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: TextField(
                controller: _controller,
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: DefterStrings.pdfSearchHint,
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: _search,
              ),
            ),
            if (_searching) const LinearProgressIndicator(),
            Expanded(
              child: _hits == null ? _buildContents(textTheme) : _buildHits(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHits() {
    final hits = _hits!;
    if (hits.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _anyText ? DefterStrings.searchNoResults : DefterStrings.pdfNoText,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.builder(
      itemCount: hits.length,
      itemBuilder: (context, i) => ListTile(
        title: Text(hits[i].snippet, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(DefterStrings.pdfPageLabel(hits[i].pageIndex + 1)),
        onTap: () => widget.onPageSelected(hits[i].pageIndex),
      ),
    );
  }

  Widget _buildContents(TextTheme textTheme) {
    return FutureBuilder<List<PdfContentsEntry>>(
      future: _contents,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return snapshot.hasError
              ? Center(child: Text(DefterStrings.pdfNoOutline))
              : const Center(child: CircularProgressIndicator());
        }
        final entries = snapshot.data!;
        if (entries.isEmpty) {
          return Center(child: Text(DefterStrings.pdfNoOutline));
        }
        return ListView.builder(
          itemCount: entries.length,
          itemBuilder: (context, i) {
            final entry = entries[i];
            return ListTile(
              contentPadding: EdgeInsets.only(
                left: 20 + entry.depth * 18.0,
                right: 20,
              ),
              dense: entry.depth > 0,
              title: Text(entry.title, maxLines: 2, overflow: TextOverflow.ellipsis),
              trailing: Text(DefterStrings.pdfPageLabel(entry.pageIndex + 1)),
              onTap: () => widget.onPageSelected(entry.pageIndex),
            );
          },
        );
      },
    );
  }
}
