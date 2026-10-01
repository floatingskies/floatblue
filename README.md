[![bluebuild build badge](https://github.com/floatingskies/floatblue/actions/workflows/build-daily.yml/badge.svg)](https://github.com/floatingskies/floatblue/actions/workflows/build-daily.yml)


My own Fedora Atomic desktop, built on top of [Bluefin DX](https://projectbluefin.io) with [BlueBuild](https://blue-build.org).

It is mostly three things. A system that is locked down but still gets out of my
way, a machine that stays usable on hardware that is not fast, and a pile of the
Unix and BSD tools I keep reaching for and Fedora does not ship.

The desktop itself is stock GNOME. Dash to Dock and AppIndicator come from the
Bluefin base and I left them alone, because they are how I actually use a
machine. Blur My Shell is off. The widgets are stock Adwaita and the colour comes
from the wallpapers, which is the only part of the desktop that changes.

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
full screen repaint. Nothing writes this key at run time any more, so it is a
plain system default that takes effect at startup.

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
* **The panel logo is in the system dconf database, not the user one.** The Logo
  Menu extension reads `use-custom-icon` and `custom-icon-path` when the shell
  starts. Setting those on the user side works, but the shell has already read
  its settings by the time a session script could run, so the logo appears on the
  second login instead of the first. Writing them to `/etc/dconf/db/distro.d`
  puts them where the shell reads them at startup. Two scripts do this, for two
  reasons: the keyfile is compiled by `dconf update`, and
  `apply-logo-menu-brand.sh` also replaces the SVGs inside the extension's own
  `Resources` directory, so the icon is still the FloatOS mark if `use-custom-icon`
  is ever turned off
* **One more script, `apply-desktop-dconf.sh`.** Dropping a file into
  `/etc/dconf/db/distro.d` does nothing on its own, the profile under
  `/etc/dconf/profile/user` is only written by an explicit `dconf update`. That
  script runs the update and reads the result back, so a profile that compiled
  but did not take effect fails the build instead of silently doing nothing
* **GTK4 needs nothing special.** Adwaita already ships the right sheet for light
  and dark inside the same theme directory, so the whole arrangement of picking a
  variant per colour scheme is gone

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

* **Adwaita** for GTK, libadwaita, the shell and the icons, with the Adwaita
  cursor. This replaced Flat Remix, which was right on two counts. It is
  maintained outside GNOME, so a release that changed a widget class could leave
  it visibly stale and the only fix was to wait for someone else. And with the
  wallpapers carrying the colour, neutral widgets let a background actually be
  looked at, which is the point of having one. Doing light and dark used to take
  real work: Flat Remix keeps them in separate theme folders and its
  `libadwaita/` has no `gtk-dark.css`, so a libadwaita app stayed light whatever
  the colour scheme said, and a per-user service, `float-theme-sync`, watched
  that setting and rewrote the GTK theme, the icon theme, the shell theme and a
  copied libadwaita overlay on every login. Adwaita needs none of that
* **The logo.** Shipped under the pixmap file names the base tooling already
  looks for, plus both Plymouth watermarks, with the initramfs rebuilt so the
  splash is branded from the very first frame
* **Wallpapers.** Three collections, every one with a light and a dark variant.
  Floatblue is nine geometric patterns drawn from a set of named palettes, with
  the logo placed differently in each. Firewatch is thirteen flat banded
  landscapes, forests, reefs and skies in the style of the game. Tails is the
  older set, kept because it sits well with the rest of the desktop. The Fedora,
  GNOME and Bluefin collections are gone along with their entries in the picker.
  All three are day and night aware, and GNOME switches between the pair by
  itself. The Tails originals were daytime pastel scenes,
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

## The Mac image

There is a second image for Intel Macs that macOS has finished with, built on
**Silverblue** rather than Bluefin DX. Same Fedora underneath, without a desktop
stack tuned for a discrete GPU and a network configuration this hardware does not
want. Everything else is the same: the branding, the Adwaita theme, the
wallpapers, the profiles, the hardening. It comes out of its own
`floatblue-mac.yml` recipe and its own workflows, `build-image-mac.yml` and
`build-iso-mac.yml`.

It is tagged `stable-mac` and `mac`, deliberately not `stable`. The tag is what
bluebuild pushes, so reusing the desktop channel's name would mean whichever
build finished last would overwrite the other, for both machines.

### WiFi

BCM43xx, which is what the Airs and Pros from roughly 2006 to 2015 have. That is
`broadcom-wl` plus `akmod-wl` from RPM Fusion nonfree, and it needs the `akmods`
package to rebuild for a new kernel. This is the ordinary Fedora path, not
something specific to this image: Silverblue and Bluefin run the stock Fedora
kernel, the `main` flavour, so `kernel-devel` comes from the normal repositories
and `akmods` has what it needs to build. Universal Blue also publishes a prebuilt
`kmod-wl` in its akmods container, tagged `main-<fedora>` for this kernel, and
that one arrives already signed for Secure Boot. It is not wired in here because
pinning the image to a kernel version makes the whole thing need a rebuild every
time Fedora moves, but it is the better option on a T2 Mac if Secure Boot turns
out to be a problem. The practical consequence is worth stating
plainly: **after a kernel update the WiFi is gone until `akmods` finishes
building the module**, which on an Atomic image happens at boot. That is how the
driver is packaged, not something this image can fix. `apply-mac-hardware.sh`
fails the build if `broadcom-wl`, `akmod-wl` or `akmods` is missing, and reports
rather than fails on the module itself, which cannot exist before boot.

Apple Silicon is not supported and cannot be. Those Macs have no Broadcom radio,
so there is nothing for any of this to drive.

### The camera, honestly

The built-in iSight is a Broadcom BCM20300 on USB. Apple wrote a driver for it,
never upstreamed it, and the out of tree version stopped building years ago.
**There is no camera driver for that hardware on a current Fedora.** The FaceTime
HD camera, the separate one that plugs in and appears as a Broadcom 1570 on PCIe,
does have a driver, but only as a COPR or prebaked in the ublue akmods
container. A COPR repo file needs a numeric project id that changes without
notice, and a repo file pointing at nothing is a problem you only find at boot,
so it is not installed here.

What is installed instead is `v4l2loopback`, which gives a real virtual webcam
that FaceTime, Meet and Zoom will open. It shows a test pattern, on purpose: a
black rectangle would read as a broken camera, and this is not a picture of you.
`apply-mac-camera.sh` also reports which Broadcom camera it found, so you know
what you are dealing with before you boot.

### The rest

`t2fan` for fan control on the T2 Macs, which run hot with no fan curve at all.
`smc-tools` for battery and fan readings, which on a Mac is where the hardware
keeps them. `bluez` for Bluetooth, which is an internal Broadcom device rather
than a USB dongle. RPM Fusion is enabled for both free and nonfree, with the keys
fetched the way RPM Fusion publishes them.

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

### The theme comes along with it

The ISO payload is the container image, so everything under `/usr` is already there: the three wallpaper collections, the pixmaps, the branding and the FloatOS panel logo. Nothing is copied in separately for the ISO.

Two things are not automatic, and the post-rootfs hook now handles both:

- `glib-compile-schemas`, which is where `org.gnome.desktop.background` lives, so the wallpaper override and its light and dark pair are picked up.
- `dconf update`, which compiles `/etc/dconf/db/*.d`. That is where the disabled Blur My Shell, animations-off and the Logo Menu panel icon live. The hook previously only ran the glib half, so the dconf half depended entirely on `float-dconf-update.service` at boot. It worked, but relying on a service for something the hook can do deterministically is how a live ISO ends up booting unthemed with nothing in the log to explain it.

The hook then checks the payload actually carries what the desktop needs: the FloatOS panel logo, both branding pixmaps, the wallpaper override and all three wallpaper collections. It no longer checks for Flat Remix theme directories, icon themes or the User Themes extension, because the desktop is stock Adwaita now and none of that is a file the image adds. Any of those missing fails the ISO build rather than producing an ISO that only gets noticed from a screenshot later.

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
