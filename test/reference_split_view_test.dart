import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/components/editor/reference_split_view.dart';

void main() {
  testWidgets(
    'open, resize and close preserve notebook state and pane bounds',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var opened = false;
      var layoutChanges = 0;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return Scaffold(
                body: ReferenceSplitView(
                  resizeLabel: 'Resize',
                  onLayoutChanged: () => layoutChanges++,
                  reference: opened
                      ? const ColoredBox(color: Colors.grey)
                      : null,
                  notebook: const _Notebook(),
                ),
              );
            },
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'Keep my note');
      final originalState = tester.state(find.byType(_Notebook));
      update(() => opened = true);
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(_Notebook)), same(originalState));
      expect(find.text('Keep my note'), findsOneWidget);
      final before = tester
          .getSize(find.byKey(const ValueKey('notebook-pane')))
          .width;
      await tester.drag(
        find.byKey(const ValueKey('reference-divider')),
        const Offset(100, 0),
      );
      await tester.pumpAndSettle();
      final after = tester
          .getSize(find.byKey(const ValueKey('notebook-pane')))
          .width;
      expect(after, lessThan(before));
      expect(
        MediaQuery.sizeOf(tester.element(find.byType(TextField))).width,
        after,
      );
      await tester.drag(
        find.byKey(const ValueKey('reference-divider')),
        const Offset(2000, 0),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byKey(const ValueKey('notebook-pane'))).width,
        greaterThan(400),
      );
      update(() => opened = false);
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(_Notebook)), same(originalState));
      expect(find.text('Keep my note'), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const ValueKey('notebook-pane'))).width,
        1200,
      );
      expect(layoutChanges, greaterThan(2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('narrow screens stack panels and permit vertical resizing', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ReferenceSplitView(
            resizeLabel: 'Resize',
            reference: ColoredBox(color: Colors.grey),
            notebook: _Notebook(),
          ),
        ),
      ),
    );
    final pane = find.byKey(const ValueKey('reference-pane'));
    final before = tester.getSize(pane).height;
    expect(tester.getSize(pane).width, 390);
    await tester.drag(
      find.byKey(const ValueKey('reference-divider')),
      const Offset(0, 80),
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(pane).height, greaterThan(before));
    expect(tester.takeException(), isNull);
  });
}

class _Notebook extends StatefulWidget {
  const _Notebook();
  @override
  State<_Notebook> createState() => _NotebookState();
}

class _NotebookState extends State<_Notebook> {
  final controller = TextEditingController();
  @override
  Widget build(BuildContext context) => TextField(controller: controller);
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
