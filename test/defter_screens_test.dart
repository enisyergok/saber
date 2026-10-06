// Renders the main screens on a tablet-sized surface so that UI work can be
// reviewed from CI without a device. Run with
// `--tags screens --update-goldens`; the images land in test/defter_shots/
// and are not committed.
@Tags(['screens'])
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_screenshot/golden_screenshot.dart';
import 'package:perfect_freehand/perfect_freehand.dart';
import 'package:saber/components/canvas/_circle_stroke.dart';
import 'package:saber/components/canvas/_rectangle_stroke.dart';
import 'package:saber/components/canvas/_stroke.dart';
import 'package:saber/data/tools/ink_eraser.dart';
import 'package:sbn/has_size.dart';
import 'package:sbn/tool_id.dart';
import 'package:saber/components/canvas/canvas.dart' as saber;
import 'package:saber/components/canvas/image/editor_image.dart';
import 'package:saber/components/canvas/canvas_background_preview.dart';
import 'package:saber/data/editor/page.dart';
import 'package:sbn/canvas_background_pattern.dart';
import 'package:saber/components/canvas/pencil_shader.dart';
import 'package:saber/components/home/new_notebook_dialog.dart';
import 'package:saber/components/home/syncing_button.dart';
import 'package:saber/components/eink/eink_image_filter.dart';
import 'package:saber/components/eink/eink_scope.dart';
import 'package:saber/components/theming/saber_theme.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/benchmark/synthetic_notes.dart';
import 'package:saber/data/defter_strings.dart';
import 'package:saber/data/eink/eink_style.dart';
import 'package:saber/data/eink/eink_texture.dart';
import 'package:saber/components/editor_gn/gn_pen_settings.dart';
import 'package:saber/data/tools/pen_feel.dart';
import 'package:saber/data/flavor_config.dart';
import 'package:saber/data/open_tabs.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/data/sentry/sentry_init.dart';
import 'package:saber/data/covers/cover_designs.dart';
import 'package:saber/data/notebooks/notebook_spec.dart';
import 'package:saber/data/notebooks/paper_templates.dart';
import 'package:saber/components/navbar/home_sidebar.dart';
import 'package:saber/pages/home/dashboard.dart';
import 'package:saber/pages/backup.dart';
import 'package:saber/pages/display_rate.dart';
import 'package:saber/data/display_rate.dart';
import 'package:saber/data/device_camera.dart';
import 'package:saber/components/toolbar/note_versions_dialog.dart';
import 'package:saber/components/toolbar/pdf_remove_dialog.dart';
import 'package:saber/data/editor/editor_core_info.dart';
import 'package:saber/data/versions/note_versions.dart';
import 'package:saber/pages/home/new_notebook_wizard.dart';
import 'package:saber/pages/home/template_gallery.dart';
import 'package:saber/data/tools/pen.dart';
import 'package:saber/data/tools/pen_assist.dart';
import 'package:saber/data/tools/select.dart';
import 'package:saber/data/tools/shape_analysis.dart';
import 'package:saber/data/tools/shape_snap.dart';
import 'package:saber/data/tools/stroke_properties.dart';
import 'package:saber/i18n/strings.g.dart';
import 'package:saber/pages/editor/editor.dart';
import 'package:saber/pages/home/browse.dart';
import 'package:saber/pages/home/home.dart';
import 'package:yaru/yaru.dart';

import 'screenshot_goldens_test.dart';
import 'utils/test_mock_channel_handlers.dart';
import 'utils/test_pdfium.dart';
import 'utils/test_user.dart';

final _baseTablet = GoldenScreenshotDevices.androidTablet.device;

/// Roughly a HUAWEI MatePad 11.5" (2200x1440) in landscape.
final _tablet = ScreenshotDevice(
  platform: _baseTablet.platform,
  resolution: const Size(2200, 1440),
  pixelRatio: 1.75,
  goldenSubFolder: 'defter/',
  frameBuilder: _baseTablet.frameBuilder,
);

