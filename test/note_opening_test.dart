import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saber/components/editor_gn/gn_bar.dart';
import 'package:saber/components/editor_gn/gn_palette.dart';
import 'package:saber/components/home/note_opening.dart';
import 'package:saber/components/home/preview_card.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/flavor_config.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/pages/editor/editor.dart';

import 'utils/test_mock_channel_handlers.dart';

const _paper = Color(0xFFFCFCFC);
const _transition = Duration(milliseconds: 300);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlavorConfig.setup();
  setupMockPathProvider();

  /// A card that opens into a [NoteOpening], the way a note's card does.
  /// [built] counts how often the "editor" was asked for.
  Widget cardApp({
    required List<int> built,
    Widget? picture,
    Duration duration = _transition,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 148,
            height: 200,
            child: OpenContainer(
              transitionDuration: duration,
              closedBuilder: (context, open) => const Center(
                child: Text('card'),
              ),
              openBuilder: (context, close) => NoteOpening(
                path: '/note',
                paper: _paper,
                picture: picture,
                editorBuilder: (context) {
                  built.add(built.length);
                  return const Scaffold(body: Center(child: Text('editor')));
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('NoteOpening:', () {
    testWidgets('only the picture grows; the editor waits for it', (
      tester,
    ) async {
      final built = <int>[];
      await tester.pumpWidget(
        cardApp(built: built, picture: const ColoredBox(color: Colors.teal)),
      );

      await tester.tap(find.text('card'));
      await tester.pump();

      // Every frame of the growing: the picture, never the editor
      for (var elapsed = 0; elapsed < 280; elapsed += 20) {
        await tester.pump(const Duration(milliseconds: 20));
        expect(find.byKey(NoteOpening.skeletonKey), findsOneWidget);
        expect(find.byKey(NoteOpening.editorKey), findsNothing);
        expect(built, isEmpty, reason: 'after $elapsed ms');
      }

      await tester.pumpAndSettle();
      expect(find.text('editor'), findsOneWidget);
      expect(find.byKey(NoteOpening.skeletonKey), findsNothing);
      expect(built, hasLength(1), reason: 'the editor is built once');
    });

    testWidgets('the picture really grows from the card to the screen', (
      tester,
    ) async {
      await tester.pumpWidget(
        cardApp(
          built: [],
          picture: const ColoredBox(
            key: ValueKey('picture'),
            color: Colors.teal,
          ),
        ),
      );
      await tester.tap(find.text('card'));
      await tester.pump();

      double shownWidth() {
        final box = tester.renderObject<RenderBox>(
          find.byKey(const ValueKey('picture')),
        );
        final left = box.localToGlobal(Offset.zero).dx;
        final right = box.localToGlobal(Offset(box.size.width, 0)).dx;
        return right - left;
      }

      await tester.pump(const Duration(milliseconds: 60));
      final early = shownWidth();
      await tester.pump(const Duration(milliseconds: 120));
      final later = shownWidth();
      expect(early, greaterThan(148));
      expect(later, greaterThan(early));
      expect(later, lessThan(800));

      await tester.pumpAndSettle();
    });

    testWidgets('the editor stays while the page closes again', (tester) async {
      final built = <int>[];
      await tester.pumpWidget(cardApp(built: built));
      await tester.tap(find.text('card'));
      await tester.pumpAndSettle();
      expect(find.text('editor'), findsOneWidget);

      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('editor'), findsOneWidget);
      expect(find.byKey(NoteOpening.skeletonKey), findsNothing);

      await tester.pumpAndSettle();
      expect(find.text('card'), findsOneWidget);
      expect(built, hasLength(1));
    });

    testWidgets('going back before it has opened never starts the editor', (
      tester,
    ) async {
      final built = <int>[];
      await tester.pumpWidget(cardApp(built: built));
      await tester.tap(find.text('card'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();

      expect(find.text('card'), findsOneWidget);
      expect(built, isEmpty);
    });

    testWidgets('nothing to wait for when the card does not grow', (
      tester,
    ) async {
      final built = <int>[];
      await tester.pumpWidget(cardApp(built: built, duration: Duration.zero));
      await tester.tap(find.text('card'));
      await tester.pump();
      await tester.pump();

      expect(find.text('editor'), findsOneWidget);
      expect(built, hasLength(1));
      await tester.pumpAndSettle();
    });

    testWidgets('nothing to wait for when animations are off', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final built = <int>[];
      await tester.pumpWidget(cardApp(built: built));
      await tester.tap(find.text('card'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      expect(find.text('editor'), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('shown as a page of its own, it is the editor at once', (
      tester,
    ) async {
      final built = <int>[];
      await tester.pumpWidget(
        MaterialApp(
          home: NoteOpening(
            path: '/note',
            paper: _paper,
            editorBuilder: (context) {
              built.add(0);
              return const Text('editor');
            },
          ),
        ),
      );
      expect(find.text('editor'), findsOneWidget);
      expect(find.byKey(NoteOpening.skeletonKey), findsNothing);
    });

    testWidgets('the picture sits under a band the colour of the bar', (
      tester,
    ) async {
      stows.editorGnLayout.value = true;
      addTearDown(
        () => stows.editorGnLayout.value = stows.editorGnLayout.defaultValue,
      );
      await tester.pumpWidget(
        cardApp(
          built: [],
          picture: const ColoredBox(
            key: ValueKey('picture'),
            color: Colors.teal,
          ),
        ),
      );
      await tester.tap(find.text('card'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final skeleton = find.byKey(NoteOpening.skeletonKey);
      final header = GnPalette.of(tester.element(skeleton)).header;
      final band = find.descendant(
        of: skeleton,
        matching: find.byWidgetPredicate(
          (widget) => widget is ColoredBox && widget.color == header,
        ),
      );
      expect(band, findsOneWidget);
      // Laid out at the size of the screen (and scaled while it grows)
      expect(tester.getSize(band), const Size(800, GnEditorBar.contentHeight));
      final picture = find.byKey(const ValueKey('picture'));
      expect(
        tester.getSize(picture),
        const Size(800, 600 - GnEditorBar.contentHeight),
      );

      await tester.pumpAndSettle();
    });

    testWidgets('without the new bar there is no band', (tester) async {
      stows.editorGnLayout.value = false;
      addTearDown(
        () => stows.editorGnLayout.value = stows.editorGnLayout.defaultValue,
      );
      await tester.pumpWidget(
        cardApp(
          built: [],
          picture: const ColoredBox(
            key: ValueKey('picture'),
            color: Colors.teal,
          ),
        ),
      );
      await tester.tap(find.text('card'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        tester.getSize(find.byKey(const ValueKey('picture'))),
        const Size(800, 600),
      );
      await tester.pumpAndSettle();
    });
  });

  group('A note card:', () {
    setUp(() async {
      await FileManager.init(shouldWatchRootDirectory: false);
    });

    testWidgets('opens into the picture first, not into the editor', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 160,
                height: 320,
                child: PreviewCard(
                  filePath: '/note-opening-test',
                  toggleSelection: (_, _) {},
                  selected: false,
                  isAnythingSelected: false,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byType(OpenContainer));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      expect(find.byType(NoteOpening), findsOneWidget);
      expect(find.byKey(NoteOpening.skeletonKey), findsOneWidget);
      expect(find.byType(Editor), findsNothing);

      // Back before it has opened: the note is never loaded
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      expect(find.byType(Editor), findsNothing);
      expect(find.byType(PreviewCard), findsOneWidget);

      // (The card looks at its picture again a moment after closing.)
      await tester.pump(const Duration(milliseconds: 600));
    });
  });
}
