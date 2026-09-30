#!/usr/bin/bash

set -eou pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

curl -fL --retry 5 --retry-delay 5 --retry-all-errors \
  https://downloads.frame.work/assets/framework-laptop12-wallpaper-pack.zip > /tmp/framework-12-wallpapers.zip

mkdir -p /usr/share/backgrounds/framework
cd /usr/share/backgrounds/framework
unzip /tmp/framework-12-wallpapers.zip

# Register the collection with GNOME's wallpaper picker.
"$SCRIPT_DIR/generate-gnome-wallpaper-xml.sh" /usr/share/backgrounds/framework framework-wallpapers "Framework"