#!/usr/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

curl -fL --retry 5 --retry-delay 5 --retry-all-errors \
  https://system76.com/content/downloads/System76-Wallpapers.zip > /tmp/System76-Wallpapers.zip
mkdir -p /usr/share/backgrounds/system76
cd /usr/share/backgrounds/system76
unzip /tmp/System76-Wallpapers.zip

# Register the collection with GNOME's wallpaper picker.
"$SCRIPT_DIR/generate-gnome-wallpaper-xml.sh" /usr/share/backgrounds/system76 system76-wallpapers "System76"