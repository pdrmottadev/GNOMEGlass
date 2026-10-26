#!/usr/bin/env bash
# Removes GNOME Glass and restores the settings saved by install.sh.
set -euo pipefail

DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
STATE_DIR="$DATA_DIR/gnomeglass"
GTK4_CSS="$CONFIG_DIR/gtk-4.0/gtk.css"
FOLLOW_BIN="$HOME/.local/bin/gnomeglass-follow-scheme"
LOCK_UUID=gnomeglass-lockscreen@gnomeglass
FLATPAK_OVERRIDES="$DATA_DIR/flatpak/overrides/global"
MARKER='GNOME Glass — GTK 4 / libadwaita'

step() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }

step "Stopping automatic switching"
pkill -f "$FOLLOW_BIN" 2>/dev/null || true
rm -f "$FOLLOW_BIN" "$CONFIG_DIR/autostart/gnomeglass-follow-scheme.desktop"

step "Removing the lock screen extension"
enabled=$(gsettings get org.gnome.shell enabled-extensions)
if [[ $enabled == *"'$LOCK_UUID'"* ]]; then
  enabled=${enabled//", '$LOCK_UUID'"/}
  enabled=${enabled//"'$LOCK_UUID', "/}
  enabled=${enabled//"'$LOCK_UUID'"/}
  gsettings set org.gnome.shell enabled-extensions "$enabled"
fi
rm -rf "${DATA_DIR:?}/gnome-shell/extensions/$LOCK_UUID"

step "Restoring settings"
if [[ -f "$STATE_DIR/previous-settings" ]]; then
  while IFS='=' read -r key value; do
    case "$key" in
      gtk-theme)        gsettings set org.gnome.desktop.interface gtk-theme "$value" ;;
      button-layout)    gsettings set org.gnome.desktop.wm.preferences button-layout "$value" ;;
      picture-uri)      gsettings set org.gnome.desktop.background picture-uri "$value" ;;
      picture-uri-dark) gsettings set org.gnome.desktop.background picture-uri-dark "$value" ;;
      shell-theme)      gsettings set org.gnome.shell.extensions.user-theme name "$value" ;;
      cursor-theme)     gsettings set org.gnome.desktop.interface cursor-theme "$value" ;;
    esac
  done < "$STATE_DIR/previous-settings"
else
  gsettings reset org.gnome.desktop.interface gtk-theme
  gsettings list-keys org.gnome.shell.extensions.user-theme >/dev/null 2>&1 &&
    gsettings reset org.gnome.shell.extensions.user-theme name
fi
[[ $(gsettings get org.gnome.desktop.interface cursor-theme) == "'GNOMEGlass-Cursors'" ]] &&
  gsettings reset org.gnome.desktop.interface cursor-theme

if [[ -f "$GTK4_CSS" ]] && grep -q "$MARKER" "$GTK4_CSS"; then
  step "Removing the libadwaita override"
  if [[ -f "$STATE_DIR/gtk4-gtk.css.backup" ]]; then
    mv "$STATE_DIR/gtk4-gtk.css.backup" "$GTK4_CSS"
  else
    rm -f "$GTK4_CSS"
  fi
fi

# Only undo the Flatpak access if install.sh granted it, and remove just that
# entry (--reset would wipe the user's other overrides).
if [[ -f "$STATE_DIR/flatpak-override" && -f "$FLATPAK_OVERRIDES" ]]; then
  step "Removing Flatpak access to gtk.css"
  sed -i -E '/^filesystems=/ s#(=|;)xdg-config/gtk-4\.0:ro;#\1#' "$FLATPAK_OVERRIDES"
  sed -i '/^filesystems=$/d' "$FLATPAK_OVERRIDES"
fi

step "Removing files"
rm -rf "$HOME/.themes/GNOMEGlass" "$HOME/.themes/GNOMEGlass-Dark" \
       "$DATA_DIR/icons/GNOMEGlass-Cursors" \
       "$DATA_DIR/backgrounds/gnomeglass" \
       "$DATA_DIR/gnome-background-properties/gnomeglass.xml" \
       "$STATE_DIR"

step "GNOME Glass removed."