void main() {
  group('Defter screens:', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    BackgroundIsolateBinaryMessenger.ensureInitialized(
      ServicesBinding.rootIsolateToken!,
    );

    setupMockPathProvider();
    setupMockPrinting();
    setupMockWindowManager();
    disableSentryForTesting();

    FlavorConfig.setup();
    StrokeOptionsExtension.setDefaults();
    SyncingButton.debugForceButtonActive = true;
    // The pictures are of the tablet, which has a camera.
    DeviceCamera.availableOverride = true;

    stows.lastStorageQuota.value = TestUser.getQuota();
    stows.username.value = 'myusername';
    stows.sentryConsent.value = .granted;

    setUpAll(() async {
      await Future.wait([
        FileManager.init(shouldWatchRootDirectory: false),
        PencilShader.init(),
      ]);
      await setupDemoFiles();
      await FileManager.createFolder('/Toplantılar');
      await FileManager.createFolder('/Projeler');
    });

    // Real directory listings don't complete inside the test zone.
    DashboardPage.overrideData = const DashboardData(
      recent: [
        '/Metric Spaces Week 1',
        '/Golden ratio',
        '/Import PDFs',
        '/Annotate images and diagrams',
        '/You can type notes too!',
        '/Coding review 1',
      ],
      folders: {
        'Dersler': 12,
        'Planlayıcılar': 8,
        'Projeler': 15,
        'Kişisel': 22,
        'Arşiv': 40,
      },
    );
    HomeSidebar.overrideFolders = const {
      'Üniversite': ['Dersler', 'Projeler'],
      'Kişisel': [],
      'Planlar': [],
      'Araştırma': [],
      'Arşiv': [],
    };

    final theme = SaberTheme.createThemeFromSeed(
      YaruColors.blue,
      Brightness.light,
      TargetPlatform.android,
    );

    _shot(
      theme: theme,
      name: 'library',
      // Real directory listings don't complete inside the test zone.
      children: DirectoryChildren(
        ['Projeler', 'Toplantılar'],
        [
          'Annotate images and diagrams',
          'Golden ratio',
          'Import PDFs',
          'Metric Spaces Week 1',
          'You can type notes too!',
          'Coding review 1',
          'HG Week 6',
          'Topology week 1',
        ],
      ),
      child: const HomePage(subpage: HomePage.browseSubpage, path: null),
    );
    _shot(
      theme: theme,
      name: 'new_notebook',
      child: const HomePage(subpage: HomePage.recentSubpage, path: null),
      afterLoad: (tester) async {
        NewNotebookDialog.show(tester.element(find.byType(HomePage)));
        await tester.pump();
      },
    );
    _shot(
      theme: theme,
      name: 'templates',
      child: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final pattern in CanvasBackgroundPattern.values.where(
                (p) => p.template,
              ))
                SizedBox(
                  width: 110,
                  height: 110 * 1.4,
                  child: FittedBox(
                    child: CanvasBackgroundPreview(
                      selected: false,
                      invert: false,
                      backgroundColor: null,
                      backgroundPattern: pattern,
                      backgroundImage: null,
                      pageSize: EditorPage.defaultSize,
                      lineHeight: stows.lastLineHeight.value,
                      lineThickness: stows.lastLineThickness.value,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    _shot(
      theme: theme,
      name: 'home',
      child: const HomePage(subpage: HomePage.dashboardSubpage, path: null),
    );
    for (final (step, name) in [
      (0, 'template'),
      (1, 'cover'),
      (2, 'size'),
      (4, 'folder'),
      (5, 'summary'),
    ])
      _shot(
        theme: theme,
        name: 'wizard_$name',
        child: const HomePage(subpage: HomePage.dashboardSubpage, path: null),
        afterLoad: (tester) async {
          showDialog<void>(
            context: tester.element(find.byType(HomePage)),
            builder: (context) => NewNotebookWizard(
              startAt: step,
              initial: NotebookSpec(
                name: 'Mühendislik Notları',
                folder: '/Projeler',
                template: PaperTemplates.byId('engineering'),
                cover: CoverDesigns.byId('c-navy'),
                format: PaperFormat.a5,
                paperColor: const Color(0xFFFFF8E7),
              ),
              loadFolders: () async => const [
                '/Dersler',
                '/Dersler/Fizik',
                '/Projeler',
                '/Arşiv',
              ],
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
        },
      );
    for (final group in [
      PaperGroup.planner,
      PaperGroup.engineering,
      PaperGroup.diagram,
    ])
      _shot(
        theme: theme,
        name: 'gallery_${group.name}',
        child: TemplateGalleryPage(group: group),
      );
    _shot(
      theme: theme,
      name: 'pen_panel',
      child: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(8),
          child: FittedBox(
            alignment: Alignment.topLeft,
            fit: BoxFit.scaleDown,
            child: GnPenSettings(
              getTool: Pen.fountainPen,
              setTool: (_) {},
              setColor: (_) {},
              onClose: () {},
              openColorPicker: () {},
              toggleGrid: () {},
              maxHeight: 1400,
            ),
          ),
        ),
      ),
    );
    _shot(
      theme: theme,
      name: 'pen_lines',
      child: const Scaffold(
        body: SizedBox.expand(child: CustomPaint(painter: _PenLinesPainter())),
      ),
    );
    _shot(
      theme: theme,
      name: 'recent',
      child: const HomePage(subpage: HomePage.recentSubpage, path: null),
    );
    _shot(
      theme: theme,
      name: 'editor',
      child: Editor(path: '/Metric Spaces Week 1'),
      afterLoad: (tester) async {
        // Pretend two other notebooks were opened earlier.
        OpenTabs.open('/Golden ratio');
        OpenTabs.open('/Import PDFs');
        await tester.pump();
      },
    );
    // What the benchmark writes on: 1,000 synthetic letters on one page.
    final syntheticNote = SyntheticNotes.note(strokes: 1000);
    _shot(
      theme: theme,
      name: 'benchmark_note',
      child: Scaffold(
        body: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Center(
            child: SizedBox(
              width: 1000,
              height: 1400,
              child: saber.Canvas(
                path: syntheticNote.filePath,
                page: syntheticNote.pages.first,
                pageIndex: 0,
                textEditing: false,
                coreInfo: syntheticNote,
                currentStroke: null,
                currentStrokeDetectedShape: null,
                currentSelection: null,
                setAsBackground: null,
                currentTool: Pen.currentPen,
                currentScale: 1,
              ),
            ),
          ),
        ),
      ),
    );
    _shot(
      theme: theme,
      name: 'editor_pages',
      child: Editor(path: '/Metric Spaces Week 1'),
      afterLoad: (tester) async {
        OpenTabs.reset();
        await tester.pump();
        final editor = tester.state<EditorState>(find.byType(Editor));
        editor.toggleBookmark(0);
        editor.showPageGrid();
        await tester.pump();
      },
    );
    _shot(
      theme: theme,
      name: 'editor_sidebar',
      child: Editor(path: '/Metric Spaces Week 1'),
      afterLoad: (tester) async {
        OpenTabs.reset();
        stows.editorPageSidebar.value = true;
        addTearDown(() => stows.editorPageSidebar.value = false);
        await tester.pump();
      },
    );
    _shot(
      theme: theme,
      name: 'editor_shape_selected',
      child: Editor(path: '/Metric Spaces Week 1'),
      afterLoad: (tester) async {
        OpenTabs.reset();
        await tester.pump();
        final editor = tester.state<EditorState>(find.byType(Editor));
        final page = editor.coreInfo.pages.first;
        Stroke raw() => Stroke(
          color: Colors.indigo,
          pressureEnabled: false,
          options: StrokeOptions(size: 6),
          pageIndex: 0,
          page: page,
          toolId: .fountainPen,
        );
        final quad = ShapeBuilder.build(
          raw(),
          ShapeGuess(
            kind: ShapeKind.polygon,
            points: const [
              Offset(180, 200),
              Offset(520, 230),
              Offset(450, 420),
              Offset(230, 380),
            ],
          ),
        );
        final ellipse = ShapeBuilder.build(
          raw()..color = Colors.deepOrange,
          ShapeGuess(
            kind: ShapeKind.ellipse,
            center: const Offset(760, 320),
            radiusX: 130,
            radiusY: 70,
            rotation: 0.3,
          ),
        );
        page.strokes
          ..add(quad)
          ..add(ellipse);
        final select = Select.currentSelect;
        select.selectResult = SelectResult(
          pageIndex: 0,
          strokes: [quad],
          images: [],
          path: Path()..addRect(quad.bounds.inflate(12)),
        );
        select.doneSelecting = true;
        editor.currentTool = select;
        page.redrawStrokes();
        tester.element(find.byType(Editor)).markNeedsBuild();
        await tester.pump();
      },
    );

    // E-ink mode next to the normal look, on the same notes: an empty page
    // with the interface, a dense handwritten page, a page with a photo and
    // a PDF page.
    const eInk = EInkStyle();
    for (final (scene, path) in [
      ('blank', '/e-ink bos not'),
      ('handwriting', '/Metric Spaces Week 1'),
    ]) {
      // An empty note never counts as "loaded" (it has nothing in it), so
      // for that scene the editor is given a moment instead.
      final waitForEditor = scene != 'blank';
      _shot(
        theme: theme,
        name: 'cmp_${scene}_normal',
        waitForEditor: waitForEditor,
        child: Editor(path: path),
        afterLoad: (_) async => OpenTabs.reset(),
      );
      _shot(
        theme: theme,
        eInk: eInk,
        name: 'cmp_${scene}_eink',
        waitForEditor: waitForEditor,
        child: Editor(path: path),
        afterLoad: (_) async => OpenTabs.reset(),
      );
    }
    // Continuous-tone content goes through the same filter the app uses for
    // photos and PDF pages. (Real notes with pictures never finish loading in
    // the test zone, so these are drawn from plain widgets.)
    for (final scene in ['photo', 'pdf']) {
      for (final on in [false, true]) {
        _shot(
          theme: theme,
          eInk: on ? eInk : null,
          name: 'cmp_${scene}_${on ? 'eink' : 'normal'}',
          child: _ToneScene(pdf: scene == 'pdf'),
        );
      }
    }
    _shot(
      theme: theme,
      eInk: eInk,
      name: 'eink_library',
      children: DirectoryChildren(
        ['Projeler', 'Toplantılar'],
        [
          'Annotate images and diagrams',
          'Golden ratio',
          'Import PDFs',
          'Metric Spaces Week 1',
          'You can type notes too!',
          'Coding review 1',
          'HG Week 6',
          'Topology week 1',
        ],
      ),
      child: const HomePage(subpage: HomePage.browseSubpage, path: null),
    );
    _shot(
      theme: theme,
      eInk: eInk,
      name: 'eink_settings',
      child: const HomePage(subpage: HomePage.settingsSubpage, path: null),
      afterLoad: (tester) async {
        // the e-ink section is far down the list
        try {
          await tester.scrollUntilVisible(
            find.text(DefterStrings.eInkSection),
            400,
            scrollable: find.byType(Scrollable).first,
            maxScrolls: 60,
          );
        } catch (_) {
          // still take the picture of whatever is on screen
        }
        await tester.pump();
      },
    );
    _shot(
      theme: theme,
      eInk: eInk,
      name: 'eink_new_notebook',
      child: const HomePage(subpage: HomePage.recentSubpage, path: null),
      afterLoad: (tester) async {
        NewNotebookDialog.show(tester.element(find.byType(HomePage)));
        await tester.pump();
      },
    );

    // The precise eraser: what was there is drawn in red underneath, what
    // is left in black on top, and the eraser's circles in blue. Red must
    // show only inside the circles: the rest of the ink has not moved.
    _shot(
      theme: theme,
      name: 'eraser_cuts',
      waitForEditor: false,
      child: const Scaffold(
        body: SizedBox.expand(child: CustomPaint(painter: _EraserCutsPainter())),
      ),
    );

    // The screen rate page. The numbers are made up for the picture; the
    // page itself reads them from the device and measures its own frames.
    _shot(
      theme: theme,
      name: 'display_rate',
      waitForEditor: false,
      child: DisplayRatePage(
        frozenAt: 59.9,
        read: () async => const DisplayRateInfo(
          max: 120,
          mode: 60,
          app: 60,
          sdk: 34,
          maker: 'HONOR',
          model: 'Pad',
          details:
              '1: 2800x1840 @ 60 Hz, 2: 2800x1840 @ 120 Hz (in use: 1, 60 Hz; '
              'window prefers mode 2; asked mode 2 (120 Hz), surface: set on 1)',
        ),
        openSettings: () async => true,
      ),
    );

    // A PDF that was just imported: a real PDF, read by the app's own PDF
    // reader. Its pages have three different sizes.
    _shot(
      theme: theme,
      name: 'pdf_import',
      child: Editor(path: '/PDF dersi'),
      afterLoad: (tester) async {
        if (!setUpPdfium()) {
          markTestSkipped('PDFium was not found on this computer');
          return;
        }
        // Pages that leave the screen are let go at once, not after a
        // wait that would outlive the test.
        EditorImage.shouldLoadOutImmediately = true;
        addTearDown(() => EditorImage.shouldLoadOutImmediately = false);
        final folder = Directory.systemTemp.createTempSync('pdf_scene');
        addTearDown(() {
          try {
            folder.deleteSync(recursive: true);
          } on FileSystemException {
            // Still open.
          }
        });
        final pdf = (await tester.runAsync(() => writeSamplePdf(folder)))!;
        final editor = tester.state<EditorState>(find.byType(Editor));
        addTearDown(editor.cancelAutosaveAndMarkSaved);
        final imported = await tester.runAsync(
          () => editor
              .importPdfFromFilePath(pdf.path)
              .timeout(const Duration(seconds: 60)),
        );
        expect(imported, isTrue);
        // Not saved: the picture is of the page, not of a file.
        editor.cancelAutosaveAndMarkSaved();
        // Nothing left over from the scenes before this one.
        Select.currentSelect.unselect();
        editor.currentTool = Pen.currentPen;
        // The pages are drawn by the PDF reader, off the main thread.
        for (var i = 0; i < 40; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 100)),
          );
          await tester.pump();
        }
      },
    );

    // Removing a PDF: what is asked before anything is taken out. The note
    // is made up for the picture: a PDF of twelve pages, three written on.
    _shot(
      theme: theme,
      name: 'pdf_remove_dialog',
      waitForEditor: false,
      child: const Scaffold(body: SizedBox.expand()),
      afterLoad: (tester) async {
        final note = EditorCoreInfo(filePath: '/Fizik');
        addTearDown(note.dispose);
        final pdf = File('${Directory.systemTemp.path}/defter_scene.pdf');
        for (var i = 0; i < 12; i++) {
          note.pages.add(
            EditorPage(
              backgroundImage: PdfEditorImage(
                id: i,
                assetCache: note.assetCache,
                pdfBytes: null,
                pdfFile: pdf,
                pdfPage: i,
                pageIndex: i,
                pageSize: const Size(1000, 1400),
                naturalSize: const Size(595, 842),
                onMoveImage: null,
                onDeleteImage: null,
                onMiscChange: null,
              ),
              images: [
                if (i < 3)
                  PngEditorImage(
                    id: 100 + i,
                    assetCache: note.assetCache,
                    extension: '.png',
                    imageProvider: MemoryImage(Uint8List(8)),
                    pageIndex: i,
                    pageSize: const Size(1000, 1400),
                    onMoveImage: null,
                    onDeleteImage: null,
                    onMiscChange: null,
                    naturalSize: const Size(10, 10),
                  ),
              ],
            ),
          );
        }
        unawaited(
          showDialog<void>(
            context: tester.element(find.byType(Scaffold)),
            builder: (context) =>
                PdfRemoveDialog(coreInfo: note, currentPageIndex: 1),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
      },
    );

    // Backup and version history. The numbers shown are made up for the
    // picture; the page itself reads them from the device.
    _shot(
      theme: theme,
      name: 'backup_page',
      waitForEditor: false,
      child: const _BackupScene(),
    );
    _shot(
      theme: theme,
      name: 'versions_dialog',
      waitForEditor: false,
      child: const Scaffold(body: SizedBox.expand()),
      afterLoad: (tester) async {
        final now = DateTime(2026, 10, 6, 15);
        NoteVersion version(int n, DateTime time, String reason, int size) =>
            NoteVersion(
              id: 'v$n',
              key: '/Fizik',
              time: time,
              extension: '.sbn2',
              main: 'a' * 64,
              assets: const [],
              preview: null,
              size: size,
              reason: reason,
            );
        unawaited(
          showDialog<void>(
            context: tester.element(find.byType(Scaffold)),
            builder: (context) => NoteVersionsDialog(
              notePath: '/Fizik',
              restore: (_) async {},
              now: now,
              load: () async => [
                version(5, DateTime(2026, 10, 6, 14, 52), 'auto', 412000),
                version(4, DateTime(2026, 10, 6, 14, 41), 'auto', 398000),
                version(3, DateTime(2026, 10, 6, 14, 30), 'open', 371000),
                version(2, DateTime(2026, 10, 5, 21, 8), 'close', 371000),
                version(1, DateTime(2026, 10, 3, 18, 2), 'restore', 96000),
              ],
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
      },
    );
  });
}

class _EraserCutsPainter extends CustomPainter {
  const _EraserCutsPainter();

  static const _page = HasSize(Size(1000, 1400));

  static Stroke _stroke(
    Pen pen, {
    double? size,
    ToolId? toolId,
  }) => Stroke(
    color: Colors.black,
    pressureEnabled: true,
    options: pen.strokeOptions.copyWith(
      size: size,
      isComplete: true,
      simulatePressure: false,
      start: StrokeEndOptions.start(
        taperEnabled: pen.strokeOptions.start.taperEnabled,
        customTaper: pen.strokeOptions.start.customTaper,
      ),
      end: StrokeEndOptions.end(
        taperEnabled: pen.strokeOptions.end.taperEnabled,
        customTaper: pen.strokeOptions.end.customTaper,
      ),
    ),
    pageIndex: 0,
    page: _page,
    toolId: toolId ?? pen.toolId,
  );

  void _draw(Canvas canvas, Stroke stroke, Color color) {
    final paint = Paint()..color = color;
    final outline = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke.options.size;
    if (stroke is CircleStroke) {
      canvas.drawCircle(stroke.center, stroke.radius, outline);
    } else if (stroke is RectangleStroke) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          stroke.rect,
          Radius.circular(stroke.options.size / 4),
        ),
        outline,
      );
    } else {
      canvas.drawPath(stroke.highQualityPath, paint);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(1.2);
    final strokes = <Stroke>[];
    final erasers = <(Offset, double)>[];

    // Written lines with each pen, pressed harder towards the middle.
    var y = 70.0;
    for (final pen in [
      Pen.fountainPen(),
      Pen.ballpointPen(),
      Pen.brushPen(),
      Pen.calligraphyPen(),
    ]) {
      final stroke = _stroke(pen, size: pen.brush ? 12 : 6);
      for (var i = 0; i <= 90; i++) {
        final at = Offset(60 + i * 5.0, y + 22 * math.sin(i / 90 * math.pi * 4));
        stroke.addPoint(at, 0.15 + 0.8 * math.sin(i / 90 * math.pi));
      }
      strokes.add(stroke);
      erasers
        ..add((Offset(60, y), 10))
        ..add((Offset(172, y + 22), 10))
        ..add((Offset(285, y), 4))
        ..add((Offset(397, y - 22), 25));
      y += 80;
    }

    // A highlighter line and a pencil line.
    final highlighter = _stroke(
      Pen.fountainPen(),
      size: 40,
      toolId: ToolId.highlighter,
    )..options.thinning = 0;
    for (var x = 60.0; x <= 510; x += 6) {
      highlighter.addPoint(Offset(x, y + 10), 0.5);
    }
    strokes.add(highlighter);
    erasers
      ..add((Offset(200, y + 10), 10))
      ..add((Offset(360, y - 6), 10))
      ..add((Offset(450, y - 22), 10));
    y += 90;

    // Shapes: a circle, a rectangle, a straight line and a triangle.
    final shapeOptions = StrokeOptions(
      size: 5,
      smoothing: 0,
      streamline: 0,
      simulatePressure: false,
      isComplete: true,
    );
    strokes
      ..add(
        CircleStroke(
          color: Colors.black,
          pressureEnabled: false,
          options: shapeOptions.copyWith(),
          pageIndex: 0,
          page: _page,
          toolId: ToolId.fountainPen,
          center: Offset(700, 150),
          radius: 90,
        ),
      )
      ..add(
        RectangleStroke(
          color: Colors.black,
          pressureEnabled: false,
          options: shapeOptions.copyWith(),
          pageIndex: 0,
          page: _page,
          toolId: ToolId.fountainPen,
          rect: const Rect.fromLTWH(840, 70, 180, 150),
        ),
      )
      ..add(
        _stroke(Pen.ballpointPen(), size: 5)
          ..setVertexHandles(const [Offset(620, 300), Offset(1020, 340)]),
      )
      ..add(
        Stroke(
          color: Colors.black,
          pressureEnabled: false,
          options: shapeOptions.copyWith(),
          pageIndex: 0,
          page: _page,
          toolId: ToolId.fountainPen,
        )..setVertexHandles(const [
          Offset(720, 380),
          Offset(900, 520),
          Offset(620, 520),
        ]),
      );
    erasers
      ..add((const Offset(700, 60), 25))
      ..add((const Offset(790, 150), 10))
      ..add((const Offset(930, 70), 10))
      ..add((const Offset(1020, 220), 25))
      ..add((const Offset(820, 320), 10))
      ..add((const Offset(900, 520), 25))
      ..add((const Offset(670, 450), 4));

    // What was there, in red.
    for (final stroke in strokes) {
      _draw(canvas, stroke, const Color(0xFFE53935));
    }

    // What is left, in black: the same strokes after the eraser.
    final left = List.of(strokes);
    final eraser = InkEraser()..begin(left);
    for (final (at, radius) in erasers) {
      eraser.eraseAt(at, radius, left);
    }
    // One swipe across the lower right, as a hand would make it.
    eraser
      ..moveTo(const Offset(640, 560), 10, left)
      ..moveTo(const Offset(760, 400), 10, left);
    for (final stroke in left) {
      _draw(canvas, stroke, Colors.black);
    }

    // Shapes with corners, untouched: as they are drawn now (black) and,
    // to the right of each, drawn from their corners alone as before
    // (red).
    for (final (corners, offset) in [
      (const [Offset(0, 0), Offset(60, 80), Offset(-50, 80)], Offset(90, 540)),
      (
        const [Offset(0, 0), Offset(55, 40), Offset(0, 80), Offset(-55, 40)],
        Offset(380, 540),
      ),
    ]) {
      final shape = Stroke(
        color: Colors.black,
        pressureEnabled: false,
        options: shapeOptions.copyWith(),
        pageIndex: 0,
        page: _page,
        toolId: ToolId.fountainPen,
      )..setVertexHandles([for (final corner in corners) corner + offset]);
      final sparse = getStroke([
        for (final corner in [...corners, corners.first])
          PointVector(corner.dx + offset.dx + 140, corner.dy + offset.dy),
      ], options: shapeOptions);
      canvas.drawPath(
        Path()..addPolygon(sparse, true),
        Paint()..color = const Color(0xFFE53935),
      );
      _draw(canvas, shape, Colors.black);
    }

    final ring = Paint()
      ..color = const Color(0xFF1E88E5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final (at, radius) in erasers) {
      canvas.drawCircle(at, radius, ring);
    }
    canvas.drawLine(const Offset(640, 560), const Offset(760, 400), ring);
  }

  @override
  bool shouldRepaint(_EraserCutsPainter oldDelegate) => false;
}

/// The backup page as it looks once a backup has been made.
class _BackupScene extends StatefulWidget {
  const _BackupScene();

  @override
  State<_BackupScene> createState() => _BackupSceneState();
}

class _BackupSceneState extends State<_BackupScene> {
  final String _before = stows.lastBackup.value;

  @override
  void initState() {
    super.initState();
    stows.lastBackup.value = LastBackup(
      time: DateTime.now().subtract(const Duration(hours: 2)),
      notes: 48,
      recordings: 6,
      zipBytes: 312 * 1024 * 1024,
    ).encode();
  }

  @override
  void dispose() {
    stows.lastBackup.value = _before;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const BackupPage();
}

void _shot({
  required ThemeData theme,
  EInkStyle? eInk,
  required String name,
  required Widget child,
  bool waitForEditor = true,
  DirectoryChildren? children,
  Future<void> Function(WidgetTester tester)? afterLoad,
}) {
  testGoldens(name, (tester) async {
    BrowsePage.overrideChildren = children;
    addTearDown(() => BrowsePage.overrideChildren = null);
    stows.platform.value = _tablet.platform;
    await tester.runAsync(() => LocaleSettings.setLocaleRaw('tr'));

    if (eInk != null) {
      stows.eInkMode.value = true;
      addTearDown(() => stows.eInkMode.value = false);
      // The paper grain is made before the page is drawn, as it is in the app.
      if (eInk.textureStep > 0) {
        await tester.runAsync(
          () => EInkTexture.load(
            eInk.textureStep,
            maxAlpha: EInkStyle.maxGrainAlpha,
          ),
        );
      }
    }

    final widget = ScreenshotApp.withConditionalTitlebar(
      theme: eInk == null
          ? theme
          : SaberTheme.createEInkTheme(eInk, _tablet.platform),
      device: _tablet,
      title: 'Defter',
      home: TranslationProvider(
        child: eInk == null
            ? child
            : EInkScope(style: eInk, child: child),
      ),
    );
    await tester.pumpWidget(widget);
    await tester.pump();

    for (final editorState in tester.stateList<EditorState>(
      find.byType(Editor),
    )) {
      // Wait for the editor to load
      var waited = 0;
      while (editorState.coreInfo.isEmpty) {
        await tester.runAsync(
          () => Future.delayed(const Duration(milliseconds: 100)),
        );
        // never wait for ever: a note with nothing in it looks unloaded
        if (++waited >= (waitForEditor ? 100 : 15)) break;
      }
      await tester.pump();
    }

    // Give async directory listings a moment to complete.
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump();

    await afterLoad?.call(tester);

    await tester.loadAssets();
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 20),
    );

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('defter_shots/$name.png'),
    );
  });
}

