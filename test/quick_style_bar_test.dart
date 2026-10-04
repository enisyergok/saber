import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saber/components/toolbar/quick_style_bar.dart';
import 'package:saber/data/flavor_config.dart';
import 'package:saber/data/tools/highlighter.dart';
import 'package:saber/data/tools/pen.dart';
import 'package:saber/data/tools/pencil.dart';

void main() {
  group('QuickStyleBar', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    FlavorConfig.setup();

    test('offers three increasing sizes within each pen\'s range', () {
      for (final pen in [Pen.fountainPen(), Pencil(), Highlighter()]) {
        final sizes = QuickStyleBar.sizesFor(pen);
        expect(sizes, hasLength(3), reason: pen.name);
        expect(sizes[0] < sizes[1] && sizes[1] < sizes[2], isTrue);
        for (final size in sizes) {
          expect(size, greaterThanOrEqualTo(pen.sizeMin), reason: pen.name);
          expect(size, lessThanOrEqualTo(pen.sizeMax), reason: pen.name);
        }
      }
    });

    testWidgets('tapping a thickness sets the pen size', (tester) async {
      final pen = Pen.fountainPen();
      final originalSize = pen.options.size;
      addTearDown(() => pen.options.size = originalSize);
      var sizeChanges = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: QuickStyleBar(
                pen: pen,
                currentColor: pen.color,
                invert: false,
                setColor: (_) {},
                onSizeChanged: () => sizeChanges++,
              ),
            ),
          ),
        ),
      );

      final sizes = QuickStyleBar.sizesFor(pen);
      final thickest = find.byTooltip(RegExp(': ${sizes.last.round()}\$'));
      expect(thickest, findsOneWidget);

      await tester.tap(thickest);
      await tester.pump();
      expect(pen.options.size, sizes.last);
      expect(sizeChanges, 1);
    });

    testWidgets('tapping a color reports it', (tester) async {
      final pen = Pen.fountainPen();
      final picked = <Color>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: QuickStyleBar(
                pen: pen,
                currentColor: Colors.black,
                invert: false,
                setColor: picked.add,
                onSizeChanged: () {},
              ),
            ),
          ),
        ),
      );

      // Four colors and three sizes, each an InkResponse.
      final dots = find.byType(InkResponse);
      expect(dots, findsNWidgets(7));

      // The second color is blue.
      await tester.tap(dots.at(1));
      await tester.pump();
      expect(picked, [Colors.blue]);
    });
  });
}
