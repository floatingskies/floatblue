#!/usr/bin/env bash
# Adapted from https://github.com/ublue-os/bazzite/blob/main/installer/titanoboa_hook_postrootfs.sh

set -exo pipefail

source /etc/os-release

# Remove all versionlocks, in order to avoid dependency issues
dnf -qy versionlock clear || true

# Install Anaconda
dnf install -qy --enable-repo=fedora-cisco-openh264 --allowerasing firefox anaconda-live libblockdev-{btrfs,lvm,dm}

mkdir -p /var/lib/rpm-state # Needed for Anaconda Web UI

# Default the installer's automatic partitioning to plain partitions instead of
# LVM. Loaded as a custom Anaconda configuration file (later than the default
# anaconda.conf), so automatic partitioning creates standard partitions.
# Users can still choose LVM, Btrfs, or a custom layout in the storage spoke.
mkdir -p /etc/anaconda/conf.d
cat >/etc/anaconda/conf.d/99-ublue-partitioning.conf <<EOF
[Storage]
default_scheme = PLAIN
EOF

# Utilities for displaying a dialog prompting users to review secure boot documentation
dnf install -qy --setopt=install_weak_deps=0 qrencode yad

# Variables
imageref="${PAYLOAD_IMAGEREF:-$(podman images --format '{{ index .Names 0 }}\n' 'ublue*' | head -1)}"
imageref="${imageref##*://}"
imageref="${imageref%%:*}"
imagetag="${PAYLOAD_IMAGETAG:-$(podman images --format '{{ .Tag }}\n' "$imageref" | head -1)}"
imagetag="${imagetag##*:}"
sbkey='https://github.com/ublue-os/akmods/raw/main/certs/public_key.der'
SECUREBOOT_KEY="/usr/share/ublue-os/sb_pubkey.der"
SECUREBOOT_DOC_URL="https://docs.bazzite.gg/sb"
SECUREBOOT_DOC_URL_QR="/usr/share/ublue-os/secure_boot_qr.png"

# Anaconda profile
: ${VARIANT_ID:=$ID}

if [[ -n "${VERSION_CODENAME:-}" ]]; then
    echo "floatblue release $VERSION_ID ($VERSION_CODENAME)" >/etc/system-release
else
    echo "floatblue release $VERSION_ID" >/etc/system-release
fi

# Secureboot Key Fetch
mkdir -p /usr/share/ublue-os
curl -Lo /usr/share/ublue-os/sb_pubkey.der "$sbkey"

# Default Kickstart
cat <<EOF >>/usr/share/anaconda/interactive-defaults.ks

# Check if there is a bitlocker partition and ask the user to disable it
%pre --erroronfail --log=/tmp/ublue_detect_bitlocker.log
DOCS_QR=/tmp/detect_bitlocker_qr.png
IS_BITLOCKER=\$(lsblk -o FSTYPE --json | jq '.blockdevices | map(select(.fstype == "BitLocker")) | . != []')
{ WARNING_MSG="\$(</dev/stdin)"; } << 'WARNINGEOF'
<span size="x-large">Windows Bitlocker partition detected</span>

It might interrupt the installation process.
In such case, please, do <b>one</b> of the following:
    a) Disconnect its storage drive.
    b) Disable Bitlocker in Windows.
    c) Delete it in GNOME Disks.

Do you wish to continue?
WARNINGEOF

if [[ \$IS_BITLOCKER =~ true ]]; then
    qrencode -o \$DOCS_QR "https://www.wikihow.com/Turn-Off-BitLocker"
    _EXITLOCK=1
    _RETCODE=0
    while [[ \$_EXITLOCK -ne 0 ]]; do
        run0 --user=liveuser yad \
            --on-top \
            --timeout=10 \
            --image=\$DOCS_QR \
            --text="\$WARNING_MSG" \
            --button="Yes, I'm aware, continue":0 --button="Cancel installation":10
        _RETCODE=\$?
        case \$_RETCODE in
            0) _EXITLOCK=0; ;;
            10) _EXITLOCK=0; pkill liveinst; pkill firefox; exit 0 ;;
        esac
    done
fi
%end

# Remove the efi dir, must match efi_dir from the profile config
%pre-install --erroronfail
rm -rf /mnt/sysroot/boot/efi/EFI/fedora
%end

# Relabel the boot partition so the rescue entry can find it
%pre-install --erroronfail --log=/tmp/ublue_repartitioning.log
set -x
xboot_dev=\$(findmnt -o SOURCE --nofsroot --noheadings -f --target /mnt/sysroot/boot)
if [[ -z \$xboot_dev ]]; then
  echo "ERROR: xboot_dev not found"
  exit 1
fi
e2label "\$xboot_dev" "ublue_xboot"
%end

# Open a dialog with the installation logs
%onerror
run0 --user=liveuser yad \
    --timeout=0 \
    --text-info \
    --no-buttons \
    --width=600 \
    --height=400 \
    --text="An error occurred during installation. Please report this issue to the developers." \
    < /tmp/anaconda.log
%end

