#!/usr/bin/env bash

# Take services off that cost memory and give nothing back on a small machine.
#
# This started as a systemd module with a disabled: list, which failed the build
# outright:
#
#   Failed to disable unit: Unit tracker-miners-fs3.service does not exist
#
# bluebuild's systemd module treats a missing unit as an error, not as a no-op.
# That is the right default for something you are turning on, where a typo means
# the thing silently never happens. It is the wrong default for a list of things
# being turned off, because there the unit not existing is the desired end state
# and the base image differs between channels. tracker-miners-fs3 is simply not
# in Bluefin DX at all, so the whole image stopped building.
#
# So this walks the list and skips what is not there. Anything present gets its
# wants symlinks removed, offline, the same way the module would have done it.
# Nothing here fails the build.

set -eou pipefail

# Each of these is idle most of the time and resident or scheduled all of the
# time, which is a bad trade at 3 to 4 GB.
UNITS=(
    tracker-miners-fs3.service          # GNOME file indexer
    tracker-miners-fs3-monitor.service
    tracker-extract.service
    packagekit.service                  # background package queries
    dnf-makecache.timer                 # daily metadata refresh
    man-db.timer                        # man page index
    plocate-update.timer                # locate database
    fwupd.service                       # wakes on a timer forever
    fwupd-refresh.timer
)

present() {
    local unit=$1 dir
    for dir in /etc/systemd/system /usr/lib/systemd/system /lib/systemd/system; do
        [[ -e $dir/$unit ]] && return 0
    done
    return 1
}

removed=0
skipped=0

for unit in "${UNITS[@]}"; do
    if ! present "$unit"; then
        printf '  %-34s not in this base image\n' "$unit"
        skipped=$((skipped + 1))
        continue
    fi

    # A unit can be wanted by more than one target, and the base image decides
    # which. Take the links rather than calling systemctl, which needs a running
    # systemd that a build container does not have.
    count=0
    while IFS= read -r link; do
        rm -f "$link"
        count=$((count + 1))
    done < <(find /etc/systemd/system -type l -lname "*/$unit" 2>/dev/null | sort)

    if ((count == 0)); then
        printf '  %-34s present but never enabled\n' "$unit"
        removed=$((removed + 1))
    else
        printf '  %-34s disabled, %d link(s) removed\n' "$unit" "$count"
        removed=$((removed + 1))
    fi
done

# Anything still wanted must be gone. This deliberately does not skip units
# whose file is missing: a wants symlink pointing at a unit that is not there is
# exactly the leftover worth catching, and the loop above could never have
# removed it because it returned early on a unit it did not find.
leftover=()
for unit in "${UNITS[@]}"; do
    hit=$(find /etc/systemd/system -type l -lname "*/$unit" -print -quit 2>/dev/null)
    [[ -n $hit ]] && leftover+=("$unit ($hit)")
done

if ((${#leftover[@]})); then
    echo "error: still enabled after trimming: ${leftover[*]}" >&2
    exit 1
fi

echo "  trimmed $removed unit(s), $skipped not in this image"
