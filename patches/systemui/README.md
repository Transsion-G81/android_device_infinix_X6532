# patches/systemui — X6532 SystemUI shade patch

## What it does

`0001-SystemUI-publish-shade-expanded-state.patch` adds one hunk to
`frameworks/base/packages/SystemUI/src/com/android/systemui/shade/NotificationShadeWindowControllerImpl.java`,
inside `onShadeOrQsExpanded(Boolean isExpanded)`, right after `apply(mCurrentState);`:

```java
// Publish the shade state for the QS shade performance handler
// (ShadeProvider, com.shade.handler): it observes qs.fps.expanded and
// drops the window blur / animation scale while the shade is open.
try {
    Settings.System.putInt(mContext.getContentResolver(), "qs.fps.expanded",
            isExpanded ? 1 : 0);
} catch (Exception e) {
    Log.e(TAG, "Failed to publish qs.fps.expanded", e);
}
```

No import change is needed: `Settings`, `Log`, the `TAG` constant and the
`mContext` field already exist in that class.

## Who consumes it

`vendor/../ShadeProvider/shadeprovider.apk` — the prebuilt `com.shade.handler`
("Shade Handler") packaged by `device.mk` as `ShadeProvider.tran`, a
`system_ext` priv-app running as `android.uid.system` with
`WRITE_SECURE_SETTINGS`. It registers a `ContentObserver` on
`Settings.System "qs.fps.expanded"` and, when the shade opens, sets
`Settings.System "disable_window_blurs" = 1` and
`Settings.Global "animator_duration_scale" = 0.85`, then restores the scale
when the shade closes (gated by the `qs.limited`, `qs.fps.limited`,
`qs.blur.fps.limited`, `qs.anim.limited` settings).

Without this hunk the APK never sees a state change and the whole
"UI performance on shade expand" feature is silently dead.

## Why a patch instead of the old sed hack

`vendorsetup.sh` used to rewrite that method with `sed`/`awk` on every
`lunch`. It matched source text, so when the surrounding method changed it
inserted nothing, printed nothing and the build still succeeded. This patch is
strict: `git apply` with no fuzz, and `vendorsetup.sh` reports a failure
instead of silently building a dead feature.

## How it is applied

`vendorsetup.sh` applies it on every `source build/envsetup.sh` (so a
`repo sync` that resets `frameworks/base` is repaired on the next envsetup).
Unlike the KL5 NFC patches it is **on by default**, because the APK in
`device.mk` depends on it; disable with:

```sh
export PATCH_SHADE=0
```

## Applying or reverting by hand

```sh
cd frameworks/base
git apply device/infinix/X6532/patches/systemui/0001-*.patch          # apply
git apply --reverse device/infinix/X6532/patches/systemui/0001-*.patch # revert
# or, without git:
patch -p1 -i device/infinix/X6532/patches/systemui/0001-*.patch
patch -p1 -R -i device/infinix/X6532/patches/systemui/0001-*.patch
```

## What was verified

* Generated against LineageOS `lineage-23.2` `NotificationShadeWindowControllerImpl.java`,
  sha256 `26561C2CB02F18FE60B1BC50210CE630188F77A9E03FC77ACCAED8237425D98F` (47936 bytes).
  Applying it must produce sha256
  `175B4EEC881E1272609F805897AB1FC1E87060055ED55B516A17CA1667A11B9C` (48445 bytes).
* `git apply --check` clean at fuzz 0 against that revision, and the applied file is
  byte-identical to the intended result.
* Re-applying is detected (`git apply --reverse --check` succeeds), so the applier
  says "already applied" rather than failing.
* If `lineage-23.2` moves and the hunk stops applying, `vendorsetup.sh` fails loudly
  and the patch needs regenerating against the new revision.

## Caveats worth knowing (the APK side, not this patch)

* The APK is a prebuilt with no source in the tree, originally signed by
  `CN=crDroid`, built with AIDE (it carries AIDE's `adrt` debug helper and a
  `com.aide.ui` watermark). It has an inert logcat-reader/socket-sender in it:
  no ADRT receiver is declared and no endpoint is baked in, so nothing is sent.
* Its raw SurfaceFlinger binder call (transaction `0x40b`, written for
  Android 11) very likely does nothing on Android 16 — the visible effect is the
  blur + animation-scale change.
* The animation-scale restore is skipped when `qsanimlimit != 0`; if the service
  is killed with the shade open, `animator_duration_scale` can stay at 0.85.
