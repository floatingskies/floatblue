# floatfin &nbsp; [![bluebuild build badge](https://github.com/floatingskies/floatfin/actions/workflows/build-daily.yml/badge.svg)](https://github.com/floatingskies/floatfin/actions/workflows/build-daily.yml)

A bit opinionated distro made by Float.

A set of [Bootable Container](https://containers.github.io/bootable/) images built on top of [Bluefin DX](https://projectbluefin.io) and [Bazzite](https://bazzite.gg) (GNOME) with [BlueBuild](https://blue-build.org)'s tools. Everything below is baked into the image at build time as a layer over the Universal Blue base, including a regenerated initramfs so the boot-time branding survives.

Modifications baked into the image:

-   Firefox as the default browser (installed from RPM)
-   **Default wallpaper** — `fox.jpg` from the `floating-skies` collection on both Bluefin and Bazzite (available alongside `floating-woof` and the System76, Framework, Ubuntu, and KDE/Plasma collections in the GNOME wallpaper picker)
-   [Intel One Mono](https://www.intel.com/content/www/us/en/company-overview/one-monospace-font.html) set as the default interface font (the document font stays Adwaita Sans)
-   Steam installed on the Bluefin images from negativo17 (Bazzite already ships it)
-   Clocks set to AM/PM view with Weekday Display
-   Single click to open items in Nautilus
-   Use smaller icons in Nautilus icon view
-   Sort directories first in Nautilus and GTK file choosers
-   Dark styles enabled by default
-   Dash-to-Dock docked at the bottom, skipping the Overview on login
-   Windows have minimize and maximize buttons
-   Touchpad tap-to-click enabled
-   Fedora/GDM logo pixmaps and the Plymouth spinner watermark swapped for our own, and the initramfs rebuilt so they show from first boot
-   The OS identifies itself as *Floatfin* (Bluefin-based images) and *Floatite* (Bazzite-based images) — Settings → About, installer branding, hostname
-   Bluefin's *uwelcome* login banner is removed; instead the fish greeting (and `fastfetch`) shows a lean system summary with the foxy.png logo and a **Floatfin** title
-   A dev-ops / sysadmin / web-dev CLI toolkit baked in: `ansible-core`, `gh`, `git-lfs`, `jq`, `shellcheck`, `sshpass`, `bind-utils`, `htop`, `iotop`, `iperf3`, `mtr`, `ncdu`, `net-tools`, `sysstat`, `tmux`, `tree`, `whois`, `wget`, `btop`, `fd-find`, `fzf`, `pv`, `ripgrep`, `nodejs`, `npm`, and `python3-pip`

From Bluefin DX, you keep the usual developer tooling out of the box: VS Code, Docker/Podman, a Logo Menu, appindicator support and the `<CTRL><ALT>t` terminal shortcut. Rootful Docker and Starship are disabled by default, and Tailscale doesn't autostart.

Bluefin's default Flatpaks still install on first login; no extra Flatpaks are baked into the image.

## Image Tags

`floatfin` is an overlay on [Bluefin DX](https://docs.projectbluefin.io/administration#upgrades-and-throttle-settings) following Bluefin's image channels:

-   `ghcr.io/floatingskies/floatfin:gts` -- Bluefin's gts stream, updated weekly
-   `ghcr.io/floatingskies/floatfin:stable` -- Bluefin's stable-weekly stream, updated weekly
-   `ghcr.io/floatingskies/floatfin:latest` -- Bluefin's latest stream, updated daily
-   `ghcr.io/floatingskies/floatite:latest` -- Bazzite (GNOME) DX, updated daily

## Installation

First, install any [Fedora Atomic](https://fedoraproject.org/atomic-desktops/) or [Universal Blue](https://universal-blue.org) desktop edition (preferably one that features GNOME, like Silverblue or Bluefin).

Then use `bootc switch` to switch to the image. For example:

```
sudo bootc switch ghcr.io/floatingskies/floatfin:latest --enforce-container-sigpolicy
```

Then reboot

```
systemctl reboot
```

## Installing via ISO

If you have `podman` installed on your system, you can generate an offline ISO with the `download-iso.sh` script in this directory, like this:

```
./download-iso.sh floatfin stable
```

where `$IMAGE_NAME` is `floatfin` and `$TAG_NAME` corresponds to `stable`, `gts`, or `latest` (the script defaults to `floatfin:gts` if you omit both).

## Live ISO Images

Like [Bluefin](https://projectbluefin.io) and [Bazzite](https://bazzite.gg), live desktop ISOs are built using [Titanoboa](https://github.com/ublue-os/titanoboa). Trigger the **"Build Live ISOs"** GitHub Actions workflow ([Actions → Build Live ISOs](https://github.com/floatingskies/floatfin/actions/workflows/build-iso.yml)) and download the artifact:

-   `floatfin-stable-live-amd64.iso` — live Bluefin desktop with the installed image inside

Boot the ISO and you get the full desktop running live from the image. To install the image to disk, launch **"Install to Disk"** from the desktop (Anaconda). The installer will also offer to enroll the Universal Blue secure boot key (password: `universalblue`) so it can boot with Secure Boot; it also works fine without Secure Boot, or you can enroll your own keys later.

## Verification

These images are signed with [Sigstore](https://www.sigstore.dev/)'s [cosign](https://github.com/sigstore/cosign). You can verify the signature by downloading the `cosign.pub` file from this repo and running the following command:

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