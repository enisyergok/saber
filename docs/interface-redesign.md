# Notebook interface revision 1

Reference: Goodnotes' public “Improved User Interface” guide
https://support.goodnotes.com/hc/en-us/articles/13682253498767-Improved-User-Interface

This is an original Noteva implementation of public document-library and
editor layout patterns, not extracted Goodnotes code, artwork, or branding.
The product keeps its own navy/cyan mark, copy, and component tokens while
using familiar note-taking ergonomics.

## Visible changes

- A shared library/search header, creation menu, larger folder and notebook
  previews, and full-width phone navigation.
- Phone dashboard now uses the same library content as the tablet dashboard.
- Editor tabs, document actions, and drawing tools occupy separate rows.
  Pencil, highlighter and shapes are directly accessible; undo/redo stay in
  the toolbar. Contextual controls have reserved space above the first page.
- Pen settings have basic, advanced and saved-profile tabs.
- Template categories use a sidebar on tablets and scrollable chips on phones.
- Notebook creation has labeled tabs on phones and icon categories on tablets.
- Settings use category/detail panes on tablets and grouped cards on phones.
- Library folder cards use compact paper surfaces, while the editor keeps a
  quiet neutral chrome and makes the selected tool the visual anchor.

## Interaction model

Implemented interaction structure:

- document tabs remain separate from navigation and tool rows;
- selection controls are hosted by the existing editor overlay;
- the library uses a persistent search surface, creation actions, folders,
  recent documents, and template categories.

Exact visual matching is not verified. Goodnotes 6.5.20 and the current
Goodnotes interface differ; reference screenshots for the chosen version
are needed before asserting layout parity. Automatic return to selection
after inserting content has not been verified by this UI pass.

## Upgrade behavior

`Stows.migrateInterface` enables the fixed editor and dashboard once, after
preferences are read. This is necessary because older releases persisted the
floating toolbar default, hiding changes to the fixed editor. Revision 1 does
not reset drawing preferences, notes, accounts, or later layout choices.

## Verification

`interface_redesign_test.dart` checks layout at 390 and 1280 pixels, tool
selection, migration idempotence and settings navigation. The build workflow
runs it with existing dashboard, floating-editor, creation and pen-settings
tests before publishing an APK. `CAPTURE_UI=true` with `--update-goldens`
produces review images; these are review captures, not an automatic assertion
that the design matches Goodnotes.

The alternative floating/legacy layouts remain selectable. Handwriting feel,
PDF rendering and device-specific stylus performance require device testing;
this interface work does not establish parity with another application's
features or latency.
