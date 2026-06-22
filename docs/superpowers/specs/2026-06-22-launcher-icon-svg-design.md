# Per-Size Launcher Icons (exact-size per device)

**Date:** 2026-06-22
**Status:** Approved design (pre-implementation). Supersedes an earlier
single-SVG idea — see "What we learned" below.

## Goal

Eliminate the Connect IQ build warning that the launcher icon "isn't compatible"
with a device's expected size and "will be scaled," so the icon is crisp at every
device's native size. Store-release polish ahead of v0.1.1.

## What we learned (why a single icon cannot work)

Empirically verified on SDK 9.1.0: the launcher-icon warning fires on **any
declared-size mismatch** between the icon and the device's required size, and a
**vector SVG does not exempt it** — the compiler checks the SVG's declared
`width`/`height` (or `viewBox`) against the device size. Confirmed directly:
fr265 (wants 60×60) + a 54×54-declared SVG → warns; fr265 + a 60×60-declared icon
→ no warning. The peer project Understated ships a single 40×40 SVG and warns on
all its non-40 devices — it simply lives with the warning. **Only an icon whose
declared size matches each device clears the warning**, so the icon must be
provided per size.

## Icon size → devices

| Icon size | Devices |
|---|---|
| 54×54 | fr70, fr165, fr165m, fr170, fr170m |
| 60×60 | fr265s, fr265, fenix843mm, epix2 |
| 65×65 | fr965, fr970, fenix847mm |
| 70×70 | venu3s, venu3 |

(Icon size is orthogonal to screen resolution — venu3s and fr165 are both 390×390
but want 70 vs 54 — so the existing `resources-WxW` resolution buckets cannot
carry the icon; icons need their own qualifier.)

## Approach

Per-size icons in icon-size-qualified resource folders, wired per-device in the
jungle — the same `resourcePath`-append mechanism already used for fonts and
watermarks, as a **second, independent append** keyed by icon size. The icon is
emitted as a small **SVG declared at each target size** (reusing the existing
vector generator), so the art stays crisp and the declared size matches the
device.

## Design

### Generator

`tools/gen_icon.py` already emits one vector `launcher_icon.svg` at a single size.
Generalize it to loop `SIZES = [54, 60, 65, 70]`, emitting
`resources-icon<N>/drawables/launcher_icon.svg` for each, with `width`/`height`/
`viewBox` all set to `<N>` (so the declared size matches the device). Artwork and
colours unchanged (dark dial `#0D0A07`, teal ring `#3FB6D6`, amber centre
`#FFC890`, transparent background); all coordinates already scale with the size.

### Resource layout

```
resources/drawables/              # LauncherIcon declaration + both icon files REMOVED
resources-icon54/drawables/   launcher_icon.svg (54) + drawables.xml
resources-icon60/drawables/   launcher_icon.svg (60) + drawables.xml
resources-icon65/drawables/   launcher_icon.svg (65) + drawables.xml
resources-icon70/drawables/   launcher_icon.svg (70) + drawables.xml
```

Each icon folder's `drawables.xml` (identical across folders) declares the icon:

```xml
<resources>
    <bitmap id="LauncherIcon" filename="launcher_icon.svg" dithering="none"/>
</resources>
```

Base `resources/drawables/` loses the `LauncherIcon` declaration, the old 54×54
`launcher_icon.png`, and the single `launcher_icon.svg` from the earlier step —
so `LauncherIcon` is declared exactly once per device (in its icon folder). Base
`resources/drawables/` then holds no resources and is removed; `manifest.xml`'s
`launcherIcon="@Drawables.LauncherIcon"` is unchanged.

### Jungle wiring

Each device gets a **second** `resourcePath` append (after its resolution bucket)
pointing at its icon-size folder, via per-size variables:

```
icon54 = resources-icon54
icon60 = resources-icon60
icon65 = resources-icon65
icon70 = resources-icon70

fr70.resourcePath    = $(fr70.resourcePath);$(res390);$(icon54)
venu3s.resourcePath  = $(venu3s.resourcePath);$(res390);$(icon70)
fr265.resourcePath   = $(fr265.resourcePath);$(res416);$(icon60)
fr965.resourcePath   = $(fr965.resourcePath);$(res454);$(icon65)
... (all 14 devices, each mapped to its icon size per the table)
```

## Verification

No Monkey C unit-test framework; the gate is `monkeyc -w`. Build one device per
icon size — **fr70 (54), fr265 (60), fr965 (65), venu3 (70)** — and confirm both:
1. `BUILD SUCCESSFUL`, and
2. the build output **no longer contains** the `launcher icon ... isn't
   compatible ... will be scaled` warning. The *absence* of that warning is the
   real success criterion (it is not `-w`-promoted).

## Scope

Only the launcher icon. The `store/` directory is a separate PR and out of scope
here. No device, theme, or settings changes.
