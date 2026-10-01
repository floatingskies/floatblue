#!/usr/bin/bash

# Put User Themes in the system list of enabled extensions.
#
# float-theme-sync also enables it, but it runs after the session starts, and
# gnome-shell has already read its extension list by then. An extension enabled
# mid session is not loaded until the shell restarts, which is why the shell
# theme only showed up on the second login. Writing the key into the system
# database instead gets it read at shell startup, so it works on the first one.

set -euo pipefail

DBDIR=/etc/dconf/db
TARGET="$DBDIR/distro.d/10-float-shell-extensions"
EXTDIR=/usr/share/gnome-shell/extensions

# ---------------------------------------------------------------- the uuid
#
# Do not hardcode this. It was wrong once already: the name was written as
# user-theme@gnome-shell-extensions.gcampari.github.com, while the extension
# BlueBuild actually installs is gcampax. Nothing complained, the key was
# written, dconf compiled it and the shell silently never loaded anything,
# because an unknown uuid in the list is not an error.
#
# metadata.json is what the extension itself declares, so ask it.
UUID=""
for meta in "$EXTDIR"/*/metadata.json; do
    [[ -f $meta ]] || continue
    if grep -qE '"name"[[:space:]]*:[[:space:]]*"User Themes"' "$meta"; then
        UUID=$(sed -n 's/.*"uuid"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$meta" | head -1)
        [[ -n $UUID ]] && break
    fi
done

if [[ -z $UUID ]]; then
    echo "error: no extension declaring itself \"User Themes\" under $EXTDIR" >&2
    echo "       the gnome-extensions module must run before this script" >&2
    exit 1
fi
echo "  User Themes is $UUID"

# ------------------------------------------------------------- the base list
#
# The list is merged, never replaced, but that is only a safety measure when
# there is something to lose. Three sources are tried, because which one the
# base image uses is not this script's decision to make:
#
#   1. gsettings, inside a throwaway session bus. The effective value, whatever
#      sets it.
#   2. the dconf keyfiles under /etc/dconf/db.
#   3. the glib schema overrides. Bluefin in particular enables its extensions
#      that way rather than through dconf, so a dconf-only scan finds nothing.
#
# And when all three come back empty that is not an error. It means the base
# image enables nothing, so the list written below is not replacing anything, it
# is only adding User Themes. Refusing to write in that case is what broke the
# Silverblue build: stock GNOME has no extension list at all and there was
# nothing to protect in the first place.
#
# The guard that matters is the one after the merge: everything that was in the
# base list still has to be in the merged one.

empty_list() {
    [[ -z ${1:-} || $1 == "@as []" || $1 == "'@as []'" ]]
}

current=""
source_note=""

got=$(dbus-run-session -- gsettings get org.gnome.shell enabled-extensions 2>/dev/null || true)
if ! empty_list "$got"; then
    current=$got
    source_note="gsettings"
fi

if empty_list "$current"; then
    while read -r f; do
        [[ -n $f ]] || continue
        v=$(sed -nE "s/^\s*enabled-extensions\s*=\s*(.*)$/\1/p" "$f" | tail -1)
        if ! empty_list "$v"; then
            current=$v
            source_note="dconf keyfile ${f##*/}"
            break
        fi
    done < <(
        for dir in "$DBDIR"/*.d; do
            [[ -d $dir ]] || continue
            for f in "$dir"/*; do
                [[ -f $f ]] && grep -qE '^\s*enabled-extensions\s*=' "$f" 2>/dev/null && printf '%s\n' "$f"
            done
        done
    )
fi

if empty_list "$current"; then
    for f in /usr/share/glib-2.0/schemas/*.gschema.override; do
        [[ -f $f ]] || continue
        v=$(sed -nE "s/^\s*enabled-extensions\s*=\s*(.*)$/\1/p" "$f" | tail -1)
        if ! empty_list "$v"; then
            current=$v
            source_note="gschema override ${f##*/}"
            break
        fi
    done
fi

if empty_list "$current"; then
    echo "  no base extension list anywhere: this image enables nothing to preserve"
    # [] and not @as []: this value is handed to the parser below, and @as [] is
    # how gsettings prints an empty list, not how a list is spelled.
    current="[]"
    source_note="none, starting from empty"
else
    echo "  base list ($source_note): $current"
fi

merged=$(python3 - "$UUID" "$current" <<'PY'
import re
import sys

uuid, raw = sys.argv[1], sys.argv[2].strip()
if not (raw.startswith("[") and raw.endswith("]")):
    sys.exit("cannot parse enabled-extensions: %r" % raw)

# gsettings spells entries as ['a', 'b']. Handwritten keyfiles and overrides
# often skip the quotes and write [a, b], so accept both rather than dying on
# a list that is perfectly readable.
entries = re.findall(r"'((?:[^'\\]|\\.)*)'", raw)
if not entries:
    body = raw.strip()[1:-1].strip()
    entries = [e.strip() for e in body.split(",") if e.strip()] if body else []

# An empty list is a real thing to merge into, it just means the base image
# enables no extensions. Only a non-empty list that parses to nothing is broken.
if not entries and raw.strip() != "[]":
    sys.exit("no entries parsed out of enabled-extensions: %r" % raw)

for e in entries:
    if e.replace("\\'", "'") == uuid:
        print(raw)
        raise SystemExit

print("[" + ", ".join("'%s'" % e for e in entries + [uuid]) + "]")
PY
)

if [[ $merged == "$current" ]]; then
    echo "  $UUID already in the system list"
else
    mkdir -p "$(dirname "$TARGET")"
    {
        echo "# Generated by enable-user-theme-systemwide.sh, merged from the base image list."
        echo "[org/gnome/shell]"
        echo "enabled-extensions=$merged"
    } >"$TARGET"
    echo "  wrote $TARGET"
    echo "    enabled-extensions=$merged"
fi

# The merge only counts if nothing from the base got dropped on the way.
for keep in $(python3 -c "
import re,sys
raw=sys.argv[1]
print(' '.join(re.findall(r\"'((?:[^'\\\\]|\\\\.)*)'\", raw)))" "$current"); do
    if [[ $keep == "$UUID" ]]; then continue; fi
    if [[ $merged != *"$keep"* ]]; then
        echo "error: $keep was in the base list but is missing from the merged list" >&2
        exit 1
    fi
done
if [[ $current == "[]" ]]; then
    echo "  base had no extensions, nothing to lose in the merge"
else
    echo "  every extension from the base survived the merge"
fi

if command -v dconf >/dev/null 2>&1; then
    dconf update
    if dconf dump /org/gnome/shell/ 2>/dev/null | grep -q "$UUID"; then
        echo "  compiled: $UUID is in the system extension list"
    else
        echo "error: $UUID is not in the compiled dconf database" >&2
        exit 1
    fi
else
    echo "  dconf not installed, left the database uncompiled"
fi
