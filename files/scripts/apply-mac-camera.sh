#!/usr/bin/env bash

# Make a working webcam out of a Mac that no longer has one it can use.
#
# The built-in iSight is a Broadcom BCM20300 on USB. Apple wrote the driver for
# it, it never made it into mainline, and the out of tree version stopped
# building years ago. There is no camera driver for that hardware on a current
# Fedora and this does not pretend otherwise.
#
# The FaceTime HD camera, the separate one Apple sold that plugs in and appears
# as a Broadcom 1570 on PCIe, does have a driver, but it only exists as a COPR or
# prebaked in the ublue akmods container. A COPR repo file needs a numeric
# project id that changes without notice, and a repo file pointing at nothing is
# a problem you only find at boot. So it is not installed here.
#
# What does work, and is what most people actually want: v4l2loopback gives a
# virtual video device that PipeWire, GNOME's camera indicator and FaceTime,
# Meet and Zoom all treat as a real webcam. Anything that just needs a camera to
# be present will open. Nothing is faked at a level the user would be misled by,
# which is why this puts a visible test pattern in it rather than freezing a
# black frame.

set -eou pipefail

MODULE=v4l2loopback
DEVICE=/dev/video-floatblue

log() { printf '  %s\n' "$*"; }

# ---------------------------------------------------------------- what is here
pci_camera() {
    for dev in /sys/bus/pci/devices/*/; do
        [[ -r $dev/vendor && -r $dev/device ]] || continue
        vendor=$(cat "$dev/vendor" 2>/dev/null || true)
        device=$(cat "$dev/device" 2>/dev/null || true)
        # Broadcom is vendor 0x14e4
        [[ ${vendor,,} == "0x14e4" ]] || continue
        printf '%s %s\n' "$dev" "$device"
    done
}

usb_camera() {
    for dev in /sys/bus/usb/devices/*/; do
        idVendor=$(cat "$dev/idVendor" 2>/dev/null || true)
        idProduct=$(cat "$dev/idProduct" 2>/dev/null || true)
        [[ ${idVendor,,} == "0x14e4" ]] || continue
        printf '%s %s\n' "$dev" "$idProduct"
    done
}

echo "Camera hardware:"
pci_found=$(pci_camera || true)
usb_found=$(usb_camera || true)

if [[ -n $pci_found ]]; then
    log "Broadcom device on PCIe: this is the FaceTime HD (1570) class of camera"
    log "  no packaged driver for it, see the comment at the top of this script"
else
    log "no Broadcom PCIe camera found"
fi
if [[ -n $usb_found ]]; then
    log "Broadcom device on USB: this is the built-in iSight (BCM20300)"
    log "  Apple never upstreamed a driver, there is none in Fedora or RPM Fusion"
else
    log "no Broadcom USB camera found"
fi

# ------------------------------------------------------- a camera that opens
if ! modinfo "$MODULE" >/dev/null 2>&1; then
    echo "error: the $MODULE kernel module is not installed, there is no webcam fallback" >&2
    exit 1
fi
log "$MODULE available"

cat > /etc/modprobe.d/floatblue-v4l2loopback.conf <<EOF
# Set up by apply-mac-camera.sh. One output node, so the device keeps the same
# name across reboots instead of coming back as video0 one day and video3 the
# next, which is what breaks a saved application camera setting.
options $MODULE devices=1 exclusive_caps=1 card_label=floatblue
EOF

cat > /etc/udev/rules.d/99-floatblue-v4l2loopback.rules <<'EOF'
# Give the loopback camera a stable name. udev has no way to rename a device
# node, so this creates a symlink under /dev and points everything, GNOME
# included, at that instead.
ACTION=="add", SUBSYSTEM=="video4linux", KERNEL=="video*", \
  ATTRS{name}=="floatblue", SYMLINK+="video-floatblue"
EOF

# The test pattern. Without it a virtual camera is a black rectangle that most
# applications will still open, which reads as a broken webcam rather than a
# working one.
cat > /usr/libexec/floatblue-webcam <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

for _ in $(seq 1 30); do
    [[ -e /dev/video-floatblue ]] && break
    sleep 1
done
[[ -e /dev/video-floatblue ]] || exit 0

command -v gst-launch-1.0 >/dev/null 2>&1 || exit 0

# A visible pattern, so it is obvious the camera is a virtual one and not a
# physical camera pointed at a dark room.
exec gst-launch-1.0 videotestsrc is-live=true \
    ! video/x-raw,width=640,height=480,framerate=30/1 \
    ! videoconvert ! jpegenc ! multifilesink location=/dev/video-floatblue
EOF
chmod +x /usr/libexec/floatblue-webcam

cat > /etc/systemd/system/floatblue-webcam.service <<'EOF'
[Unit]
Description=Float: virtual webcam for Macs with no working camera
Documentation=man:v4l2loopback(4)
After=systemd-modules-load.service
Before=graphical.target

[Service]
Type=simple
ExecStartPre=-/usr/bin/modprobe v4l2loopback
ExecStart=/usr/libexec/floatblue-webcam
Restart=on-failure
RestartSec=2

[Install]
WantedBy=graphical.target
EOF

systemctl daemon-reload >/dev/null 2>&1 || :
ln -sf /usr/lib/systemd/system/floatblue-webcam.service \
    /etc/systemd/system/graphical.target.wants/floatblue-webcam.service

log "virtual camera set up as /dev/video-floatblue, enabled at graphical.target"

echo "  no physical camera driver installed, on purpose. FaceTime, Meet and Zoom"
echo "  will open and show a test pattern. They will not transmit a real picture."
