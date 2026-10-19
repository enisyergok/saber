# Noteva — app identity

The launcher and app display name are **Noteva**. Package IDs, signing,
note formats, storage paths and backup names are deliberately unchanged.
This is an Android branding update; desktop/iOS launcher assets are not changed.

The new mark was generated with the built-in image generation tool, not the
API/CLI fallback. The approved source artwork is `assets/icon/noteva-preview.png`;
the transparent adaptive foreground is `assets/icon/noteva-foreground-source.png`.

Prompt:
> Use case: logo-brand. Asset type: production mobile app icon for a premium handwriting and notebook application named Noteva. Use a clean ivory notebook page on a midnight-to-cobalt blue field with one confident turquoise-blue handwritten ink sweep. Minimal, flat, high-contrast, and readable at 32px. No letters, words, pen nib, extra lines, watermark, or busy ornament.

`scripts/package_studio_icon.cjs` packages the generated artwork into five
Android densities and a white-alpha monochrome layer, with a navy background.
Run with Node and sharp 0.34.x available, then `node --test scripts/studio_icon.test.cjs`.
The pixel test verifies the mark stays in the circular adaptive-icon safe area.
Use this packager for the Noteva identity; the older
`make_marj_icon.py` and upstream `generate_icons.sh` generate legacy artwork.

Flutter uses the same artwork in the sidebar and About dialog; e-ink mode
tints the in-app mark with the theme's on-surface colour.
