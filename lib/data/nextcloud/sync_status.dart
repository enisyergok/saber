import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:saber/data/nextcloud/saber_syncer.dart';

/// What the person can see about syncing: when something was last
/// transferred, kept for as long as the app runs.
abstract class SyncStatus {
  /// When a file was last downloaded or uploaded, null if none this session.
  static final lastTransfer = ValueNotifier<DateTime?>(null);

  static final _subscriptions = <StreamSubscription<Object?>>[];

  /// Starts noting transfers. Safe to call more than once.
  static void attach() {
    if (_subscriptions.isNotEmpty) return;
    void note(Object? _) => lastTransfer.value = DateTime.now();
    _subscriptions
      ..add(syncer.downloader.transferStream.listen(note))
      ..add(syncer.uploader.transferStream.listen(note));
  }

  /// "5 dk önce" style text for [time] relative to [now].
  static String ago(DateTime time, DateTime now, {required bool turkish}) {
    final seconds = now.difference(time).inSeconds;
    if (seconds < 60) return turkish ? 'az önce' : 'just now';
    final minutes = seconds ~/ 60;
    if (minutes < 60) return turkish ? '$minutes dk önce' : '$minutes min ago';
    final hours = minutes ~/ 60;
    if (hours < 48) return turkish ? '$hours sa önce' : '$hours h ago';
    final days = hours ~/ 24;
    return turkish ? '$days gün önce' : '$days days ago';
  }
}
