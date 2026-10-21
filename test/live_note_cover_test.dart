import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/components/home/live_note_cover.dart';

Future<Uint8List> png(Color color) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder)
      .drawRect(const Rect.fromLTWH(0, 0, 2, 2), Paint()..color = color);
  final picture = recorder.endRecording();
  final image = await picture.toImage(2, 2);
  final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer
      .asUint8List();
  image.dispose();
  picture.dispose();
  return bytes;
}

void main() {
  testWidgets(
    'a changed cover replaces the displayed bytes without reopening',
    (tester) async {
      final red = await tester.runAsync(() => png(Colors.red));
      final blue = await tester.runAsync(() => png(Colors.blue));
      var bytes = red;
      final changes = StreamController<void>.broadcast();
      addTearDown(changes.close);
      await tester.pumpWidget(
        MaterialApp(
          home: LiveNoteCover(load: () async => bytes, changes: changes.stream),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        (tester.widget<Image>(find.byType(Image)).image as MemoryImage).bytes,
        red,
      );
      bytes = blue;
      changes.add(null);
      await tester.pumpAndSettle();
      expect(
        (tester.widget<Image>(find.byType(Image)).image as MemoryImage).bytes,
        blue,
      );
      bytes = null;
      changes.add(null);
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('an older pending read cannot overwrite a newer cover', (
    tester,
  ) async {
    final red = await tester.runAsync(() => png(Colors.red));
    final blue = await tester.runAsync(() => png(Colors.blue));
    final reads = <Completer<Uint8List?>>[];
    final changes = StreamController<void>.broadcast();
    addTearDown(changes.close);
    await tester.pumpWidget(
      MaterialApp(
        home: LiveNoteCover(
          load: () {
            final read = Completer<Uint8List?>();
            reads.add(read);
            return read.future;
          },
          changes: changes.stream,
        ),
      ),
    );
    changes.add(null);
    await tester.pump();
    reads.last.complete(blue);
    await tester.pumpAndSettle();
    reads.first.complete(red);
    await tester.pumpAndSettle();
    expect(
      (tester.widget<Image>(find.byType(Image)).image as MemoryImage).bytes,
      blue,
    );
    await tester.pumpWidget(const SizedBox());
    changes.add(null);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
