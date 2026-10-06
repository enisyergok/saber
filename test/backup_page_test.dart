import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saber/components/toolbar/note_versions_dialog.dart';
import 'package:saber/data/audio/note_recordings.dart';
import 'package:saber/data/backup/note_backup.dart';
import 'package:saber/data/defter_strings.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/flavor_config.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/search/handwriting_text.dart';
import 'package:saber/data/versions/note_versions.dart';
import 'package:saber/pages/backup.dart';

import 'utils/test_mock_channel_handlers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupMockPathProvider();
  FlavorConfig.setup();

  late Directory temp;
  late String docs;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('backup_page_test');
    docs = '${temp.path}/device/Saber';
    Directory(docs).createSync(recursive: true);
    NoteRecordings.rootOverride = Directory('${temp.path}/device/recordings');
    HandwritingTexts.fileOverride = File('${temp.path}/device/handwriting.json');
    HandwritingTexts.resetForTesting();
    NoteVersions.rootOverride = Directory('${temp.path}/device/versions');
    NoteVersions.useIsolate = false;
    NoteBackup.folderOverride = Directory('${temp.path}/backups');
    NoteBackup.useIsolate = false;
    stows.lastBackup.value = '';
    stows.versionHistory.value = true;
  });
  tearDown(() {
    NoteRecordings.rootOverride = null;
    HandwritingTexts.fileOverride = null;
    NoteVersions.rootOverride = null;
    NoteBackup.folderOverride = null;
    stows.lastBackup.value = '';
    stows.versionHistory.value = true;
    temp.deleteSync(recursive: true);
  });

  void write(String path, String content) => File('$docs$path')
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(content);

  Future<void> init(WidgetTester tester) => tester.runAsync(
    () => FileManager.init(
      documentsDirectory: docs,
      shouldWatchRootDirectory: false,
    ),
  );

  void screen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1280, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  /// Lets what was started run and the screen catch up, without waiting
  /// for progress bars that never stop turning.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  group('The backup page', () {
    testWidgets('says so when no backup was made yet', (tester) async {
      screen(tester);
      await init(tester);
      await tester.pumpWidget(const MaterialApp(home: BackupPage()));
      await settle(tester);

      expect(find.text(DefterStrings.backupTitle), findsOneWidget);
      expect(find.byKey(const ValueKey('noBackup')), findsOneWidget);
      expect(find.text(DefterStrings.backupLimits), findsOneWidget);
      // nothing is kept yet, so there is nothing to delete
      final clear = tester.widget<OutlinedButton>(
        find.byKey(const ValueKey('clearVersions')),
      );
      expect(clear.onPressed, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('makes a backup and hands it over', (tester) async {
      screen(tester);
      await init(tester);
      write('/Günlük.sbn2', 'günlük ' * 200);
      write('/Okul/Fizik.sbn2', 'fizik');
      write('/Okul/Fizik.sbn2.0', 'resim');

      final shared = <String>[];
      final saved = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: BackupPage(
            share: (file) async => shared.add(file.path),
            saveToDevice: (file) async {
              saved.add(file.path);
              return true;
            },
          ),
        ),
      );
      await settle(tester);

      await tester.tap(find.byKey(const ValueKey('createBackup')));
      await settle(tester);

      expect(find.byKey(const ValueKey('backupReady')), findsOneWidget);
      expect(find.text(DefterStrings.backupReady), findsOneWidget);
      final last = LastBackup.decode(stows.lastBackup.value)!;
      expect(last.notes, 2);
      final zip = Directory('${temp.path}/backups').listSync().single as File;
      expect(zip.path, endsWith('.zip'));
      expect(zip.lengthSync(), last.zipBytes);
      expect(NoteBackupWork.verify(zip.path).notes, 2);

      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('backupReady')),
          matching: find.text(DefterStrings.backupShare),
        ),
      );
      await settle(tester);
      expect(shared, [zip.path]);
      expect(find.byKey(const ValueKey('backupReady')), findsNothing);

      // The page now tells of the backup and still offers its file.
      expect(find.byKey(const ValueKey('lastBackup')), findsOneWidget);
      expect(find.byKey(const ValueKey('noBackup')), findsNothing);
      await tester.tap(find.text(DefterStrings.backupSave));
      await settle(tester);
      expect(saved, [zip.path]);
      expect(find.text(DefterStrings.backupSaved), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('brings a backup back after saying what it will do', (
      tester,
    ) async {
      screen(tester);
      await init(tester);
      write('/Günlük.sbn2', 'günlük ' * 200);
      write('/Okul/Fizik.sbn2', 'fizik');
      final summary = NoteBackupWork.create(
        documentsPath: docs,
        recordingsPath: NoteRecordings.root.path,
        handwritingPath: HandwritingTexts.file.path,
        penProfiles: '',
        zipPath: '${temp.path}/picked.zip',
        created: DateTime(2026, 3, 4, 10, 30),
        appVersion: '1',
      );
      // one note is lost, the other changed
      File('$docs/Okul/Fizik.sbn2').deleteSync();
      write('/Günlük.sbn2', 'günlüğün yeni hali');

      await tester.pumpWidget(
        MaterialApp(
          home: BackupPage(pickBackup: () async => summary.path),
        ),
      );
      await settle(tester);

      await tester.tap(find.byKey(const ValueKey('restoreBackup')));
      await settle(tester);
      // first it says what is in the backup, and that nothing is replaced
      expect(
        find.text(
          DefterStrings.backupRestoreTitle(
            DefterStrings.dayAndTime(DateTime(2026, 3, 4, 10, 30)),
          ),
        ),
        findsOneWidget,
      );
      expect(File('$docs/Okul/Fizik.sbn2').existsSync(), isFalse);

      await tester.tap(find.byKey(const ValueKey('confirmRestoreBackup')));
      await settle(tester);

      expect(find.byKey(const ValueKey('restoreDone')), findsOneWidget);
      expect(find.text(DefterStrings.restoreRestored(1)), findsOneWidget);
      expect(find.text(DefterStrings.restoreCopies(1)), findsOneWidget);
      expect(find.text(DefterStrings.restoreAlreadyThere(0)), findsOneWidget);
      expect(File('$docs/Okul/Fizik.sbn2').readAsStringSync(), 'fizik');
      expect(File('$docs/Günlük.sbn2').readAsStringSync(), 'günlüğün yeni hali');
      expect(File('$docs/Günlük (2).sbn2').readAsStringSync(), 'günlük ' * 200);
      expect(tester.takeException(), isNull);
    });

    testWidgets('says so when the file is not a backup', (tester) async {
      screen(tester);
      await init(tester);
      final other = File('${temp.path}/foto.jpg')..writeAsStringSync('jpeg');
      await tester.pumpWidget(
        MaterialApp(home: BackupPage(pickBackup: () async => other.path)),
      );
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('restoreBackup')));
      await settle(tester);
      expect(find.text(DefterStrings.restoreFailedTitle), findsOneWidget);
      expect(find.text(DefterStrings.backupError('notABackup')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('choosing no file does nothing', (tester) async {
      screen(tester);
      await init(tester);
      await tester.pumpWidget(
        MaterialApp(home: BackupPage(pickBackup: () async => null)),
      );
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('restoreBackup')));
      await settle(tester);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('turns the version history off and empties it', (tester) async {
      screen(tester);
      await init(tester);
      write('/Not.sbn2', 'bir' * 500);
      NoteVersions.store.snapshot(
        key: '/Not',
        mainFilePath: '$docs/Not.sbn2',
        now: DateTime(2026, 1, 1),
        reason: NoteVersion.reasonOpen,
      );
      expect(NoteVersions.store.totalSize(), greaterThan(1500));

      await tester.pumpWidget(const MaterialApp(home: BackupPage()));
      await settle(tester);
      expect(find.byKey(const ValueKey('versionsSize')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('versionsSwitch')));
      await settle(tester);
      expect(stows.versionHistory.value, isFalse);

      await tester.tap(find.byKey(const ValueKey('clearVersions')));
      await settle(tester);
      expect(find.text(DefterStrings.versionsClearBody), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('confirmClearVersions')));
      await settle(tester);
      expect(NoteVersions.store.totalSize(), 0);
      expect(NoteVersions.store.list('/Not'), isEmpty);
      expect(File('$docs/Not.sbn2').existsSync(), isTrue, reason: 'only versions go');
      expect(tester.takeException(), isNull);
    });
  });

  group('The list of versions', () {
    NoteVersion version(String id, DateTime time, String reason) => NoteVersion(
      id: id,
      key: '/Not',
      time: time,
      extension: '.sbn2',
      main: 'a' * 64,
      assets: const [],
      preview: null,
      size: 2048,
      reason: reason,
    );
    final now = DateTime(2026, 10, 6, 15);
    final versions = [
      version('v3', DateTime(2026, 10, 6, 14, 5), NoteVersion.reasonAuto),
      version('v2', DateTime(2026, 10, 5, 9, 30), NoteVersion.reasonClose),
      version('v1', DateTime(2026, 9, 28, 18, 2), NoteVersion.reasonOpen),
    ];

    Future<void> open(
      WidgetTester tester, {
      required Future<void> Function(NoteVersion version) restore,
      List<NoteVersion>? list,
    }) async {
      screen(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (context) => NoteVersionsDialog(
                    notePath: '/Not',
                    restore: restore,
                    load: () async => list ?? versions,
                    now: now,
                  ),
                ),
                child: const Text('aç'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('aç'));
      await tester.pumpAndSettle();
    }

    testWidgets('says when each version is from and why it was kept', (
      tester,
    ) async {
      await open(tester, restore: (_) async {});
      final tr = DefterStrings.isTr;
      expect(find.text(tr ? 'Bugün 14:05' : 'Today 14:05'), findsOneWidget);
      expect(find.text(tr ? 'Dün 09:30' : 'Yesterday 09:30'), findsOneWidget);
      expect(
        find.text(tr ? '28 Eylül 2026 18:02' : '28 September 2026, 18:02'),
        findsOneWidget,
      );
      expect(
        find.text('${DefterStrings.versionReasonClose} · 2.00 KB'),
        findsOneWidget,
      );
      expect(find.text(DefterStrings.versionRestore), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    });

    testWidgets('brings a version back only after asking', (tester) async {
      final restored = <String>[];
      await open(tester, restore: (version) async => restored.add(version.id));

      await tester.tap(find.text(DefterStrings.versionRestore).at(1));
      await tester.pumpAndSettle();
      expect(find.text(DefterStrings.versionRestoreBody), findsOneWidget);
      expect(restored, isEmpty);

      // changing one's mind
      await tester.tap(find.text(DefterStrings.cancel));
      await tester.pumpAndSettle();
      expect(restored, isEmpty);
      expect(find.byType(NoteVersionsDialog), findsOneWidget);

      await tester.tap(find.text(DefterStrings.versionRestore).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('confirmRestoreVersion')));
      await tester.pumpAndSettle();
      expect(restored, ['v2']);
      expect(find.byType(NoteVersionsDialog), findsNothing);
      expect(find.text(DefterStrings.versionRestored), findsOneWidget);
    });

    testWidgets('stays open and says so when a version cannot come back', (
      tester,
    ) async {
      await open(
        tester,
        restore: (_) async => throw StateError('missing files'),
      );
      await tester.tap(find.text(DefterStrings.versionRestore).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('confirmRestoreVersion')));
      await tester.pumpAndSettle();
      expect(find.byType(NoteVersionsDialog), findsOneWidget);
      expect(find.byKey(const ValueKey('versionError')), findsOneWidget);
      expect(find.text(DefterStrings.versionRestoreFailed), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('says so when nothing was kept yet', (tester) async {
      await open(tester, restore: (_) async {}, list: const []);
      expect(find.text(DefterStrings.versionsEmpty), findsOneWidget);
      expect(find.text(DefterStrings.versionRestore), findsNothing);
    });
  });

  test('days are named the way they are said', () {
    final now = DateTime(2026, 10, 6, 15);
    String say(DateTime time) => DefterStrings.dayAndTime(time, now: now);
    final tr = DefterStrings.isTr;
    expect(say(DateTime(2026, 10, 6, 0, 1)), tr ? 'Bugün 00:01' : 'Today 00:01');
    expect(
      say(DateTime(2026, 10, 5, 23, 59)),
      tr ? 'Dün 23:59' : 'Yesterday 23:59',
    );
    expect(
      say(DateTime(2026, 10, 4, 12)),
      tr ? '4 Ekim 2026 12:00' : '4 October 2026, 12:00',
    );
    // a clock that is ahead does not make "today" of tomorrow
    expect(
      say(DateTime(2026, 10, 7, 8)),
      tr ? '7 Ekim 2026 08:00' : '7 October 2026, 08:00',
    );
  });

  test('what is remembered of the last backup survives being written down', () {
    final last = LastBackup(
      time: DateTime(2026, 10, 6, 14, 5),
      notes: 12,
      recordings: 3,
      zipBytes: 123456,
    );
    final back = LastBackup.decode(last.encode())!;
    expect(back.time, last.time);
    expect(back.notes, 12);
    expect(back.recordings, 3);
    expect(back.zipBytes, 123456);
    expect(LastBackup.decode(''), isNull);
    expect(LastBackup.decode('{'), isNull);
    expect(LastBackup.decode('[]'), isNull);
  });
}
