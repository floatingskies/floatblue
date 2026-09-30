#!/usr/bin/bash

# Make the modern Plasma wallpapers and the historical KDE ones (from the
# kde-wallpapers and plasma-workspace-wallpapers packages) selectable in the
# GNOME background chooser, by flattening them into
# /usr/share/backgrounds/kde, then registering them with GNOME's wallpaper
# picker via an XML file.

set -eou pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p /usr/share/backgrounds/kde
find /usr/share/wallpapers -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) -exec cp -n {} /usr/share/backgrounds/kde/ \;
du -sh /usr/share/backgrounds/kde

"$SCRIPT_DIR/generate-gnome-wallpaper-xml.sh" /usr/share/backgrounds/kde kde-wallpapers "KDE"
