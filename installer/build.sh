#!/usr/bin/bash
# Adapted from https://github.com/ublue-os/bazzite/blob/main/installer/build.sh
# Ref: https://github.com/ondrejbudai/bootc-isos/blob/3b3a185e4a57947f57baf53d2be5aee469274f98/bazzite/src/build.sh

set -exo pipefail

{ export PS4='+( ${BASH_SOURCE}:${LINENO} ): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'; } 2>/dev/null

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_IMAGE=${BASE_IMAGE:?}
INSTALL_IMAGE_PAYLOAD=${INSTALL_IMAGE_PAYLOAD:?}
ISO_LABEL=${ISO_LABEL:-Floatblue-Live}

# Create the directory that /root is symlinked to
mkdir -p "$(realpath /root)"

# bwrap tries to write /proc/sys/user/max_user_namespaces which is mounted as ro
# so we need to remount it as rw
mount -o remount,rw /proc/sys

# Pull the container image to be installed. During `podman build` the RUN
# container can't reach the host's container storage (Containerfile mounts can
# only reference the build context), and a bind mount wouldn't persist into the
# committed image anyway — so this always pulls into the payload's own storage,
# exactly like titanoboa's bazzite example.
podman pull "$INSTALL_IMAGE_PAYLOAD"

# The payload image is pre-loaded into container storage so Anaconda can
# install offline via --transport=containers-storage, which reads the
# expanded layer diffs. The compressed layer blobs are only needed for
# push/save, and keeping them would store every layer twice inside the ISO's
# squashfs (where zstd:19 can't shrink them further). Drop them here to cut
# several GB off the final ISO. Keep the small manifest/config blobs.
blobs_dir="$(podman info --format '{{.Store.GraphRoot}}' 2>/dev/null)/blobs/sha256"
[[ -d "$blobs_dir" ]] && find "$blobs_dir" -type f -size +1M -delete 2>/dev/null || true

# Export the payload reference so the hooks don't need to guess it from podman.
PAYLOAD_REF="${INSTALL_IMAGE_PAYLOAD#*://}"
export PAYLOAD_IMAGEREF="${PAYLOAD_REF%%:*}"
export PAYLOAD_IMAGETAG="${PAYLOAD_REF##*:}"

# Determine desktop environment
if [[ ${BASE_IMAGE} == *-gnome* ]]; then
    desktop_env="gnome"
else
    desktop_env="kde"
fi

# Run the preinitramfs hook
"$SCRIPT_DIR/titanoboa_hook_preinitramfs.sh"

# Install dracut-live and regenerate the initramfs
dnf install -y dracut-live
kernel=$(kernel-install list --json pretty | jq -r '.[] | select(.has_kernel == true) | .version')
DRACUT_NO_XATTR=1 dracut -v --force --zstd --reproducible --no-hostonly \
    --add "dmsquash-live dmsquash-live-autooverlay" \
    "/usr/lib/modules/${kernel}/initramfs.img" "${kernel}"

# The live ISO boots via /images/pxeboot/vmlinuz + initrd.img, which titanoboa
# copies from /usr/lib/modules/<kernel>{vmlinuz,initramfs.img}. Fail the build
# now if either piece is missing.
for f in "/usr/lib/modules/${kernel}/vmlinuz" "/usr/lib/modules/${kernel}/initramfs.img"; do
    [[ -f "$f" ]] || { echo "error: required kernel file missing: $f" >&2; exit 1; }
done

# Install livesys-scripts and configure them
dnf install -y livesys-scripts
if [[ ${BASE_IMAGE} == *-gnome* ]]; then
    sed -i "s/^livesys_session=.*/livesys_session=gnome/" /etc/sysconfig/livesys
else
    sed -i "s/^livesys_session=.*/livesys_session=kde/" /etc/sysconfig/livesys
fi
systemctl enable livesys.service livesys-late.service

# Run the postrootfs hook
"$SCRIPT_DIR/titanoboa_hook_postrootfs.sh"

# image-builder needs gcdx64.efi
dnf install -y grub2-efi-x64-cdboot shim-x64

# image-builder expects the EFI directory to be in /boot/efi
# (on Fedora >= 44 the shim and grub EFI binaries live under /usr/lib/efi/)
mkdir -p /boot/efi
cp -av /usr/lib/efi/*/*/EFI /boot/efi/

# Remove fallback efi
cp -v /boot/efi/EFI/fedora/grubx64.efi /boot/efi/EFI/BOOT/fbx64.efi # remove this line if breaks bootloader

# Fail loudly if the UEFI bootchain titanoboa needs is incomplete, instead of
# silently producing an ISO that firmware cannot boot.
for f in \
    /boot/efi/EFI/BOOT/BOOTX64.EFI \
    /boot/efi/EFI/fedora/shimx64.efi \
    /boot/efi/EFI/fedora/mmx64.efi \
    /boot/efi/EFI/fedora/gcdx64.efi \
    /boot/efi/EFI/fedora/grubx64.efi; do
    [[ -f "$f" ]] || { echo "error: required EFI file missing: $f" >&2; exit 1; }
done

# Set the timezone to UTC
rm -f /etc/localtime
systemd-firstboot --timezone UTC

# / in a booted live ISO is an overlayfs with upperdir pointed somewhere under /run
# This means that /var/tmp is also technically under /run.
# /run is of course a tmpfs, but set with quite a small size.
# ostree needs quite a lot of space on /var/tmp for temporary files so /run is not enough.
# Mount a larger tmpfs to /var/tmp at boot time to avoid this issue.
rm -rf /var/tmp
mkdir /var/tmp
cat >/etc/systemd/system/var-tmp.mount <<'EOF'
[Unit]
Description=Larger tmpfs for /var/tmp on live system

[Mount]
What=tmpfs
Where=/var/tmp
Type=tmpfs
Options=size=50%%,nr_inodes=1m,x-systemd.graceful-option=usrquota

[Install]
WantedBy=local-fs.target
EOF
systemctl enable var-tmp.mount

# Mount /var/lib/flatpak as readonly.
# This is in order to ensure the files dont get tainted when installing them in disk.
mkdir -p /var/lib/flatpak # the bind target must exist or live boot will fail the mount
cat >/etc/systemd/system/var-lib-flatpak.mount <<'EOF'
[Mount]
Type=none
What=/var/lib/flatpak
Where=/var/lib/flatpak
Options=bind,ro

[Install]
WantedBy=multi-user.target
EOF
systemctl enable var-lib-flatpak.mount

# Copy in the iso config for image-builder
mkdir -p /usr/lib/bootc-image-builder
cat >/usr/lib/bootc-image-builder/iso.yaml <<EOF
label: "$ISO_LABEL"
grub2:
  timeout: 3
  entries:
    - name: "Launch Floatblue Installer"
      linux: "/images/pxeboot/vmlinuz quiet rhgb root=live:CDLABEL=$ISO_LABEL enforcing=0 rd.live.image"
      initrd: "/images/pxeboot/initrd.img"
    - name: "Launch Floatblue Installer (Basic Graphics Mode)"
      linux: "/images/pxeboot/vmlinuz quiet rhgb root=live:CDLABEL=$ISO_LABEL enforcing=0 rd.live.image nomodeset"
      initrd: "/images/pxeboot/initrd.img"
EOF

# Clean up dnf cache to save space
dnf clean all