[![bluebuild build badge](https://github.com/floatingskies/floatblue/actions/workflows/build-daily.yml/badge.svg)](https://github.com/floatingskies/floatblue/actions/workflows/build-daily.yml)


My own Fedora Atomic desktop, built on top of [Bluefin DX](https://projectbluefin.io) with [BlueBuild](https://blue-build.org).

It is mostly three things. A system that is locked down but still gets out of my
way, a machine that stays usable on hardware that is not fast, and a pile of the
Unix and BSD tools I keep reaching for and Fedora does not ship.

The desktop itself is stock GNOME. Dash to Dock and AppIndicator come from the
Bluefin base and I left them alone, because they are how I actually use a
machine. Blur My Shell is off. The skin is Flat Remix and nothing else moves.

## Small and old machines

The target is 3 to 4 GB of RAM on something like an i5-3550. That is a Sandy
Bridge part: no AVX2, and an integrated GPU from before Vulkan existed. The
whole low-end profile follows from those two facts.

**No Vulkan anywhere.** A pre-Haswell iGPU has no Vulkan driver in Mesa, so
anything built around it either refuses to start or falls back to software
Vulkan and ends up slower than the OpenGL path it replaced. Gamescope and
MangoHud are deliberately absent, and so is gamescope being the session
compositor. That is the one place I knowingly left performance on the table: on
a GPU from Haswell on, install both and you get a better experience. On this
hardware you would get a slower one.

**zram, half of RAM and never over 2 GB.** Compressed swap in RAM, so the
machine never reaches for the disk. This is the single biggest win at 4 GB,
because swapping on an older or spinning disk is where a responsive desktop
turns into a slideshow. It also inverts the usual advice: `vm.swappiness` is
raised to 180, because being reluctant to use a swap that lives in RAM and is
compressed just wastes memory that could hold something useful.

**earlyoom instead of the kernel OOM killer.** When memory runs out, earlyoom
kills the biggest process and tells you which one. The kernel OOM killer picks
something at random and, on a desktop, that is often the session.

**GNOME's file indexer is off.** `tracker-miners-fs3` is idle most of the time
and resident all of the time. On 4 GB that is a poor trade. PackageKit, the daily
dnf metadata refresh, `man-db` and `plocate` are off for the same reason.

**Shell animations off, system-wide.** Not a subtle preference on a software or
weak GPU. Every window open, every workspace switch and every notification is a
full screen repaint. `float-theme-sync` owns the themes, so this lives in its own
dconf keyfile and nothing else is written there.

**Laptop mode and smaller dirty ratios.** Writeback sooner and in smaller bursts,
so an older disk is not asked to absorb a large buffer all at once and stall
while it does.

Nothing here assumes a discrete GPU. Mesa's software rasteriser has to be present
and `apply-low-end-tuning.sh` fails the build if it is not, because a machine
with no working GL driver has no desktop at all.

### What the gaming profile does and does not do

GameMode is installed and set up the way Regata OS sets it up: on demand. It
raises the governor and re-nices a game while the game runs, and puts everything
back when it exits. Nothing keeps the CPU pinned at performance between games,
which is deliberate on a machine that also has to stay cool and quiet.

Two sysctls from the hardening set genuinely block games, and
`70-float-gaming.conf` relaxes them. This is a real trade and I would rather
write it down than hide it:

- `kernel.io_uring_disabled` goes from 2 to 1. It is off on the grounds that it
  has a long history of kernel bugs, which is fair, but Wine and Proton use it
  for ordinary file I/O and a good number of titles will not launch without it.
  1 keeps the syscall behind a permission check instead of removing it.
- `vm.mmap_rnd_bits` goes from 32 back to 28, the upstream default. 32 leaves
  too little address space for the very large reservations DXVK makes to
  emulate 64-bit addressing, and some of those allocations simply fail.

Nothing in the gaming profile touches kexec, BPF, userfaultfd, `tcp_timestamps`
or the ASLR setting itself. `apply-gaming-tuning.sh` checks that those are still
where the hardening file put them, so a typo in the gaming drop-in cannot
quietly take one down with it.

### Design, development, and defending

`creative.yml` is raster, vector, 3D and colour management, plus a fontconfig
drop-in that forces antialiasing and hinting on and rejects bitmap fonts. It
deliberately rejects only `.pcf` and `.bdf`, never TrueType or OpenType, since
rejecting those would leave very little to draw text with.

`developer.yml` is the things you only notice missing in the middle of a task:
git-delta, shfmt, pre-commit, direnv, bat, hyperfine, gdb, valgrind, bpftool,
podman-compose, buildah. No editor and no IDE, because on 4 GB an IDE would cost
more than everything else here put together and Bluefin DX already brings one.

`blue-team.yml` is the detection side of the hardening. AIDE for file integrity,
YARA and ClamAV for scanning, Suricata for the wire, and audit rules that watch
the sysctl drop-in, the dconf database, the sudoers and doas files and the
setuid bits. Two things it installs without arming: usbguard, because a policy
that blocks the wrong USB class takes your keyboard with it, and AIDE's database,
because `aideinit` walks the whole filesystem and would add minutes to every
build. Run `sudo aideinit` once.

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
* **The dock stays, the blur does not.** Dash to Dock and AppIndicator come from
  the Bluefin base and I kept them, they are how you actually use the machine.
  Blur My Shell is disabled through the system dconf database, because a shell
  theme over a blurred panel just looks broken
* **User Themes goes into the system extension list, not the user one.** This one
  cost me a while. `float-theme-sync` runs after the session starts, and by then
  gnome-shell has already read its extension list, so an extension enabled there
  is not picked up until the shell restarts. That is why the shell theme only
  showed up on the second login. `enable-user-theme-systemwide.sh` writes the key
  into the system dconf database instead, where it is read at shell startup. It
  merges rather than replaces: the list is read back out of the base image and
  user-theme is appended, so the dock and AppIndicator survive, and if it cannot
  parse what it found it fails the build instead of guessing
* **One more script, `apply-desktop-dconf.sh`.** Dropping a file into
  `/etc/dconf/db/distro.d` does nothing on its own, the profile under
  `/etc/dconf/profile/user` is only written by an explicit `dconf update`. That
  script runs the update and reads the result back, so a profile that compiled
  but did not take effect fails the build instead of silently doing nothing
* **GTK4 goes through the libadwaita half, as a user stylesheet.** Flat Remix
  ships two different sheets and they are not the same size. `gtk-4.0/gtk.css`
  is a 5298 line standalone sheet, `libadwaita/gtk.css` is an 83 line overlay
  with the palette and the titlebutton rules. The standalone one does not sit
  well with a modern libadwaita, which is the reason libadwaita exists as its
  own directory in the first place. So the overlay gets copied into
  `~/.config/gtk-4.0/gtk.css`, which GTK4 reads as a user stylesheet layered on
  top of the theme, and the Flatpak apps pick it up for free because the config
  dir is shared. It is copied again on every light/dark switch, since each
  variant has its own copy of the overlay. Worth being precise about one thing:
  that overlay has no dark and light mode embedded in it, no `.dark` selectors
  and no `prefers-color-scheme`. Dark mode comes from swapping between the
  `Flat-Remix-GTK-Blue-Light` and `Flat-Remix-GTK-Blue-Dark` variants, which is
  what `float-theme-sync` already does

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
* **Wallpapers.** Two collections, eleven light and dark pairs. Floatblue is nine
  patterns drawn from the Flat Remix palette, with the logo placed differently
  in each. Tails is the older set, kept because it sits well with the rest of the
  desktop. The Fedora, GNOME and Bluefin collections are gone along with their
  entries in the picker.
  Both are day and night aware. The Tails originals were daytime pastel scenes,
  so `generate-tails-nightwalls.sh` grades them per channel instead of dropping
  them to grayscale and mapping between two blues, which is the obvious way to do
  this and takes the colour out entirely. Red is scaled down hardest and blue
  barely at all, so warm things stay warm but dim and everything already cool
  goes deeper, which reads as moonlight without touching saturation. A small
  blue colorize ties it together. Mean luminance goes from 0.83 to 0.49, and
  pushing it further started crushing the fox into the background, since the
  source art has no real blacks to work with. The day versions get a small
  correction rather than a restyle: a wallpaper table set to mean 0.83 is
  unpleasant to look at on a bright desktop. Re-encoding also took the Tails
  collection from 6.6 MB to 2.7 MB.
  Which wallpaper becomes the default gets decided by `RANDOM` during the build,
  across both collections, as a light and dark pair rather than one image for
  both appearances.
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

Then switch to the image and reboot:

```
sudo bootc switch ghcr.io/floatingskies/floatblue:stable
systemctl reboot
```

Swap `:stable` for `:latest` (daily) or `:gts` (newest base).

There is no `--enforce-container-sigpolicy` on that command, and that is
deliberate. The flag makes bootc refuse to pull anything unless
`/etc/containers/policy.json` says what signature it should require, and this
image ships no policy file on purpose. With no policy, containers falls back to
`insecureAcceptAnything` and bootc would just stop with

```
containers-policy.json specifies a default of `insecureAcceptAnything`; refusing usage
```

A restrictive policy is the one actually worth having, and it is also the one
that breaks `podman pull` and `bootc switch` itself, since those are how this
image installs and updates. So there is no policy, and the images are signed
instead. Check them by hand, see [Verification](#verification) below.

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
