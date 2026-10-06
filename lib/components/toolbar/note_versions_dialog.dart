import 'dart:io';

import 'package:flutter/material.dart';
import 'package:saber/data/defter_strings.dart';
import 'package:saber/data/nextcloud/readable_bytes.dart';
import 'package:saber/data/versions/note_versions.dart';

/// Lists the versions kept of a note and brings one back.
class NoteVersionsDialog extends StatefulWidget {
  const NoteVersionsDialog({
    super.key,
    required this.notePath,
    required this.restore,
    this.load,
    this.now,
  });

  /// The note, by its path with or without extension.
  final String notePath;

  /// Brings a version back. Throws if it can't be done.
  final Future<void> Function(NoteVersion version) restore;

  /// Where the versions come from; [NoteVersions.list] unless given.
  final Future<List<NoteVersion>> Function()? load;

  /// What counts as now when saying "today" and "yesterday".
  final DateTime? now;

  @override
  State<NoteVersionsDialog> createState() => _NoteVersionsDialogState();
}

class _NoteVersionsDialogState extends State<NoteVersionsDialog> {
  List<NoteVersion>? _versions;
  String? _restoring;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final versions = await (widget.load ?? () => NoteVersions.list(widget.notePath))();
    if (mounted) setState(() => _versions = versions);
  }

  String _when(NoteVersion version) =>
      DefterStrings.dayAndTime(version.time, now: widget.now);

  Future<void> _restore(NoteVersion version) async {
    final preview = NoteVersions.previewOf(version);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(DefterStrings.versionRestoreTitle(_when(version))),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(DefterStrings.versionRestoreBody),
              if (preview != null) ...[
                const SizedBox(height: 16),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 320),
                    child: _VersionPreview(file: preview, radius: 8),
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    DefterStrings.versionFirstPage,
                    style: TextTheme.of(context).bodySmall,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(DefterStrings.cancel),
          ),
          FilledButton(
            key: const ValueKey('confirmRestoreVersion'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(DefterStrings.versionRestore),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _restoring = version.id;
      _error = null;
    });
    try {
      await widget.restore(version);
    } on Object {
      if (!mounted) return;
      setState(() {
        _restoring = null;
        _error = DefterStrings.versionRestoreFailed;
      });
      return;
    }
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    Navigator.of(context).pop();
    messenger?.showSnackBar(
      SnackBar(content: Text(DefterStrings.versionRestored)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final versions = _versions;
    final colorScheme = ColorScheme.of(context);
    final textTheme = TextTheme.of(context);
    final busy = _restoring != null;

    Widget tile(NoteVersion version) {
      final preview = NoteVersions.previewOf(version);
      return ListTile(
        key: ValueKey('version-${version.id}'),
        contentPadding: const .symmetric(horizontal: 24, vertical: 4),
        leading: SizedBox(
          width: 44,
          height: 56,
          child: preview == null
              ? DecoratedBox(
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: const .all(.circular(4)),
                  ),
                  child: Icon(
                    Icons.description_outlined,
                    color: colorScheme.onSurfaceVariant,
                  ),
                )
              : _VersionPreview(file: preview, radius: 4),
        ),
        title: Text(_when(version)),
        subtitle: Text(
          '${DefterStrings.versionReason(version.reason)} · '
          '${readableBytes(version.size)}',
        ),
        trailing: _restoring == version.id
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 3),
              )
            : TextButton(
                onPressed: busy ? null : () => _restore(version),
                child: Text(DefterStrings.versionRestore),
              ),
      );
    }

    return AlertDialog(
      title: Text(DefterStrings.versionHistory),
      contentPadding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
      // A fixed width: a list can't say how wide it would like to be.
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Text(
                  _error!,
                  key: const ValueKey('versionError'),
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.error,
                  ),
                ),
              ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  Padding(
                    padding: const .symmetric(horizontal: 24),
                    child: Text(
                      DefterStrings.versionHistoryAbout,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (!NoteVersions.enabled)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                      child: Text(
                        DefterStrings.versionsOff,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.error,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  if (versions == null)
                    const Padding(
                      padding: .all(32),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (versions.isEmpty)
                    Padding(
                      padding: const .all(32),
                      child: Text(
                        DefterStrings.versionsEmpty,
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    for (final (index, version) in versions.indexed) ...[
                      if (index > 0) const Divider(height: 1),
                      tile(version),
                    ],
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.of(context).pop(),
          child: Text(DefterStrings.close),
        ),
      ],
    );
  }
}

/// The picture of a version's first page.
class _VersionPreview extends StatelessWidget {
  const _VersionPreview({required this.file, required this.radius});

  final File file;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: .all(.circular(radius)),
      ),
      child: ClipRRect(
        borderRadius: .all(.circular(radius)),
        child: Image.file(
          file,
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          errorBuilder: (context, _, _) => ColoredBox(
            color: colorScheme.surfaceContainerHighest,
            child: Icon(
              Icons.description_outlined,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
