#!/usr/bin/bash
# Applies the parts of the hardening set that have to be done with a live
# system manager (or that touch state rather than just dropping a file).

set -eou pipefail

# ---------------------------------------------------------------- firewalld ---
# Use the desktop zone from etc/firewalld/zones/FloatWorkstation.xml.
#
# Only the default zone is changed. firewalld is enabled with --now by the
# recipe module; this just points it at our zone, tolerating a firewalld that
# is not installed.
if command -v firewall-cmd >/dev/null 2>&1; then
    if firewall-cmd --state >/dev/null 2>&1; then
        firewall-cmd --set-default-zone=FloatWorkstation
        firewall-cmd --reload
        echo "firewalld: default zone -> FloatWorkstation"
    else
        echo "firewalld: not running, leaving the default zone alone"
    fi
else
    echo "firewalld: not installed, skipping"
fi

# --------------------------------------------- MAC randomization (existing) ---
# /etc/NetworkManager/conf.d/60-mac-randomization.conf sets the default for
# connections created from now on, but it does not rewrite profiles that are
# already on disk. Do that here, idempotently and non-fatally: a malformed
# nmconnection would leave the machine with no network at all, which is a far
# worse outcome than a fixed MAC.
shopt -s nullglob
profiles=(/etc/NetworkManager/system-connections/*.nmconnection)
shopt -u nullglob

for profile in "${profiles[@]}"; do
    if grep -q 'wifi.cloned-mac-address' "$profile"; then
        continue
    fi
    if ! grep -q '^\[wifi\]' "$profile"; then
        continue
    fi
    cp -a "$profile" "${profile}.floatbak"

    # An nmconnection is an INI file and the keys must land inside the [wifi]
    # group. Appending at the end of the file would put them in whichever
    # section happens to be last, where NetworkManager silently ignores them.
    awk '
        BEGIN { inserted = 0 }
        !inserted && /^\[wifi\][[:space:]]*$/ {
            print
            print ""
            print "# Added by the Float hardening script: randomize this network'"'"'s MAC"
            print "# while keeping it stable for this network, so the AP association"
            print "# still works."
            print "wifi.cloned-mac-address=random"
            print "wifi.cloned-mac-address-flags=stable"
            inserted = 1
            next
        }
        { print }
    ' "$profile" >"${profile}.tmp" && mv "${profile}.tmp" "$profile"

    if grep -q 'wifi.cloned-mac-address' "$profile"; then
        echo "MAC randomization: added to $(basename "$profile")"
    else
        echo "warning: could not add MAC randomization to $profile, restoring backup" >&2
        mv "${profile}.floatbak" "$profile"
    fi
done

if ((${#profiles[@]} == 0)); then
    echo "MAC randomization: no saved Wi-Fi profiles yet, default in conf.d is enough"
fi

# ------------------------------------------------------- hardened_malloc ---
# Confirm the preload target actually exists. /etc/ld.so.preload pointing at a
# missing library makes every dynamically linked process fail to start, so it
# is much better to know at build time.
if [[ -e /usr/lib64/libhardened_malloc.so ]]; then
    echo "hardened_malloc: preload target present, with-standard-malloc available"
else
    echo "warning: /usr/lib64/libhardened_malloc.so is missing but /etc/ld.so.preload references it" >&2
    echo "warning: remove that line, or the image will not boot" >&2
    exit 1
fi
