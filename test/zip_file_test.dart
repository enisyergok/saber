import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart' as archive;
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saber/data/backup/zip_file.dart';

void main() {
  late Directory temp;
  setUp(() => temp = Directory.systemTemp.createTempSync('zip_file_test'));
  tearDown(() => temp.deleteSync(recursive: true));

  File source(String name, List<int> bytes) =>
      File('${temp.path}/src/$name')
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync(bytes);

  /// Bytes that don't compress and are different at every length.
  Uint8List noise(int length, [int seed = 7]) {
    final bytes = Uint8List(length);
    var x = seed;
    for (var i = 0; i < length; i++) {
      x = (x * 1103515245 + 12345) & 0x7fffffff;
      bytes[i] = x >> 16;
    }
    return bytes;
  }

  String hashOf(List<int> bytes) => sha256.convert(bytes).toString();

  test('what is written can be read back, byte for byte', () {
    final text = utf8.encode('çizgi ' * 5000);
    final picture = noise(200000);
    final path = '${temp.path}/a.zip';

    final writer = ZipWriter(path, modified: DateTime(2026, 10, 6, 14, 5, 30));
    writer.addDirectory('notes/Boş klasör/');
    final addedText = writer.addFile(
      'notes/Okul/Fizik ödevi.sbn2',
      source('text', text),
      compress: true,
    );
    final reported = <int>[];
    final addedPicture = writer.addFile(
      'notes/Okul/Fizik ödevi.sbn2.0',
      source('picture', picture),
      onBytes: reported.add,
    );
    final addedJson = writer.addBytes('defter-backup.json', utf8.encode('{}'));
    writer.close();

    expect(addedText.size, text.length);
    expect(addedText.sha256, hashOf(text));
    expect(addedPicture.sha256, hashOf(picture));
    expect(addedJson.sha256, hashOf(utf8.encode('{}')));
    expect(reported.fold<int>(0, (a, b) => a + b), picture.length);
    expect(reported.length, greaterThan(1), reason: 'read a piece at a time');

    final reader = ZipReader.open(path);
    addTearDown(reader.close);
    expect(reader.entries.map((e) => e.name), [
      'notes/Boş klasör/',
      'notes/Okul/Fizik ödevi.sbn2',
      'notes/Okul/Fizik ödevi.sbn2.0',
      'defter-backup.json',
    ]);
    expect(reader.entries.first.isDirectory, isTrue);

    final textEntry = reader.find('notes/Okul/Fizik ödevi.sbn2')!;
    expect(textEntry.method, ZipEntry.methodDeflate);
    expect(textEntry.compressedSize, lessThan(text.length ~/ 10));
    expect(reader.readBytes(textEntry), text);

    final pictureEntry = reader.find('notes/Okul/Fizik ödevi.sbn2.0')!;
    expect(pictureEntry.method, ZipEntry.methodStore);
    final pieces = <int>[];
    expect(reader.read(pictureEntry, pieces.addAll), hashOf(picture));
    expect(pieces, picture);

    final out = File('${temp.path}/out/deep/picture');
    expect(reader.extract(pictureEntry, out), hashOf(picture));
    expect(out.readAsBytesSync(), picture);
    expect(reader.find('yok'), isNull);
  });

  test('bytes that do not get smaller are stored as they are', () {
    final path = '${temp.path}/b.zip';
    final writer = ZipWriter(path)
      ..addBytes('noise', noise(5000))
      ..addBytes('empty', const [])
      ..close();
    expect(writer.path, path);
    final reader = ZipReader.open(path);
    addTearDown(reader.close);
    expect(reader.find('noise')!.method, ZipEntry.methodStore);
    expect(reader.readBytes(reader.find('noise')!), noise(5000));
    expect(reader.readBytes(reader.find('empty')!), isEmpty);
  });

  test('another program\'s reader reads what is written', () {
    final text = utf8.encode('defter ' * 3000);
    final picture = noise(70000, 3);
    final path = '${temp.path}/c.zip';
    ZipWriter(path)
      ..addDirectory('klasör/')
      ..addFile('klasör/yazı.txt', source('t', text), compress: true)
      ..addFile('klasör/resim.bin', source('p', picture))
      ..close();

    final decoded = archive.ZipDecoder().decodeBytes(
      File(path).readAsBytesSync(),
      verify: true,
    );
    final byName = {for (final file in decoded.files) file.name: file};
    expect(byName.keys, containsAll(['klasör/yazı.txt', 'klasör/resim.bin']));
    expect(byName['klasör/yazı.txt']!.content, text);
    expect(byName['klasör/resim.bin']!.content, picture);
  });

  test('a zip made by another program is read', () {
    final text = utf8.encode('başka program ' * 2000);
    final picture = noise(40000, 9);
    final other = archive.Archive()
      ..addFile(archive.ArchiveFile.bytes('notes/a.sbn2', text))
      ..addFile(
        archive.ArchiveFile.bytes('notes/a.sbn2.0', picture)
          ..compression = archive.CompressionType.none,
      );
    final path = '${temp.path}/d.zip';
    File(path).writeAsBytesSync(archive.ZipEncoder().encode(other));

    final reader = ZipReader.open(path);
    addTearDown(reader.close);
    final a = reader.find('notes/a.sbn2')!;
    expect(a.method, ZipEntry.methodDeflate);
    expect(reader.readBytes(a), text);
    expect(reader.read(a), hashOf(text));
    expect(reader.readBytes(reader.find('notes/a.sbn2.0')!), picture);
  });

  test('more files than the plain form can count', () {
    final path = '${temp.path}/many.zip';
    final writer = ZipWriter(path);
    const count = 66000;
    for (var i = 0; i < count; i++) {
      writer.addBytes('n/$i', [i & 0xff, i >> 8 & 0xff], compress: false);
    }
    writer.close();

    final reader = ZipReader.open(path);
    addTearDown(reader.close);
    expect(reader.entries.length, count);
    expect(reader.readBytes(reader.find('n/65999')!), [
      65999 & 0xff,
      (65999 >> 8) & 0xff,
    ]);
    expect(reader.readBytes(reader.find('n/0')!), [0, 0]);

    // kept for a look with other tools
    final samples = Directory('test/defter_shots/samples')
      ..createSync(recursive: true);
    File(path).copySync('${samples.path}/zip_many_entries.zip');
  });

  test('a changed byte is noticed', () {
    final picture = noise(50000);
    final path = '${temp.path}/e.zip';
    ZipWriter(path)
      ..addFile('picture', source('p', picture))
      ..addFile('text', source('t', utf8.encode('aaaa' * 4000)), compress: true)
      ..close();

    final bytes = File(path).readAsBytesSync();
    // in the middle of the stored picture
    bytes[30 + 'picture'.length + 20000] ^= 0x01;
    File(path).writeAsBytesSync(bytes);

    final reader = ZipReader.open(path);
    addTearDown(reader.close);
    expect(
      () => reader.read(reader.find('picture')!),
      throwsA(isA<ZipFormatException>()),
    );
    final out = File('${temp.path}/damaged');
    expect(
      () => reader.extract(reader.find('picture')!, out),
      throwsA(isA<ZipFormatException>()),
    );
    expect(out.existsSync(), isFalse, reason: 'nothing damaged is left behind');
    // the other file is still fine
    expect(reader.readBytes(reader.find('text')!).length, 16000);
  });

  test('damage in compressed content is noticed', () {
    final path = '${temp.path}/f.zip';
    final text = utf8.encode('sıkıştırılmış metin ' * 3000);
    ZipWriter(path)
      ..addBytes('text', text)
      ..close();
    final reader0 = ZipReader.open(path);
    final entry = reader0.find('text')!;
    reader0.close();

    final bytes = File(path).readAsBytesSync();
    for (var i = 0; i < 8; i++) {
      bytes[30 + 4 + entry.compressedSize ~/ 2 + i] ^= 0xff;
    }
    File(path).writeAsBytesSync(bytes);
    final reader = ZipReader.open(path);
    addTearDown(reader.close);
    expect(
      () => reader.read(reader.find('text')!),
      throwsA(isA<ZipFormatException>()),
    );
  });

  test('a file that is cut short or is not a zip is refused', () {
    final path = '${temp.path}/g.zip';
    ZipWriter(path)
      ..addBytes('a', noise(3000))
      ..close();
    final bytes = File(path).readAsBytesSync();

    final cut = File('${temp.path}/cut.zip')
      ..writeAsBytesSync(bytes.sublist(0, bytes.length - 30));
    expect(() => ZipReader.open(cut.path), throwsA(isA<ZipFormatException>()));

    final other = File('${temp.path}/other.zip')
      ..writeAsBytesSync(utf8.encode('this is not a zip file at all, really'));
    expect(
      () => ZipReader.open(other.path),
      throwsA(isA<ZipFormatException>()),
    );

    final empty = File('${temp.path}/empty.zip')..writeAsBytesSync(const []);
    expect(
      () => ZipReader.open(empty.path),
      throwsA(isA<ZipFormatException>()),
    );
  });

  test('names that would leave the zip are refused when writing', () {
    final writer = ZipWriter('${temp.path}/h.zip');
    expect(
      () => writer.addBytes('/absolute', const [1]),
      throwsA(isA<ZipFormatException>()),
    );
    expect(
      () => writer.addBytes(r'back\slash', const [1]),
      throwsA(isA<ZipFormatException>()),
    );
    writer.abort();
    expect(File('${temp.path}/h.zip').existsSync(), isFalse);
  });

  test('an empty zip is a zip', () {
    final path = '${temp.path}/i.zip';
    ZipWriter(path).close();
    final reader = ZipReader.open(path);
    addTearDown(reader.close);
    expect(reader.entries, isEmpty);
  });
}
