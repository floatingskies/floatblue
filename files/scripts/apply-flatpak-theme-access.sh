#!/usr/bin/bash
set -euo pipefail

# Let Flatpak apps see the Flat Remix themes and icons.
#
# A GTK app inside the sandbox has no /usr/share/themes or /usr/share/icons,
# so without this it falls back to Adwaita even though the host is themed. The
# system-wide override is applied here at image build time; float-theme-sync
# re-applies it per user so switching theme or light/dark takes effect without
# root.
#
# GTK_THEME is also set per user by float-theme-sync (it has to change between
# the Light and Dark variants). It is deliberately *not* pinned here: a value
# baked into the system override would fight the per-user one on every switch.
#
# Only the *global* override is touched — per-application overrides set in the
# Flatseal GUI are left alone.

flatpak override --system \
    --filesystem=/usr/share/themes:ro \
    --filesystem=/usr/share/icons:ro

echo "Set system-wide Flatpak override: /usr/share/themes, /usr/share/icons"
