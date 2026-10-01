#!/usr/bin/bash
# Runs as the user at each login (via /etc/xdg/autostart). Once the first-boot
# Flatpak install has finished, says so — the apps come from the network and
# the desktop is usable long before they land, which is otherwise confusing.
#
# Fires at most once per user (marker under ~/.config) and stays silent if the
# install is still running: a later login notifies instead. Autostart is
# asynchronous, so nothing ever blocks the session.
set -euo pipefail

marker="${HOME}/.config/float-flatpaks-notified"
[[ -e $marker ]] && exit 0
[[ -e /var/lib/float/flatpaks.done ]] || exit 0

# Let the session bus settle before calling notify-send.
sleep 3
if command -v notify-send >/dev/null 2>&1; then
    notify-send -a Float "Default apps installed" \
        "Your default Flatpaks finished installing — they are in your app menu." || true
fi
: >"$marker"