/// A stand-in for a photo (colour gradients and shapes) or a PDF page (text
/// lines, a grey table and a coloured chart) inside the e-ink image filter.
class _ToneScene extends StatelessWidget {
  const new({required this.pdf});

  final bool pdf;

  @override
  Widget build(BuildContext context) {
    final Widget content = pdf
        ? Container(
            color: Colors.white,
            padding: const EdgeInsets.all(48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < 12; i++)
                  Container(
                    height: 10,
                    width: 900.0 - (i % 4) * 90,
                    margin: const EdgeInsets.only(bottom: 18),
                    color: Colors.black87,
                  ),
                Container(height: 160, color: Colors.grey.shade300),
                const SizedBox(height: 24),
                Row(
                  children: [
                    for (final c in [
                      Colors.red,
                      Colors.green,
                      Colors.blue,
                      Colors.orange,
                    ])
                      Container(
                        width: 120,
                        height: 200,
                        margin: const EdgeInsets.only(right: 16),
                        color: c,
                      ),
                  ],
                ),
              ],
            ),
          )
        : Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.indigo, Colors.teal, Colors.amber, Colors.pink],
              ),
            ),
            alignment: Alignment.center,
            child: Container(
              width: 420,
              height: 420,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.orange.shade700,
                boxShadow: const [BoxShadow(blurRadius: 60, spreadRadius: 10)],
              ),
            ),
          );
    return Scaffold(
      body: Center(
        child: SizedBox(
          width: 1000,
          height: 1000,
          child: EInkImageFilter(child: content),
        ),
      ),
    );
  }
}


