#!/usr/bin/bash

# Compile the dconf database.
#
# Dropping a file into /etc/dconf/db/distro.d is not enough on its own: dconf
# reads /etc/dconf/profile/user, and that profile only gets written by an explicit
# "dconf update". Without it every key we ship is silently ignored and the greeter
# and the extension list just stay whatever the base image set.

set -eou pipefail

BLUR=blur-my-shell@aunetx
LOGO_MENU=/org/gnome/shell/extensions/Logo-menu
LOGO_PATH=/usr/share/floatblue/branding/floatos-logo-symbolic.svg

if ! command -v dconf >/dev/null 2>&1; then
    echo "dconf not installed, cannot compile the system database" >&2
    exit 1
fi

dconf update

# Read it back the same way a login session would, so a profile that compiled but
# did not take effect is caught here instead of at the greeter.
shell_dump=$(dconf dump /org/gnome/shell/ 2>/dev/null || true)
logo_dump=$(dconf dump "$LOGO_MENU/" 2>/dev/null || true)

if [[ $shell_dump != *"$BLUR"* ]]; then
    echo "error: $BLUR is not in disabled-extensions after dconf update" >&2
    exit 1
fi

# This used to check that the greeter theme was Flat-Remix-Dark, which was the
# single most load-bearing key in the image. There is no custom shell theme now,
# so the branding that does exist is checked instead: the panel icon. A wrong path
# here is not a cosmetic problem either, because an icon that fails to load falls
# back to the extension's own logo without saying anything.
if [[ $logo_dump != *"use-custom-icon=true"* ]]; then
    echo "error: logo-menu is not set to use a custom icon after dconf update" >&2
    echo "       $logo_dump" >&2
    exit 1
fi

if [[ $logo_dump != *"$LOGO_PATH"* ]]; then
    echo "error: logo-menu custom-icon-path is not $LOGO_PATH" >&2
    echo "       $logo_dump" >&2
    exit 1
fi

if [[ ! -s $LOGO_PATH ]]; then
    echo "error: logo-menu points at $LOGO_PATH and that file is not there" >&2
    exit 1
fi

echo "  dconf database compiled: blur-my-shell disabled, panel icon set to the FloatOS mark"
