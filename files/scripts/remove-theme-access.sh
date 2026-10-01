#!/usr/bin/env bash

# Take the GTK4, libadwaita and Flatpak theming back out.
#
# This is the other half of dropping Flat Remix. The image no longer installs that
# theme, but a rebase does not undo the things an older image already wrote:
#
#   /etc/flatpak/override              persists, /etc is not rebuilt by bootc switch
#   ~/.local/share/flatpak/override    persists, it is in the user's own data
#   ~/.config/gtk-4.0/gtk.css          persists, it is the user's own config
#   ~/.config/gtk-3.0/settings.ini     persists, and still names a theme that is gone
#   /usr/share/themes/Flat-Remix-*     does NOT persist, /usr is rebuilt
#   /usr/share/icons/Flat-Remix-*      does NOT persist, /usr is rebuilt
#
# The /usr half needs nothing here. A rebuilt image simply does not contain those
# directories any more. The /etc and home half is why this runs as a service rather
# than as a build step: a build step writes into the image being built, and an
# install that rebases onto it keeps its own /etc and home.
#
# Why the Flatpak override is edited rather than reset:
#
#   flatpak override --system --reset
#
# wipes the whole file, and the base image puts its own share/sockets/devices
# lines in there. Resetting them would remove the plumbing Flatpak needs to talk to
# X11, Wayland or the GPU, which has nothing to do with theming. So the four keys
# this image added are deleted and everything else is left alone.
#
# Nothing here is fatal if it is already in the desired state. The service runs on
# every boot and must be a no-op on the second one.

set -euo pipefail

SYS_OVERRIDE=/etc/flatpak/override

# Keys this image added to the Flatpak overrides. Matched on the name only, so a
# leftover from an older revision with a different value is still removed.
ENV_KEYS=(GTK_THEME XDG_DATA_DIRS)
# Character classes rather than backslash escapes: gawk warns about \. in a
# regex and this keeps the match exact without relying on that.
FS_KEYS='^(xdg-config/gtk-[34][.]0)='

log() { printf 'remove-theme-access: %s\n' "$*" >&2; }

# Strip our keys from an override file, keeping every other line and its section.
scrub_file() {
    local file=$1 removed=0

    [[ -f $file ]] || return 0

    local tmp
    tmp=$(mktemp) || return 0
    awk -v envs="$(IFS='|'; echo "${ENV_KEYS[*]}")" -v fs="$FS_KEYS" '
        BEGIN {
            n = split(envs, e, "|")
            for (i = 1; i <= n; i++) env[e[i]] = 1
        }
        {
            line = $0
            if (line ~ /^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*=/) {
                split(line, kv, "=")
                key = kv[1]
                gsub(/[[:space:]]/, "", key)
                if (key in env) { next }
            }
            if (line ~ fs) { next }
            print
        }
    ' "$file" >"$tmp" || { rm -f "$tmp"; return 0; }

    # Only replace the file if it actually changed, so a no-op boot leaves the
    # mtime alone and nothing relinks against it.
    if cmp -s "$tmp" "$file"; then
        rm -f "$tmp"
        return 0
    fi
    cat "$tmp" >"$file"
    rm -f "$tmp"
    log "cleaned $file"
    removed=1
    return 0
}

# The user override and the per-user GTK config only exist inside a session, or
# while rebuilding the image, so this is driven by whoever calls it.
clean_user() {
    local home=${1:?}
    local cfg=${2:-$home/.config}

    scrub_file "$home/.local/share/flatpak/override"

    # The libadwaita overlay: an 83 line sheet with the Flat Remix palette, layered
    # on top of whatever the theme provides. With no custom theme it is just stale
    # CSS overriding Adwaita.
    local overlay="$cfg/gtk-4.0/gtk.css"
    if [[ -s $overlay ]] && grep -qE 'Flat[- ]?Remix' "$overlay" 2>/dev/null; then
        rm -f "$overlay"
        log "removed the libadwaita overlay at $overlay"
    fi

    # settings.ini naming a theme that is no longer installed. GTK falls back to
    # Adwaita on its own, so the file only needs the keys rewritten, not deleting.
    #
    # The icon theme matters as much as the GTK one. It was Flat Remix too, and a
    # stale icon-theme name leaves the desktop without an icon theme at all rather
    # than falling back cleanly, which is more visible than a wrong GTK shade.
    local ini
    for ini in "$cfg/gtk-3.0/settings.ini" "$cfg/gtk-4.0/settings.ini"; do
        [[ -f $ini ]] || continue
        if grep -qE '^[[:space:]]*gtk-theme-name[[:space:]]*=[[:space:]]*Flat-Remix' "$ini"; then
            sed -i 's|^\([[:space:]]*gtk-theme-name[[:space:]]*=[[:space:]]*\).*$|\1Adwaita|' "$ini"
            log "repointed gtk-theme-name to Adwaita in $ini"
        fi
        if grep -qE '^[[:space:]]*gtk-icon-theme-name[[:space:]]*=[[:space:]]*Flat-Remix' "$ini"; then
            sed -i 's|^\([[:space:]]*gtk-icon-theme-name[[:space:]]*=[[:space:]]*\).*$|\1Adwaita|' "$ini"
            log "repointed gtk-icon-theme-name to Adwaita in $ini"
        fi
    done
}

if [[ ${1:-} == --user ]]; then
    clean_user "${2:?home required}" "${3:-}"
    exit 0
fi

scrub_file "$SYS_OVERRIDE"

# Rebuilding the image runs as root with no session, so /root is the best available
# stand-in. It is a no-op when there is nothing there.
if [[ -d /root/.config ]]; then
    clean_user /root
fi

echo "remove-theme-access: done"
