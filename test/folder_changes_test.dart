import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saber/components/navbar/home_sidebar.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/flavor_config.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/pages/home/dashboard.dart';
import 'package:saber/pages/home/home.dart';

import 'utils/test_mock_channel_handlers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupMockPathProvider();
  FlavorConfig.setup();
  stows.sentryConsent.value = .granted;

  group('FileManager.folderChanges:', () {
    late Directory temp;
    late List<String> changes;
    late StreamSubscription<String> subscription;

    setUp(() async {
      temp = Directory.systemTemp.createTempSync('folder_changes_test');
      await FileManager.init(
        documentsDirectory: temp.path,
        shouldWatchRootDirectory: false,
      );
      changes = [];
      subscription = FileManager.folderChanges.stream.listen(changes.add);
    });
    tearDown(() async {
      await subscription.cancel();
      temp.deleteSync(recursive: true);
    });

    Future<void> settle() => Future<void>.delayed(Duration.zero);

    test('a folder that is made is told of', () async {
      await FileManager.createFolder('/Dersler');
      await settle();
      expect(changes, ['/Dersler']);
      expect(Directory('${temp.path}/Dersler').existsSync(), isTrue);
    });

    test('an empty folder that is removed is told of, once it is gone', () async {
      await FileManager.createFolder('/Boş');
      await settle();
      changes.clear();

      // Whoever hears of it and lists the folders must not find it.
      final seenWhenTold = <bool>[];
      final listener = FileManager.folderChanges.stream.listen(
        (_) => seenWhenTold.add(Directory('${temp.path}/Boş').existsSync()),
      );
      addTearDown(listener.cancel);

      await FileManager.deleteDirectory('/Boş');
      await settle();
      expect(changes, ['/Boş']);
      expect(seenWhenTold, [false]);
    });

    test('a folder with notes that goes to the trash is told of after its '
        'notes', () async {
      await FileManager.createFolder('/Projeler');
      await FileManager.writeFile(
        '/Projeler/Not.sbn2',
        [1, 2, 3],
        awaitWrite: true,
      );
      await settle();
      changes.clear();

      final order = <String>[];
      final files = FileManager.fileWriteStream.stream.listen(
        (event) => order.add('file ${event.filePath}'),
      );
      final folders = FileManager.folderChanges.stream.listen(
        (path) => order.add(
          'folder $path, there: '
          '${Directory('${temp.path}/Projeler').existsSync()}',
        ),
      );
      addTearDown(files.cancel);
      addTearDown(folders.cancel);

      await FileManager.moveDirectoryToTrash('/Projeler');
      await settle();

      expect(Directory('${temp.path}/Projeler').existsSync(), isFalse);
      expect(order.last, 'folder /Projeler, there: false');
      expect(order.where((entry) => entry.startsWith('file ')), isNotEmpty);
    });

    test('a folder that is renamed is told of by its new name', () async {
      await FileManager.createFolder('/Eski');
      await settle();
      changes.clear();

      await FileManager.renameDirectory('/Eski', 'Yeni');
      await settle();
      expect(changes, ['/Yeni']);
      expect(Directory('${temp.path}/Yeni').existsSync(), isTrue);
      expect(Directory('${temp.path}/Eski').existsSync(), isFalse);
    });
  });

  group('The folders on the home screen:', () {
    void tablet(WidgetTester tester) {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    testWidgets('the sidebar drops a folder as soon as it is removed, even '
        'under the dialog that removed it', (tester) async {
      tablet(tester);
      final folders = <String, List<String>>{
        'Dersler': [],
        'Projeler': [],
      };
      var loads = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                HomeSidebar(
                  subpage: HomePage.dashboardSubpage,
                  path: null,
                  go: (_) {},
                  loadFolders: () async {
                    loads++;
                    return Map.of(folders);
                  },
                ),
                const Expanded(child: SizedBox()),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Projeler'), findsOneWidget);
      final loadsBefore = loads;

      // A dialog is open over the home screen (the one asking whether
      // to delete), so the home screen is not the page in front.
      showDialog<void>(
        context: tester.element(find.byType(HomeSidebar)),
        builder: (_) => const AlertDialog(title: Text('delete?')),
      );
      await tester.pump();
      expect(find.text('delete?'), findsOneWidget);

      // A note being saved does not make the sidebar list again now...
      FileManager.fileWriteStream.add(
        FileOperation(FileOperationType.write, '/Dersler/Not'),
      );
      await tester.pump();
      expect(loads, loadsBefore);

      // ... but a folder that is removed does.
      folders.remove('Projeler');
      FileManager.folderChanges.add('/Projeler');
      await tester.pump();
      await tester.pump();
      expect(loads, loadsBefore + 1);
      expect(find.text('Projeler'), findsNothing);
      expect(find.text('Dersler'), findsOneWidget);
    });

    testWidgets('the home screen drops its card as well', (tester) async {
      tablet(tester);
      var data = const DashboardData(folders: {'Dersler': 3, 'Projeler': 0});
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: DashboardPage(load: () async => data)),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Projeler'), findsOneWidget);

      showDialog<void>(
        context: tester.element(find.byType(DashboardPage)),
        builder: (_) => const AlertDialog(title: Text('delete?')),
      );
      await tester.pump();

      data = const DashboardData(folders: {'Dersler': 3});
      FileManager.folderChanges.add('/Projeler');
      await tester.pump();
      await tester.pump();
      expect(find.text('Projeler'), findsNothing);
      expect(find.text('Dersler'), findsOneWidget);
    });

    testWidgets('a listing that comes back late does not undo a newer one', (
      tester,
    ) async {
      tablet(tester);
      final first = Completer<Map<String, List<String>>>();
      final second = Completer<Map<String, List<String>>>();
      final answers = [first, second];
      var asked = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                HomeSidebar(
                  subpage: HomePage.dashboardSubpage,
                  path: null,
                  go: (_) {},
                  loadFolders: () => answers[asked++].future,
                ),
                const Expanded(child: SizedBox()),
              ],
            ),
          ),
        ),
      );
      // The first listing is still on its way when the folder is removed.
      FileManager.folderChanges.add('/Projeler');
      await tester.pump();
      expect(asked, 2);

      second.complete({'Dersler': []});
      await tester.pump();
      first.complete({'Dersler': [], 'Projeler': []});
      await tester.pump();
      await tester.pump();

      expect(find.text('Dersler'), findsOneWidget);
      expect(find.text('Projeler'), findsNothing);
    });
  });
}
