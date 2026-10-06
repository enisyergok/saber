import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart' show getCrc32;
import 'package:crypto/crypto.dart';

/// A zip file that can't be read (or written) as asked.
class ZipFormatException implements Exception {
  const ZipFormatException(this.message);
  final String message;

  @override
  String toString() => 'ZipFormatException: $message';
}

/// The file being added to a zip changed while it was read.
class ZipSourceChangedException implements Exception {
  const ZipSourceChangedException(this.path);
  final String path;

  @override
  String toString() => 'ZipSourceChangedException: $path';
}

/// One file (or folder) in a zip file.
class ZipEntry {
  const ZipEntry({
    required this.name,
    required this.method,
    required this.crc,
    required this.compressedSize,
    required this.size,
    required this.headerOffset,
  });

  /// The path inside the zip, with forward slashes. Folders end in one.
  final String name;

  /// How the content is held: [methodStore] or [methodDeflate].
  final int method;
  final int crc;
  final int compressedSize;
  final int size;

  /// Where the entry starts in the zip file.
  final int headerOffset;

  static const methodStore = 0;
  static const methodDeflate = 8;

  bool get isDirectory => name.endsWith('/');
}

/// What [ZipWriter] found out about a file as it added it.
class ZipAdded {
  const ZipAdded({required this.size, required this.sha256});
  final int size;
  final String sha256;
}

class _DigestSink implements Sink<Digest> {
  Digest? value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}

class _BytesSink implements Sink<List<int>> {
  _BytesSink(this.onData);
  final void Function(List<int> data) onData;

  @override
  void add(List<int> data) => onData(data);

  @override
  void close() {}
}

const _localSignature = 0x04034b50;
const _centralSignature = 0x02014b50;
const _endSignature = 0x06054b50;
const _end64Signature = 0x06064b50;
const _end64LocatorSignature = 0x07064b50;
const _max32 = 0xFFFFFFFF;
const _max16 = 0xFFFF;

/// File names are written as UTF-8.
const _flagUtf8 = 0x0800;
const _flagEncrypted = 0x0001;
const _zip64ExtraId = 0x0001;

/// Writes a zip file straight to disk, a file at a time, without ever
/// holding a large file in memory. Files of any size and any number of
/// them are fine (the zip64 form is used where the plain one runs out).
///
/// Everything is blocking: this is meant to be used away from the screen.
class ZipWriter {
  ZipWriter(this.path, {DateTime? modified})
    : _out = (File(path)..parent.createSync(recursive: true)).openSync(
        mode: FileMode.write,
      ),
      _modified = modified ?? DateTime.now();

  final String path;
  final RandomAccessFile _out;
  final DateTime _modified;
  final _entries = <ZipEntry>[];
  var _position = 0;
  var _closed = false;

  /// Files up to this size are compressed when asked; larger ones are
  /// stored as they are, since compressing is done in memory.
  static const maxCompressSize = 64 * 1024 * 1024;

  int get _dosTime =>
      (_modified.hour << 11) | (_modified.minute << 5) | (_modified.second ~/ 2);

  int get _dosDate {
    // Years before 1980 or after 2107 don't fit: the nearest one is written.
    var year = _modified.year - 1980;
    if (year < 0) year = 0;
    if (year > 127) year = 127;
    return (year << 9) | (_modified.month << 5) | _modified.day;
  }

  void _write(List<int> bytes) {
    _out.writeFromSync(bytes);
    _position += bytes.length;
  }

  static void _checkName(String name) {
    if (name.isEmpty || name.startsWith('/') || name.contains('\\')) {
      throw ZipFormatException('Bad entry name: $name');
    }
  }

  void _writeLocalHeader({
    required List<int> name,
    required int method,
    required int crc,
    required int compressedSize,
    required int size,
  }) {
    final zip64 = size >= _max32 || compressedSize >= _max32;
    final header = ByteData(30)
      ..setUint32(0, _localSignature, Endian.little)
      ..setUint16(4, zip64 ? 45 : 20, Endian.little)
      ..setUint16(6, _flagUtf8, Endian.little)
      ..setUint16(8, method, Endian.little)
      ..setUint16(10, _dosTime, Endian.little)
      ..setUint16(12, _dosDate, Endian.little)
      ..setUint32(14, crc, Endian.little)
      ..setUint32(18, zip64 ? _max32 : compressedSize, Endian.little)
      ..setUint32(22, zip64 ? _max32 : size, Endian.little)
      ..setUint16(26, name.length, Endian.little)
      ..setUint16(28, zip64 ? 20 : 0, Endian.little);
    _write(header.buffer.asUint8List());
    _write(name);
    if (zip64) {
      final extra = ByteData(20)
        ..setUint16(0, _zip64ExtraId, Endian.little)
        ..setUint16(2, 16, Endian.little)
        ..setUint64(4, size, Endian.little)
        ..setUint64(12, compressedSize, Endian.little);
      _write(extra.buffer.asUint8List());
    }
  }

