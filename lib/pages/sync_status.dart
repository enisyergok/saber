import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:saber/data/defter_strings.dart';
import 'package:saber/data/nextcloud/saber_syncer.dart';
import 'package:saber/data/nextcloud/sync_status.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/i18n/strings.g.dart';

/// Shows whether syncing is set up, what is waiting and when it last worked.
class SyncStatusPage extends HookWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    SyncStatus.attach();
    useStream(syncer.downloader.queueStream);
    useStream(syncer.uploader.queueStream);
    useListenable(SyncStatus.lastTransfer);

    final loggedIn = stows.loggedIn;
    final last = SyncStatus.lastTransfer.value;
    final tr = LocaleSettings.currentLocale.languageCode == 'tr';

    return Scaffold(
      appBar: AppBar(title: Text(DefterStrings.syncStatus)),
      body: ListView(
        children: [
          ListTile(
            leading: Icon(loggedIn ? Icons.cloud_done_rounded : Symbols.cloud_off_rounded),
            title: Text(
              loggedIn
                  ? DefterStrings.syncOn(stows.username.value)
                  : DefterStrings.syncOff,
            ),
            subtitle: loggedIn ? Text(stows.url.value) : null,
          ),
          if (loggedIn) ...[
            ListTile(
              leading: const Icon(Symbols.file_download_rounded),
              title: Text(DefterStrings.syncWaitingDownloads),
              trailing: Text('${syncer.downloader.numPending}'),
            ),
            ListTile(
              leading: const Icon(Symbols.file_upload_rounded),
              title: Text(DefterStrings.syncWaitingUploads),
              trailing: Text('${syncer.uploader.numPending}'),
            ),
            ListTile(
              leading: const Icon(Symbols.schedule_rounded),
              title: Text(DefterStrings.syncLastTransfer),
              trailing: Text(
                last == null
                    ? DefterStrings.syncNone
                    : SyncStatus.ago(last, DateTime.now(), turkish: tr),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(
                onPressed: syncer.downloader.isRefreshing
                    ? null
                    : syncer.downloader.refresh,
                icon: const Icon(Symbols.sync_rounded),
                label: Text(DefterStrings.syncNow),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                DefterStrings.syncExplain,
                style: TextTheme.of(context).bodySmall,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
