#!/usr/bin/env bash
# Installs and applies GNOME Glass for the current user (no sudo).
#
#   ./install.sh                 install and apply everything
#   ./install.sh --no-apply      only copy the files
#   ./install.sh --no-gtk4       leave ~/.config/gtk-4.0/gtk.css alone
#   ./install.sh --no-wallpaper  don't change the wallpaper
#   ./install.sh --no-follow     don't switch Shell/GTK3 with light/dark mode
#   ./install.sh --no-flatpak    don't give Flatpak apps access to gtk.css
#   ./install.sh --no-cursors    keep your current mouse cursor
set -euo pipefail

SRC="$(dirname "$(readlink -f "$0")")"

APPLY=1 GTK4=1 WALLPAPER=1 FOLLOW=1 FLATPAK=1 CURSORS=1
for arg in "$@"; do
  case "$arg" in
    --no-apply)     APPLY=0 ;;
    --no-gtk4)      GTK4=0 ;;
    --no-wallpaper) WALLPAPER=0 ;;
    --no-follow)    FOLLOW=0 ;;
    --no-flatpak)   FLATPAK=0 ;;
    --no-cursors)   CURSORS=0 ;;
    -h|--help)      sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $arg" >&2; exit 1 ;;
  esac
done

THEMES_DIR="$HOME/.themes"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
STATE_DIR="$DATA_DIR/gnomeglass"
BG_DIR="$DATA_DIR/backgrounds/gnomeglass"
CURSOR_THEME=GNOMEGlass-Cursors
CURSOR_DIR="$DATA_DIR/icons/$CURSOR_THEME"
GTK4_CSS="$CONFIG_DIR/gtk-4.0/gtk.css"
FOLLOW_BIN="$HOME/.local/bin/gnomeglass-follow-scheme"
AUTOSTART="$CONFIG_DIR/autostart/gnomeglass-follow-scheme.desktop"
FLATPAK_OVERRIDES="$DATA_DIR/flatpak/overrides/global"
USER_THEME_UUID=user-theme@gnome-shell-extensions.gcampax.github.com
LOCK_UUID=gnomeglass-lockscreen@gnomeglass
EXT_DIR="$DATA_DIR/gnome-shell/extensions"
MARKER='GNOME Glass — GTK 4 / libadwaita'

step() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m warning:\033[0m %s\n' "$*"; }

# --- Build ------------------------------------------------------------------

if command -v sassc >/dev/null 2>&1; then
  step "Building the theme"
  "$SRC/build.sh" >/dev/null
elif [[ ! -d "$SRC/themes/GNOMEGlass" ]]; then
  echo "error: sassc not found and there is no prebuilt theme in themes/" >&2
  exit 1
fi

# The cursors are not in the repository (they weigh 11 MB): render them here
# if the build did not, or skip them when librsvg's Python bindings are missing.
if (( CURSORS )) && [[ ! -d "$SRC/themes/$CURSOR_THEME" ]]; then
  if python3 -c 'import cairo, gi; gi.require_version("Rsvg", "2.0")' 2>/dev/null; then
    step "Rendering the cursors"
    "$SRC/tools/make-cursors" "$SRC/themes/$CURSOR_THEME"
  else
    warn "python3-cairo or librsvg not found; keeping your current mouse cursor."
    CURSORS=0
  fi
fi

# --- Files ------------------------------------------------------------------

step "Copying themes to $THEMES_DIR"
mkdir -p "$THEMES_DIR" "$STATE_DIR"
for name in GNOMEGlass GNOMEGlass-Dark; do
  rm -rf "${THEMES_DIR:?}/$name"
  cp -r "$SRC/themes/$name" "$THEMES_DIR/$name"
done

if (( CURSORS )); then
  step "Installing the cursor theme"
  mkdir -p "$(dirname "$CURSOR_DIR")"
  rm -rf "${CURSOR_DIR:?}"
  cp -r "$SRC/themes/$CURSOR_THEME" "$CURSOR_DIR"
fi

# User Themes is disabled when the screen locks; this extension keeps the theme there
step "Installing the lock screen extension"
mkdir -p "$EXT_DIR"
rm -rf "${EXT_DIR:?}/$LOCK_UUID"
cp -r "$SRC/extras/$LOCK_UUID" "$EXT_DIR/$LOCK_UUID"

if (( GTK4 )); then
  step "Installing the libadwaita override to $GTK4_CSS"
  mkdir -p "$(dirname "$GTK4_CSS")"
  if [[ -f "$GTK4_CSS" ]] && ! grep -q "$MARKER" "$GTK4_CSS"; then
    cp "$GTK4_CSS" "$STATE_DIR/gtk4-gtk.css.backup"
    warn "your previous gtk.css was saved to $STATE_DIR/gtk4-gtk.css.backup"
  fi
  cp "$SRC/themes/GNOMEGlass/gtk-4.0/libadwaita.css" "$GTK4_CSS"
fi

# Flatpak apps only see gtk.css with read access to ~/.config/gtk-4.0.
# The marker in $STATE_DIR tells uninstall.sh that we granted it.
if (( GTK4 && FLATPAK )) && command -v flatpak >/dev/null 2>&1 &&
   ! grep -qs '^filesystems=.*xdg-config/gtk-4\.0' "$FLATPAK_OVERRIDES"; then
  step "Giving Flatpak apps access to gtk.css"
  flatpak override --user --filesystem=xdg-config/gtk-4.0:ro
  touch "$STATE_DIR/flatpak-override"
fi

if (( WALLPAPER )); then
  step "Installing wallpapers"
  mkdir -p "$BG_DIR" "$DATA_DIR/gnome-background-properties"
  cp "$SRC"/wallpapers/*.svg "$BG_DIR/"
  cat > "$DATA_DIR/gnome-background-properties/gnomeglass.xml" <<EOF
<?xml version="1.0"?>
<!DOCTYPE wallpapers SYSTEM "gnome-wp-list.dtd">
<wallpapers>
  <wallpaper deleted="false">
    <name>GNOME Glass Lumen</name>
    <filename>$BG_DIR/gnomeglass-day.svg</filename>
    <filename-dark>$BG_DIR/gnomeglass-night.svg</filename-dark>
    <options>zoom</options>
    <shade_type>solid</shade_type>
    <pcolor>#4fa3f0</pcolor>
    <scolor>#ffd6bf</scolor>
  </wallpaper>
</wallpapers>
EOF
fi

if (( FOLLOW )); then
  step "Installing automatic light/dark switching"
  mkdir -p "$(dirname "$FOLLOW_BIN")" "$(dirname "$AUTOSTART")"
  install -m 755 "$SRC/extras/gnomeglass-follow-scheme" "$FOLLOW_BIN"
  cat > "$AUTOSTART" <<EOF
[Desktop Entry]
Type=Application
Name=GNOME Glass: follow light/dark mode
Exec=$FOLLOW_BIN
NoDisplay=true
X-GNOME-Autostart-enabled=true
EOF
fi

(( APPLY )) || { step "Done (not applied)."; exit 0; }

# --- Apply ------------------------------------------------------------------

# Save the current settings once, so uninstall.sh can restore them.
if [[ ! -f "$STATE_DIR/previous-settings" ]]; then
  {
    echo "gtk-theme=$(gsettings get org.gnome.desktop.interface gtk-theme)"
    echo "button-layout=$(gsettings get org.gnome.desktop.wm.preferences button-layout)"
    echo "picture-uri=$(gsettings get org.gnome.desktop.background picture-uri)"
    echo "picture-uri-dark=$(gsettings get org.gnome.desktop.background picture-uri-dark)"
    if gsettings list-keys org.gnome.shell.extensions.user-theme >/dev/null 2>&1; then
      echo "shell-theme=$(gsettings get org.gnome.shell.extensions.user-theme name)"
    fi
    echo "cursor-theme=$(gsettings get org.gnome.desktop.interface cursor-theme)"
  } > "$STATE_DIR/previous-settings"
elif ! grep -q '^cursor-theme=' "$STATE_DIR/previous-settings"; then
  # Installed before the cursors existed: record the cursor now
  echo "cursor-theme=$(gsettings get org.gnome.desktop.interface cursor-theme)" >> "$STATE_DIR/previous-settings"
fi

case "$(gsettings get org.gnome.desktop.interface color-scheme)" in
  *dark*) THEME=GNOMEGlass-Dark ;;
  *)      THEME=GNOMEGlass ;;
esac

step "Applying $THEME"
gsettings set org.gnome.desktop.interface gtk-theme "$THEME"
gsettings set org.gnome.desktop.wm.preferences button-layout 'appmenu:minimize,maximize,close'
(( CURSORS )) && gsettings set org.gnome.desktop.interface cursor-theme "$CURSOR_THEME"

if gnome-extensions info "$USER_THEME_UUID" >/dev/null 2>&1; then
  gnome-extensions enable "$USER_THEME_UUID" || true
  gsettings set org.gnome.shell.extensions.user-theme name "$THEME"

  # Add the lock screen extension to the list without touching the others.
  # The Shell only picks up new extensions at the next login.
  enabled=$(gsettings get org.gnome.shell enabled-extensions)
  if [[ $enabled != *"'$LOCK_UUID'"* ]]; then
    case "$enabled" in
      "@as []"|"[]") enabled="['$LOCK_UUID']" ;;
      *)             enabled="${enabled%]}, '$LOCK_UUID']" ;;
    esac
    gsettings set org.gnome.shell enabled-extensions "$enabled"
  fi
  gnome-extensions info "$LOCK_UUID" >/dev/null 2>&1 ||
    warn "log out and back in for the theme to apply to the lock screen too."
else
  warn "User Themes extension not found; the Shell theme was not applied."
  warn "Fedora: sudo dnf install gnome-shell-extension-user-theme"
fi

if (( WALLPAPER )); then
  gsettings set org.gnome.desktop.background picture-uri "file://$BG_DIR/gnomeglass-day.svg"
  gsettings set org.gnome.desktop.background picture-uri-dark "file://$BG_DIR/gnomeglass-night.svg"
fi

if (( FOLLOW )); then
  pkill -f "$FOLLOW_BIN" 2>/dev/null || true
  setsid "$FOLLOW_BIN" >/dev/null 2>&1 < /dev/null &
fi

step "Done! Apps that are already open need to be reopened to pick up the new look."
