#!/usr/bin/bash

set -eou pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# The Floating Skies collection is installed at /usr/share/backgrounds/Floating Skies
# by the system files module. Register it with GNOME's wallpaper picker.
"$SCRIPT_DIR/generate-gnome-wallpaper-xml.sh" "/usr/share/backgrounds/Floating Skies" floating-skies "Floating Skies"
