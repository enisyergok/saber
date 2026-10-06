import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/painting.dart';
import 'package:logging/logging.dart';
import 'package:saber/components/canvas/image/editor_image.dart';
import 'package:saber/components/canvas/image/pdf_document_cache.dart';

/// A cache for assets that are loaded from disk.
///
/// This is the analogue to Flutter's image cache,
/// but for non-image assets.
///
/// There should be one instance of this class per
/// [EditorCoreInfo] instance.
class AssetCache {
  final log = Logger('AssetCache');

  final pdfDocumentCache = PdfDocumentCache();

  /// Maps a file path to its value.
  final Map<String, Object> _cache = {};

  /// Maps a file path to the visible images that use it.
  final Map<String, Set<EditorImage>> _images = {};

  /// Whether items from the cache can be removed:
  /// set to false during file save.
  var allowRemovingAssets = true;

  /// Marks [image] as currently visible.
  ///
  /// It's safe to call this method multiple times.
  ///
  /// [file] is allowed to be null for convenience,
  /// in which case this function does nothing.
  void addImage<T extends Object>(EditorImage image, File? file, T value) {
    if (file == null) return;
    _images.putIfAbsent(file.path, () => {}).add(image);
    _cache[file.path] = value;
  }

  /// Returns null if [file] is not found.
  T? get<T extends Object>(File file) {
    return _cache[file.path] as T?;
  }

  /// Marks [image] as no longer visible.
  ///
  /// It's safe to call this method multiple times.
  ///
  /// If [image] is the last image using its file,
  /// the file is also removed from the cache.
  ///
  /// Returns whether the image was present in the cache.
  bool removeImage(EditorImage image) {
    if (!allowRemovingAssets) return false;

    for (final filePath in _images.keys) {
      final imagesUsingFile = _images[filePath]!;
      imagesUsingFile.remove(image);

      if (imagesUsingFile.isEmpty) {
        _images.remove(filePath);
        _cache.remove(filePath);
        return true;
      }
    }

    return false;
  }

  void dispose() {
    _images.clear();
    _cache.clear();
    pdfDocumentCache.dispose();
  }
}

class OrderedAssetCache {
  final log = Logger('OrderedAssetCache');

  final List<Object> _cache = [];

  /// What uses each item, in the order of the items.
  final List<List<Object>> _owners = [];

  /// Adds [value] to the cache if it is not already present and
  /// returns the index of the added item.
  ///
  /// [owner] is what the item belongs to (a picture on a page). Owners are
  /// told where their item ended up once it is on disk.
  int add<T extends Object>(T value, {Object? owner}) {
    int index = _cache.indexOf(value);
    if (index == -1 && value is List<int>) {
      // Lists need to be compared per item
      final listEq = const ListEquality().equals;
      for (int i = 0; i < _cache.length; i++) {
        final cacheItem = _cache[i];
        if (cacheItem is! List<int>) continue;
        if (!listEq(value, cacheItem)) continue;

        index = i;
        break;
      }
    }
    if (index == -1 && value is File) {
      // Two File objects for one path are one file. (The pages of a PDF
      // each have their own: without this, a PDF of a hundred pages was
      // written a hundred times with every save.)
      final path = value.absolute.path;
      index = _cache.indexWhere(
        (item) => item is File && item.absolute.path == path,
      );
    }
    log.fine('OrderedAssetCache.add: index = $index, value = $value');

    if (index == -1) {
      _cache.add(value);
      _owners.add([]);
      index = _cache.length - 1;
    }
    if (owner != null) _owners[index].add(owner);
    return index;
  }

  /// What the item at [index] belongs to.
  List<Object> ownersOf(int index) => List.unmodifiable(_owners[index]);

  /// The file the item at [index] is read from, or null if the item is
  /// held in memory.
  File? fileAt(int index) {
    final item = _cache[index];
    return switch (item) {
      File() => item,
      FileImage() => item.file,
      _ => null,
    };
  }

  /// The number of (distinct) items in the cache.
  int get length => _cache.length;
  bool get isEmpty => _cache.isEmpty;
  bool get isNotEmpty => _cache.isNotEmpty;

  /// Converts the item at position [index]
  /// to bytes and returns them.
  Future<List<int>> getBytes(int index) async {
    final item = _cache[index];
    if (item is List<int>) {
      return item;
    } else if (item is File) {
      return item.readAsBytes();
    } else if (item is String) {
      return utf8.encode(item);
    } else if (item is MemoryImage) {
      return item.bytes;
    } else if (item is FileImage) {
      return item.file.readAsBytes();
    } else {
      throw Exception(
        'OrderedAssetCache.getBytes: unknown type ${item.runtimeType}',
      );
    }
  }
}
