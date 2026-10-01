#!/usr/bin/bash
# Registers every image in a wallpaper directory with GNOME's wallpaper
# picker (Settings -> Appearance).
#
# GNOME only lists wallpapers referenced by an XML in
# /usr/share/gnome-background-properties; bare image files dropped into
# /usr/share/backgrounds are ignored. Collections shipped flat (as ours are,
# via the files module) therefore need one generated XML per directory.
#
# Usage:
#   generate-gnome-wallpaper-xml.sh <wallpaper-dir> <xml-name> [display-prefix]
#   [output-dir]
#
#   wallpaper-dir   directory to scan for images (recursive)
#   xml-name        base name of the generated file, e.g. "tails"
#   display-prefix  short label shown in front of each entry, e.g. "Tails"
#   output-dir      where to write the .xml (default: /usr/share/gnome-background-properties)

set -euo pipefail

wallpaper_dir="${1:?usage: $0 <wallpaper-dir> <xml-name> [display-prefix] [output-dir]}"
xml_name="${2:?usage: $0 <wallpaper-dir> <xml-name> [display-prefix] [output-dir]}"
display_prefix="${3:-}"
output_dir="${4:-/usr/share/gnome-background-properties}"

if [[ ! -d "$wallpaper_dir" ]]; then
    echo "error: wallpaper directory does not exist: $wallpaper_dir" >&2
    exit 1
fi

mkdir -p "$output_dir"
out="$output_dir/$xml_name.xml"

xml_escape() {
    sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e 's/"/\&quot;/g'
}

{
    printf '%s\n' '<?xml version="1.0" encoding="UTF-8"?>'
    # No DOCTYPE on purpose: GNOME resolves
    # /usr/share/backgrounds/gnome/gnome-wp-list.dtd, and this image deletes
    # /usr/share/backgrounds/gnome along with the Fedora/GNOME wallpapers, so
    # pointing at a DTD that is no longer on disk would only risk a parse error.
    printf '%s\n' '<wallpapers>'
    while IFS= read -r -d '' image; do
        name="${image##*/}"
        name="${name%.*}"
        name="${name//_/ }"
        name="${name//-/ }"
        if [[ -n "$display_prefix" ]]; then
            name="$display_prefix: $name"
        fi
        name="$(printf '%s' "$name" | xml_escape)"
        image="$(printf '%s' "$image" | xml_escape)"
        printf '  <wallpaper deleted="false">\n'
        printf '    <name>%s</name>\n' "$name"
        printf '    <filename>%s</filename>\n' "$image"
        printf '    <options>zoom</options>\n'
        printf '    <pcolor>#241f31</pcolor>\n'
        printf '    <scolor>#1c222f</scolor>\n'
        printf '  </wallpaper>\n'
    done < <(
        find "$wallpaper_dir" -type f \( \
            -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o \
            -iname '*.svg' -o -iname '*.webp' -o -iname '*.jxl' -o \
            -iname '*.avif' -o -iname '*.gif' \) -print0 | sort -z
    )
    printf '%s\n' '</wallpapers>'
} > "$out"

echo "Registered $(grep -c '<filename>' "$out") wallpaper(s) from $wallpaper_dir in $out"
