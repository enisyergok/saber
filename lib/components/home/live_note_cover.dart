import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Reloads the saved preview on writes, including while the editor covers it.
/// Reading bytes avoids FileImage's path-only cache retaining the old cover.
class LiveNoteCover extends StatefulWidget {
  const LiveNoteCover({super.key, required this.load, required this.changes});

  final Future<Uint8List?> Function() load;
  final Stream<void> changes;

  @override
  State<LiveNoteCover> createState() => _LiveNoteCoverState();
}

class _LiveNoteCoverState extends State<LiveNoteCover> {
  StreamSubscription<void>? _subscription;
  Uint8List? _bytes;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _subscription = widget.changes.listen((_) => _reload());
    _reload();
  }

  @override
  void didUpdateWidget(LiveNoteCover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.changes != widget.changes) {
      _subscription?.cancel();
      _subscription = widget.changes.listen((_) => _reload());
    }
    if (oldWidget.load != widget.load) _reload();
  }

  Future<void> _reload() async {
    final request = ++_request;
    try {
      final bytes = await widget.load();
      if (mounted && request == _request) {
        setState(() => _bytes = bytes == null || bytes.isEmpty ? null : bytes);
      }
    } catch (error) {
      debugPrint('Could not read notebook cover: $error');
      if (mounted && request == _request) setState(() => _bytes = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    return bytes == null
        ? const Icon(Icons.description_outlined)
        : Image.memory(
            bytes,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const Icon(Icons.description_outlined),
          );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
