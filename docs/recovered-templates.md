# Packaged paper and cover integration

## Connected resources

The SQLite template catalogue is also embedded as immutable metadata in
`lib/data/notebooks/recovered_catalog.dart`. It contains all 1,284 rows from
the recovered `templates` table joined with `documents` and `attachments`.
Each row has a stable `gn-<template UUID>` id, document/name/category,
orientation, canvas dimensions, page number, attachment provenance, source
kind, and flash-card/dynamic flags. The 13 recovered paper SVGs are linked to
matching records; 587 catalogue rows resolve to a safe SVG source and can be
created directly. The remaining records are shown as catalogue-only entries;
52 linked ZIP attachments are now statically unpacked into 52 template SVGs
and 170 CSS source files. PDF and element sources remain metadata-only when no
safe in-app renderer is available.

The source generator is `tool/generate_recovered_catalog.mjs`. It reads the
offline SQLite snapshot and attachment headers only; it never executes
`layout.js`, copies executable package code into the app, or runs an attachment.

All 41 recovered SVGs from `GNDynamicTemplates_GNDynamicTemplates.bundle` are
included: 13 paper variants and 28 covers. Original file hashes are retained in
`assets/goodnotes/papers/SOURCES.json`. The same SVG text is embedded in
`recovered_sources.dart` for synchronous preview/cover painting; there is no
asset-loading race when a thumbnail is requested.

The six previously selected papers retain their existing IDs. Seven additional
column/Cornell papers have `pkg-` IDs; all thirteen appear under Packaged papers.
The 28 recovered covers appear in the notebook wizard's Packaged covers group.
Existing native papers, covers, defaults and IDs remain available.

## Safe ZIP template extraction

The generator reads ZIP central directories and supports only stored/deflated
entries. It extracts the root `template.svg` and `themes/**/*.css` entries to
`assets/goodnotes/catalog/`, with stable attachment-based filenames. The
selected default theme CSS is embedded into the extracted SVG for preview;
the original CSS files are also retained as catalog metadata assets. Paths are
sanitized, CRC and size limits are checked, and encrypted, ZIP64, traversal,
unsupported-compression and oversized entries are rejected. `layout.js`,
`__MACOSX` metadata and all other package members are never read or copied.

`PackagedPaperPreview` renders these catalog SVG assets with `flutter_svg`; the
existing 41 recovered SVG resources continue using their original synchronous
renderer.

## One prepared drawing, not a preview-only substitution

`RecoveredTemplates.render` resolves the recovered layout formulas at the
selected page size, materializes percentage rectangle geometry and flattens
pattern fills. It retains grouped fills and gradient definitions. Custom paper
colours replace only the paper's background. Unsupported resources and unsafe
sizes are rejected. No target JavaScript, network resource or app binary runs.

The prepared SVG is used for the preview geometry and embedded as a
`SvgEditorImage` background in the note's ordinary asset store. Saving/reopening
therefore uses the document's own SVG, not a later lookup of a bundled template.
The optional `templateResource` image field identifies a paper background;
ordinary imported SVGs are not automatically copied to new pages.

New/inserted pages inherit a prepared paper. Paper alone counts as an empty
page, so trailing-page cleanup still works. The single blank-paper page is
retained on PDF export rather than producing an empty PDF. The PDF exporter
continues using the existing screenshot-based background pipeline; this change
does not claim vector-only PDF output.

Covers remain notebook-card metadata, not writable first pages. The source cover
geometry is drawn without adding Noteva's older spine/title-label decoration.
Name/title metadata is retained, but those words are not painted over recovered
artwork. Cover IDs round-trip through the existing NoteCover representation.

## Bounds of fidelity

This implements the recovered package's built-in sources, not Goodnotes' online
marketplace catalogue. Some original SVG comments explicitly mention unavailable
pencil decoration; those source gaps remain unclaimed. Dynamic formulas are
ported from the available scripts, not measured from a running Goodnotes app.
Screen layouts, animations and other menus are outside this resource unit.

## Verification

- Regression test reproduced Cornell's missing cue divider before implementation.
- All 41 SVGs compile at four page formats/orientations (164 combinations).
- Numeric tests independently check column/gutter layout and paper-colour scope.
- Contact sheets exercise actual rectangle, circle, alpha and gradient drawing.
- CI checks editor setup, SVG asset serialization/reload, inherited papers and PDF
  generation, alongside existing notebook wizard, covers and interface tests.

Generated captures are visual review material, not pixel-parity assertions
against Goodnotes screenshots.
