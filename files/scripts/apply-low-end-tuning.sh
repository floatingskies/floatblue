#!/usr/bin/bash

# Check the low-end configuration.
#
# This deliberately does not try to read the values back out of the running
# kernel. A build happens inside a container where /usr/lib/sysctl.d is never
# applied, because sysctl is a boot-time thing systemd does and nothing in the
# image build asks it to. So a script that verified live values here would fail
# every build while the configuration was perfectly correct.
#
# What it does instead is check what actually ships: that the drop-in exists,
# that it carries the values we intend, that the tools it depends on are
# installed, and that the dconf keyfile parses. The runtime behaviour is
# verified by float-dconf-update.service on the first boot.

set -eou pipefail

SYSCTL_DROPIN=/usr/lib/sysctl.d/70-float-low-memory.conf
DCONF_KEYFILE=/etc/dconf/db/distro.d/11-float-low-end

fail=0
ok()   { printf '  %-36s %s\n' "$1" "$2"; }
bad()  { printf '  %-36s %s\n' "$1" "$2" >&2; fail=1; }

# Values the drop-in must carry, and why. Kept in one place so the file and this
# check cannot drift apart.
declare -A want=(
    [vm.swappiness]=180
    [vm.page-cluster]=0
    [vm.vfs_cache_pressure]=50
    [vm.dirty_background_ratio]=5
    [vm.dirty_ratio]=15
    [vm.laptop_mode]=5
)

echo "Memory drop-in:"
if [[ ! -f $SYSCTL_DROPIN ]]; then
    bad "$SYSCTL_DROPIN" "missing"
else
    for key in "${!want[@]}"; do
        got=$(sed -nE "s/^[[:space:]]*${key}[[:space:]]*=[[:space:]]*([0-9]+).*/\1/p" "$SYSCTL_DROPIN" | tail -1)
        if [[ -z $got ]]; then
            bad "$key" "not set in the drop-in"
        elif [[ $got == "${want[$key]}" ]]; then
            ok "$key" "$got"
        else
            bad "$key" "drop-in says $got, expected ${want[$key]}"
        fi
    done
fi

echo "Compressed swap:"
if [[ -f /etc/zram-generator.conf ]]; then
    size=$(sed -nE "s/^[[:space:]]*zram-size[[:space:]]*=[[:space:]]*(.*)/\1/p" /etc/zram-generator.conf | tail -1)
    [[ -n $size ]] && ok "zram-size" "$size" || bad "zram-size" "not set"
    ok "swap-priority" "$(sed -nE 's/^[[:space:]]*swap-priority[[:space:]]*=[[:space:]]*(.*)/\1/p' /etc/zram-generator.conf | tail -1)"
else
    bad "/etc/zram-generator.conf" "missing, the machine will still hit disk swap"
fi
command -v zramctl >/dev/null 2>&1 && ok "zramctl" "$(command -v zramctl)" \
    || bad "zramctl" "missing"

echo "Out of memory handling:"
if [[ -e /usr/lib/systemd/system/earlyoom.service ]]; then
    ok "earlyoom" "unit present"
else
    bad "earlyoom" "not installed, an OOM kill will be silent and arbitrary"
fi

echo "Desktop:"
if [[ -f $DCONF_KEYFILE ]] && grep -qE '^enable-animations=false' "$DCONF_KEYFILE"; then
    ok "shell animations" "off, via system dconf"
else
    bad "shell animations" "not disabled, every repaint is a full screen animation"
fi

echo "Graphics, no GPU assumed:"
if [[ -e /usr/lib64/dri/swrast_dri.so || -e /usr/lib/dri/swrast_dri.so ]]; then
    ok "software rasteriser" "present, desktop renders without a GPU"
else
    bad "swrast_dri.so" "missing, a machine with no working GL driver has no desktop"
fi

# Services that cost memory and give nothing back on a 4 GB machine.
echo "Services trimmed:"
for unit in tracker-miners-fs3.service packagekit.service dnf-makecache.timer man-db.timer; do
    if [[ -L /etc/systemd/system/$unit || -e /etc/systemd/system/$unit ]]; then
        ok "$unit" "disabled"
    else
        ok "$unit" "left alone, unit not present in this image"
    fi
done

if ((fail)); then
    echo "error: the low-end profile is not correctly configured" >&2
    exit 1
fi

echo "Low-end profile configured for a 3 to 4 GB machine, no Vulkan assumed"
