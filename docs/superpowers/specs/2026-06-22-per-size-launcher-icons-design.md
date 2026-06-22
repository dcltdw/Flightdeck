# Per-Size Launcher Icons

**Date:** 2026-06-22
**Status:** Approved design (pre-implementation)

## Goal

Ship an exact-size launcher icon for every device in the roster so the Connect IQ
build no longer warns that the 54×54 icon "isn't compatible" and must be scaled.
This is store-release polish ahead of v0.1.1 — a scaled icon looks soft in the
store listing and on-device.

## Background

The launcher icon is currently a single 54×54 PNG (`resources/drawables/launcher_icon.png`,
declared as `LauncherIcon` in `resources/drawables/drawables.xml`, referenced by
`manifest.xml` via `launcherIcon="@Drawables.LauncherIcon"`). Each device family
expects a specific launcher-icon size, read from its SDK `compiler.json`
(`launcherIcon`). Those sizes are **orthogonal to screen resolution** — e.g.
venu3s and fr165 are both 390×390 screens but want 70×70 and 54×54 icons
respectively — so the existing `resources-WxW` resolution buckets cannot carry
the icon.

### Icon size → devices

| Icon size | Devices |
|---|---|
| 54×54 | fr70, fr165, fr165m, fr170, fr170m |
| 60×60 | fr265s, fr265, fenix843mm, epix2 |
| 65×65 | fr965, fr970, fenix847mm |
| 70×70 | venu3s, venu3 |

## Approach (chosen: "A")

Icon-size-qualified resource folders, wired per-device in the jungle — the same
`resourcePath`-append mechanism already used for the per-resolution fonts and
watermarks, but keyed by icon size (a second, independent append).

Rejected:
- **B — single 70×70 icon, let CIQ downscale.** Any size mismatch still emits the
  warning (scaling down warns too), so it does not meet the goal.
- **C — fold the icon into the existing resolution buckets.** Impossible: icon
  size is not a function of resolution (venu3s vs fr165, both 390, differ).

## Design

### Generator

`tools/gen_icon.py` already draws every element proportional to the output size,
so it generalizes by looping the target size. Change `SIZE = 54` to a list
`SIZES = [54, 60, 65, 70]` and, for each, render and write
`resources-icon<N>/drawables/launcher_icon.png`. The artwork (dark dial, teal
ring, corner ticks, amber centre) is unchanged.

### Resource layout

```
resources/drawables/             # LauncherIcon removed (see below)
resources-icon54/drawables/   launcher_icon.png (54) + drawables.xml
resources-icon60/drawables/   launcher_icon.png (60) + drawables.xml
resources-icon65/drawables/   launcher_icon.png (65) + drawables.xml
resources-icon70/drawables/   launcher_icon.png (70) + drawables.xml
```

Each icon folder's `drawables.xml` declares the icon (identical across folders):

```xml
<resources>
    <bitmap id="LauncherIcon" filename="launcher_icon.png"/>
</resources>
```

The `LauncherIcon` declaration and the 54×54 PNG are **removed from base**
`resources/drawables/` so the symbol is declared exactly once per device (in its
icon folder). After the move, base `resources/drawables/` holds no resources and
is removed; `manifest.xml`'s `launcherIcon="@Drawables.LauncherIcon"` is
unchanged (the symbol now resolves per-device from the icon folder).

### Jungle wiring

Each device gets a **second** `resourcePath` append (after its resolution
bucket) pointing at its icon-size folder, via per-size variables:

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
   real success criterion (it is not `-w`-promoted, so it would not fail the
   build on its own).

## Scope

Only the launcher icon. The `store/` directory (hero/preview images,
`description.md`) is a separate PR and is out of scope here. No new device ids,
themes, or settings.
