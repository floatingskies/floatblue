#!/usr/bin/bash

# Compile the dconf database.
#
# Dropping a file into /etc/dconf/db/distro.d is not enough on its own: dconf
# reads /etc/dconf/profile/user, and that profile only gets written by an
# explicit "dconf update". Without it every key we ship is silently ignored and
# the greeter and the extension list just stay whatever the base image set.

set -eou pipefail

BLUR=blur-my-shell@aunetx
GREETER_THEME=Flat-Remix-Dark

if ! command -v dconf >/dev/null 2>&1; then
    echo "dconf not installed, cannot compile the system database" >&2
    exit 1
fi

dconf update

# Read it back the same way a login session would, so a profile that compiled
# but did not take effect is caught here instead of at the greeter.
shell_dump=$(dconf dump /org/gnome/shell/ 2>/dev/null || true)
theme_dump=$(dconf dump /org/gnome/shell/extensions/user-theme/ 2>/dev/null || true)

if [[ $shell_dump != *"$BLUR"* ]]; then
    echo "error: $BLUR is not in disabled-extensions after dconf update" >&2
    exit 1
fi

if [[ $theme_dump != *"name='$GREETER_THEME'"* ]]; then
    echo "error: greeter theme is not $GREETER_THEME after dconf update" >&2
    exit 1
fi

echo "  dconf database compiled: blur-my-shell disabled, greeter set to $GREETER_THEME"
