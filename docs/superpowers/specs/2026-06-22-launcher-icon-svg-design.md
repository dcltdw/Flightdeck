# Launcher Icon: Vector (SVG) for Crisp Per-Device Sizing

**Date:** 2026-06-22
**Status:** Approved design (pre-implementation)

## Goal

Eliminate the Connect IQ build warning that the 54×54 launcher icon "isn't
compatible" with devices expecting larger icons and "will be scaled," so the
icon is crisp at every device's native size in the store listing and on-device.
Store-release polish ahead of v0.1.1.

## Background

The launcher icon is a single **raster** 54×54 PNG
(`resources/drawables/launcher_icon.png`, declared as `LauncherIcon` in
`resources/drawables/drawables.xml`, referenced by `manifest.xml` via
`launcherIcon="@Drawables.LauncherIcon"`). Each device family expects a specific
icon size — across the 14-device roster: 54, 60, 65, and 70 px square. A single
raster icon at one size warns (and looks soft) on every other size.

## Approach (chosen: "D" — single vector SVG)

Replace the raster PNG with a single **vector** `launcher_icon.svg`. Connect IQ
rasterizes a vector launcher icon at each device's exact expected size, so one
file serves the whole roster — current and future devices — with no scaling
warning. This mirrors the peer project **Understated**, which drives 80 devices
from one `launcher_icon.svg` (declared with `dithering="none"`).

### Rejected alternatives

- **A — per-size PNG folders + jungle `resourcePath`.** Four icon-size folders
  (54/60/65/70) wired per-device. Works, but four assets + 14 jungle edits where
  one vector file suffices; not future-proof (a new device size needs a new
  folder). Superseded by D.
- **B — single largest PNG, let CIQ downscale.** Any size mismatch still warns
  (scaling down warns too). Does not meet the goal.
- **C — fold the icon into the existing resolution buckets.** Impossible: icon
  size is not a function of resolution (venu3s and fr165 are both 390×390 but
  want 70 vs 54).

## Design

### Generator

Rewrite `tools/gen_icon.py` to emit `resources/drawables/launcher_icon.svg`
instead of a PNG. The artwork is unchanged — the same abstract cockpit-HUD
reticle in the Cockpit dark palette, now as resolution-independent SVG
primitives on a normalized `viewBox` (e.g. `0 0 54 54`, preserving the current
proportions):

- **dark dial disc** — filled `<circle>`, r = 0.48 × size, fill `#0D0A07`
- **teal ring** — stroked `<circle>`, r = 0.40 × size, stroke `#3FB6D6`, width 0.045 × size
- **four corner ticks** — `<line>` pairs, stroke `#3FB6D6`, width 0.045 × size
- **amber centre** — filled `<circle>`, r = 0.10 × size, fill `#FFC890`

Background stays transparent (`fill="none"`, no background rect), matching the
current icon. The SVG uses only basic shapes (`circle`, `line`) that Connect IQ's
SVG support renders reliably.

### Resource declaration

`resources/drawables/drawables.xml` — repoint `LauncherIcon` at the SVG and add
the dithering attribute Understated uses:

```xml
<bitmap id="LauncherIcon" filename="launcher_icon.svg" dithering="none"/>
```

Delete the old `resources/drawables/launcher_icon.png`. **No new folders, no
`monkey.jungle` changes, no `manifest.xml` changes** — `LauncherIcon` stays in
base `resources/drawables/` and the manifest reference is unchanged.

## Verification

No Monkey C unit-test framework; the gate is `monkeyc -w`. Build one device per
former icon-size class — **fr70 (54), fr265 (60), fr965 (65), venu3 (70)** — and
confirm both:
1. `BUILD SUCCESSFUL`, and
2. the build output **no longer contains** the `launcher icon ... isn't
   compatible ... will be scaled` warning (its absence is the real success
   criterion — the warning is not `-w`-promoted, so it does not fail the build
   on its own).

## Scope

Only the launcher icon. The `store/` directory (hero/preview images,
`description.md`) is a separate PR and out of scope here. No device, theme, or
settings changes.
