import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../lib/components/home/library_navigation.dart';

void main() {
  for (final initial in ['/home', '/documents', '/settings']) {
    testWidgets('returns from overlay to unchanged URL $initial in one tap', (
      tester,
    ) async {
      final router = GoRouter(
        initialLocation: initial,
        routes: [
          for (final path in ['/home', '/documents', '/settings'])
            GoRoute(
              path: path,
              builder: (_, _) => _Root(path: path),
            ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.tap(find.text('Open cards'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Return $initial'));
      await tester.pumpAndSettle();
      expect(find.text('Root $initial'), findsOneWidget);
      expect(find.text('Cards'), findsNothing);
      expect(router.canPop(), isFalse);
    });
  }

  testWidgets('switches several library pages without replacing router root', (
    tester,
  ) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const _Root(path: '/'),
        ),
        GoRoute(
          path: '/documents',
          builder: (_, _) => const _Root(path: '/documents'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('Open cards'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Next library page'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Return /documents'));
    await tester.pumpAndSettle();
    expect(find.text('Root /documents'), findsOneWidget);
    expect(find.text('Cards'), findsNothing);
    expect(router.canPop(), isFalse);
  });

  testWidgets(
    'back from secondary destination preserves original settings page',
    (tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, _) => Scaffold(
              body: TextButton(
                onPressed: () =>
                    LibraryNavigation.open(context, const _Cards()),
                child: const Text('Open cards'),
              ),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.tap(find.text('Open cards'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next library page'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Open cards'), findsOneWidget);
      expect(find.text('Cards'), findsNothing);
    },
  );
}

class _Root extends StatelessWidget {
  const _Root({required this.path});
  final String path;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        Text('Root $path'),
        TextButton(
          onPressed: () => Navigator.of(context)
              .push(MaterialPageRoute<void>(builder: (_) => const _Cards())),
          child: const Text('Open cards'),
        ),
      ],
    ),
  );
}

class _Cards extends StatelessWidget {
  const _Cards();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Cards')),
    body: Column(
      children: [
        for (final path in ['/', '/home', '/documents', '/settings'])
          TextButton(
            onPressed: () => LibraryNavigation.go(context, path),
            child: Text('Return $path'),
          ),
        TextButton(
          onPressed: () => LibraryNavigation.open(context, const _Cards()),
          child: const Text('Next library page'),
        ),
      ],
    ),
  );
}
