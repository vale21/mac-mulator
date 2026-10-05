#!/bin/sh
#
# Downloads the prebuilt universal (arm64 + x86_64) macOS sysroot that the UTM
# project publishes from its CI, and unpacks it into Sysroot/ at the repository
# root. MacMulator links the SPICE / GLib / GStreamer frameworks from this
# sysroot and embeds them into the application bundle.
#
# GitHub Actions artifacts can only be downloaded with an authenticated request.
# The token is taken from, in order: $GH_TOKEN, $GITHUB_TOKEN, `gh auth token`,
# or the git credential helper for github.com (the keychain entry that `git
# push` uses).
#
# Usage: scripts/fetch_sysroot.sh [artifact-id]
#
# Without an argument the newest "Sysroot-macos-universal" artifact built from
# the `main` branch of utmapp/UTM is used.
set -e

REPO="utmapp/UTM"
ARTIFACT_NAME="Sysroot-macos-universal"
SYSROOT_NAME="sysroot-macOS-arm64_x86_64"

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
        printf "protocol=https\nhost=github.com\n\n" | git credential fill 2>/dev/null | sed -n 's/^password=//p'
    fi
}

TOKEN="$(github_token)"
if [ -z "$TOKEN" ]; then
    echo "error: no GitHub token found. Set GH_TOKEN, run 'gh auth login', or store github.com credentials in git." >&2
    exit 1
fi

api () {
    curl -sfL -H "Authorization: Bearer $TOKEN" -H "Accept: application/vnd.github+json" "$@"
}

ARTIFACT_ID="$1"
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

mkdir -p "$DEST"
ZIP="$DEST/$ARTIFACT_NAME.zip"
echo "Downloading artifact $ARTIFACT_ID${HEAD_SHA:+ (UTM commit $HEAD_SHA, built $CREATED_AT)}..."
api -o "$ZIP" "https://api.github.com/repos/$REPO/actions/artifacts/$ARTIFACT_ID/zip"

echo "Unpacking into $DEST/$SYSROOT_NAME..."
rm -rf "$DEST/$SYSROOT_NAME"
unzip -oq "$ZIP" -d "$DEST"
tar -xzf "$DEST/sysroot.tgz" -C "$DEST"
rm -f "$DEST/sysroot.tgz" "$ZIP"

{
    echo "artifact: $ARTIFACT_ID"
    [ -n "$HEAD_SHA" ] && echo "utm-commit: $HEAD_SHA"
    [ -n "$CREATED_AT" ] && echo "built: $CREATED_AT"
    echo "source: https://github.com/$REPO/actions"
} > "$DEST/VERSION"

echo "Done. Sysroot is at $DEST/$SYSROOT_NAME"
