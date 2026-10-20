# Goodnotes package findings mapped to Noteva

The extracted IPA supplies selected packaged resources as well as evidence for
behavior and information architecture. Five Roobert font files and six paper
SVGs are now bundled under `assets/goodnotes/`. Apple executables, compiled
asset catalogs and model files are not Noteva runtime dependencies.

The subsequent catalogue migration adds 29 selected recovered icon resources.
Their source filenames and digests are recorded in
`assets/goodnotes/icons/SOURCES.json`. They replace the hand-drawn library
outlines and selected editor controls; the compiled `.car` files themselves are
not bundled or interpreted on Android.

## Reference package areas

| IPA area | What it indicates | Noteva implementation |
| --- | --- | --- |
| `GN6DesignSystem_GN6DesignSystem.bundle` | Roobert type family, shared visual language | `DefterDesign`, `SaberTheme`, and the Noteva library tokens |
| `GN6iOSUI_GN6iOSUI.bundle` | document and editor screen resources | `NotevaLibrary`, `GnEditorBar`, `GnPalette`, and `GnOverlay` |
| `GNLibraryUI_GNLibraryUIAssets.bundle` | library navigation and document presentation | `lib/components/home/noteva_library.dart` |
| `GNPaletteMenu_GNPaletteMenu.bundle` | tool palette and color-menu structure | `lib/components/editor_gn/gn_palette.dart` and `gn_pen_settings.dart` |
| `GNDynamicTemplates_GNDynamicTemplates.bundle` | template catalogue flow | `TemplateGalleryPage` and `PaperTemplates` |
| `GNHandwritingRecognition_GNHandwritingRecognition.bundle` | handwriting-to-text capability | `InkRecognizer`, `HandwritingService`, and `RecognizeDialog` |
| `GNOCR_GNOCR.bundle` | text recognition/search capability | handwriting index and note search modules |
| `GNTranscriptionUI_GNTranscriptionUI.bundle` | recording/transcription entry point | `NoteRecordings` and `RecordingsDialog` |
| `GNMathAssistant_GNMathAssistant.bundle` | math/ink assistance direction | shape recognition and editor math-related tooling |
| `GNShop_GNShop.bundle` | template/store navigation concept | template navigation entry in the Noteva library |

## Implemented behavior

- Library rail, search, favorites, templates, settings, list/grid switch, sort,
  folder rows, document rows, and selection mode.
- Three-row editor toolbar with pen, highlighter, shape, eraser, text, photo,
  camera, more-tools, recordings, undo, and redo.
- Pen settings with pen styles, pressure, pressure curve, colors, profiles,
  and advanced controls.
- On-device Google ML Kit handwriting recognition with Turkish and English
  models, plus optional remote transcription fallback.
- Handwriting indexing for note search.
- Audio recording storage, playback, deletion, and backup/restore handling.
- Template categories, topics, previews, and notebook creation flow.

## Explicit limits

`Assets.car`, compiled `.nib` files, Apple Core ML models and Goodnotes binaries
remain evidence sources only. The selected fonts drive Noteva typography and
the selected SVGs drive matching gallery previews through a pattern renderer.
The subsequent recovered-template integration embeds prepared SVG backgrounds
in new notes, not just previews. All 41 available built-in SVGs are now wired as
13 papers and 28 covers; see `recovered-templates.md` for persistence and limits.
The IPA archive has malformed ZIP records; an earlier extraction reported 605
members could not be recovered; those missing members remain unclaimed.

## Resource verification, 2026-10-20

REA decoded a bounded subset of 64 Interface Builder documents, including the
library row resources. Evidence:
`ev_293b6201850b6b68e517d9ffb0269500edf60f49ec472d91f4974cf04c707fdb`.
The graph is partial and does not establish runtime pixel geometry. A row's
stored font references are `.SFUI-Regular`, size 14 for its title and size 11
for its caption. Roobert's presence in the design-system bundle does not prove
that every Goodnotes screen uses Roobert. Apple system fonts were not found as
standalone font files in the inspected package.

The selected `grid.svg` declares 16-unit tiles and 0.5-unit lines;
`ruledNarrow.svg` declares a 16-unit repeat and `ruledWide.svg` a 25-unit repeat.
The renderer reads those values from the bundled XML, rather than replacing
them with guessed constants. Unknown assets and failed reads retain Noteva's
existing preview fallback.
