#!/usr/bin/env bash

# Verify the Mac hardware layer.
#
# The build container is not a Mac, so this cannot check that the WiFi works. It
# can check that everything needed for it is present, which is the part that
# actually goes wrong: a missing akmod, a repo file that points nowhere, a module
# that never loaded. A missing camera driver is reported, not failed on, because
# there is not one to install and pretending otherwise would be worse.

set -eou pipefail

fail=0
soft=0
ok()  { printf '  %-34s %s\n' "$1" "$2"; }
bad() { printf '  %-34s %s\n' "$1" "$2" >&2; fail=1; }
note(){ printf '  %-34s %s\n' "$1" "$2"; soft=$((soft + 1)); }

echo "RPM Fusion:"
for repo in rpmfusion-free rpmfusion-nonfree; do
    file=/etc/yum.repos.d/$repo.repo
    if [[ ! -f $file ]]; then
        bad "$repo" "repo file missing at $file"
        continue
    fi
    if grep -qE '^enabled=0' "$file"; then
        bad "$repo" "repo file is disabled"
    elif grep -q 'example.invalid' "$file"; then
        bad "$repo" "repo file points at a placeholder URL"
    else
        ok "$repo" "enabled"
    fi
done

echo "Broadcom WiFi:"
# The driver is broadcom-wl, its kernel module is wl. Both have to be there:
# the common files without the module load nothing, and the module without the
# firmware does not associate.
if rpm -q broadcom-wl >/dev/null 2>&1; then
    ok "broadcom-wl" "$(rpm -q --qf '%{version}' broadcom-wl)"
else
    bad "broadcom-wl" "not installed, RPM Fusion nonfree is not being read"
fi

if rpm -q akmod-wl >/dev/null 2>&1; then
    ok "akmod-wl" "$(rpm -q --qf '%{version}' akmod-wl)"
else
    bad "akmod-wl" "not installed, the module will not rebuild for a new kernel"
fi

# A kmod for the running kernel is what actually makes the card work. There is
# none in the image, by design: the kmods are per kernel and the base image's
# kernel is not known until boot. akmods rebuilding it at boot is the fallback,
# and this only reports whether the machinery for that is present.
if [[ -d /usr/lib/modules/$(uname -r)/extra ]]; then
    ok "kmod destination" "/usr/lib/modules/$(uname -r)/extra exists"
else
    note "kmod destination" "absent, akmods will create it on first boot"
fi

if [[ -e /usr/sbin/akmods ]]; then
    ok "akmods" "present, a kernel update can rebuild the module"
else
    bad "akmods" "missing, wl stops working after the next kernel update"
fi

# The wl module needs to be in the initramfs or it cannot attach to the
# firmware early, which on a Mac shows up as a card that never gets an interface.
if modinfo wl >/dev/null 2>&1; then
    ok "wl module" "available to the running kernel"
else
    note "wl module" "not built for this kernel yet, akmods builds it at boot"
fi

echo "Camera:"
if rpm -q v4l2loopback >/dev/null 2>&1; then
    ok "v4l2loopback" "installed"
else
    bad "v4l2loopback" "missing, a Mac with no usable camera has no webcam at all"
fi
[[ -e /etc/modprobe.d/floatblue-v4l2loopback.conf ]] \
    && ok "loopback config" "present" \
    || bad "loopback config" "missing, apply-mac-camera.sh did not run"
[[ -L /etc/systemd/system/graphical.target.wants/floatblue-webcam.service ]] \
    && ok "webcam service" "enabled at graphical.target" \
    || bad "webcam service" "not enabled"

# There is no driver for the built-in iSight and none packaged for the FaceTime
# HD. Say it out loud on every build so nobody reports it as a new regression.
note "built-in iSight" "no driver exists, the virtual camera stands in"

echo "Mac specifics:"
if rpm -q t2fan >/dev/null 2>&1; then
    ok "t2fan" "installed, T2 Macs will not cook without it"
else
    note "t2fan" "not installed, only matters on a 2018 or 2020 Mac"
fi
rpm -q smc-tools >/dev/null 2>&1 && ok "smc-tools" "installed" || note "smc-tools" "not installed"
rpm -q bluez >/dev/null 2>&1 && ok "bluez" "installed" || bad "bluez" "missing, no Bluetooth"

if ((fail)); then
    echo "error: the Mac hardware layer is not correctly set up" >&2
    exit 1
fi

echo "Mac hardware layer verified, $soft item(s) reported rather than failed"
