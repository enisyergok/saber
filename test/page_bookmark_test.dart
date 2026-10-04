import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saber/components/canvas/_asset_cache.dart';
import 'package:saber/data/editor/editor_core_info.dart';
import 'package:saber/data/editor/page.dart';

EditorPage _roundTrip(EditorPage page) {
  final json = page.toJson(OrderedAssetCache());
  return EditorPage.fromJson(
    json,
    inlineAssets: null,
    readOnly: false,
    fileVersion: EditorCoreInfo.sbnVersion,
    sbnPath: '/bookmark_test',
    assetCache: AssetCache(),
  );
}

void main() {
  group('Page bookmark', () {
    test('defaults to not bookmarked', () {
      expect(EditorPage().bookmarked, isFalse);
    });

    test('is not written for pages without a bookmark', () {
      // Notes that never use bookmarks stay byte-identical to upstream Saber.
      final json = EditorPage(
        size: const Size(100, 140),
      ).toJson(OrderedAssetCache());
      expect(json.containsKey('bm'), isFalse);
    });

    test('survives a save and load', () {
      final page = EditorPage(size: const Size(100, 140), bookmarked: true);
      final json = page.toJson(OrderedAssetCache());
      expect(json['bm'], isTrue);

      final loaded = _roundTrip(page);
      expect(loaded.bookmarked, isTrue);
      expect(loaded.size, const Size(100, 140));
    });

    test('pages saved without the key load as not bookmarked', () {
      final loaded = EditorPage.fromJson(
        <String, dynamic>{'w': 100.0, 'h': 140.0},
        inlineAssets: null,
        readOnly: false,
        fileVersion: EditorCoreInfo.sbnVersion,
        sbnPath: '/bookmark_test',
        assetCache: AssetCache(),
      );
      expect(loaded.bookmarked, isFalse);
    });

    test('a bookmark does not make an empty page count as non-empty', () {
      // The trailing empty page is removed on save; a bookmark alone
      // must not change that.
      expect(EditorPage(bookmarked: true).isEmpty, isTrue);
    });

    test('duplicating a page does not copy its bookmark', () {
      final page = EditorPage(bookmarked: true);
      expect(page.copyWith().bookmarked, isFalse);
    });
  });
}
