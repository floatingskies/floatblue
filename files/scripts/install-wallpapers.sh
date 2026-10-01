#!/usr/bin/bash
# Wallpapers: strip the Fedora/GNOME/Bluefin wallpapers out of the image and
# make the "Tails" collection the only one on offer, with one of its images
# picked at random as the first-boot default.
#
# The Tails images themselves are baked into the image by the files module
# (/usr/share/backgrounds/Tails), so nothing is downloaded at build time.
#
# Random is at *build* time: every rebuild / rebase picks a new default, and
# both images always show up in the GNOME wallpaper picker.

set -eou pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

BACKGROUNDS_DIR=/usr/share/backgrounds
PROPS_DIR=/usr/share/gnome-background-properties
COLLECTION="Tails"
OVERRIDE=/usr/share/glib-2.0/schemas/zz99-float-wallpaper.gschema.override

# 1. Drop every wallpaper that came with the base image. /usr/share/backgrounds
#    holds the Fedora set, the GNOME set (under gnome/) and Bluefin's own; our
#    Tails collection is the only thing that survives.
mkdir -p "$BACKGROUNDS_DIR"
find "$BACKGROUNDS_DIR" -mindepth 1 -maxdepth 1 ! -name "$COLLECTION" \
    -exec rm -rf {} +

# 2. Drop the GNOME wallpaper-picker entries too. Otherwise the picker keeps
#    listing XMLs whose <filename> now points at deleted files, which show up
#    as broken/blank previews.
if [[ -d "$PROPS_DIR" ]]; then
    find "$PROPS_DIR" -mindepth 1 -delete
fi

# 3. Register Tails with the picker.
"$SCRIPT_DIR/generate-gnome-wallpaper-xml.sh" \
    "$BACKGROUNDS_DIR/$COLLECTION" tails "$COLLECTION"

# 4. Pick one image at random and pin it as the first-boot default. Both
#    picture-uri and picture-uri-dark are set so the choice survives the
#    light/dark switch that float-theme-sync performs.
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
