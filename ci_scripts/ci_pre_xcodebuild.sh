#!/bin/sh
#
# Xcode Cloud runs this before every xcodebuild action.
#
# The Enthusiast app hosts MacMulatorTests. Its restricted entitlements
# (com.apple.vm.networking, USB accessory access) need a provisioning profile
# that lists the Mac running the app, and Xcode Cloud test runners are not
# registered devices, so the host app fails to launch ("Launchd job spawn
# failed"). The unit tests do not need these entitlements: drop them from the
# freshly cloned entitlements file only when building for testing. Archives are
# signed with the full entitlements.
set -e

if [ "$CI_XCODEBUILD_ACTION" = "build-for-testing" ]; then
    ENTITLEMENTS="$CI_PRIMARY_REPOSITORY_PATH/MacMulator/Resources/MacMulator-Enthusiast.entitlements"
    for KEY in com.apple.vm.networking com.apple.developer.accessory-access.usb; do
        /usr/libexec/PlistBuddy -c "Delete :$KEY" "$ENTITLEMENTS" 2>/dev/null || true
    done
    echo "Restricted entitlements removed for testing:"
    cat "$ENTITLEMENTS"
fi
