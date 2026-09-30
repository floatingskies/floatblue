[![bluebuild build badge](https://github.com/floatingskies/floatfin/actions/workflows/build-daily.yml/badge.svg)](https://github.com/floatingskies/floatfin/actions/workflows/build-daily.yml)

A personal choice distro made by Float.

A group of [Bootable Container](https://containers.github.io/bootable/) images built on top of [Bluefin DX](https://projectbluefin.io). [Bazzite](https://bazzite.gg) (GNOME) with [BlueBuild](https://blue-build.org)s tools. All the following is added to the image during the build time as a layer over the Universal Blue base including a generated initramfs so the boot-time branding stays.

Customizations added to the image:

-   Firefox as the browser (installed from RPM)

-   **Zorin OS themes**. All `ZorinBlue`/`Brown`/`Green`/`Grey`/`Orange`/`Purple`/`Red`/`Yellow` light+dark set in `/usr/share/themes` defaulting to `ZorinBlue-Light` (Bluefin) and `ZorinBlue-Dark` (Bazzite). Change any of them with `float-theme <name>` or `float-theme` to see all options. The theme is applied to GNOME, native GTK4 apps (via a ~/.config/gtk-4.0`) and GTK4 apps inside Flatpak

-   **Default wallpaper**. `Pixel Lake of Sound.jpeg` from the `Lake of Sound` collection on Bluefin and `Pixel Night of Sound.jpeg` on Bazzite (along with the `Floating Skies` System76 Framework, Ubuntu and KDE/Plasma collections in the GNOME wallpaper picker). Change it with `float-theme --wallpaper <name>`

-   [Intel One Mono](https://www.intel.com/content/www/us/en/company-overview/one-monospace-font.html) as the font (the document font stays Adwaita Sans)

-   Steam installed on the Bluefin images from negativo17 (Bazzite already has it)

-   Clocks set to AM/PM view with Weekday Display

-   Single click to open items in Nautilus

-   Smaller icons in Nautilus icon view

-   Directories appear first in Nautilus and GTK file choosers

-   Dark styles are the default

-   Dash-to-Dock is placed at the bottom skipping the Overview on login

-   Windows have minimize and maximize buttons

-   Touchpad tap-to-click is turned on

-   Fedora/GDM logo and the Plymouth spinner watermark are replaced with our own and the initramfs is rebuilt so they appear from the boot

-   The OS tells itself as *Floatfin* (Bluefin-based images) and *Floatite* (Bazzite-based images). Settings → About, installer branding, hostname

-   Bluefins *uwelcome* login banner is removed; instead the fish greeting (and `fastfetch`) shows a system summary with the floatfin.png logo and a **Floatfin** title

-   A dev-ops / sysadmin / web-dev CLI toolkit included: `ansible-core` `gh` `git-lfs` `jq` `shellcheck` `sshpass` `bind-utils` `htop` `iotop` `iperf3` `mtr` `ncdu` `net-tools` `sysstat` `tmux` `tree` `whois` `wget` `btop` `fd-find` `fzf` `pv` `ripgrep` `nodejs` `npm` and `python3-pip`

From Bluefin DX you get the default developer tooling out of the box: VS Code, Docker/Podman, a Logo Menu appindicator support and the `<CTRL><ALT>t` terminal shortcut. Rootful Docker and Starship are off by default and Tailscale doesn't start automatically.

Bluefins default Flatpaks still install on login; no extra Flatpaks are added to the image.

## Image Tags

`floatfin` is an overlay on [Bluefin DX](https://docs.projectbluefin.io/administration#upgrades-and-throttle-settings) following Bluefins image channels:

-   `ghcr.io/floatingskies/floatfin:gts` -- Bluefins gts stream, updated

-   `ghcr.io/floatingskies/floatfin:stable` -- Bluefins stable-weekly stream, updated weekly

-   `ghcr.io/floatingskies/floatfin:latest` -- Bluefins latest stream, updated daily

-   `ghcr.io/floatingskies/floatite:latest` -- Bazzite (GNOME) DX, updated daily

## Installation

First install any [Fedora Atomic](https://fedoraproject.org/atomic-desktops/) or [Universal Blue](https://universal-blue.org) desktop edition ( one that has GNOME, like Silverblue or Bluefin).

Then use `bootc switch` to switch to the image. For example:

```

sudo bootc switch ghcr.io/floatingskies/floatfin:latest --enforce-container-sigpolicy

```

reboot

```

systemctl reboot

```

## Installing via ISO

If you have `podman` on your system you can create an offline ISO with the `download-iso.sh` script in this directory like this:

```

./download-iso.sh floatfin stable

```

where `$IMAGE_NAME` is `floatfin` and `$TAG_NAME` is `stable` `gts` or `latest` (the script defaults to `floatfin:gts` if you omit both).

## Live ISO Images

Like [Bluefin](https://projectbluefin.io) and [Bazzite](https://bazzite.gg) live desktop ISOs are made using [Titanoboa](https://github.com/ublue-os/titanoboa). Start the **"Build ISOs"** GitHub Actions workflow ([Actions → Build Live ISOs](https://github.com/floatingskies/floatfin/actions/workflows/build-iso.yml)) and download the artifact:

-   `floatfin-stable-live-amd64.iso`. Live Bluefin desktop with the installed image inside

Boot the ISO. You have the full desktop running live from the image. To install the image to disk start **"Install, to Disk"** from the desktop (Anaconda). The installer also offers to enroll the Universal Blue boot key (password: `universalblue`) so it can boot with Secure Boot; it also works without Secure Boot or you can enroll your own keys later.

## Verification

These images are signed with [Sigstore](https://www.sigstore.dev/)s [cosign](https://github.com/sigstore/cosign). You can check the signature by downloading the `cosign.pub` file from this repo and running the following command:

```

cosign verify --key cosign.pub ghcr.io/floatingskies/floatfin:gts

cosign verify --key cosign.pub ghcr.io/floatingskies/floatfin:stable

cosign verify --key cosign.pub ghcr.io/floatingskies/floatfin:latest

cosign verify --key cosign.pub ghcr.io/floatingskies/floatite:latest

```

## Building Locally

```

./build-image.sh [recipe file]

```
