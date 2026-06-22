# Flightdeck v0.1.1 — Responsive Multi-Device Support

**Date:** 2026-06-22
**Status:** Approved design (pre-implementation)

## Goal

Make Flightdeck render correctly across Garmin's color AMOLED running watches,
not just the single 390×390 target it was hardcoded for. Today the layout uses
absolute pixel constants and the bitmap fonts are baked at fixed pixel sizes, so
on any other resolution the face would clip or mis-center. v0.1.1 makes geometry
and fonts scale to the device while preserving the exact current look at 390.

## Scope

**In scope:** round, color **AMOLED** running-capable devices across four
resolutions — 390×390, 360×360, 416×416, 454×454.

**Out of scope (v0.1.1):**
- Non-round screens (rectangle/edge) — explicitly deferred.
- MIP (non-AMOLED) devices (fr255/fr255s/fr955/fr55/fenix7) — dimmer display,
  gradients and the Phosphor watermark need separate tuning. Deferred.
- Any new metrics, themes, or settings — this release is purely about
  responsive rendering.

### Resolution buckets and device ids

Exactly **4 buckets**, one per real resolution. Each device is assigned to a
bucket; ids below are the initial set and each id's resolution is verified from
its SDK device profile (`compiler.json` → `resolution`) during implementation.

| Bucket | Devices (product ids) |
|---|---|
| **390×390** | fr70 (current target), fr165, fr165m, fr170, fr170m, venu3s |
| **360×360** | fr265s |
| **416×416** | fr265, fenix843mm, epix2 |
| **454×454** | fr965, fr970, fenix847mm, venu3 |

## Approach (chosen: "A")

Runtime-relative geometry + per-bucket bitmap font sets bundled per-device via
the jungle. Rejected alternatives: bundling all font sizes on every device (B —
blows the per-device memory budget once watermarks are included); dropping
custom fonts for built-in scalable fonts (C — abandons the custom monospace
identity and varies by device).

## Design

### 1. Geometry — one reference design × a uniform scale factor

Keep the existing 390-based numbers as the **reference design @390**. Introduce a
single scale factor computed once per draw:

```
s = dc.getWidth() / 390.0
```

Every coordinate, baseline, ascent, radius, and pen width is multiplied by `s`.
Because all four buckets are square round screens (width == height), one uniform
`s` is exact. At 390, `s == 1.0`, so the current pixels are reproduced
identically — this is a faithful re-expression, not a redesign.

- `Layout` (source/Theme.mc) holds reference @390 constants; the base `Theme.draw`
  and `txt` apply `s` when positioning. Ascents scale by `s` as well, since each
  bucket's fonts are scaled copies of the 390 fonts — so **no runtime
  font-metric measurement is required**.
- Scaled pixel coordinates are rounded to the nearest integer at draw time
  (sub-pixel rounding error ≤1px is visually negligible).

### 2. Fonts — 4 size-scaled sets, ids unchanged

`tools/gen_fonts.py` is extended to emit one font set per bucket. Per-bucket
pixel size = `round(referenceSize × bucketWidth / 390)`:

| font id | 390 (ref) | 360 | 416 | 454 |
|---|---|---|---|---|
| hero | 60 | 55 | 64 | 70 |
| value | 34 | 31 | 36 | 40 |
| label | 30 | 28 | 32 | 35 |
| title | 13 | 12 | 14 | 15 |
| herob | 72 | 67 | 77 | 84 |
| valueb | 42 | 39 | 45 | 49 |
| labelb | 36 | 33 | 38 | 42 |

Each set is written to a resolution-qualified resource folder (e.g.
`resources-454x454/fonts/`). **Font ids stay identical** (`HeroFont`,
`ValueFont`, …), so the font-loading code in `source/Theme.mc` is unchanged.

### 3. Per-device bundling via the jungle

`monkey.jungle` maps each device (or device group) to its bucket's resource
folder using per-device `resourcePath`, so the compiler bundles **only the
matching bucket's assets per device** — per-device package size stays ~flat,
which matters for the data-field memory budget and the 58 KB Phosphor watermark.

> **Verify during implementation:** the exact jungle `resourcePath` append
> syntax and per-device-group form. This is the documented Connect IQ mechanism;
> the grouping syntax is what needs confirming against the installed SDK.

### 4. Decorative art per theme

Each theme's `decorate()` (Cockpit reticles/dashed rim/scan line, Bridge,
Bulkhead, Phosphor) has its hardcoded coordinates and pen widths multiplied by
`s`. The **Phosphor watermark PNG** (currently 390×390, ~58 KB per mode) is
regenerated per bucket: `tools/gen_phosphor_watermark.sh` is extended to emit
all four sizes, written to the same resolution-qualified folders so each device
bundles only its own.

### 5. Manifest

`manifest.xml` `<iq:products>` gains the device ids listed above.

## Verification

- `monkeyc -w` (warnings-as-errors) for **one device per bucket** — build must
  stay clean.
- Simulator render check per bucket, focused on centering and clipping at the
  extremes: **360 (smallest)** and **454 (largest)**, especially the Phosphor
  watermark fit and the Cockpit dashed rim/reticles.
- Confirm at 390 the render is pixel-identical to the pre-change build (the
  `s == 1.0` invariant).

## Risks / open verification points

1. **Jungle `resourcePath` grouping syntax** — confirm against SDK (above).
2. **Per-bucket font ascent rounding** — `ascent ≈ referenceAscent × s` may differ
   from the generated font's actual `base` by ≤1px. If a bucket looks visibly
   off-baseline, read the exact `base` from the generated `.fnt` instead of
   scaling the constant.
3. **Memory budget per device** — verify the largest bucket (454, biggest fonts +
   watermark) stays within the data-field budget on a real device profile.

## Out of this spec

Cutting the v0.1.1 release (tag + GitHub Release) and archiving `swarsy-face`
follow separately, per the project's release process and the recorded resume
state.
