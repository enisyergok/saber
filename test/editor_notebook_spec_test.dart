import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_screenshot/golden_screenshot.dart';
import 'package:saber/data/editor/page.dart';
import 'package:saber/components/canvas/_asset_cache.dart';
import 'package:saber/components/canvas/image/editor_image.dart';
import 'package:saber/data/editor/editor_exporter.dart';
import 'package:saber/data/notebooks/recovered_template.dart';

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_svg/flutter_svg.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/flavor_config.dart';
import 'package:saber/data/notebooks/notebook_spec.dart';
import 'package:saber/data/notebooks/paper_templates.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/i18n/strings.g.dart';
import 'package:saber/pages/editor/editor.dart';
import 'package:sbn/canvas_background_pattern.dart';

import 'utils/test_editor.dart';
import 'utils/test_mock_channel_handlers.dart';

void main() {
  testGoldens('Editor: a notebook made in the new notebook screen', (
    tester,
  ) async {
    TestWidgetsFlutterBinding.ensureInitialized();

    setupMockPathProvider();
    setupMockPrinting();

    final unloadImmediately = EditorImage.shouldLoadOutImmediately;
    EditorImage.shouldLoadOutImmediately = true;
    addTearDown(() {
      EditorImage.shouldLoadOutImmediately = unloadImmediately;
    });

    FlavorConfig.setup();
    stows.editorGnLayout.value = false;
    final paper = stows.lastBackgroundPattern.value;
    final spacing = stows.lastLineHeight.value;
    addTearDown(() {
      stows.lastBackgroundPattern.value = paper;
      stows.lastLineHeight.value = spacing;
    });
    await tester.runAsync(FileManager.init);

    await tester.pumpWidget(
      TranslationProvider(
        child: ScreenshotApp(
          device: GoldenScreenshotDevices.androidPhone.device,
          home: Editor(),
        ),
      ),
    );
    final editor = tester.state<EditorState>(find.byType(Editor));
    addTearDown(editor.cancelAutosaveAndMarkSaved);

    // A5 on its side, cream, narrow ruled.
    final spec = NotebookSpec(
      template: PaperTemplates.byId('lined-narrow'),
      format: PaperFormat.a5,
      landscape: true,
      paperColor: const Color(0xFFFFF8E7),
    );
    await editor.applyNotebookSpec(spec);
    await tester.pump();

    final info = editor.coreInfo;
    expect(info.backgroundPattern, CanvasBackgroundPattern.lined);
    expect(info.lineHeight, 30);
    expect(info.backgroundColor, const Color(0xFFFFF8E7));
    expect(info.pages, isNotEmpty);
    for (final page in info.pages) {
      expect(page.size, spec.pageSize);
    }
    expect(spec.pageSize.width, greaterThan(spec.pageSize.height));
    final original = info.pages.first.backgroundImage! as SvgEditorImage;
    expect(original.templateResource, 'ruledNarrow.svg');
    final assets = OrderedAssetCache();
    final json = original.toJson(assets);
    final bytes = await assets.getBytes(json['a'] as int);
    expect(
      utf8.decode(bytes),
      RecoveredTemplates.render(
        'ruledNarrow.svg',
        spec.pageSize.width,
        spec.pageSize.height,
        paperColor: 0xfffff8e7,
      ),
    );
    final reopened = SvgEditorImage.fromJson(
      json,
      inlineAssets: [Uint8List.fromList(bytes)],
      sbnPath: '/roundtrip',
      assetCache: info.assetCache,
    );
    expect(reopened.templateResource, 'ruledNarrow.svg');
    expect(reopened.dstRect, Offset.zero & spec.pageSize);
    expect(
      (reopened.svgLoader as SvgStringLoader).provideSvg(null),
      utf8.decode(bytes),
    );
    // the paper becomes the one new notes start on, as before
    expect(stows.lastBackgroundPattern.value, CanvasBackgroundPattern.lined);

    // Pages added later are in the notebook's format too.
    editor.insertPageAfter(0);
    await tester.pump();
    expect(info.pages[1].size, spec.pageSize);
    expect(
      (info.pages[1].backgroundImage as SvgEditorImage).templateResource,
      'ruledNarrow.svg',
    );
    editor.createPage(info.pages.length + 1);
    expect(info.pages.last.size, spec.pageSize);
    expect(info.pages.last.size, isNot(EditorPage.defaultSize));
    expect(
      (info.pages.last.backgroundImage as SvgEditorImage).templateResource,
      'ruledNarrow.svg',
    );
    expect(info.pages.last.backgroundImage!.pageIndex, info.pages.length - 1);
    expect(
      info.pages.last.isEmpty,
      isTrue,
      reason: 'paper alone must not accumulate nonempty trailing pages',
    );
    reopened.dispose();
    final packagedPapers = PaperTemplates.inGroup(PaperGroup.recovered)
        .where((paper) => paper.canCreate)
        .toList();
    expect(packagedPapers, isNotEmpty);
    // The complete recovered catalog is validated by the catalog tests. Keep
    // this editor round-trip focused on the built-in papers plus a stable
    // sample of recovered assets so the golden suite remains bounded.
    final roundTripPapers = [
      ...packagedPapers.where((paper) => !paper.isRecoveredCatalog),
      ...packagedPapers.where((paper) => paper.isRecoveredCatalog).take(5),
    ];
    for (final paper in roundTripPapers) {
      await editor.applyNotebookSpec(NotebookSpec(template: paper));
      final background = info.pages.first.backgroundImage! as SvgEditorImage;
      final savedAssets = OrderedAssetCache();
      final saved = background.toJson(savedAssets);
      final savedBytes = Uint8List.fromList(
        await savedAssets.getBytes(saved['a'] as int),
      );
      final loaded = SvgEditorImage.fromJson(
        saved,
        inlineAssets: [savedBytes],
        sbnPath: '/resource-roundtrip',
        assetCache: info.assetCache,
      );
      expect(loaded.templateResource, paper.resource);
      final expectedSvg = paper.resource!.startsWith('assets/goodnotes/catalog/')
          ? await rootBundle.loadString(paper.resource!)
          : RecoveredTemplates.render(paper.resource!, 1000, 1400);
      expect(
        (loaded.svgLoader as SvgStringLoader).provideSvg(null),
        expectedSvg,
      );
      loaded.dispose();
    }
    await editor.applyNotebookSpec(spec);

    // Once there is something on the note, a setup no longer changes it.
    editor.drawTestStroke();
    await tester.pump();
    await editor.applyNotebookSpec(
      NotebookSpec(template: PaperTemplates.byId('gantt')),
    );
    expect(info.backgroundPattern, CanvasBackgroundPattern.lined);
    expect(info.pages.first.size, spec.pageSize);
    await tester.runAsync(() async {
      final image = await EditorExporter.screenshotPage(
        coreInfo: info,
        pageIndex: 0,
        pixelRatio: .25,
      );
      expect(image.width, closeTo(spec.pageSize.width * .25, 1));
      expect(image.height, closeTo(spec.pageSize.height * .25, 1));
      image.dispose();
      final document = await EditorExporter.generatePdf(
        info,
        tester.element(find.byType(Editor)),
      );
      final pdfBytes = await document.save();
      expect(ascii.decode(pdfBytes.sublist(0, 5)), '%PDF-');
      expect(pdfBytes.length, greaterThan(1000));
    });
  });
}
