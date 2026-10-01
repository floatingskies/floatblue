#!/usr/bin/bash

set -eou pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

BACKGROUNDS_DIR=/usr/share/backgrounds
PROPS_DIR=/usr/share/gnome-background-properties
COLLECTION="Tails"
OVERRIDE=/usr/share/glib-2.0/schemas/zz99-float-wallpaper.gschema.override

mkdir -p "$BACKGROUNDS_DIR"
find "$BACKGROUNDS_DIR" -mindepth 1 -maxdepth 1 ! -name "$COLLECTION" \
    -exec rm -rf {} +

if [[ -d "$PROPS_DIR" ]]; then
    find "$PROPS_DIR" -mindepth 1 -delete
fi

"$SCRIPT_DIR/generate-gnome-wallpaper-xml.sh" \
    "$BACKGROUNDS_DIR/$COLLECTION" tails "$COLLECTION"

mapfile -t candidates < <(find "$BACKGROUNDS_DIR/$COLLECTION" -type f \
    \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) \
    | sort)

if ((${#candidates[@]} == 0)); then
    echo "error: no images in $BACKGROUNDS_DIR/$COLLECTION" >&2
    exit 1
fi

picked=${candidates[RANDOM % ${#candidates[@]}]}

{
    printf '[org.gnome.desktop.background]\n'
    printf "picture-uri='file://%s'\n" "$picked"
    printf "picture-uri-dark='file://%s'\n" "$picked"
    printf "picture-options='zoom'\n"
} > "$OVERRIDE"

glib-compile-schemas /usr/share/glib-2.0/schemas

echo "Wallpapers: only $COLLECTION (${#candidates[@]} images) remains"
echo "Wallpapers: default picked at build time -> ${picked##*/}"