/// Lines as the pens draw them for the pressures measured on the tablet:
/// per pen, four even lines (raw pressure 0.1, 0.29, 0.45, 0.94) and one
/// that goes from light to firm and back; for the calligraphy pen the
/// thickness comes from the direction of the line. Then a dimensioned
/// line, as the dimension tool writes it.
class _PenLinesPainter extends CustomPainter {
  const _PenLinesPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black;
    void fill(List<PointVector> points, StrokeOptions options) {
      final polygon = getStroke(points, options: options);
      if (polygon.length < 3) return;
      canvas.drawPath(Path()..addPolygon(polygon, true), paint);
    }

    var y = 24.0;
    for (final pen in [
      Pen.fountainPen(),
      Pen.ballpointPen(),
      Pen.brushPen(),
      Pen.calligraphyPen(),
    ]) {
      final nib = pen.kind == PenKind.calligraphy;
      final options = pen.strokeOptions.copyWith(
        size: pen.brush || nib ? 12 : 5,
        isComplete: true,
        simulatePressure: false,
        streamline: 0,
      );
      const raws = [0.1, 0.29, 0.45, 0.94];
      for (var i = 0; i < raws.length; i++) {
        fill([
          for (var x = 20.0; x <= 330; x += 4)
            PointVector(x, y + 20 * i, nib ? 0.7 : PenFeel.pressure(raws[i])),
        ], options);
      }
      Offset wave(int i) => Offset(
        380 + i * 4.0,
        y + 30 + 26 * math.sin(i / 80 * math.pi * 2),
      );
      fill([
        for (var i = 0; i <= 80; i++)
          PointVector(
            wave(i).dx,
            wave(i).dy,
            nib
                ? PenFeel.nibPressure(
                    (wave(math.min(i + 1, 80)) - wave(math.max(i - 1, 0)))
                        .direction,
                  )
                : PenFeel.pressure(0.05 + 0.9 * math.sin(i / 80 * math.pi)),
          ),
      ], options);
      y += 120;
    }

