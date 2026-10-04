import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saber/data/defter_strings.dart';
import 'package:saber/data/flavor_config.dart';
import 'package:saber/pages/benchmark.dart';

void main() {
  group('BenchmarkPage', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    FlavorConfig.setup();

    testWidgets('explains itself and offers to start', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: BenchmarkPage()));

      expect(find.text(DefterStrings.benchmark), findsOneWidget);
      expect(find.text(DefterStrings.benchmarkIntro), findsOneWidget);
      expect(find.text(DefterStrings.benchmarkStart), findsOneWidget);
      // Nothing to copy before a run.
      expect(find.byTooltip(DefterStrings.benchmarkCopy), findsNothing);
    });
  });
}
