#!/usr/bin/bash
set -euo pipefail

# Seed ~/.config/gtk-3.0 and ~/.config/gtk-4.0 for new accounts from the
# default Flat Remix Blue-Light theme.
#
# gsettings already covers apps that go through the GNOME settings portal, but
# plenty of native/RPM GTK apps read settings.ini and nothing else — that is
# what this puts there. /etc/skel is copied into $HOME on first login, so every
# new account gets themed without anyone running a command.
#
# float-theme-sync takes over from there and rewrites gtk-theme-name on every
# light/dark switch, so this only has to get the first login right.
#
# The seeded file carries the Light variant; if the user's first session is
# already dark, float-theme-sync corrects it a moment later.

THEME=Flat-Remix-GTK-Blue-Light
THEMES_DIR=/usr/share/themes

src="$THEMES_DIR/$THEME"
if [[ ! -d $src ]]; then
    echo "error: theme not found: $src" >&2
    echo "hint: install-flat-remix-themes.sh must run before this" >&2
    exit 1
fi

for version in gtk-3.0 gtk-4.0; do
    dst="/etc/skel/.config/$version"
    mkdir -p "$dst"
    printf '[Settings]\ngtk-theme-name=%s\n' "$THEME" >"$dst/settings.ini"
    # Keep the theme's assets/css alongside settings.ini so apps that resolve
    # relative paths (and any that ignore settings.ini) still find the theme.
    rm -rf "${dst:?}/assets"
    if [[ -d "$src/$version/assets" ]]; then
        cp -a "$src/$version/assets" "$dst/assets"
    fi
    echo "Seeded $dst with $THEME"
done
