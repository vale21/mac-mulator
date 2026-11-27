#!/bin/sh
#
# Xcode Cloud runs this right after cloning the repository.
#
# The SPICE / GLib / GStreamer frameworks the app links against (and the Qemu
# bundled by the App Store flavor) live in the git-ignored Sysroot/ directory,
# so they have to be downloaded on every build.
#
# The artifact id pinned in docs/sysroot.md is used (SYSROOT_ARTIFACT_ID in the
# workflow overrides it). If the GitHub releases of vale21/mac-mulator already
# have a copy at least that recent, it is downloaded from there. If the pin is
# newer than any copy (the sysroot was updated but not uploaded yet), it is
# downloaded from UTM's CI instead, which needs a GH_TOKEN secret environment
# variable in the Xcode Cloud workflow (App Store Connect > Xcode Cloud >
# workflow > Environment). Otherwise GH_TOKEN is optional and only avoids
# GitHub's rate limit for anonymous API requests. See docs/sysroot.md.
set -e

# SwiftTerm runs a build tool plugin (SwiftTermBuildInfoPlugin), which Xcode only builds once it is trusted.
# Trusting it in Xcode does not carry over to Xcode Cloud, so skip the check here. The key name is misspelled
# ("Validatation") in Xcode itself.
defaults write com.apple.dt.Xcode IDESkipPackagePluginFingerprintValidatation -bool YES

SCRIPTS="$CI_PRIMARY_REPOSITORY_PATH/scripts"
PINNED_ID="${SYSROOT_ARTIFACT_ID:-$(sed -n 's/^| *Artifact *|.* id `\([0-9][0-9]*\)`.*/\1/p' "$CI_PRIMARY_REPOSITORY_PATH/docs/sysroot.md")}"
if [ -z "$PINNED_ID" ]; then
    echo "warning: no sysroot artifact id pinned in docs/sysroot.md, using the newest GitHub copy." >&2
    SYSROOT_SOURCE="MacMulator releases (github.com/vale21/mac-mulator/releases)"
    "$SCRIPTS/fetch_sysroot.sh"
else
    LATEST_ID="$("$SCRIPTS/fetch_sysroot.sh" --latest-id)"
    echo "Pinned sysroot: $PINNED_ID, newest GitHub copy: $LATEST_ID"
    if [ "$PINNED_ID" -gt "$LATEST_ID" ]; then
        SYSROOT_SOURCE="UTM CI (github.com/utmapp/UTM/actions)"
        echo "Sysroot source: $SYSROOT_SOURCE"
        # Package outside the repository: the release zip is not needed on CI.
        SYSROOT_PACKAGE_DIR="${TMPDIR:-/tmp}" "$SCRIPTS/fetch_utm_sysroot.sh" "$PINNED_ID"
    else
        SYSROOT_SOURCE="MacMulator releases (github.com/vale21/mac-mulator/releases)"
        echo "Sysroot source: $SYSROOT_SOURCE"
        "$SCRIPTS/fetch_sysroot.sh" "$PINNED_ID"
    fi
fi

echo "Sysroot source: $SYSROOT_SOURCE"
echo "Sysroot/VERSION:"
cat "$CI_PRIMARY_REPOSITORY_PATH/Sysroot/VERSION"
