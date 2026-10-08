import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saber/components/canvas/_asset_cache.dart';
import 'package:saber/components/canvas/image/editor_image.dart';
import 'package:saber/components/toolbar/image_crop_dialog.dart';
import 'package:saber/data/flavor_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlavorConfig.setup();

  final pngBytes = File(
    'test/demo_notes/Import PDFs.sbn2.0',
  ).readAsBytesSync();
  final cache = AssetCache();
  PngEditorImage picture() => PngEditorImage(
    id: 1,
    assetCache: cache,
    extension: '.png',
    imageProvider: MemoryImage(pngBytes),
    pageIndex: 0,
    pageSize: const Size(1000, 1400),
    onMoveImage: null,
    onDeleteImage: null,
    onMiscChange: null,
    naturalSize: const Size(400, 200),
    srcRect: const Rect.fromLTWH(0, 0, 400, 200),
    dstRect: const Rect.fromLTWH(100, 300, 400, 200),
  );

  void expectRect(Rect actual, Rect expected) {
    expect(actual.left, closeTo(expected.left, 1e-6));
    expect(actual.top, closeTo(expected.top, 1e-6));
    expect(actual.right, closeTo(expected.right, 1e-6));
    expect(actual.bottom, closeTo(expected.bottom, 1e-6));
  }

  group('A picture that is cut:', () {
    test('starts whole', () {
      final image = picture();
      expect(image.isCut, isFalse);
      expect(image.cutout, EditorImage.wholePicture);
      expect(image.toJson(OrderedAssetCache()).containsKey('kl'), isFalse);
    });

    test('keeps the part that is left where and as large as it was', () {
      final image = picture();
      // The right half.
      image.cutTo(const Rect.fromLTRB(0.5, 0, 1, 1));
      expect(image.isCut, isTrue);
      expectRect(image.dstRect, const Rect.fromLTWH(300, 300, 200, 200));
      // Then the lower half of that.
      image.cutTo(const Rect.fromLTRB(0.5, 0.5, 1, 1));
      expectRect(image.dstRect, const Rect.fromLTWH(300, 400, 200, 100));
      // Opening it up to whole again gives the first box back.
      image.cutTo(EditorImage.wholePicture);
      expectRect(image.dstRect, const Rect.fromLTWH(100, 300, 400, 200));
    });

    test('works the same when the picture is turned', () {
      for (var turns = 1; turns < 4; turns++) {
        final image = picture()..rotateQuarter(turns);
        final whole = image.dstRect;
        image.cutTo(const Rect.fromLTRB(0.25, 0, 1, 0.5));
        final cut = image.dstRect;
        // The same share of the box, whatever the turn.
        final unturnedWidth = turns.isOdd ? cut.height : cut.width;
        final unturnedHeight = turns.isOdd ? cut.width : cut.height;
        expect(unturnedWidth, closeTo(300, 1e-6), reason: 'turns $turns');
        expect(unturnedHeight, closeTo(100, 1e-6), reason: 'turns $turns');
        expect(whole.contains(cut.topLeft), isTrue, reason: 'turns $turns');
        expect(
          whole.inflate(1e-6).contains(cut.bottomRight),
          isTrue,
          reason: 'turns $turns',
        );
        image.cutTo(EditorImage.wholePicture);
        expectRect(image.dstRect, whole);
      }
    });

    test('a sliver or something outside the picture is refused', () {
      final image = picture();
      image.cutTo(const Rect.fromLTRB(0, 0, 0.01, 1));
      image.cutTo(const Rect.fromLTRB(-0.1, 0, 1, 1));
      image.cutTo(const Rect.fromLTRB(0, 0, 1.2, 1));
      expect(image.isCut, isFalse);
      expect(image.dstRect, const Rect.fromLTWH(100, 300, 400, 200));
    });

    test('is told to the history once, from before the first cut', () {
      final image = picture();
      image.cutTo(const Rect.fromLTRB(0.5, 0, 1, 1));
      image.cutTo(const Rect.fromLTRB(0.5, 0.5, 1, 1));
      expect(image.hasUnreportedCut, isTrue);
      final change = image.takeUnreportedCut()!;
      expect(change.previous, EditorImage.wholePicture);
      expect(change.current, const Rect.fromLTRB(0.5, 0.5, 1, 1));
      expect(image.takeUnreportedCut(), isNull);
      expect(image.hasUnreportedCut, isFalse);

      // A cut that is put back is no change.
      image.cutTo(EditorImage.wholePicture);
      image.cutTo(const Rect.fromLTRB(0.5, 0.5, 1, 1));
      expect(image.takeUnreportedCut(), isNull);
    });

    test('is saved, read back and copied', () {
      final image = picture()..cutTo(const Rect.fromLTRB(0.1, 0.2, 0.9, 0.7));
      final json = image.toJson(OrderedAssetCache());
      expect(json['kl'], 0.1);
      expect(json['kt'], 0.2);
      expect(json['kr'], 0.9);
      expect(json['kb'], 0.7);
      final again = EditorImage.fromJson(
        json,
        inlineAssets: [pngBytes],
        sbnPath: '/x',
        assetCache: cache,
      );
      expectRect(again.cutout, const Rect.fromLTRB(0.1, 0.2, 0.9, 0.7));
      expect(again.dstRect, image.dstRect);
      expectRect(image.copy().cutout, image.cutout);
    });

    test('a saved cut that makes no sense is ignored', () {
      final json = picture().toJson(OrderedAssetCache())
        ..['kl'] = 0.9
        ..['kt'] = 0.0
        ..['kr'] = 0.92
        ..['kb'] = 1.0;
      final read = EditorImage.fromJson(
        json,
        inlineAssets: [pngBytes],
        sbnPath: '/x',
        assetCache: cache,
      );
      expect(read.isCut, isFalse);
    });
  });

  group('Cutting as the picture is seen:', () {
    test('without a turn, what is seen is what is stored', () {
      const crop = Rect.fromLTRB(0.1, 0.2, 0.7, 0.9);
      expectRect(CropGeometry.toShown(crop, 0), crop);
      expectRect(CropGeometry.fromShown(crop, 0), crop);
    });

    test('a turn is undone on the way back, for every turn', () {
      const crop = Rect.fromLTRB(0.1, 0.2, 0.7, 0.9);
      for (var turns = 0; turns < 4; turns++) {
        final shown = CropGeometry.toShown(crop, turns);
        expectRect(CropGeometry.fromShown(shown, turns), crop);
      }
    });

    test('a quarter turn clockwise moves the top left to the top right', () {
      // The top left corner of the picture lies at the top right once turned.
      final shown = CropGeometry.toShown(
        const Rect.fromLTRB(0, 0, 0.25, 0.5),
        1,
      );
      expectRect(shown, const Rect.fromLTRB(0.5, 0, 1, 0.25));
    });
  });
}
