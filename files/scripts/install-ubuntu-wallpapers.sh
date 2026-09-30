#!/usr/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cd /tmp
# This takes far too long ...
# git clone https://git.launchpad.net/ubuntu/+source/ubuntu-wallpapers
# cd ubuntu-wallpapers
echo "Downloading Ubuntu wallpapers"
URLS=(
  "https://launchpad.net/ubuntu/+archive/primary/+sourcefiles/ubuntu-wallpapers/24.04.2/ubuntu-wallpapers_24.04.2.orig.tar.gz"
  "https://archive.ubuntu.com/ubuntu/pool/main/u/ubuntu-wallpapers/ubuntu-wallpapers_24.04.2.orig.tar.gz"
)
ok=0
for URL in "${URLS[@]}"; do
  if curl -fL --retry 5 --retry-delay 5 --retry-all-errors \
      -o ubuntu-wallpapers_24.04.2.orig.tar.gz "$URL"; then
    ok=1
    break
  fi
  echo "Download failed for $URL, trying next mirror..."
done
(( ok )) || { echo "All downloads of ubuntu-wallpapers failed" >&2; exit 1; }

tar xzf ubuntu-wallpapers_24.04.2.orig.tar.gz 
cd ubuntu-wallpapers_24.04.2.orig

UBUNTU_RELEASES="noble mantic jammy focal bionic artful xenial trusty precise lucid"
rm -rf staging_area && mkdir staging_area
for UBUNTU_VERSION in $UBUNTU_RELEASES; do
    cat debian/ubuntu-wallpapers-$UBUNTU_VERSION.install | grep -v .xml | grep -v '^$' \
    | grep -v The_Land_of_Edonias | cut -d / -f 4 \
      >> files_to_copy
done
cat files_to_copy | xargs -I % cp % staging_area
mkdir /usr/share/backgrounds/ubuntu
cp staging_area/* /usr/share/backgrounds/ubuntu
echo "Additional disk space used in kb"
du /usr/share/backgrounds/ubuntu

# Register the (flat) collection with GNOME's wallpaper picker. Ubuntu ships
# its own .xml files, but they reference the images from their original
# release subdirectories, so we regenerate one that matches our layout.
"$SCRIPT_DIR/generate-gnome-wallpaper-xml.sh" /usr/share/backgrounds/ubuntu ubuntu-wallpapers "Ubuntu"