  /// Adds an empty folder. [name] must end with a slash.
  void addDirectory(String name) {
    _checkName(name);
    if (!name.endsWith('/')) name = '$name/';
    final offset = _position;
    _writeLocalHeader(
      name: utf8.encode(name),
      method: ZipEntry.methodStore,
      crc: 0,
      compressedSize: 0,
      size: 0,
    );
    _entries.add(
      ZipEntry(
        name: name,
        method: ZipEntry.methodStore,
        crc: 0,
        compressedSize: 0,
        size: 0,
        headerOffset: offset,
      ),
    );
  }

  /// Adds [bytes] as the file [name].
  ZipAdded addBytes(String name, List<int> bytes, {bool compress = true}) {
    _checkName(name);
    final data = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    var method = ZipEntry.methodStore;
    List<int> stored = data;
    if (compress && data.isNotEmpty) {
      final deflated = ZLibEncoder(raw: true).convert(data);
      if (deflated.length < data.length) {
        method = ZipEntry.methodDeflate;
        stored = deflated;
      }
    }
    final crc = getCrc32(data);
    final offset = _position;
    _writeLocalHeader(
      name: utf8.encode(name),
      method: method,
      crc: crc,
      compressedSize: stored.length,
      size: data.length,
    );
    _write(stored);
    _entries.add(
      ZipEntry(
        name: name,
        method: method,
        crc: crc,
        compressedSize: stored.length,
        size: data.length,
        headerOffset: offset,
      ),
    );
    return ZipAdded(size: data.length, sha256: sha256.convert(data).toString());
  }

  /// Adds the file [source] as [name], reading it once, a piece at a time.
  /// [onBytes] is told how many bytes were read after each piece.
  ///
  /// Throws a [ZipSourceChangedException] (and leaves the zip as it was
  /// before the call) if the file grew or shrank while it was read.
  ZipAdded addFile(
    String name,
    File source, {
    bool compress = false,
    void Function(int bytes)? onBytes,
  }) {
    _checkName(name);
    final expected = source.lengthSync();
    if (compress && expected <= maxCompressSize) {
      final bytes = source.readAsBytesSync();
      final added = addBytes(name, bytes);
      onBytes?.call(bytes.length);
      return added;
    }

    final offset = _position;
    _writeLocalHeader(
      name: utf8.encode(name),
      method: ZipEntry.methodStore,
      crc: 0, // filled in below, once the file has been read
      compressedSize: expected,
      size: expected,
    );

    final digest = _DigestSink();
    final hasher = sha256.startChunkedConversion(digest);
    var crc = 0;
    var total = 0;
    final input = source.openSync();
    try {
      final buffer = Uint8List(1 << 16);
      while (total <= expected) {
        final read = input.readIntoSync(buffer);
        if (read <= 0) break;
        final piece = Uint8List.sublistView(buffer, 0, read);
        _out.writeFromSync(piece);
        crc = getCrc32(piece, crc);
        hasher.add(piece);
        total += read;
        onBytes?.call(read);
      }
    } finally {
      input.closeSync();
    }
    hasher.close();

    if (total != expected) {
      // Take back what was written of this file.
      _out.truncateSync(offset);
      _out.setPositionSync(offset);
      _position = offset;
      throw ZipSourceChangedException(source.path);
    }
    _position += total;

    final crcBytes = ByteData(4)..setUint32(0, crc, Endian.little);
    _out.setPositionSync(offset + 14);
    _out.writeFromSync(crcBytes.buffer.asUint8List());
    _out.setPositionSync(_position);

    _entries.add(
      ZipEntry(
        name: name,
        method: ZipEntry.methodStore,
        crc: crc,
        compressedSize: expected,
        size: expected,
        headerOffset: offset,
      ),
    );
    return ZipAdded(size: expected, sha256: digest.value!.toString());
  }

