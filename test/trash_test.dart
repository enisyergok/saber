import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saber/data/defter_strings.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/flavor_config.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/pages/trash.dart';

import 'utils/test_mock_channel_handlers.dart';

void main() {
  group('Trash:', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupMockPathProvider();
    FlavorConfig.setup();

    late final String rootDir;
    setUpAll(() async {
      await FileManager.init(shouldWatchRootDirectory: false);
      rootDir = FileManager.documentsDirectory;
    });
    setUp(() async {
      await FileManager.emptyTrash();
      stows.favoriteFiles.value.clear();
      stows.recentFiles.value.clear();
    });

    Future<void> write(String path, String content) =>
        FileManager.writeFile(path, utf8.encode(content), awaitWrite: true);
    File f(String path) => File('$rootDir$path');

    test('a trashed note leaves the library and keeps its parts', () async {
      await write('/trash_a.sbn2', 'v1');
      await write('/trash_a.sbn2', 'v2'); // creates the .bak
      await write('/trash_a.sbn2.0', 'asset');

      final trashed = await FileManager.moveToTrash('/trash_a.sbn2');
      expect(trashed, '/.Trash/trash_a.sbn2');

      expect(f('/trash_a.sbn2').existsSync(), isFalse);
      expect(f('/trash_a.sbn2.0').existsSync(), isFalse);
      expect(await f('/.Trash/trash_a.sbn2').readAsString(), 'v2');
      expect(await f('/.Trash/trash_a.sbn2.bak').readAsString(), 'v1');
      expect(await f('/.Trash/trash_a.sbn2.0').readAsString(), 'asset');
      expect(await FileManager.listTrash(), ['/.Trash/trash_a.sbn2']);
    });

    test('the trash folder is hidden from the library', () async {
      await write('/trash_hidden.sbn2', 'x');
      await FileManager.moveToTrash('/trash_hidden.sbn2');

      final children = await FileManager.getChildrenOfDirectory('/');
      expect(children!.directories, isNot(contains('.Trash')));
      final all = await FileManager.getAllFiles();
      expect(all.where((p) => p.contains('trash_hidden')), isEmpty);
    });

    test('a trashed note is no longer recent or a favourite', () async {
      await write('/trash_refs.sbn2', 'x'); // becomes recent
      stows.favoriteFiles.value.add('/trash_refs.sbn2');
      expect(stows.recentFiles.value, contains('/trash_refs.sbn2'));

      await FileManager.moveToTrash('/trash_refs.sbn2');

      expect(
        stows.recentFiles.value.where((p) => p.contains('trash_refs')),
        isEmpty,
      );
      expect(stows.favoriteFiles.value, isEmpty);
    });

    test('restoring puts the note back with everything', () async {
      await write('/trash_b.sbn2', 'v1');
      await write('/trash_b.sbn2.0', 'asset');
      await FileManager.moveToTrash('/trash_b.sbn2');

      final restored = await FileManager.restoreFromTrash(
        '/.Trash/trash_b.sbn2',
      );
      expect(restored, '/trash_b.sbn2');
      expect(await f('/trash_b.sbn2').readAsString(), 'v1');
      expect(await f('/trash_b.sbn2.0').readAsString(), 'asset');
      expect(await FileManager.listTrash(), isEmpty);
    });

    test('restoring never overwrites a note with the same name', () async {
      await write('/trash_c.sbn2', 'old');
      await FileManager.moveToTrash('/trash_c.sbn2');
      await write('/trash_c.sbn2', 'new'); // a different note, same name

      final restored = await FileManager.restoreFromTrash(
        '/.Trash/trash_c.sbn2',
      );
      expect(restored, isNot('/trash_c.sbn2'));
      expect(await f('/trash_c.sbn2').readAsString(), 'new');
      expect(await f(restored).readAsString(), 'old');
    });

    test('trashing two notes with one name keeps both', () async {
      await write('/trash_d.sbn2', 'first');
      await FileManager.moveToTrash('/trash_d.sbn2');
      await write('/trash_d.sbn2', 'second');
      await FileManager.moveToTrash('/trash_d.sbn2');

      expect(await FileManager.listTrash(), hasLength(2));
    });

    test('a folder goes to the trash note by note', () async {
      await write('/Trash Folder/one.sbn2', '1');
      await write('/Trash Folder/Inner/two.sbn2', '2');
      await write('/Trash Folder/Inner/two.sbn2.0', 'asset');

      await FileManager.moveDirectoryToTrash('/Trash Folder');

      expect(Directory('$rootDir/Trash Folder').existsSync(), isFalse);
      expect(await FileManager.listTrash(), [
        '/.Trash/Trash Folder/Inner/two.sbn2',
        '/.Trash/Trash Folder/one.sbn2',
      ]);
      expect(f('/.Trash/Trash Folder/Inner/two.sbn2.0').existsSync(), isTrue);
    });

    test('emptying the trash deletes for good', () async {
      await write('/trash_e.sbn2', 'x');
      await FileManager.moveToTrash('/trash_e.sbn2');
      await FileManager.emptyTrash();
      expect(await FileManager.listTrash(), isEmpty);
      expect(f('/.Trash/trash_e.sbn2').existsSync(), isFalse);
    });

    test('a note already in the trash is left alone', () async {
      await write('/trash_f.sbn2', 'x');
      final trashed = await FileManager.moveToTrash('/trash_f.sbn2');
      expect(await FileManager.moveToTrash(trashed!), isNull);
      expect(await FileManager.listTrash(), [trashed]);
    });

    test('favourites follow a renamed note', () async {
      await write('/fav_a.sbn2', 'x');
      stows.favoriteFiles.value.add('/fav_a.sbn2');
      await FileManager.moveFile('/fav_a.sbn2', '/fav_b.sbn2');
      expect(stows.favoriteFiles.value, ['/fav_b.sbn2']);
    });
  });

  group('TrashPage:', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupMockPathProvider();
    FlavorConfig.setup();

    setUpAll(() async {
      await FileManager.init(shouldWatchRootDirectory: false);
    });

    test('displayName hides the trash folder and extension', () {
      expect(TrashPage.displayName('/.Trash/Projects/Plan.sbn2'), 'Projects/Plan');
      expect(TrashPage.displayName('/.Trash/Old.sbn'), 'Old');
    });

    testWidgets('lists trashed notes and restores one', (tester) async {
      await tester.runAsync(() async {
        await FileManager.emptyTrash();
        await FileManager.writeFile(
          '/page_note.sbn2',
          utf8.encode('x'),
          awaitWrite: true,
        );
        await FileManager.moveToTrash('/page_note.sbn2');
      });

      await tester.runAsync(() async {
        await tester.pumpWidget(const MaterialApp(home: TrashPage()));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();
      expect(find.text('page_note'), findsOneWidget);

      await tester.runAsync(() async {
        await tester.tap(find.byTooltip(DefterStrings.restore));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();
      expect(find.text('page_note'), findsNothing);
      expect(find.text(DefterStrings.trashEmpty), findsOneWidget);
      expect(
        File('${FileManager.documentsDirectory}/page_note.sbn2').existsSync(),
        isTrue,
      );
    });
  });
}
