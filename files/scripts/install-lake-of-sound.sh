#!/usr/bin/bash

set -eou pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# The Lake of Sound collection is installed at /usr/share/backgrounds/Lake of Sound
# by the system files module. Register it with GNOME's wallpaper picker.
"$SCRIPT_DIR/generate-gnome-wallpaper-xml.sh" "/usr/share/backgrounds/Lake of Sound" lake-of-sound "Lake of Sound"
