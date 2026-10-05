import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:saber/data/covers/cover_designs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('cover ids are unique and every group is used', () {
    final ids = CoverDesigns.all.map((d) => d.id).toSet();
    expect(ids.length, CoverDesigns.all.length);
    for (final group in CoverDesigns.groups) {
      expect(CoverDesigns.inGroup(group), isNotEmpty, reason: group);
    }
    expect(CoverDesigns.byId('c-brown'), isNotNull);
    expect(CoverDesigns.byId('nope'), isNull);
  });

  testWidgets('every cover renders to a PNG', (tester) async {
    await tester.runAsync(() async {
      for (final design in CoverDesigns.all) {
        final bytes = await design.renderPng(
          const Size(200, 280),
          title: 'Test',
        );
        expect(bytes.length, greaterThan(100), reason: design.id);
        // PNG signature
        expect(bytes.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47], reason: design.id);
      }
    });
  });
}
