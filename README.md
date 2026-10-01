[![bluebuild build badge](https://github.com/floatingskies/floatblue/actions/workflows/build-daily.yml/badge.svg)](https://github.com/floatingskies/floatblue/actions/workflows/build-daily.yml)

A personal choice distro made by Float.

A [Bootable Container](https://containers.github.io/bootable/) image built on top of [Bluefin DX](https://projectbluefin.io) with [BlueBuild](https://blue-build.org)s tools. It is layered over the Universal Blue base, and it is chiefly two things: a hardened system that stays usable, and a Unix/BSD-flavoured toolbox.

## Security

The image is hardened by default, adapted from
[secureblue](https://github.com/secureblue/secureblue) — the closest thing to a
reference for this — with two deliberate constraints: it has to stay usable
every day, and it has to stay usable on old hardware, an i5-3550 being the
stated target.

### What is applied

-   **Kernel and network hardening** in
    [60-float-hardening.conf](files/system/usr/lib/sysctl.d/60-float-hardening.conf):
    anti-spoofing and martian logging, ICMP redirects and source routing off,
    IPv6 privacy extensions, BPF JIT hardening, no unprivileged BPF, hardened
    ASLR, no kexec, `io_uring` disabled, userfaultfd restricted to
    `CAP_SYS_PTRACE`. Every value has its reasoning inline
-   **Core dumps off** across the three places that produce them (limits,
    systemd system and user, `systemd-coredump`), because a core of a browser
    can hold session tokens and page contents
-   **Account lockout and password quality** through the stock
    `pam_faillock` and `pam_pwquality`. The lockout is 10 attempts for 15
    minutes, not secureblue's 24 hours — a 24-hour lockout triggered by fat
    fingers on a laptop is not security, it is a support call. No PAM stack is
    rewritten, deliberately: a botched edit to `/etc/pam.d/*` locks you out of
    the graphical login and the only way back is a live USB
-   **Per-network Wi-Fi MAC randomisation** — random, then remembered per
    network, so networks that key on the MAC keep working while a passive
    observer cannot follow the machine across networks by its hardware address
-   **NTS-authenticated time** ([chrony](files/system/etc/chrony.conf)), so the
    clock cannot be pushed around. This matters more than it looks: TLS
    validation, TOTP/2FA and log forensics all trust the clock
-   **A desktop firewall zone** (`FloatWorkstation`) that closes inbound
    connections while keeping mDNS, printer and device discovery working —
    secureblue also ships a zone with every port removed, which is right for a
    server and hostile to a desktop
-   **Privacy services off**: `geoclue` and `passim` masked, `cups`,
    `cups-browsed` and `bluetooth` disabled rather than masked, so they come
    back with one command

### What was deliberately left out

The more interesting half. Anything can be bolted on; knowing what was rejected
and why is the part worth reading. All of it is documented inline in
[hardening.yml](recipes/features/hardening.yml).

-   **`sudo`, `su` and `pkexec` stay.** secureblue replaces them with `run0`,
    which starts a full systemd user session per call — visibly slow on a Sandy
    Bridge, and it breaks ordinary scripting. `doas` is installed alongside
    sudo instead; see below
-   **Xwayland stays on**, because the image ships Steam
-   **`ping` stays on**, because the image ships a network toolset
-   **`perf_event_paranoid` is 2, not 3**, so `perf` still works on your own
    processes
-   **`rp_filter` is loose, not strict.** Strict mode drops legitimate packets on
    a laptop that has Wi-Fi, Ethernet and a VPN at the same time, which presents
    as "the internet randomly doesn't work"
-   **No blanket module blacklisting.** secureblue blocks `squashfs`, which is
    load-bearing for ostree/bootc and for the live ISO build
-   **No restrictive `containers/policy.json`.** podman and `bootc switch` are
    how this image installs and updates itself; a policy that rejects unsigned
    registries breaks both in ways that are miserable to debug
-   **No DNS-over-TLS resolver swap.** Replacing systemd-resolved with a local
    validating resolver is a real hardening win, and also a common source of
    "podman cannot resolve anything"
-   **One GNOME extension, not zero.** *User Themes*, because a shell theme is
    inert without it. No Dash to Dock, no accent icons, nothing that touches
    the layout

## doas and the Unix/BSD toolbox

**`doas` is installed as an option, alongside sudo — not instead of it.** It is
OpenBSD's privilege escalation and a genuinely smaller attack surface: one
small setuid binary against sudo's plugin stack. It is not a drop-in
replacement, though — there is no `sudo -u`, and `doas.conf` is far poorer than
`sudoers` — and this image is used for administration, where Ansible and
ordinary scripts assume sudo. So both are installed, and the `wheel` group gets
`permit persist :wheel`. Note the Fedora package is `opendoas`; the command it
installs is `doas`.

Alongside it, the BSD and Unix corner of the toolbox, picked for what a sysadmin
or web developer actually reaches for:

-   **Shells** — `ksh` (OpenBSD's shell lineage) and `dash`, a fast POSIX `sh`
    that is far better than bash for testing script portability
-   **Text tools** — `vis` (BSD's `vi`, reads vi and vim motions), `ed`, `mandoc`
    (BSD's man formatter), `bc`
-   **Inspection** — `ltrace` next to `strace`, and `lsof` for open files
-   **Sysadmin core** — `rsync`, `gawk`, `mawk`, `parallel`, `bats` for shell
    test suites, `screen` as a second multiplexer
-   **Build chain** — `m4`, `autoconf`, `automake`, `libtool`, for building from
    source on an old CPU where the toolchain is already present beats spinning
    up a container
-   **Network and light security tooling**, all from stock Fedora repos — `nmap`,
    `masscan`, `arp-scan`, `tcpdump`, `wireshark-cli`, `traceroute`, `mtr`,
    `iperf3`, `ethtool`, `netcat`, `socat`, `gnutls-utils`, `lynis`, `audit`,
    `libpwquality`. Password crackers and brute-forcers are deliberately left
    out
-   **Cockpit** on `https://localhost:9090`, which is the natural companion to
    all of the above
-   **A dev-ops / web-dev CLI toolkit** — `ansible-core` `gh` `git-lfs` `jq`
    `shellcheck` `sshpass` `bind-utils` `htop` `iotop` `ncdu` `net-tools`
    `sysstat` `tmux` `tree` `whois` `wget` `btop` `fd-find` `fzf` `pv`
    `ripgrep` `nodejs` `npm` `python3-pip`

What Fedora does not package — `openbsd-inetd`, `netcat-openbsd`, the NetBSD
`cb-*` tools — is left out because upstream does not ship it, not as an
oversight.

## RPM only. Nothing is pushed on you

No default Flatpak list, no first-boot app installer, no background service
downloading apps on login. What a machine gets is Fedora 44's own RPM set plus
the RPMs listed here. Flatpak and the Flathub remote are present and working —
`float-flatpak-remote.service` keeps the remote configured at every boot,
because a system-wide remote lives under `/var` and `bootc switch` resets it —
but the list is yours to write.

## Everything else

Details, not differentiators.

-   **Flat Remix** Blue for GTK, libadwaita, the shell and the icons, with the
    **Adwaita** cursor. GNOME's Settings → Appearance swaps all four together:
    Flat Remix ships Light and Dark as separate theme directories and its
    `libadwaita/` has no `gtk-dark.css`, so a per-user service,
    `float-theme-sync`, watches `color-scheme` and applies all four, covering
    native GTK3/GTK4 apps and Flatpaks too
-   **The FloatOS logo** under the pixmap filenames the base tooling already
    looks for, plus both Plymouth spinner watermarks, with the initramfs
    regenerated so the splash is branded from the first frame
-   **The Tails collection is the only wallpaper**; the Fedora, GNOME and Bluefin
    ones are removed along with their picker entries, and which Tails image is
    the first-boot default is decided by `RANDOM` during the build, so every
    rebuild and rebase lands on a different one
-   **Homebrew** via `ublue-brew`, with the setup service and weekly
    update/upgrade timers
-   **Multimedia codecs** from the negativo17 COPR (`ffmpeg`,
    `gstreamer1-libav`, `gstreamer1-plugins-{bad,ugly}`) so H.264/AAC and the
    usual containers just work
-   **Firefox** as the browser (RPM), **Steam** from negativo17, and
    [Intel One Mono](https://www.intel.com/content/www/us/en/company-overview/one-monospace-font.html)
    as the interface font
-   The OS calls itself **Floatblue** — Settings → About, installer branding,
    hostname — and Bluefin's *uwelcome* banner is replaced by a `fastfetch`
    system summary

The desktop layout is stock GNOME throughout: no Dash to Dock, no accent icons,
no window-button reshuffling, no interface settings on top of what the base
image ships.

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
