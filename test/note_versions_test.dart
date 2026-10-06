import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:saber/data/audio/note_recordings.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/flavor_config.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/search/handwriting_text.dart';
import 'package:saber/data/versions/note_versions.dart';

import 'utils/test_mock_channel_handlers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupMockPathProvider();
  FlavorConfig.setup();

  late Directory temp;
  late String docs;
  late NoteVersionStore store;

  setUp(() async {
    temp = Directory.systemTemp.createTempSync('note_versions_test');
    docs = '${temp.path}/docs';
    Directory(docs).createSync();
    await FileManager.init(
      documentsDirectory: docs,
      shouldWatchRootDirectory: false,
    );
    NoteVersions.rootOverride = Directory('${temp.path}/versions');
    NoteRecordings.rootOverride = Directory('${temp.path}/recordings');
    HandwritingTexts.fileOverride = File('${temp.path}/handwriting.json');
    HandwritingTexts.resetForTesting();
    NoteVersions.useIsolate = false;
    stows.versionHistory.value = true;
    store = NoteVersions.store;
  });
  tearDown(() {
    NoteVersions.rootOverride = null;
    NoteRecordings.rootOverride = null;
    HandwritingTexts.fileOverride = null;
    NoteVersions.useIsolate = false;
    stows.versionHistory.value = true;
    temp.deleteSync(recursive: true);
  });

  File file(String path) => File('$docs$path');

  /// Writes the note [key] straight to disk: its note file, assets and
  /// preview.
  void put(
    String key,
    String main, {
    List<String> assets = const [],
    String? preview,
    String extension = '.sbn2',
  }) {
    final mainFile = file('$key$extension')..parent.createSync(recursive: true);
    mainFile.writeAsStringSync(main);
    for (var i = 0; file('$key$extension.$i').existsSync(); i++) {
      file('$key$extension.$i').deleteSync();
    }
    for (final (i, asset) in assets.indexed) {
      file('$key$extension.$i').writeAsStringSync(asset);
    }
    final previewFile = file('$key$extension.p');
    if (preview != null) {
      previewFile.writeAsStringSync(preview);
    } else if (previewFile.existsSync()) {
      previewFile.deleteSync();
    }
  }

  NoteVersion? keep(
    String key, {
    required DateTime at,
    String reason = NoteVersion.reasonAuto,
    Duration minInterval = Duration.zero,
    String extension = '.sbn2',
  }) => store.snapshot(
    key: key,
    mainFilePath: file('$key$extension').path,
    now: at,
    reason: reason,
    minInterval: minInterval,
  );

  String objectText(String hash) => store.objectFile(hash).readAsStringSync();

  // Well in the past: versions kept "now" are newer than these.
  final t0 = DateTime(2026, 1, 6, 9);

  group('The store', () {
    test('keeps a note with its assets and preview', () {
      put('/Okul/Fizik', 'bir', assets: ['resim', 'pdf'], preview: 'önizleme');
      final version = keep('/Okul/Fizik', at: t0, reason: NoteVersion.reasonOpen)!;

      expect(version.key, '/Okul/Fizik');
      expect(version.time, t0);
      expect(version.extension, '.sbn2');
      expect(version.reason, NoteVersion.reasonOpen);
      expect(objectText(version.main), 'bir');
      expect(version.assets.map(objectText), ['resim', 'pdf']);
      expect(objectText(version.preview!), 'önizleme');
      expect(version.size, 'bir'.length + 'resim'.length + 'pdf'.length);

      final listed = store.list('/Okul/Fizik');
      expect(listed.single.id, version.id);
      expect(listed.single.time, t0);
      expect(listed.single.assets, version.assets);
      expect(store.damaged(listed.single), isEmpty);
      expect(store.list('/Okul/Kimya'), isEmpty);
    });

    test('keeps nothing when there is no note or nothing changed', () {
      expect(keep('/yok', at: t0), isNull);
      file('/bos.sbn2').writeAsStringSync('');
      expect(keep('/bos', at: t0), isNull);

      put('/a', 'bir', assets: ['x']);
      expect(keep('/a', at: t0), isNotNull);
      expect(keep('/a', at: t0.add(const Duration(hours: 1))), isNull);
      expect(store.list('/a').length, 1);
      expect(store.isKept('/a', file('/a.sbn2').path), isTrue);

      // the same note file with another asset is another note
      put('/a', 'bir', assets: ['xyz']);
      expect(store.isKept('/a', file('/a.sbn2').path), isFalse);
      expect(keep('/a', at: t0.add(const Duration(hours: 2))), isNotNull);
      // and so is the same note file with one asset more
      put('/a', 'bir', assets: ['xyz', 'q']);
      expect(keep('/a', at: t0.add(const Duration(hours: 3))), isNotNull);
      expect(store.list('/a').length, 3);
    });

    test('a note with nothing kept of it is not "kept"', () {
      put('/k', 'bir');
      expect(store.isKept('/k', file('/k.sbn2').path), isFalse);
      expect(store.isKept('/k', file('/yok.sbn2').path), isTrue);
    });

    test('keeps at most one version in the time asked', () {
      put('/b', 'bir');
      expect(keep('/b', at: t0), isNotNull);
      put('/b', 'iki');
      const ten = Duration(minutes: 10);
      expect(
        keep('/b', at: t0.add(const Duration(minutes: 9)), minInterval: ten),
        isNull,
      );
      final later = keep(
        '/b',
        at: t0.add(const Duration(minutes: 10)),
        minInterval: ten,
      );
      expect(objectText(later!.main), 'iki');
      expect(store.list('/b').map((v) => objectText(v.main)), ['iki', 'bir']);
    });

    test('content that several versions share is stored once', () {
      put('/c', 'bir', assets: ['büyük dosya']);
      final first = keep('/c', at: t0)!;
      put('/c', 'iki', assets: ['büyük dosya']);
      final second = keep('/c', at: t0.add(const Duration(hours: 1)))!;
      expect(second.assets, first.assets);

      final objects = Directory('${store.rootPath}/objects')
          .listSync(recursive: true)
          .whereType<File>();
      expect(objects.length, 3, reason: 'two note files and one asset');
    });

    test('lists the newest version first', () {
      put('/d', '1');
      keep('/d', at: t0);
      put('/d', '2');
      keep('/d', at: t0.add(const Duration(days: 2)));
      put('/d', '3');
      keep('/d', at: t0.add(const Duration(days: 1)));
      expect(store.list('/d').map((v) => objectText(v.main)), ['2', '3', '1']);
    });

    test('two versions in the same instant both stay', () {
      put('/e', '1');
      final a = keep('/e', at: t0)!;
      put('/e', '2');
      final b = keep('/e', at: t0)!;
      expect(a.id, isNot(b.id));
      expect(store.list('/e').length, 2);
    });

    test('thinning keeps the newest and then one a day', () {
      NoteVersion at(int index, DateTime time) => NoteVersion(
        id: 'v$index',
        key: '/n',
        time: time,
        extension: '.sbn2',
        main: 'a' * 64,
        assets: const [],
        preview: null,
        size: 1,
        reason: NoteVersion.reasonAuto,
      );
      final now = DateTime(2026, 10, 30, 20);
      final versions = [
        // four today, newest first
        for (var i = 0; i < 4; i++) at(i, now.subtract(Duration(hours: i))),
        // then three a day for six days
        for (var day = 1; day <= 6; day++)
          for (var i = 0; i < 3; i++)
            at(
              day * 10 + i,
              now.subtract(Duration(days: day, hours: i)),
            ),
      ];

      final kept = NoteVersionStore.idsToKeep(
        versions,
        keepRecent: 5,
        keepDaily: 3,
      );
      expect(kept, {
        'v0', 'v1', 'v2', 'v3', 'v10', // the newest five
        // yesterday is among those already: the next three days' last ones
        'v20', 'v30', 'v40',
      });
      expect(
        NoteVersionStore.idsToKeep(versions, keepRecent: 100, keepDaily: 0)
            .length,
        versions.length,
      );
      expect(
        NoteVersionStore.idsToKeep(versions, keepRecent: 0, keepDaily: 100),
        {'v0', 'v10', 'v20', 'v30', 'v40', 'v50', 'v60'},
      );
    });

    test('old versions go, and what only they held with them', () {
      final base = DateTime.now();
      for (var i = 0; i < 6; i++) {
        put('/f', 'sürüm $i', assets: ['ek $i']);
        store.snapshot(
          key: '/f',
          mainFilePath: file('/f.sbn2').path,
          now: base.add(Duration(seconds: i)),
          reason: NoteVersion.reasonAuto,
          keepRecent: 3,
          keepDaily: 0,
        );
      }
      final left = store.list('/f');
      expect(left.map((v) => objectText(v.main)), [
        'sürüm 5',
        'sürüm 4',
        'sürüm 3',
      ]);

      // Fresh content is left alone: something may be about to use it.
      expect(store.collectGarbage(now: base.add(const Duration(minutes: 5))), 0);
      // Later, what no version names is deleted.
      final freed = store.collectGarbage(
        now: DateTime.now().add(const Duration(hours: 1)),
      );
      expect(freed, greaterThan(0));
      final objects = Directory('${store.rootPath}/objects')
          .listSync(recursive: true)
          .whereType<File>();
      expect(objects.length, 6, reason: 'three note files and three assets');
      for (final version in left) {
        expect(store.damaged(version), isEmpty);
      }
    });

    test('a version file that cannot be read is left out', () {
      put('/g', 'bir');
      final version = keep('/g', at: t0)!;
      File('${store.directoryOf('/g').path}/bozuk.json').writeAsStringSync('{');
      File('${store.directoryOf('/g').path}/yarim.json').writeAsStringSync(
        jsonEncode({'id': 'x', 'key': '/g'}),
      );
      expect(store.list('/g').single.id, version.id);
      // and cleaning up still works around it
      store.collectGarbage(now: DateTime.now().add(const Duration(hours: 1)));
      expect(store.damaged(version), isEmpty);
    });

    test('missing or altered content is found', () {
      put('/h', 'bir', assets: ['ek']);
      final version = keep('/h', at: t0)!;
      expect(store.damaged(version), isEmpty);
      store.objectFile(version.assets.single).writeAsStringSync('başka');
      expect(store.damaged(version), [version.assets.single]);
      store.objectFile(version.main).deleteSync();
      expect(store.damaged(version).toSet(), {
        version.main,
        version.assets.single,
      });
    });

    test('versions follow a note that moves, and merge with others', () {
      put('/eski', '1');
      keep('/eski', at: t0);
      put('/yeni', '2');
      keep('/yeni', at: t0);
      store.move('/eski', '/yeni');
      expect(store.list('/eski'), isEmpty);
      expect(
        store.list('/yeni').map((v) => objectText(v.main)).toSet(),
        {'1', '2'},
      );
      store.move('/hic', '/yeni'); // nothing to move
      expect(store.list('/yeni').length, 2);
    });

    test('deleting and clearing', () {
      put('/i', '1');
      keep('/i', at: t0);
      put('/j', '2');
      keep('/j', at: t0);
      expect(store.totalSize(), greaterThan(0));
      store.deleteAll('/i');
      expect(store.list('/i'), isEmpty);
      expect(store.list('/j').length, 1);
      store.clear();
      expect(store.list('/j'), isEmpty);
      expect(store.totalSize(), 0);
    });

    test('the old note format is kept as it is', () {
      put('/old', '{"v":1}', extension: '.sbn');
      final version = keep('/old', at: t0, extension: '.sbn')!;
      expect(version.extension, '.sbn');
      expect(store.list('/old').single.extension, '.sbn');
    });

    test('a note with a long name with odd characters', () {
      // close to the longest name a file can have
      final key = '/Öğrenci/${'çok uzun ad ' * 15}: "tırnak" ?*';
      put(key, 'bir');
      expect(keep(key, at: t0), isNotNull);
      expect(store.list(key).single.key, key);
    });
  });

  group('Version history', () {
    test('names a note whatever file of it is given', () {
      expect(NoteVersions.keyOf('/a/b.sbn2'), '/a/b');
      expect(NoteVersions.keyOf('/a/b.sbn'), '/a/b');
      expect(NoteVersions.keyOf('/a/b'), '/a/b');
      expect(NoteVersions.keyOf('/a/b.sbn2.3'), '/a/b');
      expect(NoteVersions.keyOf('/a/b.sbn2.p'), '/a/b');
      expect(NoteVersions.keyOf('/a/b.sbn2.bak'), '/a/b');
      expect(NoteVersions.keyOf('/a/b.sbn2.0.tmp'), '/a/b');
      expect(NoteVersions.keyOf('/a/not.sbn2 hakkında'), '/a/not.sbn2 hakkında');
    });

    test('keeps versions as asked, and none when turned off', () async {
      put('/n1', 'bir');
      final first = await NoteVersions.snapshot(
        '/n1.sbn2',
        reason: NoteVersion.reasonOpen,
        now: t0,
      );
      expect(first!.reason, NoteVersion.reasonOpen);
      expect((await NoteVersions.list('/n1')).single.id, first.id);

      // within ten minutes of the last one, writing leaves nothing behind
      put('/n1', 'iki');
      expect(
        await NoteVersions.snapshotIfDue(
          '/n1.sbn2',
          now: t0.add(const Duration(minutes: 5)),
        ),
        isNull,
      );
      final due = await NoteVersions.snapshotIfDue(
        '/n1.sbn2',
        now: t0.add(const Duration(minutes: 11)),
      );
      expect(due!.reason, NoteVersion.reasonAuto);

      stows.versionHistory.value = false;
      put('/n1', 'üç');
      expect(
        await NoteVersions.snapshot(
          '/n1.sbn2',
          reason: NoteVersion.reasonClose,
          now: t0.add(const Duration(hours: 1)),
        ),
        isNull,
      );
      expect((await NoteVersions.list('/n1')).length, 2);
    });

    test('a version read while the note was written is thrown away', () async {
      put('/n2', 'bir');
      final reading = NoteVersions.snapshot(
        '/n2.sbn2',
        reason: NoteVersion.reasonAuto,
        now: t0,
      );
      // a save comes in before the version is done
      NoteVersions.noteWritten('/n2.sbn2.0');
      expect(await reading, isNull);
      expect(await NoteVersions.list('/n2'), isEmpty);

      // and the next one is kept as usual
      expect(
        await NoteVersions.snapshot(
          '/n2.sbn2',
          reason: NoteVersion.reasonAuto,
          now: t0,
        ),
        isNotNull,
      );
    });

    test('a version waits for a save that is under way', () async {
      put('/n3', 'eski', assets: ['a']);
      final endSave = await NoteVersions.beginSave('/n3.sbn2');
      var done = false;
      final reading = NoteVersions.snapshot(
        '/n3.sbn2',
        reason: NoteVersion.reasonAuto,
        now: t0,
      ).whenComplete(() => done = true);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(done, isFalse, reason: 'the save is not finished');

      put('/n3', 'yeni', assets: ['b']);
      endSave();
      final version = (await reading)!;
      expect(objectText(version.main), 'yeni');
      expect(objectText(version.assets.single), 'b');
      await NoteVersions.whenIdle();
    });

    test('brings a version back, and keeps what was there', () async {
      put('/r', 'bir', assets: ['a0', 'a1', 'a2'], preview: 'p1');
      final first = (await NoteVersions.snapshot(
        '/r.sbn2',
        reason: NoteVersion.reasonOpen,
        now: t0,
      ))!;
      put('/r', 'iki', assets: ['b0'], preview: 'p2');
      await NoteVersions.snapshot(
        '/r.sbn2',
        reason: NoteVersion.reasonAuto,
        now: t0.add(const Duration(hours: 1)),
      );
      // changed since the last version was kept
      put('/r', 'üç', assets: ['c0', 'c1', 'c2', 'c3'], preview: 'p3');

      await NoteVersions.restore('/r.sbn2', first);

      expect(file('/r.sbn2').readAsStringSync(), 'bir');
      expect(file('/r.sbn2.0').readAsStringSync(), 'a0');
      expect(file('/r.sbn2.1').readAsStringSync(), 'a1');
      expect(file('/r.sbn2.2').readAsStringSync(), 'a2');
      expect(file('/r.sbn2.3').existsSync(), isFalse);
      expect(file('/r.sbn2.p').readAsStringSync(), 'p1');

      // what was there is the newest version now
      final versions = await NoteVersions.list('/r');
      expect(versions.length, 3);
      expect(versions.first.reason, NoteVersion.reasonRestore);
      expect(objectText(versions.first.main), 'üç');
      expect(versions.first.assets.map(objectText), ['c0', 'c1', 'c2', 'c3']);

      // so bringing a version back can be undone
      await NoteVersions.restore('/r.sbn2', versions.first);
      expect(file('/r.sbn2').readAsStringSync(), 'üç');
      expect(file('/r.sbn2.3').readAsStringSync(), 'c3');
      expect(file('/r.sbn2.p').readAsStringSync(), 'p3');
    });

    test('brings versions back even when keeping them is turned off', () async {
      put('/off', 'bir');
      final first = (await NoteVersions.snapshot(
        '/off.sbn2',
        reason: NoteVersion.reasonOpen,
        now: t0,
      ))!;
      stows.versionHistory.value = false;
      put('/off', 'iki');
      await NoteVersions.restore('/off.sbn2', first);
      expect(file('/off.sbn2').readAsStringSync(), 'bir');
      final versions = await NoteVersions.list('/off');
      expect(objectText(versions.first.main), 'iki');
    });

    test('a damaged version is refused and the note left alone', () async {
      put('/dmg', 'bir', assets: ['a0']);
      final first = (await NoteVersions.snapshot(
        '/dmg.sbn2',
        reason: NoteVersion.reasonOpen,
        now: t0,
      ))!;
      put('/dmg', 'iki', assets: ['b0', 'b1']);
      store.objectFile(first.assets.single).deleteSync();

      await expectLater(
        NoteVersions.restore('/dmg.sbn2', first),
        throwsA(isA<StateError>()),
      );
      expect(file('/dmg.sbn2').readAsStringSync(), 'iki');
      expect(file('/dmg.sbn2.1').readAsStringSync(), 'b1');
    });

    test('a version without a preview takes the old picture away', () async {
      put('/np', 'bir');
      final first = (await NoteVersions.snapshot(
        '/np.sbn2',
        reason: NoteVersion.reasonOpen,
        now: t0,
      ))!;
      put('/np', 'iki', preview: 'ikinin resmi');
      await NoteVersions.restore('/np.sbn2', first);
      expect(file('/np.sbn2').readAsStringSync(), 'bir');
      expect(file('/np.sbn2.p').existsSync(), isFalse);
    });

    test('a version in the old format replaces the note in the new', () async {
      put('/conv', '{"old":true}', extension: '.sbn');
      final old = (await NoteVersions.snapshot(
        '/conv',
        reason: NoteVersion.reasonOpen,
        now: t0,
      ))!;
      expect(old.extension, '.sbn');

      // the note was saved in the new format since, which removes the old
      file('/conv.sbn').deleteSync();
      put('/conv', 'yeni', assets: ['x']);
      await NoteRecordings.newRecordingFile(
        '/conv',
      ).then((f) => f.writeAsString('ses'));

      await NoteVersions.restore('/conv.sbn2', old);
      expect(file('/conv.sbn').readAsStringSync(), '{"old":true}');
      expect(file('/conv.sbn2').existsSync(), isFalse);
      expect(file('/conv.sbn2.0').existsSync(), isFalse);
      // what belongs to the note stays with it
      expect(await NoteRecordings.hasAny('/conv'), isTrue);
      expect((await NoteVersions.list('/conv')).length, 2);
    });

    test('versions follow a note that is renamed or put in the trash', () async {
      put('/Ders/Not', 'bir');
      await NoteVersions.snapshot(
        '/Ders/Not.sbn2',
        reason: NoteVersion.reasonOpen,
        now: t0,
      );

      final renamed = await FileManager.moveFile(
        '/Ders/Not.sbn2',
        '/Ders/Yeni ad.sbn2',
      );
      expect(renamed, '/Ders/Yeni ad.sbn2');
      expect(await NoteVersions.list('/Ders/Not'), isEmpty);
      expect((await NoteVersions.list('/Ders/Yeni ad')).length, 1);

      final trashed = (await FileManager.moveToTrash('/Ders/Yeni ad.sbn2'))!;
      expect((await NoteVersions.list(trashed)).length, 1);

      final back = await FileManager.restoreFromTrash(trashed);
      expect((await NoteVersions.list(back)).length, 1);
    });

    test('versions follow the notes of a renamed folder', () async {
      put('/Eski klasör/Not', 'bir');
      await NoteVersions.snapshot(
        '/Eski klasör/Not.sbn2',
        reason: NoteVersion.reasonOpen,
        now: t0,
      );
      await NoteRecordings.newRecordingFile(
        '/Eski klasör/Not',
      ).then((f) => f.writeAsString('ses'));

      await FileManager.renameDirectory('/Eski klasör', 'Yeni klasör');
      expect(file('/Yeni klasör/Not.sbn2').existsSync(), isTrue);
      expect((await NoteVersions.list('/Yeni klasör/Not')).length, 1);
      expect(await NoteVersions.list('/Eski klasör/Not'), isEmpty);
      expect(await NoteRecordings.hasAny('/Yeni klasör/Not'), isTrue);
    });

    test('versions go with a note that is deleted for good', () async {
      put('/sil', 'bir');
      await NoteVersions.snapshot(
        '/sil.sbn2',
        reason: NoteVersion.reasonOpen,
        now: t0,
      );
      await FileManager.deleteFile('/sil.sbn2');
      expect(await NoteVersions.list('/sil'), isEmpty);
    });

    test('everything can be deleted, and the size is known', () async {
      put('/s1', 'bir' * 100);
      await NoteVersions.snapshot(
        '/s1.sbn2',
        reason: NoteVersion.reasonOpen,
        now: t0,
      );
      expect(await NoteVersions.totalSize(), greaterThan(300));
      await NoteVersions.clear();
      expect(await NoteVersions.totalSize(), 0);
      expect(await NoteVersions.list('/s1'), isEmpty);
    });

    test('works in another isolate, as it does in the app', () async {
      NoteVersions.useIsolate = true;
      put('/iso', 'bir', assets: ['a0'], preview: 'p');
      final first = (await NoteVersions.snapshot(
        '/iso.sbn2',
        reason: NoteVersion.reasonOpen,
        now: t0,
      ))!;
      expect(objectText(first.main), 'bir');

      put('/iso', 'iki');
      final second = await NoteVersions.snapshotIfDue(
        '/iso.sbn2',
        now: t0.add(const Duration(minutes: 30)),
      );
      expect(second, isNotNull);
      expect((await NoteVersions.list('/iso.sbn2')).length, 2);

      put('/iso', 'üç');
      await NoteVersions.restore('/iso.sbn2', first);
      expect(file('/iso.sbn2').readAsStringSync(), 'bir');
      expect(file('/iso.sbn2.0').readAsStringSync(), 'a0');
      expect((await NoteVersions.list('/iso')).length, 3);

      await NoteVersions.move('/iso.sbn2', '/iso2.sbn2');
      expect((await NoteVersions.list('/iso2')).length, 3);
      expect(await NoteVersions.totalSize(), greaterThan(0));
      await NoteVersions.collectGarbage();
      await NoteVersions.deleteAll('/iso2.sbn2');
      expect(await NoteVersions.list('/iso2'), isEmpty);
      await NoteVersions.clear();
      expect(await NoteVersions.totalSize(), 0);

      // a version read while the note is written is thrown away here too
      put('/iso3', 'bir');
      final reading = NoteVersions.snapshot(
        '/iso3.sbn2',
        reason: NoteVersion.reasonAuto,
        now: t0,
      );
      NoteVersions.noteWritten('/iso3.sbn2');
      expect(await reading, isNull);
      expect(await NoteVersions.list('/iso3'), isEmpty);
    });
  });
}
