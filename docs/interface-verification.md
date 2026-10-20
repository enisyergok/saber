# Noteva interface verification

Target: the classic Goodnotes 6 library supplied in the user's screenshots.
Newer Goodnotes interfaces are not a substitute for that version.

## Implemented in this change

- One shared vector navigation rail for Home, Documents, Favorites, Search,
  Shared and Templates. The Home entry is retained at the user's request.
- Shared light library chrome: white content, neutral rail, blue actions,
  pale-blue selection, 29px page titles, thin separators and 12px modal corners.
- Search, Favorites, Trash and Templates retain the same library frame.
- Tablet Settings opens inside the library frame and retains its category pane.
- Editor action colors, selected tab surface and floating-panel corners follow
  the same chrome tokens. E-ink retains its separate palette.
- Folder navigation displays the current path and a parent-folder action.
- Phone/tablet captures added for search, favorites and trash. Existing captures
  cover the library, editor, tool menus, templates, settings and notebook wizard.

## Verification boundaries

CI widget tests check behavior and overflow; generated screenshots are review
artifacts. `--update-goldens` does not compare against Goodnotes screenshots.
Build success is not proof of visual parity.

Only the supplied library screenshots are an exact visual reference in this
change. The other Goodnotes 6 screens, their open menus, fonts, animation timing
and pressed/disabled states have not been verified pixel-for-pixel.
The six-step Noteva notebook wizard and the pen-settings controls remain Noteva
implementations. Shared-document service is not connected. These are not claimed
to be a complete Goodnotes implementation.

Subsequent packaged-resource integration adds five recovered Roobert font
files and six paper SVG sources. The latter drive selected gallery previews.
This supplements the screenshot references, but the bounded NIB graph and
unconverted Apple asset catalogs do not establish full visual parity.

Local widget testing currently requires the missing Rust toolchain used by
super_native_extensions. GitHub Actions supplies the executable widget-test
and Android-build environment. Real Huawei touch response requires device testing.
