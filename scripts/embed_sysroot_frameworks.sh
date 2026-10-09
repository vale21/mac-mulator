#!/bin/sh
#
# Xcode build phase: copies the SPICE client frameworks (and everything they
# depend on) from the prebuilt UTM sysroot into the application bundle and
# code-signs them with the identity of the build.
#
# The App Store flavor (APPSTORE in SWIFT_ACTIVE_COMPILATION_CONDITIONS) also
# gets the UTM build of Qemu from the same sysroot: the qemu-*-softmmu
# frameworks, the qemu-system-* and qemu-img executables (Contents/MacOS) and
# the firmware Qemu loads at run time (Contents/Resources/qemu). The Enthusiast
# flavor runs the Qemu installed by the user and bundles none of this.
#
# Binaries are thinned to the architecture being built when there is only one
# (ARCHS), so an arm64-only target embeds arm64-only frameworks and executables.
#
# The frameworks reference each other through @rpath, so the list of what to
# embed is computed here by following the load commands of the frameworks the
# application links directly. This keeps the list in sync with the sysroot.
#
# Expects the usual Xcode build settings in the environment. SYSROOT_DIR
# (relative to PROJECT_DIR) can be overridden, and must match the path used in
# the target's FRAMEWORK_SEARCH_PATHS / LIBRARY_SEARCH_PATHS.
set -e

SYSROOT_DIR="${SYSROOT_DIR:-Sysroot/sysroot-macOS-arm64_x86_64}"
SYSROOT="${PROJECT_DIR}/${SYSROOT_DIR}"
SRC_DIR="${SYSROOT}/Frameworks"
DST_DIR="${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"
EXEC_DIR="${TARGET_BUILD_DIR}/${EXECUTABLE_FOLDER_PATH}"
DATA_DIR="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/qemu"
QEMU_ENTITLEMENTS="${PROJECT_DIR}/MacMulator/Resources/QemuHelper.entitlements"

# Qemu system emulators bundled in the App Store flavor. Keep in sync with
# QemuConstants.ARCH_* and with scripts/fetch_sysroot.sh.
QEMU_TARGETS="aarch64 x86_64 i386 arm ppc ppc64 m68k riscv32 riscv64"
QEMU_EXECUTABLES="qemu-img"
for t in ${QEMU_TARGETS}; do
    QEMU_EXECUTABLES="${QEMU_EXECUTABLES} qemu-system-${t}"
done

case " ${SWIFT_ACTIVE_COMPILATION_CONDITIONS} " in
    *" APPSTORE "*) BUNDLE_QEMU=1 ;;
    *) BUNDLE_QEMU= ;;
esac

if [ ! -d "${SRC_DIR}" ]; then
    echo "error: UTM sysroot not found at ${SYSROOT}. Run scripts/fetch_sysroot.sh first." >&2
    exit 1
fi

