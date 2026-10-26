# Changelog

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[Semantic Versioning](https://semver.org/).

## 1.1.0 - 2026-10-26

### Added

- **Glass cursors** (`GNOMEGlass-Cursors`): white glass pointers with the Aero gloss and a fine
  dark outline, a glass ring with a blue arc for waiting, glass orbs for help, copy, link and
  "not allowed", and a glass magnifier for zoom. All the names GNOME and X11 apps ask for, in
  sizes 24 to 96. `install.sh` installs and selects them (`--no-cursors` skips that), and
  `uninstall.sh` puts your previous cursor back.
- `tools/make-cursors`, which draws the cursors and writes the Xcursor files. `build.sh` runs it,
  and so does `install.sh` when the cursors are missing, since they are not in the repository.

### Changed

- **Floating sidebar:** it now sits in a 6px frame of the title bar glass on all sides, which
  joins the title bar of the content with straight edges, with no gap at the corner (before,
  the title bar ended in a straight cut next to the sidebar). Its title lines up with the
  content's title (it sat 6px lower), and the light spot in the corner of the content's title
  bar is gone, so the joint has no bright patch.
- **Dock and dash:** hovered icons, and the focused app in Dash to Dock, light up in a round
  glass bubble. In light mode the bubble is a shade darker than the dock, so light icons stay
  visible.
- **Close button:** it is now a round orb like minimize and maximize, still red ("ember").

### Fixed

- Hovering an icon in the dock also lit up the whole square tile behind it.
- Maximized and tiled windows kept rounded corners: the theme's `--window-radius` has user
  priority and overrode libadwaita, which sets it to 0 for those windows.

## 1.0.0 - 2026-10-26

First release:
- GNOME Shell 50+ theme: floating glass islands in the top bar with the Activities orb, glass
  menus, quick settings, calendar and notifications, smoked glass OSD, Alt+Tab and tooltips,
  glass dash and search in the overview, Dash to Dock support, glass lock screen;
- the glass follows the system accent color in the Shell and in GTK4;
- GTK4/libadwaita override: accent-tinted title bars, orb and ember window controls, glass
  buttons lit from below on hover, floating sidebar, glass toggle groups, tabs, popovers and
  dialogs, progress bar shimmer;
- GTK3, with the same look and GNOME's default blue;
- "Lumen" day/night wallpapers and their generator;
- automatic light/dark switching;
- lock screen extension;
- install and uninstall scripts;
- `tools/check-css`, which parses the built GTK stylesheets with GTK during the build.
