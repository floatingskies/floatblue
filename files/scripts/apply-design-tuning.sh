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
soft=0

# ok   something this image ships, failing it means we shipped it wrong
# bad  ditto, and it fails the build
# note something that comes from a package this recipe installs optionally.
#      Reported, never fatal: a check that is hard while the thing it checks is
#      optional means one renamed package takes the whole image build down.
ok()  { printf '  %-36s %s\n' "$1" "$2"; }
bad() { printf '  %-36s %s\n' "$1" "$2" >&2; fail=1; }
note() { printf '  %-36s %s\n' "$1" "$2"; soft=$((soft + 1)); }

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

# fontconfig itself comes from the base image rather than from this recipe, so a
# missing binary is worth saying out loud but is not our drop-in being wrong.
if command -v fc-match >/dev/null 2>&1; then
    note "fc-match sans" "$(fc-match sans 2>/dev/null | sed 's/:.*//;s|.*/||')"
    note "fc-match mono" "$(fc-match monospace 2>/dev/null | sed 's/:.*//;s|.*/||')"
else
    note "fc-match" "not installed, nothing to resolve against"
fi

echo "Colour management:"
# Reported, not failed. These come from packages installed with
# skip-unavailable, and making a check that hard while the thing it checks is
# optional means one renamed package fails the whole image build. That is the
# same mistake as demanding a unit the base image does not ship.
#
# colord ships its own profiles, AdobeRGB1998, ProPhotoRGB and Rec709, so
# /usr/share/color/icc being populated and colord being installed go together and
# neither is a sign that anything we shipped is wrong.
if [[ -d /usr/share/color/icc ]]; then
    profiles=$(find /usr/share/color/icc -name '*.icc' -o -name '*.icm' 2>/dev/null | wc -l)
    if ((profiles > 0)); then
        note "ICC profiles" "$profiles available"
    else
        note "ICC profiles" "none installed, colord will fall back to sRGB"
    fi
else
    note "ICC profiles" "/usr/share/color/icc missing, colour management is inert"
fi

if command -v colord >/dev/null 2>&1; then
    note "colord" "$(command -v colord)"
else
    note "colord" "not installed, applications fall back to sRGB"
fi

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
    echo "       only the checks above marked as errors are ours; the ones marked" >&2
    echo "       as notes come from packages that are optional on purpose" >&2
    exit 1
fi

echo "Creative profile configured, $soft optional item(s) reported"