# With a single architecture the universal sysroot binaries are thinned to it;
# otherwise they are embedded as they are.
set -- ${ARCHS}
if [ $# -eq 1 ]; then
    THIN_ARCH="$1"
else
    THIN_ARCH=
fi

# Thins the Mach-O file $1 in place to the architecture being built, if needed.
thin_binary () {
    if [ -n "${THIN_ARCH}" ] && [ "$(lipo -archs "$1")" != "${THIN_ARCH}" ]; then
        lipo "$1" -thin "${THIN_ARCH}" -output "$1.thin"
        mv -f "$1.thin" "$1"
    fi
}

# Whether $2 is an up-to-date copy of the Mach-O file $1: not older, and with
# the architectures wanted for this build.
is_current () {
    [ -f "$2" ] || return 1
    [ "$1" -nt "$2" ] && return 1
    if [ -n "${THIN_ARCH}" ]; then
        [ "$(lipo -archs "$2")" = "${THIN_ARCH}" ]
    else
        [ "$(lipo -archs "$2")" = "$(lipo -archs "$1")" ]
    fi
}

# Frameworks linked by the application / CocoaSpice. Keep in sync with OTHER_LDFLAGS.
SEEDS="spice-client-glib-2.0.8 glib-2.0.0 gobject-2.0.0 gio-2.0.0 gmodule-2.0.0 gthread-2.0.0 intl.8 \
gstreamer-1.0.0 gstbase-1.0.0 gstaudio-1.0.0 gstvideo-1.0.0 gstapp-1.0.0 gstpbutils-1.0.0 gsttag-1.0.0 \
gstriff-1.0.0 gstfft-1.0.0 gstcontroller-1.0.0 gstnet-1.0.0 gstallocators-1.0.0 jpeg.62"

if [ -n "${BUNDLE_QEMU}" ]; then
    for t in ${QEMU_TARGETS}; do
        SEEDS="${SEEDS} qemu-${t}-softmmu"
    done
    # ANGLE (EGL / GLESv2) is loaded at run time by epoxy for 3D accelerated guests, not linked.
    SEEDS="${SEEDS} EGL GLESv2"
fi

# Follow @rpath/<name>.framework/... load commands to compute the dependency closure.
QUEUE="$SEEDS"
DONE=" "
while [ -n "$QUEUE" ]; do
    set -- $QUEUE
    NAME="$1"
    shift
    QUEUE="$*"
    case "$DONE" in
        *" $NAME "*) continue ;;
    esac
    DONE="$DONE$NAME "
    BIN="${SRC_DIR}/${NAME}.framework/Versions/A/${NAME}"
    if [ ! -f "$BIN" ]; then
        echo "error: ${NAME}.framework not found in ${SRC_DIR}" >&2
        exit 1
    fi
    DEPS="$(otool -L "$BIN" | tail -n +2 | awk '{print $1}' | sed -n 's|^@rpath/\(.*\)\.framework/.*|\1|p')"
    for d in $DEPS; do
        case "$DONE" in
            *" $d "*) ;;
            *) QUEUE="$QUEUE $d" ;;
        esac
    done
done

mkdir -p "${DST_DIR}"

if [ "${CODE_SIGNING_ALLOWED}" != "NO" ] && [ -n "${EXPANDED_CODE_SIGN_IDENTITY}" ]; then
    SIGN=1
    if [ "${ENABLE_HARDENED_RUNTIME}" = "YES" ]; then
        RUNTIME_FLAGS="--options runtime"
    fi
fi

for NAME in $DONE; do
    SRC="${SRC_DIR}/${NAME}.framework"
    DST="${DST_DIR}/${NAME}.framework"
    if is_current "${SRC}/Versions/A/${NAME}" "${DST}/Versions/A/${NAME}"; then
        continue
    fi
    echo "Embedding ${NAME}.framework"
    rm -rf "${DST}"
    # Extended attributes on the input would make codesign refuse the bundle.
    ditto --norsrc --noextattr --noqtn "${SRC}" "${DST}"
    thin_binary "${DST}/Versions/A/${NAME}"
    if [ -n "${SIGN}" ]; then
        codesign --force --sign "${EXPANDED_CODE_SIGN_IDENTITY}" ${RUNTIME_FLAGS} ${OTHER_CODE_SIGN_FLAGS} "${DST}"
    fi
done

