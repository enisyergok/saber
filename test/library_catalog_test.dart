import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/components/home/library_glyph.dart';
import '../lib/components/home/catalog_icon.dart';

class _SourceAssets extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    if (!key.startsWith('assets/goodnotes/')) return rootBundle.load(key);
    const source = String.fromEnvironment('NOTEVA_SOURCE', defaultValue: '.');
    return ByteData.sublistView(await File('$source/$key').readAsBytes());
  }
}

void main() {
  const assets = [
    'sidebar.svg',
    'home.svg',
    'documents.svg',
    'folder-orange.png',
    'bookmark.svg',
    'search.svg',
    'users.svg',
    'marketplace.svg',
    'bell.svg',
    'settings.svg',
    'check-circle.svg',
    'list.svg',
    'grid.svg',
    'star.svg',
    'star-active.svg',
    'chevron-down.svg',
    'chevron-left.svg',
    'chevron-right.svg',
    'plus.svg',
    'download.svg',
    'pen.svg',
    'pencil.svg',
    'highlighter.svg',
    'lasso.svg',
    'eraser.svg',
    'text.svg',
    'image.svg',
    'share.svg',
    'more.svg',
  ];
  testWidgets('all bound catalog assets decode and retain a fixed icon slot', (
    tester,
  ) async {
    const source = String.fromEnvironment('NOTEVA_SOURCE', defaultValue: '.');
    final loader = FontLoader('Roobert')
      ..addFont(
        Future.value(
          ByteData.sublistView(
            File('$source/assets/goodnotes/fonts/Roobert-Regular.ttf')
                .readAsBytesSync(),
          ),
        ),
      );
    await tester.runAsync(loader.load);
    final bundle = _SourceAssets();
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.runAsync(() async {
      for (final asset in assets.where((name) => name.endsWith('.svg'))) {
        await SvgAssetLoader(
          'assets/goodnotes/icons/$asset',
          assetBundle: bundle,
        ).loadBytes(null);
      }
      await precacheImage(
        AssetImage('assets/goodnotes/icons/folder-orange.png', bundle: bundle),
        tester.element(find.byType(SizedBox).first),
      );
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'Roobert'),
        home: DefaultAssetBundle(
          bundle: bundle,
          child: Center(
            child: RepaintBoundary(
              key: const Key('catalog-sheet'),
              child: Material(
                color: Colors.white,
                child: Container(
                  width: 720,
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 16,
                    children: [
                      for (final asset in assets)
                        SizedBox(
                          width: 104,
                          height: 76,
                          child: Column(
                            children: [
                              CatalogIcon(
                                asset,
                                size: 36,
                                color: const Color(0xff0072ce),
                                preserveColors: [
                                  'folder-orange.png',
                                  'documents.svg',
                                  'pen.svg',
                                  'pencil.svg',
                                  'highlighter.svg',
                                ].contains(asset),
                              ),
                              const SizedBox(height: 8),
                              Text(asset, style: const TextStyle(fontSize: 10)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(CatalogIcon), findsNWidgets(29));
    for (final element in find.byType(CatalogIcon).evaluate()) {
      expect(tester.getSize(find.byWidget(element.widget)), const Size(36, 36));
    }
    // A loaded widget is not proof that the asynchronous vector was painted.
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const Key('catalog-sheet')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      try {
        final rgba = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        var bluePixels = 0;
        for (var y = 16; y < 52; y++) {
          for (var x = 50; x < 86; x++) {
            final offset = (y * image.width + x) * 4;
            if (rgba.getUint8(offset) < 80 &&
                rgba.getUint8(offset + 1) > 50 &&
                rgba.getUint8(offset + 2) > 150)
              bluePixels++;
          }
        }
        expect(
          bluePixels,
          greaterThan(40),
          reason: 'the recovered sidebar paths must actually reach the canvas',
        );
      } finally {
        image.dispose();
      }
    });
    if (const bool.fromEnvironment('CAPTURE_UI')) {
      await expectLater(
        find.byKey(const Key('catalog-sheet')),
        matchesGoldenFile('goldens/redesign/recovered_catalog_icons.png'),
      );
    }
  });
  for (final (icon, name) in [
    (Icons.search, 'search.svg'),
    (Icons.description_outlined, 'documents.svg'),
    (Icons.bookmark_border, 'bookmark.svg'),
    (Icons.space_dashboard_outlined, 'sidebar.svg'),
    (Icons.storefront_outlined, 'marketplace.svg'),
  ]) {
    testWidgets('$name is rendered from recovered SVG, not a guessed path', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DefaultAssetBundle(
            bundle: _SourceAssets(),
            child: Center(child: LibraryGlyph(icon, size: 24)),
          ),
        ),
      );
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(find.byType(SvgPicture), findsOneWidget);
      final picture = tester.widget<SvgPicture>(find.byType(SvgPicture));
      expect(
        (picture.bytesLoader as SvgAssetLoader).assetName,
        'assets/goodnotes/icons/$name',
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('an unmapped control keeps a visible platform icon', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: LibraryGlyph(Icons.info_outline)),
    );
    expect(find.byIcon(Icons.info_outline), findsOneWidget);
  });
}
