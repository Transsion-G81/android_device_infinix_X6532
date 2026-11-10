# patches/systemui

`0001-SystemUI-publish-shade-expanded-state.patch`

Adds to `NotificationShadeWindowControllerImpl.onShadeOrQsExpanded()`:

```java
Settings.System.putInt(mContext.getContentResolver(), "qs.fps.expanded",
        isExpanded ? 1 : 0);
```

ShadeProvider (`com.shade.handler`, packaged by `device.mk`) observes that setting and,
while the shade is open, disables the blur and shortens the animation scale. No import
change is needed - `Settings`, `Log`, `TAG` and `mContext` already exist in that class.

Applied by `vendorsetup.sh` on every `envsetup.sh` run, once, idempotently; opt out with
`PATCH_SHADE=0`. By hand, from `frameworks/base`:

```sh
git apply ../../device/infinix/X6532/patches/systemui/0001-*.patch
git apply --reverse ../../device/infinix/X6532/patches/systemui/0001-*.patch
```

Generated against lineage-23.2 `NotificationShadeWindowControllerImpl.java`,
sha256 `26561C2CB02F18FE60B1BC50210CE630188F77A9E03FC77ACCAED8237425D98F` (47936 bytes).
If that file changes the patch stops applying - `vendorsetup.sh` reports it.
