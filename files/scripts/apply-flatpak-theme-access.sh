#!/usr/bin/bash
set -eou pipefail

# Flatpak apps could not see the theme, and the reason was in an override that
# never worked:
#
#   flatpak override --system --filesystem=/usr/share/themes:ro
#
# Flatpak reserves /usr for the runtime's own files, so it refuses that mount.
# At every app launch:
#
#   F: "/usr/share/themes" not shared with sandbox: Path "/usr" is reserved
#
# and inside the sandbox /usr/share/themes holds only the runtime's themes,
# Default and Emacs. GTK3 apps looked fine because GTK_THEME is an environment
# variable and the per-user override sets it. GTK4 and libadwaita ignore
# GTK_THEME entirely and read gtk-theme-name from dconf, and neither the theme
# directory nor ~/.config/gtk-4.0/settings.ini was visible, so every libadwaita
# app in a sandbox came up plain Adwaita.
#
# What works: the host's /usr is always bind-mounted read-only at
# /run/host/usr, it is just not on XDG_DATA_DIRS. Adding it there puts the real
# themes on the search path, and xdg-config/N exposes the per-user GTK config
# directory that carries settings.ini and the libadwaita overlay.

flatpak override --system \
    --filesystem=xdg-config/gtk-3.0:ro \
    --filesystem=xdg-config/gtk-4.0:ro \
    --env=XDG_DATA_DIRS=/app/share:/usr/share:/usr/share/runtime/share:/run/host/user-share:/run/host/share:/run/host/usr/share

# Drop the refused mounts if an older image already set them. They linger in the
# override because flatpak stores them happily and only complains at launch.
if flatpak override --system --show 2>/dev/null | grep -q '/usr/share/themes'; then
    flatpak override --system --reset >/dev/null 2>&1 || true
    flatpak override --system \
        --filesystem=xdg-config/gtk-3.0:ro \
        --filesystem=xdg-config/gtk-4.0:ro \
        --env=XDG_DATA_DIRS=/app/share:/usr/share:/usr/share/runtime/share:/run/host/user-share:/run/host/share:/run/host/usr/share
fi

# Check it the way an app would see it, not the way flatpak stores it.
shown=$(flatpak override --system --show 2>/dev/null || true)
if [[ $shown == *"/usr/share/themes"* ]]; then
    echo "error: the refused /usr/share/themes mount is still in the override" >&2
    exit 1
fi
if [[ $shown != *"run/host/usr/share"* ]]; then
    echo "error: XDG_DATA_DIRS in the override does not expose the host themes" >&2
    exit 1
fi

echo "Set system-wide Flatpak override: host themes on XDG_DATA_DIRS, xdg-config/gtk-3.0 and gtk-4.0"