  /// Writes the list of contents and closes the file. Until this has been
  /// called, the zip can't be read.
  void close() {
    if (_closed) return;
    _closed = true;

    final directoryOffset = _position;
    for (final entry in _entries) {
      final name = utf8.encode(entry.name);
      final bigSize = entry.size >= _max32 || entry.compressedSize >= _max32;
      final bigOffset = entry.headerOffset >= _max32;
      final extra = BytesBuilder();
      if (bigSize || bigOffset) {
        final length = (bigSize ? 16 : 0) + (bigOffset ? 8 : 0);
        final field = ByteData(4 + length)
          ..setUint16(0, _zip64ExtraId, Endian.little)
          ..setUint16(2, length, Endian.little);
        var at = 4;
        if (bigSize) {
          field
            ..setUint64(at, entry.size, Endian.little)
            ..setUint64(at + 8, entry.compressedSize, Endian.little);
          at += 16;
        }
        if (bigOffset) field.setUint64(at, entry.headerOffset, Endian.little);
        extra.add(field.buffer.asUint8List());
      }
      final header = ByteData(46)
        ..setUint32(0, _centralSignature, Endian.little)
        ..setUint16(4, 45, Endian.little) // made by
        ..setUint16(6, bigSize || bigOffset ? 45 : 20, Endian.little)
        ..setUint16(8, _flagUtf8, Endian.little)
        ..setUint16(10, entry.method, Endian.little)
        ..setUint16(12, _dosTime, Endian.little)
        ..setUint16(14, _dosDate, Endian.little)
        ..setUint32(16, entry.crc, Endian.little)
        ..setUint32(20, bigSize ? _max32 : entry.compressedSize, Endian.little)
        ..setUint32(24, bigSize ? _max32 : entry.size, Endian.little)
        ..setUint16(28, name.length, Endian.little)
        ..setUint16(30, extra.length, Endian.little)
        ..setUint16(32, 0, Endian.little) // comment
        ..setUint16(34, 0, Endian.little) // disk
        ..setUint16(36, 0, Endian.little) // internal attributes
        ..setUint32(38, entry.isDirectory ? 0x10 : 0, Endian.little)
        ..setUint32(42, bigOffset ? _max32 : entry.headerOffset, Endian.little);
      _write(header.buffer.asUint8List());
      _write(name);
      _write(extra.takeBytes());
    }
    final directorySize = _position - directoryOffset;
    final count = _entries.length;

    if (count >= _max16 || directorySize >= _max32 || directoryOffset >= _max32) {
      final end64Offset = _position;
      final end64 = ByteData(56)
        ..setUint32(0, _end64Signature, Endian.little)
        ..setUint64(4, 44, Endian.little) // size of the rest of this record
        ..setUint16(12, 45, Endian.little)
        ..setUint16(14, 45, Endian.little)
        ..setUint32(16, 0, Endian.little)
        ..setUint32(20, 0, Endian.little)
        ..setUint64(24, count, Endian.little)
        ..setUint64(32, count, Endian.little)
        ..setUint64(40, directorySize, Endian.little)
        ..setUint64(48, directoryOffset, Endian.little);
      _write(end64.buffer.asUint8List());
      final locator = ByteData(20)
        ..setUint32(0, _end64LocatorSignature, Endian.little)
        ..setUint32(4, 0, Endian.little)
        ..setUint64(8, end64Offset, Endian.little)
        ..setUint32(16, 1, Endian.little);
      _write(locator.buffer.asUint8List());
    }

    final end = ByteData(22)
      ..setUint32(0, _endSignature, Endian.little)
      ..setUint16(4, 0, Endian.little)
      ..setUint16(6, 0, Endian.little)
      ..setUint16(8, count >= _max16 ? _max16 : count, Endian.little)
      ..setUint16(10, count >= _max16 ? _max16 : count, Endian.little)
      ..setUint32(
        12,
        directorySize >= _max32 ? _max32 : directorySize,
        Endian.little,
      )
      ..setUint32(
        16,
        directoryOffset >= _max32 ? _max32 : directoryOffset,
        Endian.little,
      )
      ..setUint16(20, 0, Endian.little);
    _write(end.buffer.asUint8List());
    _out.flushSync();
    _out.closeSync();
  }

  /// Gives up: closes the file and deletes it.
  void abort() {
    if (!_closed) {
      _closed = true;
      _out.closeSync();
    }
    final file = File(path);
    if (file.existsSync()) file.deleteSync();
  }
}

/// Reads a zip file from disk, an entry at a time, without holding large
/// entries in memory. Reads what [ZipWriter] writes and the ordinary zip
/// files other programs make (stored or deflated, zip64 or not); encrypted
/// and otherwise compressed entries are refused.
class ZipReader {
  ZipReader._(this.path, this._file, this.entries);

