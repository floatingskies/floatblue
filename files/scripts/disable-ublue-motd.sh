#!/usr/bin/bash

set -eou pipefail

# Remove the MOTD launchers and binaries baked into the Bluefin/Bazzite base
# images so no update/tip banner is shown on login for bash, zsh or fish.
#
# Bluefin's banner is "uwelcome" (launched from /etc/profile.d/uwelcome.sh and
# from the base fish greeting); older ublue-motd installs are cleaned up too.
#
# The Floatfin fish greeting (/usr/share/fish/vendor_conf.d/fish_greeting.fish)
# is shipped separately and intentionally left alone: it drops the banner and
# runs `ublue-fastfetch` (with the foxy.png logo) as a lean system summary.
rm -f /etc/profile.d/uwelcome.sh
rm -f /etc/profile.d/user-motd.sh
rm -f /etc/profile.d/ublue-motd.sh
rm -f /usr/bin/uwelcome
rm -rf /etc/uwelcome
rm -f /usr/libexec/ublue-motd
rm -f /usr/bin/ublue-motd
rm -f /usr/bin/umotd
rm -rf /usr/share/ublue-os/motd
rm -f /usr/share/fish/vendor_conf.d/fish_greeting.sh
rm -f /usr/share/fish/vendor_conf.d/fish_greeting.bash
rm -f /etc/fish/conf.d/fish_greeting.fish
