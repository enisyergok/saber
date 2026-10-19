# Goodnotes package findings mapped to Noteva

The extracted IPA is used as a reference for behavior and information
architecture. Goodnotes binary, fonts, compiled asset catalogs, and model files
are not copied into Noteva.

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

`Assets.car`, compiled `.nib` files, proprietary font files, Apple Core ML
models, and Goodnotes binaries are evidence sources only. They are not runtime
dependencies of Noteva. The IPA archive has malformed ZIP records, so 605
members could not be recovered; those missing members remain unclaimed.
