import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:saber/data/backup/note_backup.dart';
import 'package:saber/data/defter_strings.dart';
import 'package:saber/data/nextcloud/readable_bytes.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/versions/note_versions.dart';
import 'package:share_plus/share_plus.dart';

/// What is remembered of the backup that was last made on this device.
class LastBackup {
  const LastBackup({
    required this.time,
    required this.notes,
    required this.recordings,
    required this.zipBytes,
  });

  final DateTime time;
  final int notes;
  final int recordings;
  final int zipBytes;

  factory LastBackup.of(BackupSummary summary) => LastBackup(
    time: summary.created,
    notes: summary.notes,
    recordings: summary.recordings,
    zipBytes: summary.zipBytes,
  );

  String encode() => jsonEncode({
    'time': time.toUtc().toIso8601String(),
    'notes': notes,
    'recordings': recordings,
    'zipBytes': zipBytes,
  });

  /// Reads [encode]'s text; null if there is none or it can't be read.
  static LastBackup? decode(String text) {
    if (text.isEmpty) return null;
    try {
      final json = jsonDecode(text);
      if (json is! Map) return null;
      final time = DateTime.tryParse('${json['time']}');
      final notes = json['notes'], recordings = json['recordings'];
      final zipBytes = json['zipBytes'];
      if (time == null || notes is! int || zipBytes is! int) return null;
      return LastBackup(
        time: time.toLocal(),
        notes: notes,
        recordings: recordings is int ? recordings : 0,
        zipBytes: zipBytes,
      );
    } on FormatException {
      return null;
    }
  }
}

/// Makes a backup of the whole library and brings one back, and looks
/// after the version history: whether versions are kept, how much room
/// they take, and deleting them.
class BackupPage extends StatefulWidget {
  const BackupPage({
    super.key,
    this.pickBackup = BackupPage.pickWithFilePicker,
    this.share = BackupPage.shareFile,
    this.saveToDevice = BackupPage.saveWithFilePicker,
  });

  /// Lets the person choose a backup file; its path, or null if they
  /// didn't choose one.
  final Future<String?> Function() pickBackup;

  /// Hands the backup at [File.path] to the system's share sheet.
  final Future<void> Function(File file) share;

  /// Lets the person choose where to save the backup; whether it was saved.
  final Future<bool> Function(File file) saveToDevice;

  /// Saving to the device goes through memory, so only backups up to this
  /// size are offered it.
  static const maxSaveBytes = 150 * 1024 * 1024;

  static Future<String?> pickWithFilePicker() async {
    final file = await FilePicker.pickFile(type: FileType.any);
    return file?.path;
  }

  static Future<void> shareFile(File file) => SharePlus.instance.share(
    ShareParams(files: [XFile(file.path, mimeType: 'application/zip')]),
  );

  static Future<bool> saveWithFilePicker(File file) async {
    final saved = await FilePicker.saveFile(
      fileName: file.uri.pathSegments.last,
      bytes: await file.readAsBytes(),
      type: FileType.custom,
      allowedExtensions: const ['zip'],
    );
    return saved != null;
  }

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  static final log = Logger('BackupPage');

