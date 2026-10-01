#!/usr/bin/bash

# Check the gaming configuration.
#
# Same reason as the low-end script: a build runs in a container, so sysctl values
# are not live here and must not be read back from the kernel. Check the files
# that ship instead.

set -eou pipefail

SYSCTL_DROPIN=/usr/lib/sysctl.d/70-float-gaming.conf

fail=0
ok()  { printf '  %-36s %s\n' "$1" "$2"; }
bad() { printf '  %-36s %s\n' "$1" "$2" >&2; fail=1; }

echo "Gaming drop-in:"
# io_uring fully off blocks Wine and Proton. mmap_rnd_bits of 32 leaves too
# little address space for the large reservations DXVK makes.
declare -A want=(
    [kernel.io_uring_disabled]=1
    [vm.mmap_rnd_bits]=28
)
if [[ ! -f $SYSCTL_DROPIN ]]; then
    bad "$SYSCTL_DROPIN" "missing"
else
    for key in "${!want[@]}"; do
        got=$(sed -nE "s/^[[:space:]]*${key}[[:space:]]*=[[:space:]]*([0-9]+).*/\1/p" "$SYSCTL_DROPIN" | tail -1)
        [[ $got == "${want[$key]}" ]] && ok "$key" "$got" || bad "$key" "got '$got', wanted ${want[$key]}"
    done
fi

echo "The hardening values the gaming drop-in must leave alone:"
for pair in "kernel.kexec_load_disabled 1" "kernel.unprivileged_bpf_disabled 1" "vm.unprivileged_userfaultfd 0"; do
    key=${pair% *}
    want_v=${pair#* }
    got=$(sed -nE "s/^[[:space:]]*${key}[[:space:]]*=[[:space:]]*([0-9]+).*/\1/p" \
          /usr/lib/sysctl.d/60-float-hardening.conf 2>/dev/null | tail -1)
    [[ $got == "$want_v" ]] && ok "$key" "untouched at $got" || bad "$key" "hardening file says '$got'"
done

echo "GameMode:"
command -v gamemoderun >/dev/null 2>&1 && ok "gamemoderun" "$(command -v gamemoderun)" \
    || bad "gamemoderun" "missing, on demand tuning will not happen"
[[ -f /etc/gamemode.ini ]] && ok "/etc/gamemode.ini" "present" || bad "/etc/gamemode.ini" "missing"
[[ -e /usr/lib/systemd/system/gamemoded.service ]] && ok "gamemoded.service" "unit present" \
    || bad "gamemoded.service" "not installed"

# Steam must not open by itself. It costs memory and a network handshake on
# every login, and the autostart entry comes back with some Steam updates.
if [[ -e /etc/xdg/autostart/steam.desktop ]]; then
    bad "Steam autostart" "still enabled"
else
    ok "Steam autostart" "removed"
fi

if ((fail)); then
    echo "error: gaming profile is not correctly configured" >&2
    exit 1
fi

echo "Gaming profile configured, Vulkan deliberately not required"
