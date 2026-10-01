#!/usr/bin/bash

# Check the creative profile.
#
# The interesting part is not the editors, it is what they need to agree on.
# Every one of these applications draws type, and they all ask fontconfig
# separately. If fontconfig has not been told to hint and antialias, or if colord
# has no ICC profiles to map against, the same document looks different in GIMP,
# Inkscape and a browser, and that is the kind of thing that gets discovered at
# review time rather than at export time.

set -eou pipefail

FONTCONF_DROPIN=/etc/fontconfig/conf.d/62-float-design.conf

fail=0
ok()  { printf '  %-36s %s\n' "$1" "$2"; }
bad() { printf '  %-36s %s\n' "$1" "$2" >&2; fail=1; }

echo "Font rendering:"
if [[ ! -f $FONTCONF_DROPIN ]]; then
    bad "$FONTCONF_DROPIN" "missing"
else
    grep -q 'antialias' "$FONTCONF_DROPIN" \
        && ok "antialiasing" "forced on" \
        || bad "antialiasing" "not set, type renders thin and aliased"
    grep -q 'hinting' "$FONTCONF_DROPIN" \
        && ok "hinting" "forced on" \
        || bad "hinting" "not set"
fi

# The drop-in must not reject hinted fonts. It got that wrong once, rejecting
# .otf and .ttf along with the bitmap faces, which would have left the desktop
# with very little to draw text with.
if grep -qE '\*\.(otf|ttf)' "$FONTCONF_DROPIN" 2>/dev/null; then
    bad "bitmap rejection" "drop-in rejects hinted fonts as well"
else
    ok "bitmap rejection" "bitmaps only, hinted fonts untouched"
fi

if command -v fc-match >/dev/null 2>&1; then
    ok "fc-match sans" "$(fc-match sans 2>/dev/null | sed 's/:.*//' | sed 's|.*/||')"
    ok "fc-match mono" "$(fc-match monospace 2>/dev/null | sed 's/:.*//' | sed 's|.*/||')"
else
    bad "fontconfig" "fc-match missing"
fi

echo "Colour management:"
if [[ -d /usr/share/color/icc ]]; then
    profiles=$(find /usr/share/color/icc -name '*.icc' -o -name '*.icm' 2>/dev/null | wc -l)
    if ((profiles > 0)); then
        ok "ICC profiles" "$profiles available"
    else
        bad "ICC profiles" "none installed, colord has nothing to map against"
    fi
else
    bad "ICC profiles" "/usr/share/color/icc missing"
fi
command -v colord >/dev/null 2>&1 && ok "colord" "$(command -v colord)" \
    || bad "colord" "not installed"

echo "Editors, present or not:"
for tool in gimp inkscape krita darktable blender scribus; do
    if command -v "$tool" >/dev/null 2>&1; then
        ok "$tool" "installed"
    else
        # Not a failure. These are skip-unavailable on purpose so a rename in
        # one Fedora release does not take the whole image build down with it.
        printf '  %-36s %s\n' "$tool" "not in this image, skipped on purpose"
    fi
done

if ((fail)); then
    echo "error: the creative profile is not correctly configured" >&2
    exit 1
fi

echo "Creative profile configured"
