[![bluebuild build badge](https://github.com/floatingskies/floatblue/actions/workflows/build-daily.yml/badge.svg)](https://github.com/floatingskies/floatblue/actions/workflows/build-daily.yml)

A personal choice distro made by Float.

A [Bootable Container](https://containers.github.io/bootable/) image built on top of [Bluefin DX](https://projectbluefin.io) with [BlueBuild](https://blue-build.org)s tools. All the following is added to the image during the build time as a layer over the Universal Blue base.

The desktop layout is left stock GNOME: no Dash to Dock, no accent icons, no
window-button reshuffling, no interface settings on top of what the base image
ships. Only the skin changes, and the rest of this is deliberately few.

## What makes it different

Most things below are table stakes for a Universal Blue image. These four are
the reasons the image is not just Bluefin with a coat of paint.

### The light/dark toggle moves the whole theme at once

Flipping GNOME's Settings → Appearance swaps GTK, libadwaita, the shell theme
and the icon set together, and keeps swapping on every later toggle. That is
not something the base image does, and Flat Remix specifically cannot do it on
its own: Light and Dark ship as *separate theme directories*, and its
`libadwaita/` directory contains only a `gtk.css` with no `gtk-dark.css`, so
every libadwaita application would stay light no matter what `color-scheme`
said.

`float-theme-sync` closes that gap. It is a per-user service enabled for every
login — present and future accounts — that watches `color-scheme` and applies
all four layers, including native GTK3/GTK4 applications through
`~/.config/gtk-{3,4}.0/settings.ini` seeded from `/etc/skel`, and Flatpak apps
through a per-user `flatpak override`. See
[recipes/features/theming.yml](recipes/features/theming.yml).

The skins themselves are Flat Remix, Blue, pinned to an upstream commit so
rebuilds are reproducible. That part is interchangeable; the synchronisation
is the point.

### Hardening with the rejections written down

Adapted from [secureblue](https://github.com/secureblue/secureblue), which is
the closest thing to a reference for this. The difference is the part secureblue
leaves out, and the fact that an i5-3550 is a stated target:

-   `sudo`, `su` and `pkexec` stay. secureblue's replacement, `run0`, starts a
    full systemd user session per call, which is visibly slow on a Sandy
    Bridge and breaks ordinary scripting. `doas` is installed alongside sudo
    instead — a much smaller attack surface, and not a drop-in replacement.
-   `perf_event_paranoid` is 2, not 3, so `perf` still works on your own
    processes.
-   `rp_filter` is loose rather than strict; strict mode drops legitimate
    packets on a laptop with Wi-Fi, Ethernet and a VPN.
-   No blanket module blacklisting. secureblue blocks `squashfs`, which is
    load-bearing for ostree and for the live ISO build.
-   No restrictive `containers/policy.json`: podman and `bootc switch` are how
    this image installs and updates itself.
-   Xwayland and `ping` stay on, because the image ships Steam and a network
    toolset.

What is applied: kernel and network sysctls, core dumps off, account lockout
and password quality through the stock `pam_faillock`/`pam_pwquality`,
per-network Wi-Fi MAC randomisation, NTS-authenticated time, and a desktop
firewalld zone that closes inbound connections without killing mDNS and device
discovery. Every omission is documented inline in
[recipes/features/hardening.yml](recipes/features/hardening.yml).

### RPM only. Nothing is pushed on you

No default Flatpak list, no first-boot app installer, no background service
downloading apps on login. What a machine gets is Fedora 44's own RPM set plus
the RPMs listed below. Flatpak and the Flathub remote are present and working
— `float-flatpak-remote.service` keeps the remote configured at every boot,
because a system-wide remote lives under `/var` and `bootc switch` resets it —
but the list is yours to write.

### Branded through the whole boot chain, and a wallpaper chosen by the build

The FloatOS logo ships under the pixmap filenames the base tooling already
looks for, so GDM, Settings → About and the installer pick it up by name, plus
both Plymouth spinner watermarks, with the initramfs regenerated so the splash
is branded from the first frame. The logo is square, so it is letterboxed into
each target box rather than squashed.

The wallpaper is the **Tails** collection and nothing else: the Fedora, GNOME
and Bluefin wallpapers are removed along with their GNOME picker entries, and
which Tails image is the first-boot default is decided by `RANDOM` during the
build. Every rebuild and every rebase lands on a different one.

## What it also ships

Table stakes for a uBlue image, listed without further argument.

-   **Flat Remix** Blue for GTK, libadwaita, shell and icons; **Adwaita** cursor
-   **doas** and the BSD/Unix corner: `ksh` `dash` `vis` `ed` `mandoc` `bc`
    `bats` `screen` `ltrace` `strace` `lsof` `rsync` `gawk` `mawk` `parallel`
    and the `m4`/`autoconf`/`automake`/`libtool` chain
-   **Network and light security tooling** from stock Fedora: `nmap` `masscan`
    `arp-scan` `tcpdump` `wireshark-cli` `traceroute` `mtr` `iperf3` `ethtool`
    `netcat` `socat` `gnutls-utils` `lynis` `audit` `libpwquality`. Password
    crackers and brute-forcers are deliberately left out
-   **A dev-ops / sysadmin / web-dev CLI toolkit**: `ansible-core` `gh`
    `git-lfs` `jq` `shellcheck` `sshpass` `bind-utils` `htop` `iotop` `ncdu`
    `net-tools` `sysstat` `tmux` `tree` `whois` `wget` `btop` `fd-find` `fzf`
    `pv` `ripgrep` `nodejs` `npm` `python3-pip`
-   **Homebrew** via `ublue-brew`, with the setup service and weekly
    update/upgrade timers
-   **Cockpit** on `https://localhost:9090`, and **multimedia codecs** from the
    negativo17 COPR (`ffmpeg`, `gstreamer1-libav`, `gstreamer1-plugins-{bad,ugly}`)
    so H.264/AAC and the usual containers just work
-   **Firefox** as the browser (RPM), **Steam** from negativo17, and
    [Intel One Mono](https://www.intel.com/content/www/us/en/company-overview/one-monospace-font.html)
    as the interface font
-   The OS calls itself **Floatblue** — Settings → About, installer branding,
    hostname — and Bluefin's *uwelcome* banner is replaced by a `fastfetch`
    system summary

From Bluefin DX you get the default developer tooling out of the box: VS Code, Docker/Podman, a Logo Menu appindicator support and the `<CTRL><ALT>t` terminal shortcut. Rootful Docker and Starship are off by default and Tailscale doesn't start automatically.

## Image Tags

`floatblue` is an overlay on [Bluefin DX](https://docs.projectbluefin.io/administration#upgrades-and-throttle-settings) following Bluefins image channels:

-   `ghcr.io/floatingskies/floatblue:gts` -- Bluefins gts stream, updated

-   `ghcr.io/floatingskies/floatblue:stable` -- Bluefins stable-weekly stream, updated weekly

-   `ghcr.io/floatingskies/floatblue:latest` -- Bluefins latest stream, updated daily


## Installation

First install any [Fedora Atomic](https://fedoraproject.org/atomic-desktops/) or [Universal Blue](https://universal-blue.org) desktop edition ( one that has GNOME, like Silverblue or Bluefin).

Then use `bootc switch` to switch to the image. For example:

```

sudo bootc switch ghcr.io/floatingskies/floatblue:latest --enforce-container-sigpolicy

```

reboot

```

systemctl reboot

```

## Installing via ISO

If you have `podman` on your system you can create an offline ISO with the `download-iso.sh` script in this directory like this:

```

./download-iso.sh floatblue stable

```

where `$IMAGE_NAME` is `floatblue` and `$TAG_NAME` is `stable` `gts` or `latest` (the script defaults to `floatblue:gts` if you omit both).

## Live ISO Images

Like [Bluefin](https://projectbluefin.io) live desktop ISOs are made using [Titanoboa](https://github.com/ublue-os/titanoboa). Start the **"Build ISOs"** GitHub Actions workflow ([Actions → Build Live ISOs](https://github.com/floatingskies/floatblue/actions/workflows/build-iso.yml)) and download the artifact:

-   `floatblue-stable-live-amd64.iso`. Live Bluefin desktop with the installed image inside

Boot the ISO. You have the full desktop running live from the image. To install the image to disk start **"Install, to Disk"** from the desktop (Anaconda). The installer also offers to enroll the Universal Blue boot key (password: `universalblue`) so it can boot with Secure Boot; it also works without Secure Boot or you can enroll your own keys later.

## Verification

These images are signed with [Sigstore](https://www.sigstore.dev/)s [cosign](https://github.com/sigstore/cosign). You can check the signature by downloading the `cosign.pub` file from this repo and running the following command:

```

cosign verify --key cosign.pub ghcr.io/floatingskies/floatblue:gts

cosign verify --key cosign.pub ghcr.io/floatingskies/floatblue:stable

cosign verify --key cosign.pub ghcr.io/floatingskies/floatblue:latest


```

## Building Locally

```

./build-image.sh [recipe file]

```
