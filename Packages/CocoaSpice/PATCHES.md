# Vendored CocoaSpice

This directory is a copy of [utmapp/CocoaSpice](https://github.com/utmapp/CocoaSpice)
(commit `d8d29fc810047a3ddcebb351cdadc8fe4b4f308d`, after tag `v1.3.2`), licensed under
Apache 2.0 (see `LICENSE`). This is the same revision that UTM itself pins.

CocoaSpice is written against the patched `spice-gtk` / GLib / GStreamer that UTM builds
into its own sysroot. MacMulator uses that very sysroot: `scripts/fetch_sysroot.sh`
downloads the prebuilt universal (arm64 + x86_64) macOS sysroot artifact from UTM's CI
into `Sysroot/` (git-ignored), and the application links and embeds the frameworks from
it. Because the libraries are the ones CocoaSpice was written for, the sources are kept
as close to upstream as possible. The differences are:

## `Package.swift`

- The `ExternalHeaders` snapshot of the UTM sysroot headers was removed. The targets now
  compile against the headers of the downloaded sysroot
  (`Sysroot/sysroot-macOS-arm64_x86_64/include`), so that headers and frameworks always
  match.
- The `CocoaSpiceTests` target was dropped.

## `Sources/CocoaSpice/gst_ios_init.m`

- The iOS-style environment setup (`HOME`, `XDG_*`, `TMPDIR`, ...) is skipped on macOS: it
  would redirect `HOME` to `~/Documents` for the whole process and for every child process
  the app spawns (such as QEMU).

`CSMain.m` and `gst_ios_init.h` are unmodified upstream files: the sysroot's `spice-gtk`
provides `spice_util_set_main_context()`, and GStreamer plugins are linked statically and
registered through the `GST_IOS_PLUGIN*` macros exactly as in UTM.

## Linking and embedding

The application target (`FRAMEWORK_SEARCH_PATHS`, `LIBRARY_SEARCH_PATHS`, `OTHER_LDFLAGS`,
all pointing into `Sysroot/sysroot-macOS-arm64_x86_64`) links:

- the sysroot frameworks `spice-client-glib-2.0.8`, `glib-2.0.0`, `gobject-2.0.0`,
  `gio-2.0.0`, `gmodule-2.0.0`, `gthread-2.0.0`, `intl.8`, `gstreamer-1.0.0` and the GStreamer
  library frameworks (`gstbase`, `gstaudio`, `gstvideo`, `gstapp`, `gstpbutils`, `gsttag`,
  `gstriff`, `gstfft`, `gstcontroller`, `gstnet`, `gstallocators`), plus `jpeg.62`;
- the static GStreamer plugins from `lib/gstreamer-1.0` that `gst_ios_init.h` enables
  (`coreelements`, `adder`, `app`, `audioconvert`, `audiorate`, `audioresample`,
  `audiotestsrc`, `gio`, `typefindfunctions`, `videoconvert`, `videorate`, `videoscale`,
  `videotestsrc`, `volume`, `autodetect`, `videofilter`, `osxaudio`, `playback`, `jpeg`);
- the system frameworks `CoreAudio`, `AudioUnit` and `AudioToolbox` needed by `osxaudio`.

The "Embed Sysroot Frameworks" run-script build phase
(`scripts/embed_sysroot_frameworks.sh`) copies those frameworks and their transitive
dependencies (33 frameworks, about 45 MB) into `Contents/Frameworks` and signs them with
the build's identity, so the hardened runtime's library validation is satisfied and no
Homebrew installation is needed on the user's machine.
