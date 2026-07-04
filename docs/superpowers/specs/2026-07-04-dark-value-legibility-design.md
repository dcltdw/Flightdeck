# Dark-mode value legibility — design

**Date:** 2026-07-04
**Status:** approved (validated interactively in the simulator on fr965)

## Problem

The corner metric **values** on the dark faces were hard to read on-wrist. The
small value font (34px @390) combined with mid-luminance, saturated hues
(Cockpit's orange/green, Bulkhead's red) reads poorly at a glance in daylight —
saturated colour at small size has lower effective acuity than white regardless
of computed contrast ratio. Labels were fine and stay unchanged.

## Principle

On the dark faces, legibility comes from luminance: the **session (top) row is
white**, and the **lap (bottom) row is a distinct per-theme accent** that keeps
the session-vs-lap distinction and carries the theme's identity. The **hero
(elapsed time)** is unified to Cockpit's warm off-white `#FFC890` across all four
dark faces, so the clock reads identically everywhere and theme identity lives in
the lap accent + background art.

Only the **dark** palettes change. Light modes (dark-on-light, already legible),
all **labels**, and font names/sizes are untouched.

## Changes (dark `buildPalette` only)

| Face | top (session) | lap accent | hero |
|---|---|---|---|
| Cockpit  | `#FFB066` → `#FFFFFF` | `#5FD98E` → `#3BE06E` (green)  | `#FFC890` (unchanged) |
| Bridge   | `#FFFFFF` (same)     | `#FFFFFF` → `#FFFF00` (yellow) | `#E0A23A` → `#FFC890` |
| Bulkhead | `#E63A28` → `#FFFFFF` | `#E63A28` → `#FF6B52` (red)    | `#E0A23A` → `#FFC890` |
| Phosphor | `#BFE9EE` → `#FFFFFF` | `#BFE9EE` → `#00FFFF` (cyan)   | `#45CFE0` → `#FFC890` |

The four lap accents — green / yellow / red / cyan — are mutually distinct, so
the faces remain easy to tell apart at a glance.

## Rejected alternatives

- **Brighten in-hue** (keep Cockpit orange/green, just lighter): rendered in the
  sim and rejected — too subtle to fix the stated legibility problem.
- **Keep Bulkhead's red / Phosphor's pale cyan as-is**: rendered; both were the
  hardest to read of their groups.
- **Bridge with no accent (white/white)** and **Phosphor magenta hero**: both
  explored and dropped in favour of the unified scheme above.

## Verification

`monkeyc -w` clean on fr70 / fr265s / fr265 / fr965 (all four resolution
buckets). Faces confirmed in the simulator on fr965. No code paths change —
palette constants only.
