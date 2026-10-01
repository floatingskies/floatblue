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