  File? _latestFile;
  int? _versionsSize;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    File? latest;
    int? size;
    try {
      latest = await NoteBackup.latest();
      size = await NoteVersions.totalSize();
    } on Object catch (e, st) {
      log.warning('Could not look at backups and versions: $e', e, st);
    }
    if (!mounted) return;
    setState(() {
      _latestFile = latest;
      _versionsSize = size;
    });
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  /// Runs [work] behind a progress dialog that can't be dismissed.
  Future<T> _withProgress<T>(
    String title,
    Future<T> Function(void Function(BackupProgress progress) onProgress) work,
  ) async {
    final progress = ValueNotifier<BackupProgress?>(null);
    final navigator = Navigator.of(context, rootNavigator: true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (context) => PopScope(
        canPop: false,
        child: _ProgressDialog(title: title, progress: progress),
      ),
    );
    setState(() => _busy = true);
    try {
      return await work((value) => progress.value = value);
    } finally {
      navigator.pop();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showError(String title, Object error) {
    final failure = error is BackupException ? error.failure.name : 'io';
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(DefterStrings.backupError(failure)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(DefterStrings.close),
          ),
        ],
      ),
    );
  }

  Future<void> _create() async {
    if (_busy) return;
    final BackupSummary summary;
    try {
      summary = await _withProgress(
        DefterStrings.backupWriting,
        (onProgress) => NoteBackup.create(onProgress: onProgress),
      );
    } on Object catch (e, st) {
      log.severe('Could not make a backup: $e', e, st);
      await _refresh();
      if (mounted) await _showError(DefterStrings.backupFailed, e);
      return;
    }
    stows.lastBackup.value = LastBackup.of(summary).encode();
    await _refresh();
    if (!mounted) return;

    final file = File(summary.path);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        key: const ValueKey('backupReady'),
        icon: const Icon(Icons.verified_outlined),
        title: Text(DefterStrings.backupReady),
        content: SingleChildScrollView(
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DefterStrings.backupSummary(
                summary.notes,
                summary.recordings,
                readableBytes(summary.zipBytes),
              ),
              style: TextTheme.of(context).titleMedium,
            ),
            const SizedBox(height: 12),
            Text(DefterStrings.backupReadyHint),
          ],
        ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(DefterStrings.close),
          ),
          if (summary.zipBytes <= BackupPage.maxSaveBytes)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _save(file);
              },
              child: Text(DefterStrings.backupSave),
            ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              _share(file);
            },
            child: Text(DefterStrings.backupShare),
          ),
        ],
      ),
    );
  }

  Future<void> _share(File file) async {
    try {
      await widget.share(file);
    } on Object catch (e, st) {
      log.severe('Could not share the backup: $e', e, st);
      if (mounted) await _showError(DefterStrings.backupFailed, e);
    }
  }

  Future<void> _save(File file) async {
    if (file.lengthSync() > BackupPage.maxSaveBytes) {
      _snack(DefterStrings.backupTooLargeToSave);
      return;
    }
    try {
      if (await widget.saveToDevice(file)) _snack(DefterStrings.backupSaved);
    } on Object catch (e, st) {
      log.severe('Could not save the backup: $e', e, st);
      if (mounted) await _showError(DefterStrings.backupFailed, e);
    }
  }

  Future<void> _restore() async {
    if (_busy) return;
    final path = await widget.pickBackup();
    if (path == null || !mounted) return;

    final BackupManifest manifest;
    try {
      manifest = await NoteBackup.inspect(path);
    } on Object catch (e, st) {
      log.warning('Not a backup that can be read: $e', e, st);
      if (mounted) await _showError(DefterStrings.restoreFailedTitle, e);
      return;
    }
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          DefterStrings.backupRestoreTitle(
            DefterStrings.dayAndTime(manifest.created),
          ),
        ),
        content: SingleChildScrollView(
          child: Text(
            DefterStrings.backupRestoreBody(
              manifest.notes,
              manifest.recordings,
              readableBytes(manifest.bytes),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(DefterStrings.cancel),
          ),
          FilledButton(
            key: const ValueKey('confirmRestoreBackup'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(DefterStrings.versionRestore),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final RestoreOutcome outcome;
    try {
      outcome = await _withProgress(
        DefterStrings.backupRestoring,
        (onProgress) => NoteBackup.restore(path, onProgress: onProgress),
      );
    } on Object catch (e, st) {
      log.severe('Could not restore the backup: $e', e, st);
      if (mounted) await _showError(DefterStrings.restoreFailedTitle, e);
      return;
    }
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        key: const ValueKey('restoreDone'),
        title: Text(DefterStrings.backupRestoreDone),
        content: SingleChildScrollView(
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(DefterStrings.restoreRestored(outcome.restored.length)),
            Text(DefterStrings.restoreAlreadyThere(outcome.alreadyThere.length)),
            if (outcome.copies.isNotEmpty)
              Text(DefterStrings.restoreCopies(outcome.copies.length)),
            if (outcome.recordings > 0)
              Text(DefterStrings.restoreRecordings(outcome.recordings)),
            if (outcome.failed.isNotEmpty)
              Text(
                DefterStrings.restoreFailed(outcome.failed.length),
                style: TextStyle(color: ColorScheme.of(context).error),
              ),
          ],
        ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(DefterStrings.close),
          ),
        ],
      ),
    );
  }

  Future<void> _clearVersions() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(DefterStrings.versionsClear),
        content: Text(DefterStrings.versionsClearBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(DefterStrings.cancel),
          ),
          FilledButton(
            key: const ValueKey('confirmClearVersions'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(DefterStrings.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await NoteVersions.clear();
    } on Object catch (e, st) {
      log.severe('Could not delete the versions: $e', e, st);
    }
    await _refresh();
    _snack(DefterStrings.versionsCleared);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    final textTheme = TextTheme.of(context);
    final last = LastBackup.decode(stows.lastBackup.value);
    final latestFile = _latestFile;
    final versionsSize = _versionsSize;

    Widget section(String title, List<Widget> children) => Card(
      margin: const .symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const .all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: textTheme.titleLarge),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );

    Widget note(String text) => Padding(
      padding: const .only(top: 8),
      child: Text(
        text,
        style: textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(DefterStrings.backupTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const .symmetric(vertical: 8),
            children: [
              section(DefterStrings.backupSection, [
                Text(DefterStrings.backupAbout),
                note(DefterStrings.backupLimits),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      key: const ValueKey('createBackup'),
                      onPressed: _busy ? null : _create,
                      icon: const Icon(Icons.archive_outlined),
                      label: Text(DefterStrings.backupCreate),
                    ),
                    OutlinedButton.icon(
                      key: const ValueKey('restoreBackup'),
                      onPressed: _busy ? null : _restore,
                      icon: const Icon(Icons.unarchive_outlined),
                      label: Text(DefterStrings.backupRestore),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),
                if (last == null)
                  Text(DefterStrings.backupNone, key: const ValueKey('noBackup'))
                else ...[
                  Text(
                    DefterStrings.backupLast(
                      DefterStrings.dayAndTime(last.time),
                    ),
                    key: const ValueKey('lastBackup'),
                    style: textTheme.titleSmall,
                  ),
                  Text(
                    DefterStrings.backupSummary(
                      last.notes,
                      last.recordings,
                      readableBytes(last.zipBytes),
                    ),
                  ),
                  if (latestFile == null)
                    note(DefterStrings.backupFileGone)
                  else
                    Padding(
                      padding: const .only(top: 8),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          TextButton.icon(
                            onPressed: () => _share(latestFile),
                            icon: const Icon(Icons.ios_share),
                            label: Text(DefterStrings.backupShare),
                          ),
                          if (last.zipBytes <= BackupPage.maxSaveBytes)
                            TextButton.icon(
                              onPressed: () => _save(latestFile),
                              icon: const Icon(Icons.save_alt),
                              label: Text(DefterStrings.backupSave),
                            ),
                        ],
                      ),
                    ),
                ],
              ]),
              section(DefterStrings.versionsSection, [
                SwitchListTile(
                  key: const ValueKey('versionsSwitch'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(DefterStrings.versionsSwitch),
                  value: stows.versionHistory.value,
                  onChanged: (value) =>
                      setState(() => stows.versionHistory.value = value),
                ),
                Text(DefterStrings.versionHistoryAbout),
                note(DefterStrings.versionsWhere),
                const SizedBox(height: 12),
                if (versionsSize != null)
                  Text(
                    DefterStrings.versionsSize(readableBytes(versionsSize)),
                    key: const ValueKey('versionsSize'),
                  ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  key: const ValueKey('clearVersions'),
                  onPressed: versionsSize == null || versionsSize == 0
                      ? null
                      : _clearVersions,
                  icon: const Icon(Icons.delete_sweep_outlined),
                  label: Text(DefterStrings.versionsClear),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressDialog extends StatelessWidget {
  const _ProgressDialog({required this.title, required this.progress});

  final String title;
  final ValueNotifier<BackupProgress?> progress;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: SizedBox(
        width: 360,
        child: ValueListenableBuilder(
          valueListenable: progress,
          builder: (context, value, _) {
            final label = switch (value?.phase) {
              BackupPhase.verifying => DefterStrings.backupVerifying,
              BackupPhase.restoring => DefterStrings.backupRestoring,
              BackupPhase.writing => DefterStrings.backupWriting,
              null => title,
            };
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextTheme.of(context).titleMedium),
                const SizedBox(height: 16),
                LinearProgressIndicator(value: value?.fraction),
                const SizedBox(height: 8),
                Text(
                  value == null
                      ? ''
                      : DefterStrings.backupProgress(
                          readableBytes(value.done),
                          readableBytes(value.total),
                        ),
                  style: TextTheme.of(context).bodySmall,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
