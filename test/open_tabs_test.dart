import 'package:flutter_test/flutter_test.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/open_tabs.dart';

void main() {
  group('OpenTabs', () {
    setUp(OpenTabs.reset);

    test('open appends new paths and ignores duplicates', () {
      OpenTabs.open('/a');
      OpenTabs.open('/b');
      OpenTabs.open('/a');
      expect(OpenTabs.paths.value, ['/a', '/b']);
    });

    test('open drops the oldest tab past the limit', () {
      for (var i = 0; i < OpenTabs.maxTabs + 2; i++) {
        OpenTabs.open('/note$i');
      }
      expect(OpenTabs.paths.value, hasLength(OpenTabs.maxTabs));
      expect(OpenTabs.paths.value.first, '/note2');
      expect(OpenTabs.paths.value.last, '/note${OpenTabs.maxTabs + 1}');
    });

    test('close removes only the given path', () {
      OpenTabs.open('/a');
      OpenTabs.open('/b');
      OpenTabs.open('/c');
      OpenTabs.close('/b');
      expect(OpenTabs.paths.value, ['/a', '/c']);

      OpenTabs.close('/missing');
      expect(OpenTabs.paths.value, ['/a', '/c']);
    });

    test('rename keeps the tab position', () {
      OpenTabs.open('/a');
      OpenTabs.open('/b');
      OpenTabs.open('/c');
      OpenTabs.rename('/b', '/renamed');
      expect(OpenTabs.paths.value, ['/a', '/renamed', '/c']);
    });

    test('rename restores the position if the old tab is already gone', () {
      // Renaming a file broadcasts a delete for the old path,
      // which can close the tab before rename() is called.
      OpenTabs.open('/a');
      OpenTabs.open('/b');
      OpenTabs.open('/c');
      OpenTabs.close('/b');
      OpenTabs.rename('/b', '/renamed', index: 1);
      expect(OpenTabs.paths.value, ['/a', '/renamed', '/c']);
    });

    test('rename does not duplicate an existing tab', () {
      OpenTabs.open('/a');
      OpenTabs.open('/b');
      OpenTabs.rename('/a', '/b');
      expect(OpenTabs.paths.value, ['/b']);
    });

    test('notifies listeners only when the list changes', () {
      var notifications = 0;
      void listener() => notifications++;
      OpenTabs.paths.addListener(listener);
      addTearDown(() => OpenTabs.paths.removeListener(listener));

      OpenTabs.open('/a');
      OpenTabs.open('/a');
      OpenTabs.close('/missing');
      expect(notifications, 1);
    });

    test('a deleted note is closed', () async {
      OpenTabs.open('/a');
      OpenTabs.open('/b');

      FileManager.broadcastFileWrite(FileOperationType.delete, '/a.sbn2');
      await Future<void>.delayed(Duration.zero);
      expect(OpenTabs.paths.value, ['/b']);

      // Writes and unrelated files leave the tabs alone.
      FileManager.broadcastFileWrite(FileOperationType.write, '/b.sbn2');
      FileManager.broadcastFileWrite(FileOperationType.delete, '/b.sbn2.p');
      await Future<void>.delayed(Duration.zero);
      expect(OpenTabs.paths.value, ['/b']);
    });
  });
}
