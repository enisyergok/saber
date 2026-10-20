# Recovered packaged resources

Source: the user-supplied `Goodnotes-6-v6.5.20-iosvizor.ipa`.
Archive SHA-256:
`4e06c8e0333e3029d99cfa98cd98f36572bdbe1af71c96b5243b54521c5f0b6e`.

- `fonts/`: five unchanged Roobert TTFs from
  `Payload/Goodnotes.app/GN6DesignSystem_GN6DesignSystem.bundle/`.
- `papers/`: six unchanged SVGs from
  `Payload/Goodnotes.app/GNDynamicTemplates_GNDynamicTemplates.bundle/`.

All eleven destination files were SHA-256 compared with the extracted source
files on 2026-10-20; all eleven matched. Font declarations are in `pubspec.yaml`.
The SVG subset renderer consumes the actual paper XML for gallery previews;
saved document backgrounds still use Noteva's existing implementation.

This is a selected-resource integration, not a claim that all Goodnotes assets,
compiled catalogs, screen layouts or proprietary runtime components are present.
See `docs/goodnotes-feature-map.md` for extraction and analysis limits.
