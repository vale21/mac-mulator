#!/bin/sh
#
# Downloads the prebuilt universal (arm64 + x86_64) macOS sysroot that the UTM
# project publishes from its CI, and unpacks the parts MacMulator needs into
# Sysroot/ at the repository root:
#
# - the SPICE / GLib / GStreamer frameworks and static GStreamer plugins, linked
#   by both flavors of the application and embedded into the bundle;
# - the UTM build of Qemu (qemu-*-softmmu frameworks, qemu-system-* and
#   qemu-img executables, firmware in share/qemu), bundled by the App Store
#   flavor only. See scripts/embed_sysroot_frameworks.sh.
#
# The full sysroot is 2.6 GB; only the Qemu emulators MacMulator supports are
# extracted, and the EDK2 firmware images are skipped (MacMulator ships its own).
#
# GitHub Actions artifacts can only be downloaded with an authenticated request.
# The token is taken from, in order: $GH_TOKEN, $GITHUB_TOKEN, `gh auth token`,
# or the git credential helper for github.com (the keychain entry that `git
# push` uses). On Xcode Cloud, define GH_TOKEN as a secret environment variable
# of the workflow; ci_scripts/ci_post_clone.sh then runs this script.
#
# Usage: scripts/fetch_sysroot.sh [artifact-id]
#
# Without an argument the newest "Sysroot-macos-universal" artifact built from
# the `main` branch of utmapp/UTM is used. Set SYSROOT_TGZ to the path of an
# already downloaded sysroot.tgz to skip the download.
set -e

REPO="utmapp/UTM"
ARTIFACT_NAME="Sysroot-macos-universal"
SYSROOT_NAME="sysroot-macOS-arm64_x86_64"

# Qemu system emulators bundled in the App Store flavor. Keep in sync with
# QemuConstants.ARCH_* and with scripts/embed_sysroot_frameworks.sh.
QEMU_TARGETS="aarch64 x86_64 i386 arm ppc ppc64 m68k riscv32 riscv64"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/Sysroot"

github_token () {
    if [ -n "$GH_TOKEN" ]; then
        echo "$GH_TOKEN"
    elif [ -n "$GITHUB_TOKEN" ]; then
        echo "$GITHUB_TOKEN"
    elif command -v gh >/dev/null 2>&1 && gh auth token >/dev/null 2>&1; then
        gh auth token
    else
        # GIT_TERMINAL_PROMPT=0 / GIT_ASKPASS keep git from asking interactively on a CI machine.
        printf "protocol=https\nhost=github.com\n\n" | GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/usr/bin/false git credential fill 2>/dev/null | sed -n 's/^password=//p'
    fi
}

WORK="$(mktemp -d "${TMPDIR:-/tmp}/macmulator-sysroot.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

ARTIFACT_ID="$1"
HEAD_SHA=
CREATED_AT=

if [ -n "$SYSROOT_TGZ" ]; then
    echo "Using local sysroot archive $SYSROOT_TGZ..."
    TGZ="$SYSROOT_TGZ"
else
    TOKEN="$(github_token)"
    if [ -z "$TOKEN" ]; then
        echo "error: no GitHub token found. Set GH_TOKEN, run 'gh auth login', or store github.com credentials in git." >&2
        exit 1
    fi

    api () {
        curl -sfL -H "Authorization: Bearer $TOKEN" -H "Accept: application/vnd.github+json" "$@"
    }

    if [ -z "$ARTIFACT_ID" ]; then
        echo "Looking up the latest $ARTIFACT_NAME artifact of $REPO (main)..."
        ARTIFACT_ID="$(api "https://api.github.com/repos/$REPO/actions/artifacts?per_page=100&name=$ARTIFACT_NAME" | /usr/bin/python3 -c '
import json, sys
artifacts = json.load(sys.stdin)["artifacts"]
for a in artifacts:
    if not a["expired"] and a["workflow_run"]["head_branch"] == "main":
        print(a["id"], a["workflow_run"]["head_sha"], a["created_at"])
        break
')"
    fi

    set -- $ARTIFACT_ID
    ARTIFACT_ID="$1"
    HEAD_SHA="$2"
    CREATED_AT="$3"
    if [ -z "$ARTIFACT_ID" ]; then
        echo "error: no non-expired $ARTIFACT_NAME artifact found." >&2
        exit 1
    fi

    echo "Downloading artifact $ARTIFACT_ID${HEAD_SHA:+ (UTM commit $HEAD_SHA, built $CREATED_AT)}..."
    api -o "$WORK/$ARTIFACT_NAME.zip" "https://api.github.com/repos/$REPO/actions/artifacts/$ARTIFACT_ID/zip"
    unzip -oq "$WORK/$ARTIFACT_NAME.zip" -d "$WORK"
    rm -f "$WORK/$ARTIFACT_NAME.zip"
    TGZ="$WORK/sysroot.tgz"
fi

echo "Extracting the SPICE, GLib and GStreamer parts..."
mkdir -p "$WORK/out"
tar -xzf "$TGZ" -C "$WORK/out" \
    --exclude="$SYSROOT_NAME/Frameworks/qemu-*" \
    --exclude="$SYSROOT_NAME/Frameworks/D3DMetal.framework" \
    --exclude="$SYSROOT_NAME/Frameworks/d3dmetal-native.framework" \
    --exclude="$SYSROOT_NAME/Frameworks/dxmt-native.framework" \
    --exclude="$SYSROOT_NAME/Frameworks/LTO.framework" \
    --exclude="$SYSROOT_NAME/Frameworks/Remarks.framework" \
    --exclude="$SYSROOT_NAME/Frameworks/MoltenVK.framework" \
    "$SYSROOT_NAME/Frameworks" \
    "$SYSROOT_NAME/lib/gstreamer-1.0" \
    "$SYSROOT_NAME/lib/glib-2.0" \
    "$SYSROOT_NAME/include"

echo "Extracting Qemu..."
QEMU_PATHS="$SYSROOT_NAME/bin/qemu-img"
for t in $QEMU_TARGETS; do
    QEMU_PATHS="$QEMU_PATHS $SYSROOT_NAME/Frameworks/qemu-$t-softmmu.framework $SYSROOT_NAME/bin/qemu-system-$t"
done
tar -xzf "$TGZ" -C "$WORK/out" \
    --exclude="$SYSROOT_NAME/share/qemu/edk2-*" \
    $QEMU_PATHS \
    "$SYSROOT_NAME/share/qemu"

mkdir -p "$DEST"
rm -rf "$DEST/$SYSROOT_NAME"
mv "$WORK/out/$SYSROOT_NAME" "$DEST/$SYSROOT_NAME"

{
    [ -n "$ARTIFACT_ID" ] && echo "artifact: $ARTIFACT_ID"
    [ -n "$HEAD_SHA" ] && echo "utm-commit: $HEAD_SHA"
    [ -n "$CREATED_AT" ] && echo "built: $CREATED_AT"
    echo "source: https://github.com/$REPO/actions"
} > "$DEST/VERSION"

echo "Done. Sysroot is at $DEST/$SYSROOT_NAME ($(du -sh "$DEST/$SYSROOT_NAME" | cut -f1))"
