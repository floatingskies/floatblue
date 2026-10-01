[![bluebuild build badge](https://github.com/floatingskies/floatblue/actions/workflows/build-daily.yml/badge.svg)](https://github.com/floatingskies/floatblue/actions/workflows/build-daily.yml)

A personal choice distro made by Float.

A [Bootable Container](https://containers.github.io/bootable/) image built on top of [Bluefin DX](https://projectbluefin.io) with [BlueBuild](https://blue-build.org)s tools. All the following is added to the image during the build time as a layer over the Universal Blue base.

The desktop layout is left stock GNOME: no Dash to Dock, no accent icons, no
window-button reshuffling, no interface settings on top of what the base image
ships. Only the skin changes.

Customizations added to the image:

-   **Flat Remix theming**, Blue by default, across all four layers at once: GTK
    (`Flat-Remix-GTK-Blue-Light`/`-Dark`), libadwaita, GNOME Shell
    (`Flat-Remix-Light`/`-Dark`, via the *User Themes* extension) and icons
    (`Flat-Remix-Blue-Light`/`-Dark`). The cursor stays **Adwaita**. Flatpak apps
    get the same themes through a system-wide `flatpak override`. Upstream
    tarballs are pinned to a commit, so rebuilds are reproducible.

-   **The light/dark toggle follows through.** GNOME's Settings → Appearance (or
    the quick-settings toggle) swaps GTK, libadwaita, the shell theme and the
    icons together. This needs a little help: Flat Remix ships Light and Dark as
    *separate theme directories*, and its `libadwaita/` directory only contains a
    `gtk.css` (no `gtk-dark.css`), so leaving it to GTK's own colour-scheme
    handling would keep every libadwaita app light. `float-theme-sync`, a per-user
    service enabled for every login, watches `color-scheme` and applies all four.
    Native GTK3/GTK4 apps are covered too, via `~/.config/gtk-{3,4}.0/settings.ini`
    seeded from `/etc/skel`.

-   **Tails wallpapers, picked at random per build.** The Fedora, GNOME and
    Bluefin wallpapers are deleted along with their GNOME picker entries; the
    Tails collection is the only one offered. Both images show up in the picker,
    and which one is the first-boot default is decided by `RANDOM` during the
    build, so every rebuild/rebase lands on a different one. Nothing is
    downloaded at build time.

-   **The FloatOS logo everywhere it can show up.** Shipped under the pixmap
    filenames the base tooling already looks for (`fedora-gdm-logo.png`,
    `fedora-logo{,-icon,-med,-small}.png`, `fedora-whitelogo-med.png`) plus both
    Plymouth spinner watermarks, and the initramfs is regenerated so the splash
    is branded from the first frame. The logo is square, so it is letterboxed
    into each target box rather than squashed.

-   **Secureblue-style hardening, adapted** (see
    [recipes/features/hardening.yml](recipes/features/hardening.yml) for the full
    list of what was left out and why): kernel/network sysctl hardening,
    core dumps disabled, account lockout and password quality via the stock
    `pam_faillock`/`pam_pwquality`, per-network Wi-Fi MAC randomization,
    NTS-authenticated time, a desktop firewalld zone, and
    `geoclue`/`passim`/`cups`/`bluetooth` off. It stops short of removing
    `sudo`/`su`/`pkexec`, disabling Xwayland, blocking `ping`, or restricting
    `containers/policy.json`, because this image ships Steam, a network toolset,
    and uses podman/`bootc switch` to install and update itself.

-   **Homebrew** via `ublue-brew`, with the setup service and weekly
    update/upgrade timers enabled.

-   **No Flatpaks are pushed on you.** Flatpak and the Flathub remote are there
    and working, but the image installs no apps of its own: what you get is
    Fedora 44's RPM set plus the RPMs listed here. Install Flatpaks yourself
    whenever you want them.

-   **doas and the BSD/Unix corner of the toolbox.** `doas` (OpenBSD's privilege
    escalation) is installed *alongside* sudo, not instead of it: it is a much
    smaller attack surface, but it is not a drop-in replacement — no `sudo -u`,
    and `doas.conf` is far poorer than sudoers — and this image gets used for
    administration where Ansible and ordinary scripts assume sudo. The `wheel`
    group gets `permit persist :wheel`. Note the package is `opendoas`, the
    command is still `doas`. Alongside it: `ksh` (OpenBSD's shell lineage),
    `dash` (fast POSIX sh), `vis` (BSD's vi), `ed`, `mandoc`, `bc`, `bats`,
    `screen`, `ltrace`, `strace`, `lsof`, `rsync`, `gawk`, `mawk`, `parallel`,
    and the `m4`/`autoconf`/`automake`/`libtool` chain. What Fedora does not
    package — `openbsd-inetd`, `netcat-openbsd`, the NetBSD `cb-*` tools — is
    left out because upstream does not ship it, not as an oversight.

-   **Network and light security tooling**, all from stock Fedora repos: `nmap`
    `masscan` `arp-scan` `tcpdump` `wireshark-cli` `termshark` `traceroute` `mtr`
    `iperf3` `ethtool` `netcat` `socat` `gnutls-cli` `lynis` `audit`
    `libpwquality-tools`. Password crackers and brute-forcers are deliberately
    left out.

-   **Multimedia codecs** from the negativo17 COPR: `ffmpeg`,
    `gstreamer1-libav`, `gstreamer1-plugins-{bad,ugly}`, replacing the `-free`
    set so H.264/AAC and the usual containers just work.

-   Firefox as the browser (installed from RPM)

-   [Intel One Mono](https://www.intel.com/content/www/us/en/company-overview/one-monospace-font.html) as the font (the document font stays Adwaita Sans)

-   Steam installed from negativo17

-   The OS tells itself as *Floatblue*. Settings → About, installer branding, hostname

-   Bluefins *uwelcome* login banner is removed; instead the fish greeting (and `fastfetch`) shows a system summary with the Floatblue ASCII logo and a **Floatblue** title

-   A dev-ops / sysadmin / web-dev CLI toolkit included: `ansible-core` `gh` `git-lfs` `jq` `shellcheck` `sshpass` `bind-utils` `htop` `iotop` `iperf3` `mtr` `ncdu` `net-tools` `sysstat` `tmux` `tree` `whois` `wget` `btop` `fd-find` `fzf` `pv` `ripgrep` `nodejs` `npm` and `python3-pip`

From Bluefin DX you get the default developer tooling out of the box: VS Code, Docker/Podman, a Logo Menu appindicator support and the `<CTRL><ALT>t` terminal shortcut. Rootful Docker and Starship are off by default and Tailscale doesn't start automatically.

Bluefins default Flatpaks still install on login; no extra Flatpaks are added to the image.

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
