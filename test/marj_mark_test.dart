import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_screenshot/golden_screenshot.dart';
import 'package:saber/components/eink/eink_scope.dart';
import 'package:saber/components/theming/marj_mark.dart';
import 'package:saber/data/eink/eink_style.dart';

void main() {
  for (final size in [24.0, 48.0, 96.0]) {
    testWidgets('brand asset decodes and fits a $size pixel slot', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(child: MarjMark(size: size)),
        ),
      );
      await tester.loadAssets();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(MarjMark)), Size.square(size));
      final image = tester.widget<Image>(find.byType(Image));
      expect(
        image.color,
        isNull,
        reason: 'normal mode preserves the gold artwork',
      );
      if (size == 96 && const bool.fromEnvironment('CAPTURE_UI')) {
        await expectLater(
          find.byType(MarjMark),
          matchesGoldenFile('goldens/redesign/studio_mark.png'),
        );
      }
    });
  }

  testWidgets('e-ink mode uses a contrast-aware monochrome mark', (
    tester,
  ) async {
    const scheme = ColorScheme.light(onSurface: Colors.black);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(colorScheme: scheme),
        home: const EInkScope(
          style: EInkStyle(texture: 0),
          child: Center(child: MarjMark()),
        ),
      ),
    );
    await tester.loadAssets();
    await tester.pumpAndSettle();
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.color, Colors.black);
    expect(image.colorBlendMode, BlendMode.srcIn);
    expect(tester.takeException(), isNull);
  });
}
