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

# SwiftTerm runs a build tool plugin (SwiftTermBuildInfoPlugin), which Xcode only builds once it is trusted.
# Trusting it in Xcode does not carry over to Xcode Cloud, so skip the check here. The key name is misspelled
# ("Validatation") in Xcode itself.
defaults write com.apple.dt.Xcode IDESkipPackagePluginFingerprintValidatation -bool YES

"$CI_PRIMARY_REPOSITORY_PATH/scripts/fetch_sysroot.sh" ${SYSROOT_ARTIFACT_ID:+"$SYSROOT_ARTIFACT_ID"}
