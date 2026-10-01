#!/usr/bin/bash
set -euo pipefail

flatpak override --system \
    --filesystem=/usr/share/themes:ro \
    --filesystem=/usr/share/icons:ro

echo "Set system-wide Flatpak override: /usr/share/themes, /usr/share/icons"
