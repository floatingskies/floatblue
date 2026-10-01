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

# libadwaita is the GTK4 half of the theme: it is what Adwaita based apps end
# up reading, so its stylesheet is also the one a GTK4 app should find. GTK4
# looks under a gtk-4.0 directory though, so mirror libadwaita/ into
# libadwaita/gtk-4.0/ instead of leaving the two to drift. The assets are
# copied as well, the titlebutton css references them by relative path and the
# window controls end up unstyled if they go missing.
mirror_libadwaita_to_gtk4() {
    local theme=$1 entry
    mkdir -p "$theme/libadwaita/gtk-4.0"
    for entry in "$theme/libadwaita"/*; do
        [[ -e $entry ]] || continue
        [[ $(basename "$entry") == gtk-4.0 ]] && continue
        cp -a "$entry" "$theme/libadwaita/gtk-4.0/"
    done
}

echo "Flat Remix GTK (Blue):"
gtk_tar=$(fetch flat-remix-gtk "$GTK_REF")
for variant in Light Dark; do
    install_dir "$gtk_tar" "themes/Flat-Remix-GTK-Blue-$variant" \
        "$THEMES_DIR/Flat-Remix-GTK-Blue-$variant"
    mirror_libadwaita_to_gtk4 "$THEMES_DIR/Flat-Remix-GTK-Blue-$variant"
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

# Check the stylesheets themselves, not just the directories. Each variant is
# self contained: the Dark one carries a dark libadwaita/gtk.css and a dark
# gtk-4.0/gtk.css, so swapping the theme name is all it takes to move GTK3,
# GTK4 and libadwaita together. That only holds while the files are really
# there, and a bare "gtk-4.0" directory that happens to be empty would ship a
# system where every GTK4 app silently renders as Adwaita.
for t in "$THEMES_DIR"/Flat-Remix-GTK-Blue-Light "$THEMES_DIR"/Flat-Remix-GTK-Blue-Dark; do
    for f in gtk-3.0/gtk.css gtk-3.0/gtk-dark.css \
             gtk-4.0/gtk.css gtk-4.0/gtk-dark.css \
             libadwaita/gtk.css libadwaita/gtk-4.0/gtk.css; do
        [[ -s "$t/$f" ]] || { echo "error: missing or empty $t/$f" >&2; exit 1; }
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
