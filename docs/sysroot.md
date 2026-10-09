# Sysroot management

MacMulator does not build SPICE, GLib, GStreamer or Qemu itself. It takes them prebuilt from the
**UTM sysroot**, the universal (arm64 + x86_64) macOS sysroot that the
[UTM project](https://github.com/utmapp/UTM) builds on GitHub Actions for its own app. This document
explains how that sysroot is obtained, pinned and updated.

## Current pin

| What | Value |
|---|---|
| Artifact | `Sysroot-macos-universal` id `10846077902` |
| UTM commit | `7eadb056ae0f91d979059544d0ddcd2d5a40be92` (`main`, built 2026-09-25) |
| Qemu | 10.0.12 (UTM fork) |
| CocoaSpice | revision `d8d29fc810047a3ddcebb351cdadc8fe4b4f308d` |

Update this table whenever the sysroot or CocoaSpice is changed.

## What the sysroot is and who uses it

The sysroot lives in `Sysroot/sysroot-macOS-arm64_x86_64/` at the root of the repository. The whole
`Sysroot/` directory is git-ignored: every machine that builds MacMulator has to download it.
`Sysroot/VERSION` records which artifact was downloaded.

| Part of the sysroot | Used by | How |
|---|---|---|
| `Frameworks/spice-client-glib-*`, `glib-*`, `gstreamer-*`, `jpeg.62`, ... | both flavors | linked through `OTHER_LDFLAGS` and `FRAMEWORK_SEARCH_PATHS`, embedded into `Contents/Frameworks` |
| `lib/gstreamer-1.0/*.a` | both flavors | static GStreamer plugins listed in `OTHER_LDFLAGS` (`-lgst...`) |
| `include/` | both flavors | headers for CocoaSpice |
| `Frameworks/qemu-*-softmmu.framework` | App Store flavor | embedded into `Contents/Frameworks` |
| `bin/qemu-system-*`, `bin/qemu-img` | App Store flavor | copied to `Contents/MacOS`, load commands rewritten, signed with `MacMulator/Resources/QemuHelper.entitlements` |
| `share/qemu/` | App Store flavor | firmware subset copied to `Contents/Resources/qemu`, passed to Qemu with `-L` |

Two scripts do all the work:

- `scripts/fetch_sysroot.sh` downloads an artifact and extracts the parts above into `Sysroot/`.
- `scripts/embed_sysroot_frameworks.sh` is the "Embed Sysroot" Run Script phase of both app targets.
  It follows the `@rpath` load commands of the frameworks the app links to compute what to embed,
  thins binaries to the architecture being built, signs everything, and adds the Qemu pieces when the
  target defines `APPSTORE`. It also removes Qemu leftovers from an Enthusiast build, since both
  targets produce the same `MacMulator.app`.

The SPICE client code itself comes from the `CocoaSpice` Swift package (product `CocoaSpiceNoUsb`),
which is compiled against the headers and frameworks of the sysroot. See
[Updating CocoaSpice](#updating-cocoaspice-when-utm-releases-a-new-version).

## Setting up a new development machine

1. Install Xcode and clone the repository. Open `MacMulator.xcworkspace`, not the project.
2. Provide a GitHub token. GitHub only serves Actions artifacts to authenticated requests, even for
   public repositories. The fetch script looks for a token in this order:
   - the `GH_TOKEN` environment variable;
   - the `GITHUB_TOKEN` environment variable;
   - the GitHub CLI, if `gh auth login` was run;
   - the git credential helper for `github.com` (the keychain entry that `git push` over HTTPS uses).

   A fine-grained token only needs read access to *Actions* on public repositories; a classic token
   needs the `repo` scope.
3. Download the sysroot:

   ```sh
   scripts/fetch_sysroot.sh
   ```

   This downloads about 650 MB and leaves about 530 MB in `Sysroot/`. Check `Sysroot/VERSION`
   afterwards. To reproduce exactly what the rest of the team uses, pass the artifact id from the
   [Current pin](#current-pin) table instead of taking the newest one (see
   [Choosing the artifact](#downloading-the-sysroot-and-choosing-the-artifact-id)).
4. Build the `MacMulator Enthusiast` scheme and the `MacMulator App Store` scheme once each. The
   first build of each flavor is slow because the Run Script phase copies and signs the frameworks.
   Code signing needs a development certificate of the team: the embedded frameworks and the Qemu
   executables are signed with the same identity as the app.

Troubleshooting:

| Message | Cause and fix |
|---|---|
| `UTM sysroot not found at ...` | `Sysroot/` is missing. Run the fetch script. |
| `X.framework not found in sysroot` | A framework the app needs was not extracted, usually because the sysroot predates a dependency change. Re-run the fetch script or adjust its exclude list. |
| `the sysroot ... has no Qemu executables or firmware` | The sysroot was fetched with an older version of the script that skipped Qemu. Re-run the fetch script. |
| Stale or mixed frameworks in the built app | Both schemes write the same `MacMulator.app`. Delete the Products folder in DerivedData and rebuild. |

## What to do in Xcode Cloud

Xcode Cloud starts from a clean clone, so it downloads the sysroot on every build:

- `ci_scripts/ci_post_clone.sh` runs `scripts/fetch_sysroot.sh` right after the clone.
- The script needs a token: in App Store Connect open the workflow, go to *Environment*, and add an
  environment variable named `GH_TOKEN` marked as **secret**, containing a GitHub token as described
  above.
- To build against a fixed artifact instead of the newest `main` one, add a second environment
  variable `SYSROOT_ARTIFACT_ID` with the artifact id. Keep it equal to the
  [Current pin](#current-pin). Remember that artifacts expire (see below): when the pinned one
  expires, the build fails at the post-clone step until the variable is updated.
- Workflows must use the `MacMulator Enthusiast` or `MacMulator App Store` scheme. The App Store
  scheme is arm64-only and produces the sandboxed, Qemu-bundling app.

The download adds roughly a minute and a half to each build.

## Downloading the sysroot and choosing the artifact ID

UTM's "Build" workflow uploads one `Sysroot-macos-universal` artifact per run, for every branch it
builds. Artifacts are kept for **90 days** and then expire; an expired artifact cannot be downloaded
any more.

List the available artifacts with the GitHub CLI:

```sh
gh api "repos/utmapp/UTM/actions/artifacts?name=Sysroot-macos-universal&per_page=30" \
  --jq '.artifacts[] | select(.expired == false) | "\(.id)  \(.workflow_run.head_branch)  \(.workflow_run.head_sha[0:9])  created \(.created_at)  expires \(.expires_at)"'
```

Each line shows the id, the branch or tag the run was built from, the UTM commit, and the dates.
Choosing one:

- `head_branch` equal to a **release tag** (for example `v5.0.6`) is the artifact of a UTM release.
  Prefer these for anything shipped: they correspond to a Qemu and SPICE build UTM itself tested.
- `head_branch` equal to `main` is a development build. Fine for day-to-day work.
- Other branches are UTM feature branches. Avoid them.
- Pick the newest artifact of the chosen kind; an older one has less time left before it expires.

Then download it:

```sh
scripts/fetch_sysroot.sh 10846077902        # a specific artifact id
scripts/fetch_sysroot.sh                    # or: the newest non-expired artifact of main
```

The script extracts only what MacMulator uses. It skips the Qemu system emulators for architectures
MacMulator does not support, the EDK2 firmware images (MacMulator ships its own EFI), and the GPU
bits UTM uses for Windows guests (`D3DMetal`, `dxmt-native`, `MoltenVK`, ...). The lists live at the
top of the script.

If the artifact was downloaded by other means (for example from the browser, through *Actions* on
UTM's GitHub page, where the artifact zip contains a `sysroot.tgz`), the download step can be skipped:

```sh
SYSROOT_TGZ=~/Downloads/sysroot.tgz scripts/fetch_sysroot.sh
```

In that case `Sysroot/VERSION` cannot record the UTM commit; add it by hand if it matters.

## Updating Qemu when UTM releases a new version

Qemu is not a separate download: a new UTM release means a new sysroot artifact built from the
release tag, which brings the new Qemu **and** new SPICE, GLib and GStreamer frameworks. Updating
Qemu therefore affects both flavors, not only the App Store one.

1. Find the artifact of the release tag with the listing command above and fetch it with its id.
2. Update CocoaSpice to the revision UTM pins at that tag (next section). SPICE client and server
   must agree.
3. Build both schemes. Two kinds of failure are expected after a big update:
   - `X.framework not found in sysroot`: a framework became a new dependency. If the fetch script
     excludes it, remove it from the exclude list and fetch again. The embed script needs no change,
     it discovers dependencies by itself.
   - Linker errors: the framework names in `OTHER_LDFLAGS` carry a version (`spice-client-glib-2.0.8`,
     `glib-2.0.0`, `jpeg.62`, ...). When UTM bumps one, update `OTHER_LDFLAGS` in **both** targets
     and the `SEEDS` list in `scripts/embed_sysroot_frameworks.sh`. The same goes for the static
     GStreamer plugins (`-lgst...`), which must exist in `lib/gstreamer-1.0`.
4. Check the Qemu version and capabilities from a build of the App Store scheme. The stubs in
   `Sysroot/bin` cannot run directly (their load commands point to UTM's build machine); the copies
   inside the app can:

   ```sh
   APP=~/Library/Developer/Xcode/DerivedData/MacMulator-*/Build/Products/Debug/MacMulator.app
   "$APP"/Contents/MacOS/qemu-img --version
   "$APP"/Contents/MacOS/qemu-system-aarch64 -display help
   "$APP"/Contents/MacOS/qemu-system-aarch64 -audiodev help
   ```

   The App Store command line relies on a few properties of UTM's Qemu build that may change with a
   new version: there is no `cocoa` display (the Spice display is forced on), `-spice` needs an
   explicit `gl=` option, the `none` display refuses `gl=on`, and there is no default audio driver
   (`-audio coreaudio` is always added). The code for these is in `QemuCommandBuilder`,
   `QemuRunner` and `EditVMViewControllerVideo`, under `#if APPSTORE`. Re-check them if any of the
   outputs above changed.
5. If MacMulator gains or loses a Qemu architecture, update `QEMU_TARGETS` in both scripts together
   with `QemuConstants.ARCH_*`.
6. Smoke test: in the Enthusiast flavor open a VM with the Spice display; in the App Store flavor
   open Preferences (it runs the bundled `qemu-img`), then start an ARM64 VM with HVF and an x86_64
   VM with TCG. Check that an Enthusiast build contains no `qemu-*` in `Contents/MacOS`.
7. Update the [Current pin](#current-pin) table, the `SYSROOT_ARTIFACT_ID` of the Xcode Cloud
   workflow if one is set, and commit.

## Updating CocoaSpice when UTM releases a new version

CocoaSpice is a Swift package, not a CocoaPod. The project references
`https://github.com/utmapp/CocoaSpice.git` pinned to an exact **commit**, both in the project
(package dependency rule "Commit") and in `MacMulator.xcworkspace/xcshareddata/swiftpm/Package.resolved`.

The revision to use is the one UTM builds against for the chosen sysroot. UTM records it in its own
package resolution file; read it at the commit stored in `Sysroot/VERSION`:

```sh
COMMIT=$(sed -n 's/^utm-commit: //p' Sysroot/VERSION)
curl -sL "https://raw.githubusercontent.com/utmapp/UTM/$COMMIT/UTM.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved" \
  | python3 -c 'import json,sys; print([p["state"]["revision"] for p in json.load(sys.stdin)["pins"] if p["identity"] == "cocoaspice"][0])'
```

Then, in Xcode:

1. Select the project, open the *Package Dependencies* tab and double-click `CocoaSpice`.
2. Set the dependency rule to *Commit* and paste the revision from the command above.
3. Run *File > Packages > Resolve Package Versions*, then build both schemes.
4. Commit `MacMulator.xcodeproj/project.pbxproj` and
   `MacMulator.xcworkspace/xcshareddata/swiftpm/Package.resolved`, and update the
   [Current pin](#current-pin) table.

Things to check after an update:

- The product name is `CocoaSpiceNoUsb`. If upstream renames or splits products, fix the package
  product in both targets' *Frameworks, Libraries, and Embedded Content*.
- `QemuSpiceViewerViewController` works around CocoaSpice's `gst_ios_init()`, which rewrites
  `HOME`, `TMPDIR` and `XDG_*` for the whole process: it snapshots and restores those variables right
  after `spiceStart`. Verify that this is still needed and still works.
- Headers come from `Sysroot/.../include`; a CocoaSpice revision newer than the sysroot may need
  headers the sysroot does not have. Keep the two aligned instead of updating one of them alone.