    final thin = StrokeOptions(
      size: 2,
      thinning: 0,
      smoothing: 0,
      streamline: 0,
      simulatePressure: false,
      isComplete: true,
    );
    const a = Offset(60, 560), b = Offset(345.7, 560);
    fill([PointVector(a.dx, a.dy, 0.5), PointVector(b.dx, b.dy, 0.5)], thin);
    for (final line in PenAssist.lineDimension(a, b)) {
      fill([for (final p in line) PointVector(p.dx, p.dy, 0.5)], thin);
    }
    const c = Offset(520, 640), d = Offset(700, 520);
    fill([PointVector(c.dx, c.dy, 0.5), PointVector(d.dx, d.dy, 0.5)], thin);
    for (final line in PenAssist.lineDimension(c, d)) {
      fill([for (final p in line) PointVector(p.dx, p.dy, 0.5)], thin);
    }
    final text = PenAssist.textLines(
      '0123456789 Ø 12,5 mm',
      origin: const Offset(60, 680),
      along: const Offset(1, 0),
      up: const Offset(0, -1),
      height: 28,
    );
    for (final line in text) {
      fill([for (final p in line) PointVector(p.dx, p.dy, 0.5)], thin);
    }
  }

  @override
  bool shouldRepaint(_PenLinesPainter old) => false;
}
