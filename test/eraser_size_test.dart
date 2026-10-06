import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saber/components/toolbar/quick_style_bar.dart';
import 'package:saber/data/defter_strings.dart';
import 'package:saber/data/flavor_config.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/tools/eraser.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlavorConfig.setup();

  group('Eraser size:', () {
    final original = stows.eraserSize.value;
    tearDown(() => stows.eraserSize.value = original);

    test('a new eraser uses the saved size', () {
      stows.eraserSize.value = 25;
      expect(Eraser().size, 25);
    });

    test('an explicit size wins over the saved one', () {
      stows.eraserSize.value = 25;
      expect(Eraser(size: 7).size, 7);
    });

    test('presets are increasing and include the default', () {
      expect(Eraser.sizePresets, hasLength(4));
      for (var i = 1; i < Eraser.sizePresets.length; i++) {
        expect(Eraser.sizePresets[i], greaterThan(Eraser.sizePresets[i - 1]));
      }
      expect(Eraser.sizePresets, contains(10.0));
    });

    test('changing the size changes what is erased', () {
      final eraser = Eraser(size: 10);
      expect(eraser.sqrSize, 100);
      eraser.size = 50;
      expect(eraser.sqrSize, 2500);
    });

    testWidgets('tapping a size resizes the eraser and remembers it', (
      tester,
    ) async {
      final eraser = Eraser(size: 10);
      var changes = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: EraserSizeBar(eraser: eraser, onSizeChanged: () => changes++),
            ),
          ),
        ),
      );

      await tester.tap(
        find.byTooltip('${DefterStrings.eraserSize}: ${Eraser.sizePresets[2].round()}'),
      );
      expect(eraser.size, Eraser.sizePresets[2]);
      expect(stows.eraserSize.value, Eraser.sizePresets[2]);
      expect(changes, 1);
    });
  });
}
