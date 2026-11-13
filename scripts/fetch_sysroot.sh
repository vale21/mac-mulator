#!/bin/sh
#
# Downloads the MacMulator copy of the prebuilt universal (arm64 + x86_64) UTM
# macOS sysroot and unpacks it into Sysroot/ at the repository root.
#
# The copies are attached as MacMulator-UTM-SysRoot-<artifact-id>.zip to the
# GitHub releases of vale21/mac-mulator, so the build does not depend on UTM's
# CI artifacts, which expire after 90 days. Each zip contains the Sysroot/
# directory exactly as scripts/fetch_utm_sysroot.sh produces it (only the parts
# MacMulator needs, plus Sysroot/VERSION); <artifact-id> is the id of the UTM
# CI artifact it was extracted from. See docs/sysroot.md.
#
# The release assets are public. A GitHub token is optional and only used to
# avoid the API rate limit of anonymous requests; it is taken from $GH_TOKEN,
# $GITHUB_TOKEN or `gh auth token`. On Xcode Cloud, ci_scripts/ci_post_clone.sh
# runs this script.
#
# Usage: scripts/fetch_sysroot.sh [artifact-id]
#
# Without an argument the copy with the highest artifact id (the most recent
# UTM build) found in any release is used. Set SYSROOT_ZIP to the path of an
# already downloaded MacMulator-UTM-SysRoot-*.zip to skip the download.
set -e

REPO="vale21/mac-mulator"
ASSET_PREFIX="MacMulator-UTM-SysRoot-"
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
    fi
}

WORK="$(mktemp -d "${TMPDIR:-/tmp}/macmulator-sysroot.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

ARTIFACT_ID="$1"
SOURCE=

if [ -n "$SYSROOT_ZIP" ]; then
    echo "Using local sysroot archive $SYSROOT_ZIP..."
    ZIP="$SYSROOT_ZIP"
    SOURCE="$SYSROOT_ZIP"
else
    TOKEN="$(github_token)"

    api () {
        if [ -n "$TOKEN" ]; then
            curl -sfL -H "Authorization: Bearer $TOKEN" -H "Accept: application/vnd.github+json" "$@"
        else
            curl -sfL -H "Accept: application/vnd.github+json" "$@"
        fi
    }

    # Fetch every page of the release list; the tag a copy is attached to is not known in advance.
    echo "Looking up ${ARTIFACT_ID:-the latest} sysroot in the releases of $REPO..."
    PAGE=1
    while :; do
        api -o "$WORK/releases-$PAGE.json" "https://api.github.com/repos/$REPO/releases?per_page=100&page=$PAGE"
        COUNT="$(/usr/bin/python3 -c 'import json, sys; print(len(json.load(open(sys.argv[1]))))' "$WORK/releases-$PAGE.json")"
        [ "$COUNT" -lt 100 ] && break
        PAGE=$((PAGE + 1))
    done

    FOUND="$(/usr/bin/python3 - "$ASSET_PREFIX" "$ARTIFACT_ID" "$WORK"/releases-*.json <<'EOF'
import json, re, sys
prefix, wanted, pages = sys.argv[1], sys.argv[2], sys.argv[3:]
pattern = re.compile(re.escape(prefix) + r"(\d+)\.zip")
best = None
for page in pages:
    for release in json.load(open(page)):
        if release.get("draft"):
            continue
        for asset in release["assets"]:
            m = pattern.fullmatch(asset["name"])
            if not m or (wanted and m.group(1) != wanted):
                continue
            if best is None or int(m.group(1)) > int(best[0]):
                best = (m.group(1), release["tag_name"], asset["browser_download_url"])
if best:
    print(*best)
EOF
)"

    REQUESTED_ID="$ARTIFACT_ID"
    set -- $FOUND
    ARTIFACT_ID="$1"
    TAG="$2"
    URL="$3"
    if [ -z "$URL" ]; then
        echo "error: no $ASSET_PREFIX${REQUESTED_ID:-*}.zip asset found in the releases of $REPO." >&2
        exit 1
    fi

    echo "Downloading sysroot $ARTIFACT_ID from release $TAG..."
    ZIP="$WORK/$ASSET_PREFIX$ARTIFACT_ID.zip"
    curl -fL --progress-bar -o "$ZIP" "$URL"
    SOURCE="$URL"
fi

echo "Extracting..."
mkdir -p "$WORK/out"
# ditto keeps the framework symlinks and folds any __MACOSX/AppleDouble entries back into the files.
ditto -x -k "$ZIP" "$WORK/out"
if [ ! -d "$WORK/out/Sysroot/$SYSROOT_NAME" ]; then
    echo "error: $ZIP does not contain Sysroot/$SYSROOT_NAME." >&2
    exit 1
fi
find "$WORK/out" -name .DS_Store -delete

mkdir -p "$DEST"
rm -rf "$DEST/$SYSROOT_NAME"
mv "$WORK/out/Sysroot/$SYSROOT_NAME" "$DEST/$SYSROOT_NAME"

# Keep the VERSION written by fetch_utm_sysroot.sh (UTM artifact and commit) and record where the copy came from.
{
    if [ -f "$WORK/out/Sysroot/VERSION" ]; then
        grep -v '^mirror: ' "$WORK/out/Sysroot/VERSION"
    elif [ -n "$ARTIFACT_ID" ]; then
        echo "artifact: $ARTIFACT_ID"
    fi
    echo "mirror: $SOURCE"
} > "$DEST/VERSION"

echo "Done. Sysroot is at $DEST/$SYSROOT_NAME ($(du -sh "$DEST/$SYSROOT_NAME" | cut -f1))"
