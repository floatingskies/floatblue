#!/usr/bin/bash
# Installs the Flat Remix theme family (upstream: github.com/daniruiz):
#
#   /usr/share/themes/Flat-Remix-GTK-Blue-{Light,Dark}   GTK3 + GTK4 + libadwaita
#   /usr/share/icons/Flat-Remix-Blue-{Light,Dark}         icon themes
#   /usr/share/themes/Flat-Remix-{Light,Dark}             GNOME Shell themes
#
# Only the Blue colour variants are installed, because Blue is the image
# default (the icon and GTK families both ship a Blue variant per shade; the
# GNOME Shell family has no colour variants, only Light/Dark).
#
# The three upstream repositories are fetched as pinned commit tarballs, so a
# rebuild downloads exactly the same bits. Only the handful of theme
# directories that are actually used are extracted — the full GTK tarball is
# ~48 MB across 84 themes and the icon tarball ~114 MB across 6 variants.

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
        # Both of these must go to stderr: the caller captures this function's
        # stdout with $(...), so anything printed here would end up glued into
        # the tarball path and tar would be handed "Downloading foo\n/path".
        echo "Downloading $repo@${ref:0:12}" >&2
        curl -fL --retry 5 --retry-delay 5 --retry-all-errors \
            "https://codeload.github.com/daniruiz/$repo/tar.gz/$ref" \
            -o "$tarball" >&2
    fi
    printf '%s\n' "$tarball"
}

# Extract <repo tarball> <path inside repo> <destination>
#
# The archive is rooted at a single directory whose name codeload derives from
# the ref ("flat-remix-gtk-master" even when a commit SHA was requested), so it
# cannot be spelled out. The depth to strip is therefore computed rather than
# hardcoded: 1 for the unknown root, plus one per component of the path we
# want. That matters because the three repos are laid out differently — the
# GTK and Shell themes live under themes/, the icon themes at the repo root —
# and getting it wrong leaves the content one directory too deep.
install_dir() {
    # Two statements on purpose: `local a=$1 b=$2 rest=$b` would expand every
    # word before assigning any of them, so $b would be unset here and `set -u`
    # would abort the build.
    local tarball=$1 inner=$2 dest=$3
    # 1 for the archive root (whose name codeload derives from the ref), 1 for
    # the theme directory itself, plus one per separator inside $inner.
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
    # The trailing /* matters: matching only "*/$inner" selects the directory
    # entry itself, which the strip then collapses to nothing, and tar does not
    # descend into it.
    tar xzf "$tarball" -C "$dest" --strip-components="$depth" --wildcards "*/$inner/*"

    # Upstream ships install.sh/uninstall.sh inside the GTK theme dirs; they
    # are meant for a user running the theme from ~/.themes and have no
    # business being on the system path.
    rm -f "$dest/install.sh" "$dest/uninstall.sh"

    # A wrong strip depth is silent — the tree just ends up in the wrong place —
    # so refuse to continue instead of shipping a theme GTK cannot load.
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

# A GNOME Shell theme is only honoured when the User Themes extension is
# installed; without it gnome-shell silently keeps Adwaita. The extension is
# installed by the theming recipe module, this only asserts we got the themes.
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