  final String path;
  final RandomAccessFile _file;

  /// In the order of the zip's list of contents.
  final List<ZipEntry> entries;

  late final _byName = {for (final entry in entries) entry.name: entry};

  ZipEntry? find(String name) => _byName[name];

  /// Opens the zip at [path]. Throws a [ZipFormatException] if it isn't
  /// one, or is cut short.
  factory ZipReader.open(String path) {
    final file = File(path).openSync();
    try {
      return ZipReader._(path, file, _readDirectory(file));
    } on Object {
      file.closeSync();
      rethrow;
    }
  }

  static Uint8List _readAt(RandomAccessFile file, int offset, int length) {
    if (offset < 0 || length < 0) {
      throw const ZipFormatException('The zip file is damaged');
    }
    file.setPositionSync(offset);
    final bytes = file.readSync(length);
    if (bytes.length != length) {
      throw const ZipFormatException('The zip file is cut short');
    }
    return bytes;
  }

  static List<ZipEntry> _readDirectory(RandomAccessFile file) {
    final length = file.lengthSync();
    if (length < 22) throw const ZipFormatException('Not a zip file');

    // The end record is the last thing in the file, bar a comment.
    final tailLength = length < 22 + _max16 ? length : 22 + _max16;
    final tailOffset = length - tailLength;
    final tail = _readAt(file, tailOffset, tailLength);
    final tailData = ByteData.sublistView(tail);
    var endAt = -1;
    for (var i = tailLength - 22; i >= 0; i--) {
      if (tailData.getUint32(i, Endian.little) != _endSignature) continue;
      if (i + 22 + tailData.getUint16(i + 20, Endian.little) > tailLength) {
        continue;
      }
      endAt = i;
      break;
    }
    if (endAt < 0) throw const ZipFormatException('Not a zip file');

    var count = tailData.getUint16(endAt + 10, Endian.little);
    var directorySize = tailData.getUint32(endAt + 12, Endian.little);
    var directoryOffset = tailData.getUint32(endAt + 16, Endian.little);

    if (count == _max16 || directorySize == _max32 || directoryOffset == _max32) {
      final locatorOffset = tailOffset + endAt - 20;
      if (locatorOffset < 0) {
        throw const ZipFormatException('The zip file is damaged');
      }
      final locator = ByteData.sublistView(_readAt(file, locatorOffset, 20));
      if (locator.getUint32(0, Endian.little) != _end64LocatorSignature) {
        throw const ZipFormatException('The zip file is damaged');
      }
      final end64 = ByteData.sublistView(
        _readAt(file, locator.getUint64(8, Endian.little), 56),
      );
      if (end64.getUint32(0, Endian.little) != _end64Signature) {
        throw const ZipFormatException('The zip file is damaged');
      }
      count = end64.getUint64(32, Endian.little);
      directorySize = end64.getUint64(40, Endian.little);
      directoryOffset = end64.getUint64(48, Endian.little);
    }
    if (directoryOffset + directorySize > length) {
      throw const ZipFormatException('The zip file is cut short');
    }

    final directory = _readAt(file, directoryOffset, directorySize);
    final data = ByteData.sublistView(directory);
    final entries = <ZipEntry>[];
    var at = 0;
    for (var n = 0; n < count; n++) {
      if (at + 46 > directory.length ||
          data.getUint32(at, Endian.little) != _centralSignature) {
        throw const ZipFormatException('The zip file is damaged');
      }
      final flags = data.getUint16(at + 8, Endian.little);
      final method = data.getUint16(at + 10, Endian.little);
      final crc = data.getUint32(at + 16, Endian.little);
      var compressedSize = data.getUint32(at + 20, Endian.little);
      var size = data.getUint32(at + 24, Endian.little);
      final nameLength = data.getUint16(at + 28, Endian.little);
      final extraLength = data.getUint16(at + 30, Endian.little);
      final commentLength = data.getUint16(at + 32, Endian.little);
      var headerOffset = data.getUint32(at + 42, Endian.little);
      final nameAt = at + 46;
      final extraAt = nameAt + nameLength;
      final next = extraAt + extraLength + commentLength;
      if (next > directory.length) {
        throw const ZipFormatException('The zip file is damaged');
      }
      final name = utf8.decode(
        Uint8List.sublistView(directory, nameAt, extraAt),
        allowMalformed: true,
      );

      // Sizes and places too large for the plain fields are in an extra one.
      var field = extraAt;
      final extraEnd = extraAt + extraLength;
      while (field + 4 <= extraEnd) {
        final id = data.getUint16(field, Endian.little);
        final fieldLength = data.getUint16(field + 2, Endian.little);
        var value = field + 4;
        final fieldEnd = value + fieldLength;
        if (fieldEnd > extraEnd) break;
        if (id == _zip64ExtraId) {
          if (size == _max32 && value + 8 <= fieldEnd) {
            size = data.getUint64(value, Endian.little);
            value += 8;
          }
          if (compressedSize == _max32 && value + 8 <= fieldEnd) {
            compressedSize = data.getUint64(value, Endian.little);
            value += 8;
          }
          if (headerOffset == _max32 && value + 8 <= fieldEnd) {
            headerOffset = data.getUint64(value, Endian.little);
          }
        }
        field = fieldEnd;
      }

      if (flags & _flagEncrypted != 0) {
        throw ZipFormatException('$name is encrypted');
      }
      entries.add(
        ZipEntry(
          name: name,
          method: method,
          crc: crc,
          compressedSize: compressedSize,
          size: size,
          headerOffset: headerOffset,
        ),
      );
      at = next;
    }
    return entries;
  }