# Both flavors build the same MacMulator.app product, so a build of one flavor
# can find sysroot frameworks embedded by a build of the other. Drop anything
# from the sysroot that this build does not need.
for FW in "${DST_DIR}"/*.framework; do
    [ -d "${FW}" ] || continue
    NAME="$(basename "${FW}" .framework)"
    [ -d "${SRC_DIR}/${NAME}.framework" ] || continue
    case "$DONE" in
        *" $NAME "*) ;;
        *)
            echo "Removing stale ${NAME}.framework"
            rm -rf "${FW}"
            ;;
    esac
done

if [ -z "${BUNDLE_QEMU}" ]; then
    rm -rf "${DATA_DIR}"
    for NAME in ${QEMU_EXECUTABLES}; do
        rm -f "${EXEC_DIR}/${NAME}"
    done
    exit 0
fi

# ---------------------------------------------------------------------------
# Qemu (App Store flavor only)
# ---------------------------------------------------------------------------

if [ ! -d "${SYSROOT}/bin" ] || [ ! -d "${SYSROOT}/share/qemu" ]; then
    echo "error: the sysroot at ${SYSROOT} has no Qemu executables or firmware. Re-run scripts/fetch_sysroot.sh." >&2
    exit 1
fi

# The executables in the sysroot reference their libraries through absolute
# paths of the machine that built them (.../sysroot-macOS-<arch>/lib/libfoo.dylib).
# Rewrite those load commands so they resolve to the frameworks embedded above.
fix_load_commands () {
    DEPS="$(otool -L "$1" | tail -n +2 | awk '{print $1}' | grep '/sysroot-macOS-[^/]*/lib/lib[^/]*\.dylib$' || true)"
    for DEP in ${DEPS}; do
        LIB="$(basename "${DEP}" .dylib)"
        FW="${LIB#lib}"
        if [ ! -d "${DST_DIR}/${FW}.framework" ]; then
            echo "error: $(basename "$1") needs ${FW}.framework, which is not embedded" >&2
            exit 1
        fi
        install_name_tool -change "${DEP}" "@rpath/${FW}.framework/Versions/A/${FW}" "$1"
    done
    install_name_tool -add_rpath "@executable_path/../Frameworks" "$1"
}

mkdir -p "${EXEC_DIR}"
for NAME in ${QEMU_EXECUTABLES}; do
    SRC="${SYSROOT}/bin/${NAME}"
    DST="${EXEC_DIR}/${NAME}"
    if [ ! -f "${SRC}" ]; then
        echo "error: ${SRC} not found. Re-run scripts/fetch_sysroot.sh." >&2
        exit 1
    fi
    if is_current "${SRC}" "${DST}"; then
        continue
    fi
    echo "Embedding ${NAME}"
    rm -f "${DST}" "${DST}.tmp"
    cp "${SRC}" "${DST}.tmp"
    chmod 755 "${DST}.tmp"
    thin_binary "${DST}.tmp"
    fix_load_commands "${DST}.tmp"
    if [ -n "${SIGN}" ]; then
        # Launched by the application, these executables inherit its sandbox; their own
        # entitlements grant them Hypervisor.framework and JIT access (QemuHelper.entitlements).
        codesign --force --sign "${EXPANDED_CODE_SIGN_IDENTITY}" ${RUNTIME_FLAGS} ${OTHER_CODE_SIGN_FLAGS} \
            --identifier "${PRODUCT_BUNDLE_IDENTIFIER}.${NAME}" --entitlements "${QEMU_ENTITLEMENTS}" "${DST}.tmp"
    fi
    mv -f "${DST}.tmp" "${DST}"
done

# Firmware and data files Qemu loads at run time; the application passes this
# directory to Qemu with -L. The sysroot has files for every architecture Qemu
# supports: keep only what the bundled emulators can use, and leave out the
# EDK2 images since MacMulator ships its own EFI firmware.
mkdir -p "${DATA_DIR}"
rsync -a --delete \
    --exclude='edk2-*' \
    --exclude='firmware/' \
    --exclude='*sparc*' \
    --exclude='hppa-*' \
    --exclude='skiboot.lid' \
    --exclude='palcode-clipper' \
    --exclude='pnv-pnor.bin' \
    --exclude='s390-ccw.img' \
    --exclude='u-boot*' \
    --exclude='*.dtb' \
    --exclude='npcm*' \
    --exclude='QEMU,*' \
    --exclude='qemu-nsis.bmp' \
    --exclude='trace-events-all' \
    "${SYSROOT}/share/qemu/" "${DATA_DIR}/"
