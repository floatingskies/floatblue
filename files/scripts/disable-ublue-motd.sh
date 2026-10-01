#!/usr/bin/bash

set -eou pipefail

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
