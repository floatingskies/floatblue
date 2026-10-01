#!/usr/bin/bash

set -eou pipefail

GTK_REF=919494f4f4ede88e2efb45cd48b98db7cc23f6ee
ICONS_REF=e7de6c346da46e008987228f363b0eae6e638637
SHELL_REF=95cb659507188db7d2ffdaa6f714db0e3555baf4

CACHE=/var/cache/flat-remix
THEMES_DIR=/usr/share/themes
ICONS_DIR=/usr/share/icons

mkdir -p "$CACHE" "$THEMES_DIR" "$ICONS_DIR"

fetch() {
    local repo=$1 ref=$2 tarball="$CACHE/$1-$2.tar.gz"

    if [[ ! -s $tarball ]]; then
        echo "Downloading $repo@${ref:0:12}" >&2
        curl -fL --retry 5 --retry-delay 5 --retry-all-errors \
            "https://codeload.github.com/daniruiz/$repo/tar.gz/$ref" \
            -o "$tarball" >&2
    fi
    printf '%s\n' "$tarball"
}

install_dir() {
    local tarball=$1 inner=$2 dest=$3
    local depth=2 rest=$inner

    if [[ -d $dest ]]; then
        echo "  ${dest##*/} already installed"
        return 0
    fi

    while [[ $rest == */* ]]; do
        rest=${rest#*/}
        depth=$((depth + 1))
    done

    mkdir -p "$dest"
    tar xzf "$tarball" -C "$dest" --strip-components="$depth" --wildcards "*/$inner/*"

    rm -f "$dest/install.sh" "$dest/uninstall.sh"

    if [[ -z $(find "$dest" -mindepth 1 -maxdepth 1 -print -quit) ]]; then
        echo "error: nothing extracted into $dest (bad strip depth?)" >&2
        exit 1
    fi
    echo "  installed $dest"
}

echo "Flat Remix GTK (Blue):"
gtk_tar=$(fetch flat-remix-gtk "$GTK_REF")
for variant in Light Dark; do
    install_dir "$gtk_tar" "themes/Flat-Remix-GTK-Blue-$variant" \
        "$THEMES_DIR/Flat-Remix-GTK-Blue-$variant"
done

echo "Flat Remix icons (Blue):"
icons_tar=$(fetch flat-remix "$ICONS_REF")
for variant in Light Dark; do
    install_dir "$icons_tar" "Flat-Remix-Blue-$variant" \
        "$ICONS_DIR/Flat-Remix-Blue-$variant"
done

echo "Flat Remix GNOME Shell:"
shell_tar=$(fetch flat-remix-gnome "$SHELL_REF")
for variant in Light Dark Light-fullPanel Dark-fullPanel; do
    install_dir "$shell_tar" "themes/Flat-Remix-$variant" \
        "$THEMES_DIR/Flat-Remix-$variant"
done

for t in "$THEMES_DIR"/Flat-Remix-GTK-Blue-Light "$THEMES_DIR"/Flat-Remix-GTK-Blue-Dark; do
    for d in gtk-3.0 gtk-4.0 libadwaita; do
        [[ -d "$t/$d" ]] || { echo "error: missing $t/$d" >&2; exit 1; }
    done
done
for t in "$ICONS_DIR"/Flat-Remix-Blue-Light "$ICONS_DIR"/Flat-Remix-Blue-Dark; do
    [[ -f "$t/index.theme" ]] || { echo "error: missing $t/index.theme" >&2; exit 1; }
done
for t in Light Dark; do
    [[ -f "$THEMES_DIR/Flat-Remix-$t/gnome-shell/gnome-shell.css" ]] || {
        echo "error: missing shell theme Flat-Remix-$t" >&2
        exit 1
    }
done

echo "Flat Remix installed: 2 GTK themes, 2 icon themes, 4 shell themes"
