#!/usr/bin/bash
set -euo pipefail

BASE_OS_RELEASE="${BASE_OS_RELEASE:-/etc/os-release}"
OUT_OS_RELEASE="${OUT_OS_RELEASE:-/usr/lib/os-release}"

get_kv() {
    local key="$1"
    grep "^${key}=" "$BASE_OS_RELEASE" | head -1 | cut -d= -f2- | tr -d '"' || true
    return 0
}

BASE_ID="$(get_kv ID)"
BASE_ID="${BASE_ID:-fedora}"
BASE_ID_LIKE="$(get_kv ID_LIKE)"
BASE_VERSION_ID="$(get_kv VERSION_ID)"
BASE_VERSION_CODENAME="$(get_kv VERSION_CODENAME)"
BASE_VARIANT="$(get_kv VARIANT)"
BASE_VARIANT_ID="$(get_kv VARIANT_ID)"
BASE_SUPPORT_END="$(get_kv SUPPORT_END)"

case "$BASE_ID" in
    bluefin*)
        IMAGE_NAME="${IMAGE_NAME:-Floatblue}"
        IMAGE_ID="${IMAGE_ID:-floatblue}"
        IMAGE_HOSTNAME="${IMAGE_HOSTNAME:-floatblue}"
        ;;
    bazzite*)
        IMAGE_NAME="${IMAGE_NAME:-Floatite}"
        IMAGE_ID="${IMAGE_ID:-floatite}"
        IMAGE_HOSTNAME="${IMAGE_HOSTNAME:-floatite}"
        ;;
    *)
        IMAGE_NAME="${IMAGE_NAME:-Floatblue}"
        IMAGE_ID="${IMAGE_ID:-floatblue}"
        IMAGE_HOSTNAME="${IMAGE_HOSTNAME:-floatblue}"
        ;;
esac

RELEASE_TYPE="${RELEASE_TYPE:-stable}"
IMAGE_HOME_URL="${IMAGE_HOME_URL:-https://github.com/floatingskies/floatblue}"
IMAGE_DOCUMENTATION_URL="${IMAGE_DOCUMENTATION_URL:-https://github.com/floatingskies/floatblue#readme}"
IMAGE_SUPPORT_URL="${IMAGE_SUPPORT_URL:-https://github.com/floatingskies/floatblue/issues}"
IMAGE_BUG_REPORT_URL="${IMAGE_BUG_REPORT_URL:-https://github.com/floatingskies/floatblue/issues}"

VERSION="$RELEASE_TYPE-$BASE_VERSION_ID.$(date -u +%Y%m%d).1"

{
    printf 'NAME="%s"\n' "$IMAGE_NAME"
    printf 'VERSION="%s (%s)"\n' "$VERSION" "${BASE_VARIANT:-Silverblue}"
    printf 'RELEASE_TYPE=%s\n' "$RELEASE_TYPE"
    printf 'ID=%s\n' "$IMAGE_ID"
    printf 'ID_LIKE="%s"\n' "${BASE_ID_LIKE:-fedora}"
    printf 'VERSION_ID=%s\n' "$BASE_VERSION_ID"
    if [[ -n "$BASE_VERSION_CODENAME" ]]; then
        printf 'VERSION_CODENAME="%s"\n' "$BASE_VERSION_CODENAME"
    fi
    printf 'PRETTY_NAME="%s (Version: %s)"\n' "$IMAGE_NAME" "$VERSION"
    printf 'ANSI_COLOR="0;38;2;60;110;180"\n'
    printf 'LOGO=fedora-logo-icon\n'
    printf 'CPE_NAME="cpe:/o:%s:%s:%s"\n' "$IMAGE_ID" "$IMAGE_ID" "$BASE_VERSION_ID"
    printf 'DEFAULT_HOSTNAME="%s"\n' "$IMAGE_HOSTNAME"
    printf 'HOME_URL="%s"\n' "$IMAGE_HOME_URL"
    printf 'DOCUMENTATION_URL="%s"\n' "$IMAGE_DOCUMENTATION_URL"
    printf 'SUPPORT_URL="%s"\n' "$IMAGE_SUPPORT_URL"
    printf 'BUG_REPORT_URL="%s"\n' "$IMAGE_BUG_REPORT_URL"
    if [[ -n "$BASE_SUPPORT_END" ]]; then
        printf 'SUPPORT_END=%s\n' "$BASE_SUPPORT_END"
    fi
    printf 'VARIANT="%s"\n' "${BASE_VARIANT:-Silverblue}"
    printf 'VARIANT_ID="%s"\n' "${BASE_VARIANT_ID:-silverblue}"
} > "$OUT_OS_RELEASE"

echo "Wrote $OUT_OS_RELEASE: $IMAGE_NAME ($IMAGE_ID), Fedora-like $BASE_VERSION_ID"
