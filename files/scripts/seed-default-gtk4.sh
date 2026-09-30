#!/usr/bin/bash
set -euo pipefail

# Seed ~/.config/gtk-4.0 for new users from the flavour's default Zorin theme.
#
# gsettings already covers apps that go through the GNOME settings portal, but
# a plain `copy gtk-4.0 into ~/.config/gtk-4.0` is what most native/RPM GTK4
# apps actually read. /etc/skel is copied into $HOME on first login, so this
# gives every new account the theme without anyone running a command.
#
# An existing skel copy is replaced; accounts that already exist keep whatever
# they had (float-theme is the way to change it after the fact).

THEMES_DIR=/usr/share/themes

# floatite (Bazzite) is dark, floatfin (Bluefin) is light — same rule the
# gschema overrides and `float-theme --reset` use.
if [[ -r /usr/lib/os-release ]] && grep -q '^ID=floatite' /usr/lib/os-release; then
    theme=ZorinBlue-Dark
else
    theme=ZorinBlue-Light
fi

src="$THEMES_DIR/$theme/gtk-4.0"
if [[ ! -d $src ]]; then
    echo "error: default theme not found: $src" >&2
    exit 1
fi

dst=/etc/skel/.config/gtk-4.0
mkdir -p "$dst"
cp -a "$src/." "$dst/"

echo "Seeded /etc/skel/.config/gtk-4.0 from $theme"
