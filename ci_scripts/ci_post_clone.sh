#!/bin/sh
#
# Xcode Cloud runs this right after cloning the repository.
#
# The SPICE / GLib / GStreamer frameworks the app links against live in the
# git-ignored Sysroot/ directory, so they have to be downloaded on every build.
# The download needs a GitHub token: define GH_TOKEN as a secret environment
# variable in the Xcode Cloud workflow (App Store Connect > Xcode Cloud >
# workflow > Environment).
set -e

"$CI_PRIMARY_REPOSITORY_PATH/scripts/fetch_sysroot.sh"