  /// Reads the content of [entry], handing it to [onData] a piece at a
  /// time, and returns its SHA-256.
  ///
  /// Throws a [ZipFormatException] if the content is not what the zip says
  /// it should be (its length or checksum is off): it is damaged.
  String read(ZipEntry entry, [void Function(Uint8List data)? onData]) {
    if (entry.method != ZipEntry.methodStore &&
        entry.method != ZipEntry.methodDeflate) {
      throw ZipFormatException(
        '${entry.name} is compressed in a way that is not supported',
      );
    }
    final header = ByteData.sublistView(_readAt(_file, entry.headerOffset, 30));
    if (header.getUint32(0, Endian.little) != _localSignature) {
      throw ZipFormatException('${entry.name} is damaged');
    }
    final dataOffset =
        entry.headerOffset +
        30 +
        header.getUint16(26, Endian.little) +
        header.getUint16(28, Endian.little);

    final digest = _DigestSink();
    final hasher = sha256.startChunkedConversion(digest);
    var crc = 0;
    var total = 0;
    void take(List<int> data) {
      final piece = data is Uint8List ? data : Uint8List.fromList(data);
      crc = getCrc32(piece, crc);
      hasher.add(piece);
      total += piece.length;
      onData?.call(piece);
    }

    final inflater = entry.method == ZipEntry.methodDeflate
        ? ZLibDecoder(raw: true).startChunkedConversion(_BytesSink(take))
        : null;

    _file.setPositionSync(dataOffset);
    var left = entry.compressedSize;
    try {
      while (left > 0) {
        // A new list each time: the inflater may hold on to what it is given.
        final piece = _file.readSync(left < (1 << 16) ? left : 1 << 16);
        if (piece.isEmpty) {
          throw ZipFormatException('${entry.name} is cut short');
        }
        left -= piece.length;
        if (inflater != null) {
          inflater.add(piece);
        } else {
          take(piece);
        }
      }
      inflater?.close();
    } on ZipFormatException {
      rethrow;
    } on FileSystemException {
      rethrow;
    } on Object {
      // Whatever the inflater makes of content that is not what it was.
      throw ZipFormatException('${entry.name} is damaged');
    }
    hasher.close();

    if (total != entry.size || crc != entry.crc) {
      throw ZipFormatException('${entry.name} is damaged');
    }
    return digest.value!.toString();
  }

  /// The whole content of [entry]. Only for entries known to be small.
  Uint8List readBytes(ZipEntry entry, {int maxSize = 64 * 1024 * 1024}) {
    if (entry.size > maxSize) {
      throw ZipFormatException('${entry.name} is too large');
    }
    final bytes = BytesBuilder(copy: true);
    read(entry, bytes.add);
    return bytes.takeBytes();
  }

  /// Writes the content of [entry] to [target] (replacing it) and returns
  /// its SHA-256. If the entry turns out to be damaged, [target] is
  /// deleted again and a [ZipFormatException] thrown.
  String extract(ZipEntry entry, File target) {
    target.parent.createSync(recursive: true);
    final out = target.openSync(mode: FileMode.write);
    try {
      final hash = read(entry, out.writeFromSync);
      out.flushSync();
      out.closeSync();
      return hash;
    } on Object {
      try {
        out.closeSync();
      } on FileSystemException {
        // already closed
      }
      if (target.existsSync()) target.deleteSync();
      rethrow;
    }
  }

  void close() => _file.closeSync();
}
