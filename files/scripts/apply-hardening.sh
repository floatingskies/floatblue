#!/usr/bin/bash

set -eou pipefail

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
