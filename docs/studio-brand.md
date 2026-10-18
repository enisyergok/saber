# Marj Studio — Android identity

The launcher and app display name are **Marj Studio**. Package IDs, signing,
note formats, storage paths and backup names are deliberately unchanged.
This is an Android branding update; desktop/iOS launcher assets are not changed.

The new mark was generated with the built-in image generation tool, not the
API/CLI fallback. Source: `assets/icon/marj-studio-source.png`. The packaged
icon and in-app mark are `marj-studio.png` and `marj-studio-mark.png` alongside it.

Prompt:
> Use case: logo-brand. Asset type: production Android app icon foreground for a premium handwriting and notebook application named Marj Studio. Create one original, elegant sculptural M monogram subtly evoking two open notebook pages and a fountain-pen stroke. Understated luxury, geometric crisp silhouette, warm champagne-gold satin metal with extremely subtle tonal shading, robust thick forms readable at 32px. Transparent background, no tile or backdrop. Square image; center the entire symbol within the middle 48 percent of both canvas width and height, leaving truly empty transparent margins on all sides for Android adaptive-icon cropping. Straight-on 2D view, no perspective, no extruded depth, no cast shadow, no thin ornamental lines. Only the M symbol: no words, no app name, no slogan, no border, no watermark. Designed to sit on a deep midnight navy background.

`scripts/package_studio_icon.cjs` packages the generated artwork into five
Android densities and a white-alpha monochrome layer, with a navy background.
Run with Node and sharp 0.34.x available, then `node --test scripts/studio_icon.test.cjs`.
The pixel test verifies the mark stays in the circular adaptive-icon safe area.
Use this packager for the Android Marj Studio identity; the older
`make_marj_icon.py` and upstream `generate_icons.sh` generate legacy artwork.

Flutter uses the same artwork in the sidebar and About dialog; e-ink mode
tints the in-app mark with the theme's on-surface colour.
