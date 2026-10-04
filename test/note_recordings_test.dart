import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:saber/data/audio/note_recordings.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/flavor_config.dart';

import 'utils/test_mock_channel_handlers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupMockPathProvider();
  FlavorConfig.setup();

  late Directory temp;
  setUpAll(() async {
    await FileManager.init();
    temp = Directory.systemTemp.createTempSync('recordings_test');
    NoteRecordings.rootOverride = temp;
  });
  tearDownAll(() {
    NoteRecordings.rootOverride = null;
    temp.deleteSync(recursive: true);
  });

  Future<void> record(String note, DateTime at, [String content = 'x']) async {
    final file = await NoteRecordings.newRecordingFile(note, now: at);
    await file.writeAsString(content);
  }

  test('recordings are listed newest first with their start time', () async {
    await record('/a/Ders', DateTime(2026, 10, 4, 9, 30, 5));
    await record('/a/Ders', DateTime(2026, 10, 4, 14, 0, 0));
    final list = await NoteRecordings.list('/a/Ders.sbn2');
    expect(list.length, 2);
    expect(list.first.startedAt, DateTime(2026, 10, 4, 14));
    expect(list.last.startedAt, DateTime(2026, 10, 4, 9, 30, 5));
  });

  test('another note has its own recordings', () async {
    expect(await NoteRecordings.list('/baska'), isEmpty);
    expect(await NoteRecordings.hasAny('/a/Ders'), isTrue);
  });

  test('recordings follow a renamed note', () async {
    await record('/eski', DateTime(2026, 1, 1, 1, 1, 1), 'abc');
    await NoteRecordings.move('/eski.sbn2', '/yeni/ad.sbn2');
    expect(await NoteRecordings.list('/eski'), isEmpty);
    final moved = await NoteRecordings.list('/yeni/ad');
    expect(moved.single.size, 3);
  });

  test('moving onto a note that has recordings keeps both', () async {
    await record('/m1', DateTime(2026, 2, 2, 2, 2, 2), '1');
    await record('/m2', DateTime(2026, 2, 2, 2, 2, 2), '22');
    await NoteRecordings.move('/m1', '/m2');
    expect((await NoteRecordings.list('/m2')).length, 2);
    expect(await NoteRecordings.list('/m1'), isEmpty);
  });

  test('deleting a note deletes its recordings', () async {
    await record('/sil', DateTime(2026, 3, 3, 3, 3, 3));
    await NoteRecordings.deleteAll('/sil.sbn2');
    expect(await NoteRecordings.list('/sil'), isEmpty);
  });

  test('one recording can be deleted', () async {
    await record('/tek', DateTime(2026, 4, 4, 4, 4, 4));
    await record('/tek', DateTime(2026, 4, 4, 4, 4, 5));
    final first = (await NoteRecordings.list('/tek')).first;
    await NoteRecordings.delete(first);
    expect((await NoteRecordings.list('/tek')).length, 1);
  });
}
