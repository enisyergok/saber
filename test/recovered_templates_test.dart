import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:xml/xml.dart';

import '../lib/components/home/packaged_paper_preview.dart';
import '../lib/components/home/packaged_template_painter.dart';
import '../lib/data/notebooks/recovered_template.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final size in [
    const Size(1000, 1400),
    const Size(1414.29, 1000),
    const Size(704.76, 1000),
    const Size(1000, 1000),
  ]) {
    test(
      'all 41 resources produce loadable self-contained SVG at $size',
      () async {
        final resources = [
          ...RecoveredTemplates.papers,
          ...RecoveredTemplates.covers,
        ];
        expect(resources.toSet().length, 41);
        for (final resource in resources) {
          final svg = RecoveredTemplates.render(
            resource,
            size.width,
            size.height,
          );
          final doc = XmlDocument.parse(svg);
          expect(doc.findAllElements('pattern'), isEmpty, reason: resource);
          expect(svg.contains('NaN'), isFalse, reason: resource);
          final picture = await vg.loadPicture(SvgStringLoader(svg), null);
          expect(
            picture.size.width,
            closeTo(size.width, .001),
            reason: resource,
          );
          expect(
            picture.size.height,
            closeTo(size.height, .001),
            reason: resource,
          );
          picture.picture.dispose();
        }
      },
    );
  }

  test('two-column geometry follows the packaged ten-unit gutter formula', () {
    final doc = XmlDocument.parse(
      RecoveredTemplates.render('twoColumn.svg', 1000, 1400),
    );
    XmlElement group(String id) =>
        doc.descendantElements.firstWhere((e) => e.getAttribute('id') == id);
    final first = group('column1').childElements.first;
    final second = group('column2').childElements.first;
    expect(double.parse(first.getAttribute('x')!), 30);
    expect(double.parse(first.getAttribute('width')!), 465);
    expect(double.parse(second.getAttribute('x')!), 505);
    expect(double.parse(second.getAttribute('y')!), 50);
  });

  test(
    'custom colour changes only the paper background, not guide colours',
    () {
      final doc = XmlDocument.parse(
        RecoveredTemplates.render(
          'grid.svg',
          1000,
          1400,
          paperColor: 0xffe0f0ff,
        ),
      );
      expect(
        doc.rootElement.childElements
            .where((e) => e.name.local == 'rect')
            .first
            .getAttribute('fill'),
        '#e0f0ff',
      );
      expect(
        doc.descendantElements.any(
          (e) => e.getAttribute('fill') == 'rgb(208,210,211)',
        ),
        isTrue,
      );
      expect(
        () => RecoveredTemplates.render('grid.svg', double.nan, 1400),
        throwsArgumentError,
      );
      expect(
        () => RecoveredTemplates.render('grid.svg', 0, 1400),
        throwsArgumentError,
      );
      expect(
        () => RecoveredTemplates.render('not-a-resource.svg', 1000, 1400),
        throwsArgumentError,
      );
    },
  );

  for (final (label, resources) in [
    ('papers', RecoveredTemplates.papers),
    ('covers', RecoveredTemplates.covers),
  ]) {
    testWidgets('paint every packaged $label and capture its actual artwork', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const pageSize = Size(1000, 1400);
      canvas.drawColor(Colors.white, BlendMode.src);
      for (var i = 0; i < resources.length; i++) {
        canvas.save();
        canvas.translate(20 + (i % 7) * 165, 20 + (i ~/ 7) * 230);
        PackagedTemplatePainter(
          resources[i],
          pageSize,
        ).paint(canvas, const Size(145, 203));
        canvas.restore();
      }
      final picture = recorder.endRecording();
      await tester.runAsync(() async {
        final image = await picture.toImage(
          1200,
          label == 'papers' ? 480 : 950,
        );
        try {
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          expect(bytes!.lengthInBytes, greaterThan(1000));
          if (const bool.fromEnvironment('CAPTURE_UI')) {
            final file = File('test/goldens/redesign/recovered_$label.png');
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes.buffer.asUint8List());
          }
        } finally {
          image.dispose();
          picture.dispose();
        }
      });
    });
  }
  testWidgets(
    'Cornell renders the vertical cue line, not just its ruled paper',
    (tester) async {
      tester.view.physicalSize = const Size(1100, 1500);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      const source = String.fromEnvironment('NOTEVA_SOURCE', defaultValue: '.');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMessageHandler('flutter/assets', (data) async {
        final key = const StringCodec().decodeMessage(data)!;
        return ByteData.sublistView(File('$source/$key').readAsBytesSync());
      });
      addTearDown(
        () => messenger.setMockMessageHandler('flutter/assets', null),
      );
      await tester.runAsync(
        () => rootBundle.loadString('assets/goodnotes/papers/cornell.svg'),
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(
            child: RepaintBoundary(
              key: Key('paper'),
              child: PackagedPaperPreview(
                asset: 'cornell.svg',
                pageSize: Size(1000, 1400),
                fallback: Text('missing paper'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
      expect(find.text('missing paper'), findsNothing);
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const Key('paper')),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        try {
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          final redAtCue = bytes.getUint8((401 * image.width + 300) * 4);
          final redAtBody = bytes.getUint8((401 * image.width + 400) * 4);
          expect(
            redAtCue,
            lessThan(redAtBody - 40),
            reason: 'the cue divider must survive preview rendering',
          );
        } finally {
          image.dispose();
        }
      });
      expect(tester.takeException(), isNull);
    },
  );
}
