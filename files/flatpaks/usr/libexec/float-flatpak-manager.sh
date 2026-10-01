#!/usr/bin/bash
# Installs the default Flatpaks on first boot.
#
# The live ISO boots this same image, so this also populates the live session
# and every freshly installed system.
#
# Configure by editing /etc/flatpak/install (one app-id per line; '#' comments
# and blank lines are ignored).
#
# A stamp is written under /var, so this runs once per image. /var is reset by
# `bootc switch` (rebase), which is intentional: after rebasing onto a new
# base the default apps are installed again automatically.
set -euo pipefail

INSTALL_LIST=/etc/flatpak/install
STAMP=/var/lib/float/flatpaks.done

if [[ ! -f $INSTALL_LIST ]]; then
    echo "float-flatpak-manager: no ${INSTALL_LIST}, nothing to do"
    exit 0
fi
if [[ -e $STAMP ]]; then
    exit 0
fi

ids=()
while IFS= read -r line || [[ -n $line ]]; do
    line="${line%%\#*}"
    line="${line//[[:space:]]/}"
    [[ -n $line ]] && ids+=("$line")
done <"$INSTALL_LIST"

if ((${#ids[@]} == 0)); then
    echo "float-flatpak-manager: ${INSTALL_LIST} has no entries, nothing to do"
    exit 0
fi

# Flathub only. No third-party remote is ever added here, which is also what
# keeps this consistent with the image's container/flatpak signature policy.
flatpak remote-add --if-not-exists --system flathub \
    https://dl.flathub.org/repo/flathub.flatpakrepo

echo "float-flatpak-manager: installing ${#ids[@]} flatpak(s)"
if flatpak install --system --noninteractive --assumeyes flathub "${ids[@]}"; then
    mkdir -p "$(dirname "$STAMP")"
    touch "$STAMP"
    echo "float-flatpak-manager: done (${STAMP})"
else
    # Non-zero here is what makes systemd retry: a partial failure should not
    # be recorded as success, or the stamp would block it forever.
    echo "float-flatpak-manager: install failed, will retry" >&2
    exit 1
fi
