#!/bin/sh
#
# Xcode Cloud runs this right after cloning the repository.
#
# The SPICE / GLib / GStreamer frameworks the app links against (and the Qemu
# bundled by the App Store flavor) live in the git-ignored Sysroot/ directory,
# so they have to be downloaded on every build. The download needs a GitHub
# token: define GH_TOKEN as a secret environment variable in the Xcode Cloud
# workflow (App Store Connect > Xcode Cloud > workflow > Environment).
#
# By default the newest sysroot built from UTM's main branch is used. Define
# SYSROOT_ARTIFACT_ID in the workflow to build against a specific artifact.
# See docs/sysroot.md.
set -e

"$CI_PRIMARY_REPOSITORY_PATH/scripts/fetch_sysroot.sh" ${SYSROOT_ARTIFACT_ID:+"$SYSROOT_ARTIFACT_ID"}
