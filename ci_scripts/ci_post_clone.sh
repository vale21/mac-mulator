#!/bin/sh
#
# Xcode Cloud runs this right after cloning the repository.
#
# The SPICE / GLib / GStreamer frameworks the app links against (and the Qemu
# bundled by the App Store flavor) live in the git-ignored Sysroot/ directory,
# so they have to be downloaded on every build. They come from the copies of
# the UTM sysroot attached to the GitHub releases of vale21/mac-mulator, which
# are public. A GH_TOKEN secret environment variable in the Xcode Cloud workflow
# (App Store Connect > Xcode Cloud > workflow > Environment) is optional and
# only avoids GitHub's rate limit for anonymous API requests.
#
# By default the newest copy is used. Define SYSROOT_ARTIFACT_ID in the
# workflow to build against a specific one. See docs/sysroot.md.
set -e

"$CI_PRIMARY_REPOSITORY_PATH/scripts/fetch_sysroot.sh" ${SYSROOT_ARTIFACT_ID:+"$SYSROOT_ARTIFACT_ID"}
