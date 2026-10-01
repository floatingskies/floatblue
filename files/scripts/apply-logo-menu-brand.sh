#!/usr/bin/env bash

# Put the FloatOS mark into the Logo Menu extension itself.
#
# The dconf keyfile sets use-custom-icon and custom-icon-path, and that is what
# actually decides the panel icon: setIconImage() in extension.js checks those
# first and only falls back to the per-distro list in constants.js when they are
# off. So on its own the keyfile is enough and nothing here is required.
#
# This covers the other path. The extension picks its icon by an integer index
# into that list, so if use-custom-icon is ever off, or a user resets it, the
# panel goes back to whatever SVG sits at the configured index, and today that is
# the Universal Blue logo. Replacing the SVGs themselves means there is no index
# left that shows the wrong brand.
#
# What this does not survive: a package update. These files belong to the
# extension's package, and dnf reinstalls the originals over the top. The dconf
# keyfile does survive updates, which is why both are there. Run this from the
# recipe and the panel is branded on the image as built; run it again, or rebuild,
# after an update.

set -euo pipefail

EXTROOT=/usr/share/gnome-shell/extensions
BRANDING=/usr/share/floatblue/branding

# The upstream uuid. Resolved from metadata.json rather than trusted blindly,
# because everything else in this file hangs off that directory name.
UUID=logomenu@aryan_k

fail=0
soft=0

# bad  something this image is supposed to ship, failing means we shipped it wrong
# note something that depends on the base image, reported and never fatal. The
# Mac recipe builds on Silverblue, which may not carry this extension at all, and
# a missing extension is not a broken image.
bad() { printf '  %-38s %s\n' "$1" "$2" >&2; fail=1; }
note() { printf '  %-38s %s\n' "$1" "$2"; soft=$((soft + 1)); }

find_extension() {
    local meta
    for meta in "$EXTROOT"/*/metadata.json; do
        [[ -f $meta ]] || continue
        if grep -qE "\"uuid\"[[:space:]]*:[[:space:]]*\"$UUID\"" "$meta"; then
            printf '%s\n' "${meta%/metadata.json}"
            return 0
        fi
    done
    return 1
}

EXTDIR=$(find_extension || true)

if [[ -z $EXTDIR ]]; then
    note "extension" "$UUID not installed, skipping"
    echo "Logo Menu branding: not applied, $soft optional item(s) reported"
    exit 0
fi
echo "  extension: $EXTDIR"

# Source files. These are ours, so a missing one is a real failure: it means the
# branding payload did not land.
declare -A SRC=(
    [ublue-logo-symbolic.svg]="$BRANDING/floatos-logo-symbolic.svg"
    [ublue-logo.svg]="$BRANDING/floatos-logo.svg"
)

for name in "${!SRC[@]}"; do
    src=${SRC[$name]}
    dst="$EXTDIR/Resources/$name"

    if [[ ! -s $src ]]; then
        bad "$name" "source missing: $src"
        continue
    fi

    if [[ ! -d $EXTDIR/Resources ]]; then
        bad "$name" "no Resources directory in $EXTDIR"
        continue
    fi

    if cmp -s "$src" "$dst"; then
        note "$name" "already the FloatOS mark"
        continue
    fi

    cp -a "$src" "$dst"
    echo "  replaced $dst"
done

# Verify by reading the files back rather than trusting the copies. An extension
# whose logo silently fails to load shows the fallback, not an error, so this is
# the only place a mistake here would become visible.
for name in "${!SRC[@]}"; do
    dst="$EXTDIR/Resources/$name"
    [[ -s $dst ]] || continue
    if cmp -s "${SRC[$name]}" "$dst"; then
        note "$name" "verified"
    else
        bad "$name" "did not take at $dst"
    fi
done

if ((fail)); then
    echo "error: the Logo Menu branding is not correctly applied" >&2
    exit 1
fi

echo "Logo Menu branding applied, $soft optional item(s) reported"
