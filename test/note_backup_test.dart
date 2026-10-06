import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart' as archive;
import 'package:flutter_test/flutter_test.dart';
import 'package:saber/data/audio/note_recordings.dart';
import 'package:saber/data/backup/note_backup.dart';
import 'package:saber/data/backup/zip_file.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/flavor_config.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/search/handwriting_text.dart';
import 'package:saber/data/tools/pen_styles.dart';
import 'package:saber/data/versions/note_versions.dart';

import 'utils/test_mock_channel_handlers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupMockPathProvider();
  FlavorConfig.setup();

  late Directory temp;
  late String docs;
  late String recordings;
  late String handwriting;
  final created = DateTime(2026, 10, 6, 14, 5);

  setUp(() async {
    temp = Directory.systemTemp.createTempSync('note_backup_test');
    docs = '${temp.path}/device/Saber';
    recordings = '${temp.path}/device/note_recordings';
    handwriting = '${temp.path}/device/note_handwriting_text.json';
    Directory(docs).createSync(recursive: true);
    await FileManager.init(
      documentsDirectory: docs,
      shouldWatchRootDirectory: false,
    );
    NoteRecordings.rootOverride = Directory(recordings);
    HandwritingTexts.fileOverride = File(handwriting);
    HandwritingTexts.resetForTesting();
    NoteVersions.rootOverride = Directory('${temp.path}/device/note_versions');
    NoteBackup.folderOverride = Directory('${temp.path}/backups');
    NoteBackup.useIsolate = false;
    stows.penProfiles.value = '';
  });
  tearDown(() {
    NoteRecordings.rootOverride = null;
    HandwritingTexts.fileOverride = null;
    NoteVersions.rootOverride = null;
    NoteBackup.folderOverride = null;
    NoteBackup.useIsolate = false;
    stows.penProfiles.value = '';
    temp.deleteSync(recursive: true);
  });

  void write(String root, String path, String content) =>
      File('$root$path')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(content);

  String? read(String root, String path) {
    final file = File('$root$path');
    return file.existsSync() ? file.readAsStringSync() : null;
  }

  void recording(String root, String key, String name, String content) =>
      write(root, '/${Uri.encodeComponent(key)}/$name', content);

  /// A small library: notes in folders, with assets, previews, recordings,
  /// handwriting text, and the things that must stay out of a backup.
  void fillDevice() {
    write(docs, '/Günlük.sbn2', 'günlük ' * 400);
    write(docs, '/Günlük.sbn2.p', 'günlük resmi');
    write(docs, '/Okul/Fizik ödevi.sbn2', 'fizik ' * 300);
    write(docs, '/Okul/Fizik ödevi.sbn2.0', 'resim 0');
    write(docs, '/Okul/Fizik ödevi.sbn2.1', 'pdf 1');
    write(docs, '/Okul/Fizik ödevi.sbn2.p', 'fizik resmi');
    write(docs, '/Okul/Eski not.sbn', '{"eski":true}');
    Directory('$docs/Boş klasör/İçi boş').createSync(recursive: true);

    // none of these belong in a backup
    write(docs, '/Okul/Fizik ödevi.sbn2.bak', 'önceki kayıt');
    write(docs, '/Okul/Fizik ödevi.sbn2.tmp', 'yarım kayıt');
    write(docs, '/Okul/Bozuk.sbn2.bad', 'bozuk');
    write(docs, '/.Trash/Silinen.sbn2', 'silinmiş');
    write(docs, '/config.sbc', 'ayar');

    recording(recordings, '/Okul/Fizik ödevi', '20261004_093005.m4a', 'ses 1');
    recording(recordings, '/Okul/Fizik ödevi', '20261005_140000.m4a', 'ses 2');
    recording(recordings, '/.Trash/Silinen', '20260101_010101.m4a', 'çöp ses');

    File(handwriting).writeAsStringSync(
      jsonEncode({
        '/Okul/Fizik ödevi': {
          'm': 1790000000000,
          'p': ['kuvvet ve hareket', ''],
        },
        '/Günlük': {
          'm': 1790000000001,
          'p': ['bugün'],
        },
      }),
    );
  }

  BackupSummary make(String name, {String penProfiles = ''}) =>
      NoteBackupWork.create(
        documentsPath: docs,
        recordingsPath: recordings,
        handwritingPath: handwriting,
        penProfiles: penProfiles,
        zipPath: '${temp.path}/$name',
        created: created,
        appVersion: '1.2.3',
      );

  /// Another device, with nothing on it.
  ({String docs, String recordings}) otherDevice(String name) {
    final root = '${temp.path}/$name';
    Directory('$root/Saber').createSync(recursive: true);
    return (docs: '$root/Saber', recordings: '$root/note_recordings');
  }

  group('A backup', () {
    test('holds every note with what belongs to it, and nothing else', () {
      fillDevice();
      final summary = make('a.zip', penProfiles: '[{"id":"custom7"}]');

      expect(summary.notes, 3);
      expect(summary.recordings, 2);
      expect(summary.created, created);
      expect(summary.zipBytes, File(summary.path).lengthSync());
      expect(summary.zipBytes, greaterThan(0));

      final reader = ZipReader.open(summary.path);
      addTearDown(reader.close);
      final names = reader.entries.map((entry) => entry.name).toSet();
      expect(names, {
        'notes/Boş klasör/',
        'notes/Boş klasör/İçi boş/',
        'notes/Okul/',
        'notes/Günlük.sbn2',
        'notes/Günlük.sbn2.p',
        'notes/Okul/Fizik ödevi.sbn2',
        'notes/Okul/Fizik ödevi.sbn2.0',
        'notes/Okul/Fizik ödevi.sbn2.1',
        'notes/Okul/Fizik ödevi.sbn2.p',
        'notes/Okul/Eski not.sbn',
        'recordings/%2FOkul%2FFizik%20%C3%B6devi/20261004_093005.m4a',
        'recordings/%2FOkul%2FFizik%20%C3%B6devi/20261005_140000.m4a',
        'handwriting.json',
        'pen_profiles.json',
        'defter-backup.json',
      });
      expect(reader.entries.last.name, BackupManifest.entryName);

      // note files are compressed, the rest stored as they are
      final note = reader.find('notes/Günlük.sbn2')!;
      expect(note.method, ZipEntry.methodDeflate);
      expect(note.compressedSize, lessThan(note.size ~/ 5));
      expect(
        reader.find('notes/Okul/Fizik ödevi.sbn2.0')!.method,
        ZipEntry.methodStore,
      );
      expect(
        utf8.decode(reader.readBytes(reader.find('notes/Okul/Eski not.sbn')!)),
        '{"eski":true}',
      );

      final manifest = NoteBackupWork.inspect(summary.path);
      expect(manifest.created, created);
      expect(manifest.appVersion, '1.2.3');
      expect(manifest.notes, 3);
      expect(manifest.recordings, 2);
      expect(manifest.files.length, 11, reason: 'all but folders and itself');
      expect(manifest.bytes, summary.bytes);
      expect(
        manifest.files['notes/Okul/Fizik ödevi.sbn2.1']!.size,
        utf8.encode('pdf 1').length,
      );

      // kept for a look with other tools
      final samples = Directory('test/defter_shots/samples')
        ..createSync(recursive: true);
      File(summary.path).copySync('${samples.path}/backup_sample.zip');
    });

    test('can be opened by any program that reads zip files', () {
      fillDevice();
      final summary = make('b.zip');
      final decoded = archive.ZipDecoder().decodeBytes(
        File(summary.path).readAsBytesSync(),
        verify: true,
      );
      final byName = {for (final file in decoded.files) file.name: file};
      expect(
        utf8.decode(byName['notes/Okul/Fizik ödevi.sbn2']!.content),
        'fizik ' * 300,
      );
      expect(
        utf8.decode(byName['notes/Okul/Fizik ödevi.sbn2.1']!.content),
        'pdf 1',
      );
      final manifest = jsonDecode(
        utf8.decode(byName[BackupManifest.entryName]!.content),
      );
      expect(manifest['app'], 'Defter');
      expect(manifest['notes'], 3);
    });

    test('of an empty library is still a backup', () {
      final summary = make('empty.zip');
      expect(summary.notes, 0);
      expect(NoteBackupWork.verify(summary.path).files, isEmpty);
      final device = otherDevice('other');
      final outcome = NoteBackupWork.restore(
        zipPath: summary.path,
        documentsPath: device.docs,
        recordingsPath: device.recordings,
      );
      expect(outcome.changedAnything, isFalse);
    });

    test('reports how far it has got', () {
      fillDevice();
      final seen = <BackupProgress>[];
      NoteBackupWork.create(
        documentsPath: docs,
        recordingsPath: recordings,
        handwritingPath: handwriting,
        penProfiles: '',
        zipPath: '${temp.path}/p.zip',
        created: created,
        appVersion: '1',
        report: seen.add,
      );
      final writing = seen.where((p) => p.phase == BackupPhase.writing);
      final verifying = seen.where((p) => p.phase == BackupPhase.verifying);
      expect(writing, isNotEmpty);
      expect(verifying, isNotEmpty);
      expect(writing.last.done, writing.last.total);
      expect(writing.last.fraction, 1);
      expect(verifying.last.fraction, 1);
      expect(seen.indexOf(verifying.first), greaterThan(seen.indexOf(writing.last)));
    });

    test('that was altered is found out', () {
      fillDevice();
      final summary = make('c.zip');
      expect(NoteBackupWork.verify(summary.path).notes, 3);

      final reader = ZipReader.open(summary.path);
      final asset = reader.find('notes/Okul/Fizik ödevi.sbn2.0')!;
      reader.close();
      final bytes = File(summary.path).readAsBytesSync();
      final nameLength = utf8.encode(asset.name).length;
      bytes[asset.headerOffset + 30 + nameLength + 2] ^= 0x20;
      File(summary.path).writeAsBytesSync(bytes);

      expect(
        () => NoteBackupWork.verify(summary.path),
        throwsA(
          isA<BackupException>()
              .having((e) => e.failure, 'failure', BackupFailure.damaged)
              .having((e) => e.detail, 'detail', asset.name),
        ),
      );
    });

    test('is told apart from other files', () {
      final notZip = File('${temp.path}/x.zip')..writeAsStringSync('merhaba');
      expect(
        () => NoteBackupWork.inspect(notZip.path),
        throwsA(
          isA<BackupException>().having(
            (e) => e.failure,
            'failure',
            BackupFailure.notABackup,
          ),
        ),
      );

      // a zip, but not one of ours
      ZipWriter('${temp.path}/y.zip')
        ..addBytes('notes/a.sbn2', utf8.encode('a'))
        ..close();
      expect(
        () => NoteBackupWork.inspect('${temp.path}/y.zip'),
        throwsA(
          isA<BackupException>().having(
            (e) => e.failure,
            'failure',
            BackupFailure.notABackup,
          ),
        ),
      );

      // one from a later version of the app
      ZipWriter('${temp.path}/z.zip')
        ..addBytes(
          BackupManifest.entryName,
          utf8.encode(
            jsonEncode({
              'app': 'Defter',
              'format': BackupManifest.format + 1,
              'created': created.toIso8601String(),
              'files': <Object>[],
            }),
          ),
        )
        ..close();
      expect(
        () => NoteBackupWork.inspect('${temp.path}/z.zip'),
        throwsA(
          isA<BackupException>().having(
            (e) => e.failure,
            'failure',
            BackupFailure.newerFormat,
          ),
        ),
      );

      expect(
        () => NoteBackupWork.inspect('${temp.path}/yok.zip'),
        throwsA(isA<BackupException>()),
      );
    });
  });

  group('Restoring', () {
    test('on an empty device brings everything back', () {
      fillDevice();
      final summary = make('a.zip', penProfiles: '[]');
      final device = otherDevice('new');
      final seen = <BackupProgress>[];

      final outcome = NoteBackupWork.restore(
        zipPath: summary.path,
        documentsPath: device.docs,
        recordingsPath: device.recordings,
        report: seen.add,
      );

      expect(outcome.restored, ['/Günlük', '/Okul/Eski not', '/Okul/Fizik ödevi']);
      expect(outcome.copies, isEmpty);
      expect(outcome.alreadyThere, isEmpty);
      expect(outcome.failed, isEmpty);
      expect(outcome.recordings, 2);
      expect(outcome.changedAnything, isTrue);
      expect(outcome.penProfiles, '[]');
      expect(outcome.handwriting.keys.toSet(), {'/Okul/Fizik ödevi', '/Günlük'});
      expect(outcome.writtenFiles.toSet(), {
        '/Günlük.sbn2',
        '/Günlük.sbn2.p',
        '/Okul/Fizik ödevi.sbn2',
        '/Okul/Fizik ödevi.sbn2.0',
        '/Okul/Fizik ödevi.sbn2.1',
        '/Okul/Fizik ödevi.sbn2.p',
        '/Okul/Eski not.sbn',
      });

      expect(read(device.docs, '/Günlük.sbn2'), 'günlük ' * 400);
      expect(read(device.docs, '/Günlük.sbn2.p'), 'günlük resmi');
      expect(read(device.docs, '/Okul/Fizik ödevi.sbn2'), 'fizik ' * 300);
      expect(read(device.docs, '/Okul/Fizik ödevi.sbn2.0'), 'resim 0');
      expect(read(device.docs, '/Okul/Fizik ödevi.sbn2.1'), 'pdf 1');
      expect(read(device.docs, '/Okul/Eski not.sbn'), '{"eski":true}');
      expect(Directory('${device.docs}/Boş klasör/İçi boş').existsSync(), isTrue);
      expect(Directory('${device.docs}/.Trash').existsSync(), isFalse);
      expect(
        read(
          device.recordings,
          '/${Uri.encodeComponent('/Okul/Fizik ödevi')}/20261004_093005.m4a',
        ),
        'ses 1',
      );

      // nothing half done is left lying about
      final leftovers = Directory(temp.path)
          .listSync(recursive: true)
          .where((entity) => entity.path.endsWith('.tmp'))
          .where((entity) => !entity.path.contains('/device/'));
      expect(leftovers, isEmpty);

      expect(seen.last.phase, BackupPhase.restoring);
      expect(seen.last.fraction, 1);
    });

    test('never replaces what is on the device', () {
      fillDevice();
      final summary = make('a.zip');

      // Since the backup: one note changed, one was deleted, one is new.
      write(docs, '/Günlük.sbn2', 'günlüğün yeni hali');
      File('$docs/Okul/Eski not.sbn').deleteSync();
      write(docs, '/Yeni not.sbn2', 'yedekten sonra yazıldı');

      final outcome = NoteBackupWork.restore(
        zipPath: summary.path,
        documentsPath: docs,
        recordingsPath: recordings,
      );

      expect(outcome.alreadyThere, ['/Okul/Fizik ödevi']);
      expect(outcome.restored, ['/Okul/Eski not']);
      expect(outcome.copies, {'/Günlük': '/Günlük (2)'});
      expect(outcome.failed, isEmpty);
      expect(outcome.recordings, 0, reason: 'they are here already');

      expect(read(docs, '/Günlük.sbn2'), 'günlüğün yeni hali');
      expect(read(docs, '/Günlük (2).sbn2'), 'günlük ' * 400);
      expect(read(docs, '/Günlük (2).sbn2.p'), 'günlük resmi');
      expect(read(docs, '/Yeni not.sbn2'), 'yedekten sonra yazıldı');
      expect(read(docs, '/Okul/Eski not.sbn'), '{"eski":true}');
      // the copy's handwriting text goes with the copy
      expect(outcome.handwriting.keys, contains('/Günlük (2)'));
      expect(outcome.handwriting.keys, isNot(contains('/Günlük')));

      // Doing it again changes nothing: no "(3)".
      final again = NoteBackupWork.restore(
        zipPath: summary.path,
        documentsPath: docs,
        recordingsPath: recordings,
      );
      expect(again.restored, isEmpty);
      expect(again.copies, isEmpty);
      expect(again.alreadyThere.toSet(), {
        '/Günlük',
        '/Okul/Eski not',
        '/Okul/Fizik ödevi',
      });
      expect(again.changedAnything, isFalse);
      expect(File('$docs/Günlük (3).sbn2').existsSync(), isFalse);
    });

    test('a note that only differs in an attachment is a different note', () {
      fillDevice();
      final summary = make('a.zip');
      write(docs, '/Okul/Fizik ödevi.sbn2.1', 'başka bir pdf');

      final outcome = NoteBackupWork.restore(
        zipPath: summary.path,
        documentsPath: docs,
        recordingsPath: recordings,
      );
      expect(outcome.copies, {'/Okul/Fizik ödevi': '/Okul/Fizik ödevi (2)'});
      expect(read(docs, '/Okul/Fizik ödevi.sbn2.1'), 'başka bir pdf');
      expect(read(docs, '/Okul/Fizik ödevi (2).sbn2.1'), 'pdf 1');
      // its recordings come along under the new name
      expect(outcome.recordings, 2);
      expect(
        read(
          recordings,
          '/${Uri.encodeComponent('/Okul/Fizik ödevi (2)')}/20261005_140000.m4a',
        ),
        'ses 2',
      );
    });

    test('leaves out what is damaged and brings back the rest', () {
      fillDevice();
      final summary = make('a.zip');

      final reader = ZipReader.open(summary.path);
      final asset = reader.find('notes/Okul/Fizik ödevi.sbn2.1')!;
      reader.close();
      final bytes = File(summary.path).readAsBytesSync();
      bytes[asset.headerOffset + 30 + utf8.encode(asset.name).length] ^= 0x01;
      File(summary.path).writeAsBytesSync(bytes);

      final device = otherDevice('new');
      final outcome = NoteBackupWork.restore(
        zipPath: summary.path,
        documentsPath: device.docs,
        recordingsPath: device.recordings,
      );
      expect(outcome.failed, ['/Okul/Fizik ödevi']);
      expect(outcome.restored, ['/Günlük', '/Okul/Eski not']);
      // not a single file of the damaged note is left behind
      expect(
        Directory('${device.docs}/Okul')
            .listSync()
            .map((entity) => entity.path.split('/').last),
        ['Eski not.sbn'],
      );
      expect(outcome.recordings, 0);
      expect(outcome.handwriting.keys, ['/Günlük']);
    });

    test('ignores names that point outside the notes folder', () {
      final path = '${temp.path}/evil.zip';
      final writer = ZipWriter(path);
      final files = <String, ({int size, String sha256})>{};
      for (final name in [
        'notes/../../kaçak.sbn2',
        'notes/./gizli.sbn2',
        'notes/.Trash/çöp.sbn2',
        'notes/iyi.sbn2',
        'recordings/..%2F..%2Fkaçak/20260101_010101.m4a',
        'recordings/%2Fiyi/..',
      ]) {
        final added = writer.addBytes(name, utf8.encode('içerik'));
        files[name] = (size: added.size, sha256: added.sha256);
      }
      writer
        ..addBytes(
          BackupManifest.entryName,
          utf8.encode(
            jsonEncode(
              BackupManifest(created: created, appVersion: '1', files: files),
            ),
          ),
        )
        ..close();

      final device = otherDevice('new');
      final outcome = NoteBackupWork.restore(
        zipPath: path,
        documentsPath: device.docs,
        recordingsPath: device.recordings,
      );
      expect(outcome.restored, ['/iyi']);
      final everything = Directory(temp.path)
          .listSync(recursive: true)
          .whereType<File>()
          .map((file) => file.path)
          .where((path) => path.contains('kaçak') || path.contains('gizli'));
      expect(everything, isEmpty);
      expect(Directory('${device.docs}/.Trash').existsSync(), isFalse);
      expect(outcome.recordings, 0);
    });

    test('a path is safe only if it stays inside', () {
      expect(NoteBackupWork.isSafePath('/a/b.sbn2'), isTrue);
      expect(NoteBackupWork.isSafePath('/Okul/Fizik ödevi (2).sbn2.0'), isTrue);
      expect(NoteBackupWork.isSafePath('a/b'), isFalse);
      expect(NoteBackupWork.isSafePath('/a/../b'), isFalse);
      expect(NoteBackupWork.isSafePath('/a/./b'), isFalse);
      expect(NoteBackupWork.isSafePath('/a//b'), isFalse);
      expect(NoteBackupWork.isSafePath(r'/a\b'), isFalse);
      expect(NoteBackupWork.isSafePath('/'), isFalse);
    });
  });

  group('In the app', () {
    test('a backup is made, checked and named after its time', () async {
      fillDevice();
      Directory('${temp.path}/backups').createSync();
      File('${temp.path}/backups/Defter-yedek-2025-01-01-0000.zip')
          .writeAsStringSync('eski yedek');
      expect(NoteBackup.fileName(created), 'Marj-yedek-2026-10-06-1405.zip');

      final summary = await NoteBackup.create(now: created);
      expect(
        summary.path,
        '${temp.path}/backups/Marj-yedek-2026-10-06-1405.zip',
      );
      expect(summary.notes, 3);
      expect((await NoteBackup.latest())!.path, summary.path);
      expect(
        Directory('${temp.path}/backups').listSync().length,
        1,
        reason: 'only the newest backup is kept there',
      );
      expect((await NoteBackup.inspect(summary.path)).notes, 3);
    });

    test('restoring adds handwriting text and pen profiles that are missing', () async {
      fillDevice();
      final custom = PenProfile(
        id: 'custom9',
        name: 'Benim kalemim',
        subtitle: '',
        style: PenStyle.ballpoint,
        size: 6,
        sensitivity: 0.2,
        stabilization: 0.4,
      );
      PenProfiles.save([...PenProfiles.builtIn(), custom]);
      final summary = await NoteBackup.create(now: created);

      // The device loses a note, its text, and the profile.
      File('$docs/Günlük.sbn2').deleteSync();
      File('$docs/Günlük.sbn2.p').deleteSync();
      await HandwritingTexts.remove('/Günlük');
      stows.penProfiles.value = '';
      expect(PenProfiles.load().any((p) => p.id == 'custom9'), isFalse);
      // …and has newer text for another one, which must stay.
      await HandwritingTexts.put(
        '/Okul/Fizik ödevi',
        const NoteHandwriting(recognizedMs: 5, pages: ['yeni okuma']),
      );

      final outcome = await NoteBackup.restore(summary.path);
      expect(outcome.restored, ['/Günlük']);
      expect(read(docs, '/Günlük.sbn2'), 'günlük ' * 400);
      expect(HandwritingTexts.of('/Günlük')!.pages, ['bugün']);
      expect(HandwritingTexts.of('/Okul/Fizik ödevi')!.pages, ['yeni okuma']);
      final profiles = PenProfiles.load();
      expect(profiles.where((p) => p.id == 'custom9').single.name, 'Benim kalemim');
      expect(profiles.length, PenProfiles.builtIn().length + 1);
    });

    test('works in another isolate, as it does in the app', () async {
      NoteBackup.useIsolate = true;
      fillDevice();
      final made = <BackupProgress>[];
      final summary = await NoteBackup.create(now: created, onProgress: made.add);
      expect(summary.notes, 3);
      expect(made.map((p) => p.phase).toSet(), {
        BackupPhase.writing,
        BackupPhase.verifying,
      });
      expect((await NoteBackup.inspect(summary.path)).recordings, 2);

      File('$docs/Okul/Eski not.sbn').deleteSync();
      final restored = <BackupProgress>[];
      final outcome = await NoteBackup.restore(
        summary.path,
        onProgress: restored.add,
      );
      expect(outcome.restored, ['/Okul/Eski not']);
      expect(outcome.alreadyThere.length, 2);
      expect(restored, isNotEmpty);
      expect(read(docs, '/Okul/Eski not.sbn'), '{"eski":true}');

      // errors come back as what they are
      final notZip = File('${temp.path}/x.zip')..writeAsStringSync('merhaba');
      await expectLater(
        NoteBackup.inspect(notZip.path),
        throwsA(
          isA<BackupException>().having(
            (e) => e.failure,
            'failure',
            BackupFailure.notABackup,
          ),
        ),
      );
    });
  });
}
