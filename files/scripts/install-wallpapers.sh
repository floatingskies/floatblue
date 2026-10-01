#!/usr/bin/bash

set -eou pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

BACKGROUNDS_DIR=/usr/share/backgrounds
PROPS_DIR=/usr/share/gnome-background-properties
COLLECTION="Floatblue"
OVERRIDE=/usr/share/glib-2.0/schemas/zz99-float-wallpaper.gschema.override

mkdir -p "$BACKGROUNDS_DIR"
find "$BACKGROUNDS_DIR" -mindepth 1 -maxdepth 1 ! -name "$COLLECTION" \
    -exec rm -rf {} +

# PROPS_DIR is passed on purpose. Cleaning one directory and writing the XML to
# another only works by luck, since the generator falls back to the same default
# path this script happens to clean.
"$SCRIPT_DIR/generate-gnome-wallpaper-xml.sh" \
    "$BACKGROUNDS_DIR/$COLLECTION" floatblue "$COLLECTION" "$PROPS_DIR"

# Every pattern was drawn twice, once per appearance. Pairing them is the whole
# point: the desktop follows GNOME's day and night switch, so a wallpaper that
# is the same image on both sides loses half of it. One random pattern per build,
# light for the light appearance and dark for the dark one.
mapfile -t images < <(find "$BACKGROUNDS_DIR/$COLLECTION" -type f \
    \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) \
    | sort)

if ((${#images[@]} == 0)); then
    echo "error: no images in $BACKGROUNDS_DIR/$COLLECTION" >&2
    exit 1
fi

declare -A variant=()
for img in "${images[@]}"; do
    stem="${img%.*}"
    case "$stem" in
        *_light) variant["${stem%_light}"]="${variant["${stem%_light}"]:-}$img"$'\n' ;;
        *_dark)  variant["${stem%_dark}"]="${variant["${stem%_dark}"]:-}$img"$'\n' ;;
        *)       variant["${stem}"]="${variant["${stem}"]:-}$img"$'\n' ;;
    esac
done

paired=()
for stem in "${!variant[@]}"; do
    # ${stem##*/} strips the directories, so the collection has to go back on.
    # Without it this builds /usr/share/backgrounds/aurora instead of
    # /usr/share/backgrounds/Floatblue/aurora, finds no pair anywhere, and
    # quietly ships one image for both appearances.
    base="$BACKGROUNDS_DIR/$COLLECTION/${stem##*/}"
    have_light="" have_dark=""
    for ext in jpg jpeg png webp; do
        [[ -f "$base"_light."$ext" ]] && have_light="$base"_light."$ext"
        [[ -f "$base"_dark."$ext" ]] && have_dark="$base"_dark."$ext"
    done
    [[ -n $have_light && -n $have_dark ]] && paired+=("$have_light"$'\t'"$have_dark")
done

if ((${#paired[@]} == 0)); then
    # No light/dark pair anywhere, so fall back to any single image rather than
    # shipping an image with a broken wallpaper-uri.
    picked=${images[RANDOM % ${#images[@]}]}
    light=$picked
    dark=$picked
    echo "Wallpapers: no light/dark pairs found, using a single image"
else
    IFS=$'\t' read -r light dark <<<"${paired[RANDOM % ${#paired[@]}]}"
fi

{
    printf '[org.gnome.desktop.background]\n'
    printf "picture-uri='file://%s'\n" "$light"
    printf "picture-uri-dark='file://%s'\n" "$dark"
    printf "picture-options='zoom'\n"
} > "$OVERRIDE"

glib-compile-schemas /usr/share/glib-2.0/schemas

echo "Wallpapers: only $COLLECTION (${#images[@]} images, ${#paired[@]} light/dark pairs) remains"
echo "Wallpapers: default drawn at build time -> ${light##*/} + ${dark##*/}"
