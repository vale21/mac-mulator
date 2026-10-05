// swift-tools-version:5.6

import PackageDescription

// MacMulator vendored copy of https://github.com/utmapp/CocoaSpice
// See PATCHES.md for the differences from upstream.
//
// Upstream ships a snapshot of the UTM sysroot headers in `ExternalHeaders`.
// This copy compiles against the headers of the prebuilt UTM sysroot that
// `scripts/fetch_sysroot.sh` downloads into `Sysroot/`, so that the headers
// always match the frameworks the application links against and embeds.
let sysroot = "\(Context.packageDirectory)/../../Sysroot/sysroot-macOS-arm64_x86_64"

let sysrootIncludes: [CSetting] = [
    .unsafeFlags([
        "-I\(sysroot)/include",
        "-I\(sysroot)/include/glib-2.0",
        "-I\(sysroot)/lib/glib-2.0/include",
        "-I\(sysroot)/include/gstreamer-1.0",
        "-I\(sysroot)/include/spice-1",
        "-I\(sysroot)/include/spice-client-glib-2.0",
    ]),
]

let package = Package(
    name: "CocoaSpice",
    platforms: [
        .iOS(.v11), .macOS(.v10_14),
    ],
    products: [
        .library(
            name: "CocoaSpice",
            targets: ["CocoaSpice"]
        ),
        .library(
            name: "CocoaSpiceNoUsb",
            targets: ["CocoaSpiceNoUsb"]
        ),
    ],
    targets: [
        .target(
            name: "CocoaSpiceRenderer",
            dependencies: [],
            resources: [
                .process("CSShaders.metal"),
            ]
        ),
        .target(
            name: "CocoaSpice",
            dependencies: ["CocoaSpiceRenderer"],
            cSettings: [
                .define("WITH_USB_SUPPORT"),
                .unsafeFlags(["-I\(sysroot)/include/libusb-1.0"]),
            ] + sysrootIncludes
        ),
        .target(
            name: "CocoaSpiceNoUsb",
            dependencies: ["CocoaSpiceRenderer"],
            exclude: [
                "CSUSBDevice.m",
                "CSUSBManager.m",
            ],
            cSettings: sysrootIncludes
        ),
    ]
)
