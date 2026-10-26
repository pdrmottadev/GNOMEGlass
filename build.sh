#!/usr/bin/env bash
# Compiles the SCSS/CSS sources in src/ into themes/GNOMEGlass and themes/GNOMEGlass-Dark,
# and renders the cursors into themes/GNOMEGlass-Cursors.
set -euo pipefail

cd "$(dirname "$(readlink -f "$0")")"

if ! command -v sassc >/dev/null 2>&1; then
  echo "error: sassc not found (Fedora: sudo dnf install sassc)" >&2
  exit 1
fi

OUT=themes
VERSION=$(cat VERSION)
GTK4_DEFAULT='resource:///org/gtk/libgtk/theme/Default'

display_name() { # GNOMEGlass-Dark -> "GNOME Glass Dark"
  local name=${1/GNOMEGlass/GNOME Glass}
  echo "${name/-/ }"
}

write_index() { # $1 = theme name
  cat > "$OUT/$1/index.theme" <<EOF
[Desktop Entry]
Type=X-GNOME-Metatheme
Name=$(display_name "$1")
Comment=Aero glass meets liquid glass, reimagined for GNOME 50+ (v$VERSION)
Encoding=UTF-8

[X-GNOME-Metatheme]
GtkTheme=$1
IconTheme=Adwaita
CursorTheme=Adwaita
ButtonLayout=appmenu:minimize,maximize,close
EOF
}

# GTK4 CSS: --glass-* variables generated from the palette + rules from src/gtk-4.0/gtk.css
gtk4_css() {
  sassc -t expanded src/gtk-4.0/palette.scss
  echo
  cat src/gtk-4.0/gtk.css
}

# Standalone GTK4 theme (GTK4 apps without libadwaita): Default base + overrides
write_gtk4_theme() { # $1 = destination, $2 = GTK4 base stylesheet
  {
    echo "@import url(\"$GTK4_DEFAULT/$2\");"
    echo
    gtk4_css
  } > "$1"
}

rm -rf "$OUT/GNOMEGlass" "$OUT/GNOMEGlass-Dark"

for name in GNOMEGlass GNOMEGlass-Dark; do
  mkdir -p "$OUT/$name/gnome-shell" "$OUT/$name/gtk-3.0" "$OUT/$name/gtk-4.0"
  write_index "$name"
done

# GNOME Shell
sassc -t expanded src/gnome-shell/gnome-shell.scss      "$OUT/GNOMEGlass/gnome-shell/gnome-shell.css"
sassc -t expanded src/gnome-shell/gnome-shell-dark.scss "$OUT/GNOMEGlass-Dark/gnome-shell/gnome-shell.css"

# GTK 3
sassc -t expanded src/gtk-3.0/gtk.scss      "$OUT/GNOMEGlass/gtk-3.0/gtk.css"
sassc -t expanded src/gtk-3.0/gtk-dark.scss "$OUT/GNOMEGlass/gtk-3.0/gtk-dark.css"
cp "$OUT/GNOMEGlass/gtk-3.0/gtk-dark.css"   "$OUT/GNOMEGlass-Dark/gtk-3.0/gtk.css"

# GTK 4
write_gtk4_theme "$OUT/GNOMEGlass/gtk-4.0/gtk.css"      gtk-light.css
write_gtk4_theme "$OUT/GNOMEGlass/gtk-4.0/gtk-dark.css" gtk-dark.css
write_gtk4_theme "$OUT/GNOMEGlass-Dark/gtk-4.0/gtk.css" gtk-dark.css
# libadwaita override (installed to ~/.config/gtk-4.0/gtk.css)
gtk4_css > "$OUT/GNOMEGlass/gtk-4.0/libadwaita.css"

# Cursors, rendered with librsvg. They are not committed; when PyGObject or
# librsvg are missing this is skipped, and install.sh keeps the current cursor.
if python3 -c 'import cairo, gi; gi.require_version("Rsvg", "2.0")' 2>/dev/null; then
  tools/make-cursors "$OUT/GNOMEGlass-Cursors"
fi

# Let GTK parse what we built: a broken rule is dropped without any warning.
# GTK needs a display for that, so this only runs inside a desktop session.
if [[ -n ${WAYLAND_DISPLAY:-}${DISPLAY:-} ]] && python3 -c 'import gi' 2>/dev/null; then
  tools/check-css 3 "$OUT"/GNOMEGlass/gtk-3.0/*.css
  tools/check-css 4 "$OUT"/GNOMEGlass/gtk-4.0/*.css
fi

echo "Theme built in $OUT/"
