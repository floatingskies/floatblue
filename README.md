[![bluebuild build badge](https://github.com/floatingskies/floatblue/actions/workflows/build-daily.yml/badge.svg)](https://github.com/floatingskies/floatblue/actions/workflows/build-daily.yml)


My own Fedora Atomic desktop, built on top of [Bluefin DX](https://projectbluefin.io) with [BlueBuild](https://blue-build.org).

It is mostly two things. A system that is locked down but still gets out of my
way, and a pile of the Unix and BSD tools I keep reaching for and Fedora does
not ship. Everything else is small.

The desktop itself is stock GNOME. No dock, no accent icons, no window button
shuffling, nothing like that. Just the skin.

## Security

I started from [secureblue](https://github.com/secureblue/secureblue), which is
the best reference for this kind of work, and then took a lot of it back out
again. Two reasons. I want this to be my daily driver, and I have an i5-3550
under the desk that I do not want to make slower.

### What it does

* A pile of kernel and network sysctls in
  [60-float-hardening.conf](files/system/usr/lib/sysctl.d/60-float-hardening.conf).
  Anti spoofing, martian logging, ICMP redirects and source routing off, IPv6
  privacy extensions, hardened ASLR, no kexec, io_uring off, and so on
* Core dumps turned off in all three places that produce them. A core dump of a
  browser can be full of session tokens and page contents
* Account lockout and password rules through the stock `pam_faillock` and
  `pam_pwquality`. Ten tries, fifteen minutes. secureblue uses 24 hours, which
  on a laptop just means support calls. I do not touch any PAM stack, because
  breaking `/etc/pam.d/*` locks you out of the login screen and the only way
  back is a live USB
* Wi-Fi MAC addresses randomized per network. Random, but remembered, so
  networks that key on the MAC keep working while nobody can follow the machine
  around by its hardware address
* Time over NTS, in [chrony.conf](files/system/etc/chrony.conf), so nobody can
  shove a bogus clock at the machine. This one matters more than it looks.
  TLS, 2FA and log forensics all trust the clock
* A firewall zone of my own. It closes inbound connections but keeps mDNS and
  device discovery working, because secureblue also ships a zone with every
  port removed and that is great for a server and miserable for a desktop
* `geoclue` and `passim` masked, `cups`, `cups-browsed` and `bluetooth` merely
  disabled so they come back with one command

### What I took back out

This is the part worth reading if you are copying any of this.

* **sudo, su and pkexec all stay.** secureblue drops them for `run0`, and
  `run0` starts a whole systemd session every single time you call it. On a
  Sandy Bridge you feel that, and it breaks ordinary scripting. I put doas
  next to sudo instead, which is a real improvement, just not a swap
* **Xwayland stays on**, the image has Steam
* **ping stays on**, the image has a network toolset
* **`perf_event_paranoid` is 2 instead of 3**, so perf still works on my own
  processes
* **`rp_filter` is loose, not strict.** Strict drops legitimate packets on a
  laptop with Wi-Fi, Ethernet and a VPN at once, which shows up as "the
  internet randomly doesn't work"
* **No blanket module blacklisting.** secureblue blocks `squashfs` and that
  one is load bearing for ostree, bootc and the live ISO build
* **No restrictive `containers/policy.json`.** podman and `bootc switch` are
  how this image installs and updates itself, and a policy that rejects
  unsigned registries breaks both in ways that are miserable to debug
* **I did not swap the resolver.** Running a local validating DNS server is a
  real hardening win and also a classic way to end up with podman that cannot
  resolve anything
* **One GNOME extension, not zero.** User Themes, because a shell theme does
  nothing without it. No dock, no accent icons, nothing that touches the layout

## doas and the BSD/Unix tools

doas is OpenBSD's privilege escalation. It is a much smaller attack surface
than sudo, one small setuid binary instead of a pile of plugins, and I like
it. But it is not a drop in replacement. There is no `sudo -u`, and doas.conf
is a lot poorer than sudoers, and I do admin work where Ansible and scripts
just assume sudo. So both are installed and wheel gets `permit persist :wheel`.
Note the Fedora package is called `opendoas`, the command is still `doas`.

Then the tools. All of these are in stock Fedora, nothing from a third party
repo to babysit across releases.

* **Shells.** `ksh`, which is OpenBSD's shell lineage, and `dash`, a fast POSIX
  sh that is much better than bash when you are checking whether a script
  really is portable
* **Text.** `vis` is BSD's vi and understands vi and vim motions. `ed`, `mandoc`
  for man pages, `bc`
* **Looking at things.** `ltrace` next to strace, `lsof` for open files
* **The usual suspects.** `rsync`, `gawk`, `mawk`, `parallel`, `bats` for shell
  test suites, `screen` as a second multiplexer
* **Building from source.** `m4`, `autoconf`, `automake`, `libtool`. Having the
  toolchain sitting there beats spinning up a container on this CPU
* **Network and light security.** `nmap` `masscan` `arp-scan` `tcpdump`
  `wireshark-cli` `traceroute` `mtr` `iperf3` `ethtool` `netcat` `socat`
  `gnutls-utils` `lynis` `audit` `libpwquality`. I left the password crackers
  and the brute forcers out on purpose
* **Cockpit** on `https://localhost:9090`, which goes with the rest of that
* **A devops pile.** `ansible-core` `gh` `git-lfs` `jq` `shellcheck` `sshpass`
  `bind-utils` `htop` `iotop` `ncdu` `net-tools` `sysstat` `tmux` `tree` `whois`
  `wget` `btop` `fd-find` `fzf` `pv` `ripgrep` `nodejs` `npm` `python3-pip`

Some BSD things Fedora simply does not package, so they are not here:
`openbsd-inetd`, `netcat-openbsd`, the NetBSD `cb-*` tools. Not an oversight,
upstream does not ship them.

## No Flatpaks pushed on you

There is no default Flatpak list, no installer that runs on first boot, no
background service quietly downloading apps while you log in. What a machine
ends up with is Fedora 44's own RPM set plus the RPMs listed here.

Flatpak and Flathub are there and work. `float-flatpak-remote.service` keeps
the remote configured at every boot, because a system wide remote lives under
`/var` and `bootc switch` throws `/var` away. The list of apps is yours to
write.

## Smaller stuff

* **Flat Remix** in blue, for GTK, libadwaita, the shell and the icons, with
  the Adwaita cursor. Toggling light and dark in Settings swaps all four at
  once, which took a little work: Flat Remix keeps Light and Dark in separate
  theme folders and its `libadwaita/` has no `gtk-dark.css`, so every libadwaita
  app would stay light no matter what the colour scheme said. A per user
  service called `float-theme-sync` watches that setting and applies all four,
  including to native GTK3 and GTK4 apps and to Flatpaks
* **The logo.** Shipped under the pixmap file names the base tooling already
  looks for, plus both Plymouth watermarks, with the initramfs rebuilt so the
  splash is branded from the very first frame
* **Wallpapers.** Just the Tails collection. The Fedora, GNOME and Bluefin ones
  are gone along with their entries in the picker, and which Tails image is the
  default gets decided by `RANDOM` during the build, so every rebuild lands on
  a different one
* **Homebrew** via `ublue-brew`, with the setup service and the weekly update
  and upgrade timers
* **Codecs** from the negativo17 COPR (`ffmpeg`, `gstreamer1-libav`,
  `gstreamer1-plugins-{bad,ugly}`) so H.264 and AAC and the usual containers
  just work
* **Firefox** as the browser, as an RPM. **Steam** from negativo17.
  [Intel One Mono](https://www.intel.com/content/www/us/en/company-overview/one-monospace-font.html)
  as the interface font
* The system calls itself **Floatblue**, in Settings, in the installer and as
  the hostname. Bluefin's welcome banner is gone, replaced by a `fastfetch`
  summary

From Bluefin DX you already have VS Code, Docker and Podman, the app indicator
menu and Ctrl+Alt+T. Rootful Docker and Starship are off and Tailscale does
not start on its own.

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
