#!/usr/bin/bash
set -euo pipefail

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
    rm -rf "${dst:?}/assets"
    if [[ -d "$src/$version/assets" ]]; then
        cp -a "$src/$version/assets" "$dst/assets"
    fi
    echo "Seeded $dst with $THEME"
done

# Same reasoning as float-theme-sync, seeded rather than applied: a fresh
# account has no color-scheme change to trigger anything, so the libadwaita
# overlay has to already be sitting in the skel.
skel=/etc/skel/.config/gtk-4.0
if [[ -s "$src/libadwaita/gtk.css" ]]; then
    mkdir -p "$skel"
    cp -a "$src/libadwaita/gtk.css" "$skel/gtk.css"
    rm -rf "${skel:?}/assets"
    if [[ -d $src/libadwaita/assets ]]; then
        cp -a "$src/libadwaita/assets" "$skel/assets"
    fi
    echo "Seeded $skel/gtk.css from the libadwaita overlay"
else
    echo "error: $src/libadwaita/gtk.css is missing" >&2
    exit 1
fi
