import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:saber/data/defter_strings.dart';
import 'package:saber/data/routes.dart';
import 'package:saber/data/search/note_search.dart';

/// Searches note names and the text typed in notes.
class SearchPage extends StatefulWidget {
  const SearchPage({super.key, this.index, this.onOpen});

  /// The index to search; defaults to the app's shared one.
  final NoteSearchIndex? index;

  /// Called with a note's path (without extension) when a result is tapped.
  final void Function(BuildContext context, String path)? onOpen;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  late final NoteSearchIndex _index = widget.index ?? NoteSearchIndex.shared;
  final _controller = TextEditingController();
  Timer? _debounce;

  List<NoteSearchResult> _results = const [];
  var _indexing = true;

  @override
  void initState() {
    super.initState();
    _refreshIndex();
  }

  Future<void> _refreshIndex() async {
    await _index.load();
    if (mounted) setState(_runSearch); // show what was indexed last time
    await _index.refresh();
    if (!mounted) return;
    setState(() {
      _indexing = false;
      _runSearch();
    });
  }

  void _runSearch() => _results = _index.search(_controller.text);

  void _onChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 150), () {
      if (mounted) setState(_runSearch);
    });
  }

  void _open(String path) {
    final onOpen = widget.onOpen;
    if (onOpen != null) {
      onOpen(context, path);
    } else {
      context.push(RoutePaths.editFilePath(path));
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasQuery = _controller.text.trim().isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: DefterStrings.searchHint,
            border: InputBorder.none,
          ),
          onChanged: _onChanged,
        ),
        bottom: _indexing
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(minHeight: 2),
              )
            : null,
      ),
      body: _results.isEmpty
          ? Center(
              child: Text(
                !hasQuery
                    ? ''
                    : _indexing
                    ? DefterStrings.searchIndexing
                    : DefterStrings.searchNoResults,
              ),
            )
          : ListView.builder(
              itemCount: _results.length,
              itemBuilder: (context, i) {
                final result = _results[i];
                final slash = result.path.lastIndexOf('/');
                final folder = result.path.substring(0, slash);
                final name = result.path.substring(slash + 1);
                return ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: Text(name),
                  subtitle: Text(
                    [
                      if (folder.isNotEmpty) folder,
                      if (result.snippet != null) result.snippet!,
                    ].join('\n'),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  isThreeLine: folder.isNotEmpty && result.snippet != null,
                  onTap: () => _open(result.path),
                );
              },
            ),
    );
  }
}
