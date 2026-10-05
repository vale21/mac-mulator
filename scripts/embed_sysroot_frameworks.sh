#!/bin/sh
#
# Xcode build phase: copies the SPICE client frameworks (and everything they
# depend on) from the prebuilt UTM sysroot into the application bundle and
# code-signs them with the identity of the build.
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
SRC_DIR="${PROJECT_DIR}/${SYSROOT_DIR}/Frameworks"
DST_DIR="${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"

if [ ! -d "${SRC_DIR}" ]; then
    echo "error: UTM sysroot not found at ${PROJECT_DIR}/${SYSROOT_DIR}. Run scripts/fetch_sysroot.sh first." >&2
    exit 1
fi

# Frameworks linked by the application / CocoaSpice. Keep in sync with OTHER_LDFLAGS.
SEEDS="spice-client-glib-2.0.8 glib-2.0.0 gobject-2.0.0 gio-2.0.0 gmodule-2.0.0 gthread-2.0.0 intl.8 \
gstreamer-1.0.0 gstbase-1.0.0 gstaudio-1.0.0 gstvideo-1.0.0 gstapp-1.0.0 gstpbutils-1.0.0 gsttag-1.0.0 \
gstriff-1.0.0 gstfft-1.0.0 gstcontroller-1.0.0 gstnet-1.0.0 gstallocators-1.0.0 jpeg.62"

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
    # Only recopy when the sysroot binary is newer than the embedded one.
    if [ -f "${DST}/Versions/A/${NAME}" ] && [ ! "${SRC}/Versions/A/${NAME}" -nt "${DST}/Versions/A/${NAME}" ]; then
        continue
    fi
    echo "Embedding ${NAME}.framework"
    rm -rf "${DST}"
    # Extended attributes on the input would make codesign refuse the bundle.
    ditto --norsrc --noextattr --noqtn "${SRC}" "${DST}"
    if [ -n "${SIGN}" ]; then
        codesign --force --sign "${EXPANDED_CODE_SIGN_IDENTITY}" ${RUNTIME_FLAGS} ${OTHER_CODE_SIGN_FLAGS} "${DST}"
    fi
done
