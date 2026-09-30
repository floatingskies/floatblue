#!/usr/bin/bash
set -euo pipefail

# Grant Flatpak apps read access to the host theme and wallpaper directories.
#
# Without this, a GTK4 app inside a sandbox cannot see /usr/share/themes, so it
# falls back to Adwaita even though the host is running ZorinBlue-*. The
# override is applied system-wide here (image build time); `float-theme` re-applies
# it at the user level so a theme switch takes effect without root.
#
# Only the *global* override is touched — per-application overrides users set in
# the Flatseal GUI are left alone.

flatpak override --system \
    --filesystem=/usr/share/themes:ro \
    --filesystem=/usr/share/backgrounds:ro

echo "Set system-wide Flatpak override: /usr/share/themes, /usr/share/backgrounds"
