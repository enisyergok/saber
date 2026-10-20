# Recovered catalogue integration, 2026-10-20

## Scope actually connected

29 original resources (28 SVGs and one PNG) are bundled as Flutter assets.
Library navigation, header actions, grid/list switches, favourite controls,
folder artwork and row actions now consume these resources instead of the
previous manually drawn paths. An unmapped `LibraryGlyph` falls back to a
visible platform icon instead of silently painting nothing.

The editor consumes recovered artwork for search, share, more, pen, pencil,
highlighter, lasso, eraser, text and image controls. Their existing callbacks,
tool-selection state and read-only checks are retained. This changes visuals,
not the Huawei ink pipeline or stored documents.

Monochrome controls follow the current IconTheme; source colours are retained
for document/folder artwork and the illustrated pen tools. SVG filters such as
inner shadows are unsupported by Flutter's SVG renderer; this is not a claim
of pixel-identical shadow rendering. Packed bitmap atlas renditions with
inconsistent decoded dimensions were excluded from the selected resources.

## Extraction boundary

REA `inspect_asset_catalog` was unavailable on this Windows host because it
requires macOS assetutil. Local extraction instead used
`https://github.com/xiongnemo/car-unpacker-py` at commit
`090837ee7d26363da0b96147e90584c6df9e9ccc`, with a local branch-node traversal
adapter and `lzfse 0.4.2.post1`. These results are independent-decoder output,
not REA assetutil Evidence.

The library catalogue contained 781 rendition records and exported 445 files;
the design-system catalogue contained 7,688 records and exported 2,497 files.
Export counts do not mean every rendition is supported or used by Noteva.
All 172 library SVG payloads parsed as SVG XML. Selected asset identities are
retained in SOURCES.json; full local manifests remain outside the app repo in
`goodnotes-catalog-export/`.

## Layout measurements actually applied

The retained classic library row graph is REA Evidence
`ev_28f6aa2775a0a1096dd60e3e7aadf902fe1ba4a4f13995e80779ffb4db1676f2`,
for `GN5App_GN5App.bundle/FoldersCollectionListItemCell.nib`.
Its stored bounds show a 73-unit row, a 70x57 cover view and 44x44 action buttons.
The 73-unit row and title/caption sizes 14/11 were already present. This change
aligns the cover slot and action buttons with those stored measurements.

The graph is bounded and static. It does not recover all runtime constraints,
all Swift-created screens, transitions, responsive variants or states. Editor
bar geometry and the notebook wizard are not claimed as recovered layouts.

## Verification

`test/library_catalog_test.dart` loads all 29 actual resources and verifies
their fixed icon slots, representative file bindings and unknown-icon fallback.
Its contact sheet is a rendered resource proof, not a full app screenshot.
`interface_redesign_test.dart` adds cover/action geometry assertions and list
captures at phone and tablet widths. CI still runs the existing editor action
and layout tests. Updating goldens produces review captures, not a comparison
against Goodnotes runtime screenshots.
