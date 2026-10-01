#!/usr/bin/bash

set -eou pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

BACKGROUNDS_DIR=/usr/share/backgrounds
PROPS_DIR=/usr/share/gnome-background-properties
OVERRIDE=/usr/share/glib-2.0/schemas/zz99-float-wallpaper.gschema.override

# Two collections. Floatblue is drawn from the theme's own palette and ships a
# light and a dark variant per pattern. Tails is the older set, kept because it
# sits well with the rest of the desktop, and because having images with no light
# and dark split at all is worth keeping in the picker.
#
# Everything else under /usr/share/backgrounds is removed. That is the point: the
# Fedora, GNOME and Bluefin collections are thousands of files of stock art.
COLLECTIONS=(Floatblue Tails)

mkdir -p "$BACKGROUNDS_DIR"

for c in "${COLLECTIONS[@]}"; do
    if [[ ! -d $BACKGROUNDS_DIR/$c ]]; then
        echo "error: collection missing: $BACKGROUNDS_DIR/$c" >&2
        exit 1
    fi
done

keep_expr=()
first=1
for c in "${COLLECTIONS[@]}"; do
    if ((first)); then
        keep_expr+=(-name "$c")
        first=0
    else
        keep_expr+=(-o -name "$c")
    fi
done

find "$BACKGROUNDS_DIR" -mindepth 1 -maxdepth 1 \
    ! \( "${keep_expr[@]}" \) \
    -exec rm -rf {} +

if [[ -d $PROPS_DIR ]]; then
    find "$PROPS_DIR" -mindepth 1 -delete
fi

# One XML per collection, so the picker groups them.
for c in "${COLLECTIONS[@]}"; do
    "$SCRIPT_DIR/generate-gnome-wallpaper-xml.sh" \
        "$BACKGROUNDS_DIR/$c" "${c,,}" "$c" "$PROPS_DIR"
done

images_in() {
    find "$BACKGROUNDS_DIR/$1" -type f \
        \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) \
        | sort
}

# One entry per wallpaper to choose from, as "light<TAB>dark".
#
# A Floatblue pattern with both variants becomes a pair, so light mode and dark
# mode get the matching image. The desktop already follows the day and night
# switch, and a wallpaper that is the same file on both sides throws that away.

declare -A consumed=()
choices=()

# Pairs first. This has to happen before the singles pass, because a dark
# variant that belongs to a pair must not also be offered on its own. Doing that
# weights every pattern twice and, worse, hands a light desktop a dark image.
for c in "${COLLECTIONS[@]}"; do
    while IFS= read -r light; do
        [[ $light == *_light.* ]] || continue
        stem="${light%.*}"
        ext="${light##*.}"
        dark="${stem%_light}_dark.$ext"
        [[ -f $dark ]] || continue
        choices+=("$light"$'\t'"$dark")
        # Both halves, not just the dark one: the light file is what this loop
        # matched on, so leaving it unmarked lets the singles pass offer it a
        # second time as an unpaired image.
        consumed["$light"]=1
        consumed["$dark"]=1
    done < <(images_in "$c")
done

# Then whatever is left: the Tails images, and any half of a pair whose other
# half happens to be missing.
for c in "${COLLECTIONS[@]}"; do
    while IFS= read -r img; do
        [[ -n ${consumed["$img"]:-} ]] && continue
        choices+=("$img"$'\t'"$img")
    done < <(images_in "$c")
done

if ((${#choices[@]} == 0)); then
    echo "error: no images in ${COLLECTIONS[*]}" >&2
    exit 1
fi

IFS=$'\t' read -r light dark <<<"${choices[RANDOM % ${#choices[@]}]}"

{
    printf '[org.gnome.desktop.background]\n'
    printf "picture-uri='file://%s'\n" "$light"
    printf "picture-uri-dark='file://%s'\n" "$dark"
    printf "picture-options='zoom'\n"
} > "$OVERRIDE"

glib-compile-schemas /usr/share/glib-2.0/schemas

echo "Wallpapers: ${COLLECTIONS[*]} kept, everything else removed"
echo "Wallpapers: ${#choices[@]} candidates, default drawn at build time -> ${light##*/} + ${dark##*/}"
[[ $light == "$dark" ]] && echo "Wallpapers: that one has no light/dark pair, used for both appearances"
exit 0
