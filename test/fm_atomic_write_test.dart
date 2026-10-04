import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saber/data/editor/editor_core_info.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/flavor_config.dart';
import 'package:saber/pages/editor/editor.dart';
import 'package:sbn/canvas_background_pattern.dart';

import 'utils/test_mock_channel_handlers.dart';

void main() {
  group('Atomic save and backup:', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupMockPathProvider();
    FlavorConfig.setup();

    late final String rootDir;
    setUpAll(() async {
      await FileManager.init();
      rootDir = FileManager.documentsDirectory;
    });

    File f(String path) => File('$rootDir$path');
    Future<String> read(String path) => f(path).readAsString();

    test('a write leaves no temporary file behind', () async {
      const path = '/atomic_clean.sbn2';
      await FileManager.writeFile(path, utf8.encode('one'), awaitWrite: true);
      expect(await read(path), 'one');
      expect(f('$path.tmp').existsSync(), isFalse);
    });

    test('overwriting a note keeps the previous version as .bak', () async {
      const path = '/atomic_bak.sbn2';
      await FileManager.writeFile(path, utf8.encode('v1'), awaitWrite: true);
      expect(f('$path.bak').existsSync(), isFalse);

      await FileManager.writeFile(path, utf8.encode('v2'), awaitWrite: true);
      expect(await read(path), 'v2');
      expect(await read('$path.bak'), 'v1');

      await FileManager.writeFile(path, utf8.encode('v3'), awaitWrite: true);
      expect(await read(path), 'v3');
      expect(await read('$path.bak'), 'v2');
    });

    test('assets are written atomically but get no backup', () async {
      const path = '/atomic_asset.sbn2.0';
      await FileManager.writeFile(path, utf8.encode('a'), awaitWrite: true);
      await FileManager.writeFile(path, utf8.encode('b'), awaitWrite: true);
      expect(await read(path), 'b');
      expect(f('$path.bak').existsSync(), isFalse);
      expect(f('$path.tmp').existsSync(), isFalse);
    });

    test('an interrupted write never damages the saved note', () async {
      const path = '/atomic_interrupted.sbn2';
      await FileManager.writeFile(path, utf8.encode('good'), awaitWrite: true);

      // Simulate a crash halfway through the next save:
      // a half-written temp file exists, the real file was never touched.
      await f('$path.tmp').writeAsString('hal');

      expect(await read(path), 'good');
      expect(utf8.decode((await FileManager.readFile(path))!), 'good');

      // The next save replaces the stale temp file.
      await FileManager.writeFile(path, utf8.encode('next'), awaitWrite: true);
      expect(await read(path), 'next');
      expect(f('$path.tmp').existsSync(), isFalse);
    });

    test('lastModified is applied to the final file', () async {
      const path = '/atomic_modified.sbn2';
      final date = DateTime(2020, 5, 17, 12);
      await FileManager.writeFile(
        path,
        utf8.encode('x'),
        awaitWrite: true,
        lastModified: date,
      );
      expect(f(path).lastModifiedSync().isAtSameMomentAs(date), isTrue);
    });

    test('concurrent writes to one file end with the last one', () async {
      const path = '/atomic_concurrent.sbn2';
      await Future.wait([
        for (var i = 0; i < 20; i++)
          FileManager.writeFile(
            path,
            utf8.encode('write $i'),
            awaitWrite: true,
          ),
      ]);
      expect(await read(path), 'write 19');
      expect(f('$path.tmp').existsSync(), isFalse);
    });

    test('transient files are recognised', () {
      for (final p in [
        '/a.sbn2.tmp',
        '/a.sbn2.bak',
        '/a.sbn2.bad',
        '/a.sbn2.0.tmp',
        '/dir/a.sbn.bak',
      ]) {
        expect(FileManager.transientFileRegex.hasMatch(p), isTrue, reason: p);
      }
      for (final p in ['/a.sbn2', '/a.sbn2.0', '/a.sbn2.p', '/a.bak.pdf']) {
        expect(FileManager.transientFileRegex.hasMatch(p), isFalse, reason: p);
      }
    });

    test('transient files are not listed in the library', () async {
      const path = '/atomic_listing.sbn2';
      await FileManager.writeFile(path, utf8.encode('1'), awaitWrite: true);
      await FileManager.writeFile(path, utf8.encode('2'), awaitWrite: true);
      await f('$path.bad').writeAsString('junk');

      final children = await FileManager.getChildrenOfDirectory(
        '/',
        includeExtensions: true,
        includeAssets: true,
      );
      final names = children!.files.where(
        (n) => n.startsWith('atomic_listing'),
      );
      expect(names, ['atomic_listing.sbn2']);
    });

    test('deleting a note also deletes its backup', () async {
      const path = '/atomic_delete.sbn2';
      await FileManager.writeFile(path, utf8.encode('1'), awaitWrite: true);
      await FileManager.writeFile(path, utf8.encode('2'), awaitWrite: true);
      expect(f('$path.bak').existsSync(), isTrue);

      await FileManager.deleteFile(path);
      expect(f(path).existsSync(), isFalse);
      expect(f('$path.bak').existsSync(), isFalse);
    });

    test('moving a note also moves its backup', () async {
      const from = '/atomic_move_a.sbn2', to = '/atomic_move_b.sbn2';
      await FileManager.writeFile(from, utf8.encode('1'), awaitWrite: true);
      await FileManager.writeFile(from, utf8.encode('2'), awaitWrite: true);

      await FileManager.moveFile(from, to);
      expect(await read(to), '2');
      expect(await read('$to.bak'), '1');
      expect(f('$from.bak').existsSync(), isFalse);
    });
  });

  group('Crash recovery:', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupMockPathProvider();
    FlavorConfig.setup();

    late final String rootDir;
    setUpAll(() async {
      await FileManager.init();
      rootDir = FileManager.documentsDirectory;
    });

    File f(String path) => File('$rootDir$path');

    Future<void> saveTwice(String note) async {
      final first = EditorCoreInfo(filePath: note);
      first.backgroundPattern = .grid;
      await FileManager.writeFile(
        note + Editor.extension,
        first.saveToBinary(currentPageIndex: 0).$1,
        awaitWrite: true,
      );
      final second = EditorCoreInfo(filePath: note);
      second.backgroundPattern = .dots;
      await FileManager.writeFile(
        note + Editor.extension,
        second.saveToBinary(currentPageIndex: 0).$1,
        awaitWrite: true,
      );
    }

    test('a missing note opens from its backup', () async {
      const note = '/recover_missing';
      await saveTwice(note);
      await f('$note$Editor.extension').delete();

      final info = await EditorCoreInfo.loadFromFilePath(note);
      expect(info.readOnlyReason, isNull);
      expect(info.backgroundPattern, CanvasBackgroundPattern.grid);
    });

    test('a corrupted note opens from its backup and is repaired', () async {
      const note = '/recover_corrupt';
      await saveTwice(note);
      await f('$note$Editor.extension').writeAsBytes([1, 2, 3, 4, 5, 6, 7, 8]);

      final info = await EditorCoreInfo.loadFromFilePath(note);
      expect(info.readOnlyReason, isNull);
      expect(info.backgroundPattern, CanvasBackgroundPattern.grid);

      // The main file is healthy again and the broken one is kept aside.
      final again = await EditorCoreInfo.loadFromFilePath(note);
      expect(again.readOnlyReason, isNull);
      expect(again.backgroundPattern, CanvasBackgroundPattern.grid);
      expect(f('$note$Editor.extension.bad').existsSync(), isTrue);
    });

    test('a corrupted note without a backup stays read-only', () async {
      const note = '/recover_nobackup';
      await f('$note$Editor.extension').writeAsBytes([1, 2, 3, 4, 5, 6, 7, 8]);

      // Debug builds (tests) rethrow parse errors, release builds open the
      // note as read-only so it is never overwritten.
      if (kDebugMode) {
        await expectLater(
          EditorCoreInfo.loadFromFilePath(note),
          throwsA(anything),
        );
      } else {
        final info = await EditorCoreInfo.loadFromFilePath(note);
        expect(info.readOnlyReason, isNotNull);
      }
      expect(f('$note${Editor.extension}').existsSync(), isTrue);
    });
  });
}
