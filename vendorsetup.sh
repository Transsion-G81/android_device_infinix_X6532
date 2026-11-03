#!/bin/sh
# Applies patches/systemui/*.patch to frameworks/base on every envsetup.sh run.
# Opt out with PATCH_SHADE=0.  Details: patches/systemui/README.md.

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
            # tree drifted: fall through to patch(1)
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
        echo "vendorsetup.sh: SystemUI shade patch NOT applied - ShadeProvider.tran will do nothing" >&2
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
