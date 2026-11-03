#!/bin/sh
# vendorsetup.sh for android_device_infinix_X6532 (TECNO/Infinix X6532)
#
# build/envsetup.sh sources every device/*/*/vendorsetup.sh it finds, so this
# runs on every "source build/envsetup.sh".
#
# It applies patches/systemui/0001-*.patch to frameworks/base.  That single
# hunk makes SystemUI publish the notification-shade state:
#
#     Settings.System.putInt(cr, "qs.fps.expanded", isExpanded ? 1 : 0)
#
# in onShadeOrQsExpanded(), which is what ShadeProvider.tran (the prebuilt
# com.shade.handler APK packaged by device.mk) waits for: while the shade is
# open it drops the window blur and shortens the animation scale, and restores
# both when the shade closes.  Without this hunk the APK never sees a state
# change, so the "UI performance on shade expand" feature is silently dead.
#
# This replaces the old vendorsetup.sh sed/awk hack that rewrote
# NotificationShadeWindowControllerImpl.java in place.  That version failed
# silently: it matched source text, so once the surrounding method changed it
# simply stopped inserting anything and the build still succeeded.  The patch
# below is strict (git apply, no fuzz) and says so when it does not apply.
#
# Unlike the KL5 NFC patches this is ON by default, and only has an opt-out
# (PATCH_SHADE=0), because the APK shipped by device.mk depends on it: a build
# that silently skips the patch ships a service that does nothing.
#
# Applying by hand, or reverting: see patches/systemui/README.md.

apply_x6532_systemui_patches() {
    top="${ANDROID_BUILD_TOP:-$PWD}"
    self="${BASH_SOURCE[0]:-$0}"
    here="$(cd "$(dirname "$self")" 2>/dev/null && pwd)" || here=""

    fb="$top/frameworks/base"
    pdir="${here:-$top/device/infinix/X6532}/patches/systemui"

    if [ ! -d "$fb" ]; then
        echo "vendorsetup.sh: $fb does not exist - SystemUI patch skipped" >&2
        return 0
    fi
    if [ ! -d "$pdir" ]; then
        echo "vendorsetup.sh: $pdir does not exist - SystemUI patch skipped" >&2
        return 0
    fi

    failed=0
    seen=0
    for p in "$pdir"/[0-9][0-9][0-9][0-9]-*.patch; do
        [ -f "$p" ] || continue
        seen=$((seen + 1))
        name=$(basename "$p")

        if [ -d "$fb/.git" ]; then
            # already applied?  (holds whether it was applied or committed)
            if git -C "$fb" apply --reverse --check "$p" 2>/dev/null; then
                echo "  $name: already applied"
                continue
            fi
            if git -C "$fb" apply --check "$p" 2>/dev/null; then
                if git -C "$fb" apply "$p" 2>/dev/null; then
                    echo "  $name: applied"
                else
                    echo "  $name: FAILED (git apply)" >&2
                    failed=1
                fi
                continue
            fi
            # otherwise the tree has drifted: fall through to patch(1)
        fi

        if patch -p1 --reverse --dry-run --fuzz=3 -d "$fb" -i "$p" >/dev/null 2>&1; then
            echo "  $name: already applied"
        elif patch -p1 --dry-run --fuzz=3 -d "$fb" -i "$p" >/dev/null 2>&1; then
            if patch -p1 --fuzz=3 --no-backup-if-mismatch -d "$fb" -i "$p" >/dev/null 2>&1; then
                echo "  $name: applied (patch --fuzz=3)"
            else
                echo "  $name: FAILED (patch)" >&2
                failed=1
            fi
        else
            echo "  $name: FAILED - apply it by hand, see $pdir/README.md" >&2
            failed=1
        fi
    done

    if [ "$seen" -eq 0 ]; then
        echo "vendorsetup.sh: no patches found in $pdir" >&2
    elif [ "$failed" -eq 0 ]; then
        echo "vendorsetup.sh: SystemUI shade patch OK"
    else
        echo "vendorsetup.sh: the SystemUI shade patch was NOT applied -" >&2
        echo "                ShadeProvider.tran will do nothing this build" >&2
    fi
    return 0
}

case "${PATCH_SHADE:-1}" in
    0|false|FALSE|False|no|NO|off|OFF)
        echo "vendorsetup.sh: PATCH_SHADE=$PATCH_SHADE - SystemUI shade patch skipped"
        ;;
    *)
        apply_x6532_systemui_patches
        ;;
esac
