#!/usr/bin/env bash

# Night versions of the Tails wallpapers, and a gentle pass on the day ones.
#
# The images are committed rather than generated at build time, same as the
# Floatblue set. This stays so the recipe is reproducible and tweakable.
#
# The night look is a per-channel grade rather than a duotone. The obvious way
# to make something look like night is to drop it to grayscale and map it between
# two blues, and that is exactly what is wrong with it: it takes the colour out
# entirely, and a wallpaper with no colour in it is a wallpaper with no subject.
#
# So the channels are scaled separately instead. Red is pulled down hardest,
# green a little less, blue barely at all. Warm things stay warm but dim, and
# everything that was already cool goes deeper, which reads as moonlight without
# touching saturation. A small blue colorize over the top ties the two together.
#
# Measured on thonk.jpg, mean luminance 0.83 going to 0.49. Not a dark wallpaper
# in the numbers, and deliberately so: pushing it further started crushing the
# fox into the background, since the source art is a flat pastel with no real
# blacks to work with.

set -eou pipefail

DIR="${1:?usage: $0 <tails-dir>}"

cd "$DIR"

night() {
    magick "$1" -colorspace sRGB \
        -sigmoidal-contrast 3,48% \
        -channel R -evaluate multiply 0.36 +channel \
        -channel G -evaluate multiply 0.42 +channel \
        -channel B -evaluate multiply 0.76 +channel \
        -modulate 100,100,100 \
        -fill '#16264f' -colorize 12 \
        -sigmoidal-contrast 4,32% \
        -quality 88 "$2"
}

# The day version is barely touched: a touch more contrast, a whisper of blue,
# and saturation nudged up to offset the fact that everything else is dimmer.
# A wallpapers table set to mean 0.83 is genuinely unpleasant to look at on a
# bright desktop, so this is a small correction rather than a restyle.
day() {
    magick "$1" -colorspace sRGB \
        -sigmoidal-contrast 2,48% \
        -channel R -evaluate multiply 0.93 +channel \
        -channel G -evaluate multiply 0.97 +channel \
        -channel B -evaluate multiply 1.00 +channel \
        -modulate 100,112,100 \
        -fill '#8fb4e8' -colorize 6 \
        -quality 88 "$2"
}

for name in thonk with-cap; do
    if [[ ! -f $name.jpg ]]; then
        echo "error: $name.jpg not found in $DIR" >&2
        exit 1
    fi
    night "$name.jpg" "${name}_dark.jpg"
    day "$name.jpg" "${name}_light.jpg"
    printf '  %-16s light %s dark %s\n' "$name" \
        "$(magick "${name}_light.jpg" -format '%[fx:int(mean*100)]%%' info:)" \
        "$(magick "${name}_dark.jpg" -format '%[fx:int(mean*100)]%%' info:)"
done

echo "Tails night and day pairs written to $DIR"
echo "The originals are left alone. Remove them by hand once the pairs look right,"
echo "or install-wallpapers.sh will offer the same picture twice."
