import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:record/record.dart';
import 'package:saber/data/audio/note_recordings.dart';
import 'package:saber/data/defter_strings.dart';

/// Record audio for a note and play back its recordings.
class RecordingsDialog extends StatefulWidget {
  const new({super.key, required this.notePath});

  final String notePath;

  @override
  State<RecordingsDialog> createState() => _RecordingsDialogState();
}

class _RecordingsDialogState extends State<RecordingsDialog> {
  final _recorder = AudioRecorder();
  final _player = AudioPlayer();

  List<NoteRecording> _recordings = const [];
  bool _recording = false;
  Duration _elapsed = Duration.zero;
  Timer? _timer;
  String? _error;
  String? _playingPath;

  @override
  void initState() {
    super.initState();
    _reload();
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playingPath = null);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    // A recording in progress is kept, not lost, when the dialog closes.
    unawaited(_stopAndDispose());
    _player.dispose();
    super.dispose();
  }

  Future<void> _stopAndDispose() async {
    try {
      if (await _recorder.isRecording()) await _recorder.stop();
    } finally {
      await _recorder.dispose();
    }
  }

  Future<void> _reload() async {
    final list = await NoteRecordings.list(widget.notePath);
    if (mounted) setState(() => _recordings = list);
  }

  Future<void> _toggleRecording() async {
    if (_recording) {
      _timer?.cancel();
      await _recorder.stop();
      setState(() => _recording = false);
      await _reload();
      return;
    }

    if (!await _recorder.hasPermission()) {
      setState(() => _error = DefterStrings.micDenied);
      return;
    }
    await _player.stop();
    final file = await NoteRecordings.newRecordingFile(widget.notePath);
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: file.path,
    );
    _elapsed = Duration.zero;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed += const Duration(seconds: 1));
    });
    setState(() {
      _recording = true;
      _error = null;
      _playingPath = null;
    });
  }

  Future<void> _togglePlay(NoteRecording recording) async {
    if (_playingPath == recording.file.path) {
      await _player.pause();
      setState(() => _playingPath = null);
      return;
    }
    await _player.play(DeviceFileSource(recording.file.path));
    setState(() => _playingPath = recording.file.path);
  }

  String _format(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inMinutes)}:${two(d.inSeconds % 60)}';
  }

  String _label(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.day)}.${two(t.month)}.${t.year} ${two(t.hour)}:${two(t.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(DefterStrings.recordings),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: FilledButton.icon(
                style: _recording
                    ? FilledButton.styleFrom(
                        backgroundColor: ColorScheme.of(context).error,
                      )
                    : null,
                onPressed: _toggleRecording,
                icon: Icon(_recording ? Icons.stop_rounded : Symbols.mic_rounded),
                label: Text(
                  _recording
                      ? '${DefterStrings.stopRecording}  ${_format(_elapsed)}'
                      : DefterStrings.startRecording,
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!),
            ],
            const SizedBox(height: 12),
            Flexible(
              child: _recordings.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(DefterStrings.noRecordings),
                    )
                  : ListView(
                      shrinkWrap: true,
                      children: [
                        for (final recording in _recordings)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(_label(recording.startedAt)),
                            subtitle: Text(
                              '${(recording.size / 1024).round()} KB',
                            ),
                            leading: IconButton(
                              tooltip: _playingPath == recording.file.path
                                  ? DefterStrings.pause
                                  : DefterStrings.play,
                              icon: Icon(
                                _playingPath == recording.file.path
                                    ? Icons.pause_circle_rounded
                                    : Icons.play_circle_rounded,
                              ),
                              onPressed: _recording
                                  ? null
                                  : () => _togglePlay(recording),
                            ),
                            trailing: IconButton(
                              tooltip: DefterStrings.delete,
                              icon: const Icon(Symbols.delete_rounded),
                              onPressed: () async {
                                if (_playingPath == recording.file.path) {
                                  await _player.stop();
                                  _playingPath = null;
                                }
                                await NoteRecordings.delete(recording);
                                await _reload();
                              },
                            ),
                          ),
                      ],
                    ),
            ),
            Text(
              DefterStrings.recordingsNote,
              style: TextTheme.of(context).bodySmall,
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
    );
  }
}