ostreecontainer --url=$imageref:$imagetag --transport=containers-storage --no-signature-verification
%include /usr/share/anaconda/post-scripts/ublue-install-configure-upgrade.ks
%include /usr/share/anaconda/post-scripts/ublue-secureboot-enroll-key.ks
%include /usr/share/anaconda/post-scripts/ublue-secureboot-docs.ks
EOF

mkdir -p /usr/share/anaconda/post-scripts

# Switch to the container image on disk
cat <<EOF >/usr/share/anaconda/post-scripts/ublue-install-configure-upgrade.ks
%post --erroronfail --log=/tmp/ublue_bootc-switch.log
bootc switch --mutate-in-place --enforce-container-sigpolicy --transport registry $imageref:$imagetag
%end
EOF

# Enroll Secureboot Key
cat <<EOF >/usr/share/anaconda/post-scripts/ublue-secureboot-enroll-key.ks
%post --erroronfail --nochroot --log=/tmp/ublue_secureboot-enroll-key.log
set -oue pipefail

readonly ENROLLMENT_PASSWORD="universalblue"
readonly SECUREBOOT_KEY="$SECUREBOOT_KEY"

if [[ ! -d "/sys/firmware/efi" ]]; then
	echo "EFI mode not detected. Skipping key enrollment."
	exit 0
fi

if [[ ! -f "\$SECUREBOOT_KEY" ]]; then
	echo "Secure boot key not provided: \$SECUREBOOT_KEY"
	exit 0
fi

mokutil --timeout -1 || :
echo -e "\$ENROLLMENT_PASSWORD\n\$ENROLLMENT_PASSWORD" | mokutil --import "\$SECUREBOOT_KEY" || :
%end
EOF

cat <<EOF >/usr/share/anaconda/post-scripts/ublue-secureboot-docs.ks
%post --nochroot --log=/tmp/ublue_secureboot-docs.log
SECUREBOOT_KEY="$SECUREBOOT_KEY"
SECUREBOOT_DOC_URL="$SECUREBOOT_DOC_URL"
SECUREBOOT_DOC_URL_QR="$SECUREBOOT_DOC_URL_QR"

LC_ALL=C mokutil -t "\$SECUREBOOT_KEY" | grep -q "is already in the enrollment request" && \
    run0 --user=liveuser yad --timeout=0 --on-top --button=Ok:0 --image="\$SECUREBOOT_DOC_URL_QR" --text="<b>Secure Boot Key added:</b>\nPlease check the documentation to finish enrolling the key\n\$SECUREBOOT_DOC_URL"
%end
EOF

qrencode -o "$SECUREBOOT_DOC_URL_QR" "$SECUREBOOT_DOC_URL"

### Livecds runtime tweaks ###

# Disable services
(
    set +e
    for s in \
        rpm-ostree-countme.service \
        tailscaled.service \
        ublue-hardware-setup.service \
        bootloader-update.service \
        rpm-ostreed-automatic.timer \
        uupd.timer \
        ublue-guest-user.service \
        ublue-os-media-automount.service \
        ublue-system-setup.service \
        ublue-flatpak-manager.service \
        flatpak-add-fedora-repos.service \
        greenboot-set-rollback-trigger.service \
        greenboot-healthcheck.service \
        switcheroo-control.service \
        check-sb-key.service; do
        if systemctl list-unit-files "$s" >/dev/null 2>&1; then
            systemctl disable "$s"
        fi
    done

    for s in \
        podman-auto-update.timer \
        ublue-user-setup.service; do
        if systemctl --global list-unit-files "$s" >/dev/null 2>&1; then
            systemctl --global disable "$s"
        fi
    done
)

### Desktop-environment specific tweaks ###

# Determine desktop environment. Must match one of /usr/libexec/livesys/sessions.d/livesys-{desktop_env}
desktop_env=""
_session_file="$(find /usr/share/wayland-sessions/ /usr/share/xsessions \
    -maxdepth 1 -type f -not -name '*gamescope*.desktop' -and -name '*.desktop' -printf '%P' -quit)"
case $_session_file in
budgie*) desktop_env=budgie ;;
cosmic*) desktop_env=cosmic ;;
gnome*) desktop_env=gnome ;;
plasma*) desktop_env=kde ;;
sway*) desktop_env=sway ;;
xfce*) desktop_env=xfce ;;
esac

# Don't check for verified image
rm -vf /etc/profile.d/verify_motd.sh

# Don't start the fedora-welcome app (gnome only)
if [[ $desktop_env == gnome ]]; then
    sed -i 's@\[Desktop Entry\]@\[Desktop Entry\]\nHidden=true@g' /usr/share/anaconda/gnome/org.fedoraproject.welcome-screen.desktop || :
fi

rm -f /usr/bin/rpm-ostree # Should never under any circumstance be ran on the live ISO

# Recompile schemas so the live session picks up dconf/gschema overrides
if [[ $desktop_env == gnome ]]; then
    glib-compile-schemas /usr/share/glib-2.0/schemas
fi

# Install Gparted
dnf -yq install gparted

###############################