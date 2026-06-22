# Store Assets (`store/`)

**Date:** 2026-06-22
**Status:** Approved design (pre-implementation)

## Goal

Assemble a `store/` directory with the assets needed to submit Flightdeck to the
Garmin Connect IQ store ahead of v0.1.1: a hero banner, preview screenshots, and
listing copy. Modeled on the peer project Understated's `store/`.

## Constraints

- The store listing accepts **5 preview images**; the **hero banner showcases 3**
  faces. Across those **8 images, every one is a distinct theme×mode face**.
- Flightdeck has exactly 4 themes × 2 modes = 8 faces, so the 8 images are the 8
  combinations, each shown once:
  - **Hero (3):** Cockpit Dark, Bulkhead Dark, Bridge Light.
  - **Previews (5):** Cockpit Light, Bridge Dark, Bulkhead Light, Phosphor Dark,
    Phosphor Light.
- This is assets only — **no app/code changes**, separate PR.

## Why real simulator captures

Flightdeck's faces use custom bitmap fonts, procedural decorations, and the
Phosphor radar watermark. Only a real Connect IQ simulator render shows them
accurately; a re-implemented mockup would drift. (The private predecessor's
mockup scripts were intentionally left behind.) So all 8 images are genuine
simulator captures.

## Directory layout

```
store/
  README.md              # documents each asset + recapture / rebuild steps
  description.md         # store listing copy + "What's changed" section
  hero.png               # 1440×720 store banner
  gen_hero.sh            # reproducibly composites hero.png from the 3 hero captures (ImageMagick)
  screenshots/
    hero/                # 3 source captures (cockpit-dark, bulkhead-dark, bridge-light)
    preview/             # 5 store previews (cockpit-light, bridge-dark, bulkhead-light, phosphor-dark, phosphor-light)
```

## Capture method

- **Device:** fr965 (454×454) — largest/crispest, a Forerunner befitting a run
  field. Each capture is 454×454.
- **Forced builds:** for each of the 8 faces, build a throwaway `.prg` with the
  theme/mode **and** a fixed sample running pose forced in code, so every shot is
  identical and polished (no `--` placeholders, no activity-simulation fiddling).
  These forced edits are never committed (same pattern used for the visual-pass
  theme previews). Sample pose:
  - top row: **PACE 5:14**, **DIST 8.2**
  - hero (elapsed): **28:13**
  - bottom row: lap **PACE 5:02**, **TIME 9:48**
- **Capture:** attempt `screencapture` of the simulator window per face; if the
  shell lacks Screen Recording permission, fall back to the sim's
  **File → Save Screen Shot** for the affected faces. Crop/normalize each to
  454×454.
- File names: `screenshots/hero/{cockpit-dark,bulkhead-dark,bridge-light}.png`;
  `screenshots/preview/{cockpit-light,bridge-dark,bulkhead-light,phosphor-dark,phosphor-light}.png`.

## Hero banner (`hero.png`, 1440×720)

Dark banner. Left/over: the **FLIGHTDECK** wordmark and the tagline
**"Full-screen run metrics — four ways to fly."** Right/across: the 3 hero faces
(Cockpit Dark, Bulkhead Dark, Bridge Light) arranged to tell the
"four themes, dark or light" story. Built by `gen_hero.sh` (ImageMagick) from the
3 `screenshots/hero/` captures, so it is reproducible; 1440×720 is the store's
required hero size.

## Listing copy (`description.md`)

Markdown for cut-and-paste into the store listing:

- **Pitch:** a customizable, **full-screen run data field** for Garmin (Connect
  IQ). An *additive* run page — add it to a run profile and swipe to it; it does
  not replace native screens.
- **Features:** four themes (Cockpit / Bridge / Bulkhead / Phosphor) × Dark/Light,
  selectable from the Garmin Connect app; live pace, distance, elapsed, and lap
  pace/time from `Activity.Info`; custom bitmap typography; requests **no**
  permissions.
- **Devices:** AMOLED running watches across 390/360/416/454 (Forerunner
  70/165/170/265/265s/965/970, Fenix 8, Epix 2, Venu 3/3s).
- **"What's changed"** section (release notes), seeded from `CHANGELOG.md`:
  - **v0.1.1** — Initial public release: four themes × dark/light; responsive
    rendering across AMOLED running watches (390/360/416/454); custom bitmap
    fonts; per-device launcher icons.

## `README.md`

Documents what each asset is, the exact recapture procedure (forced-build +
simulator + `screencapture`/Save Screen Shot), `gen_hero.sh` usage, and — for
reference, like Understated — the `.iq` store-package build command (the package
itself is a release-time artifact, git-ignored, not built here).

## Verification

Assets only, so no `monkeyc` gate. Verify:
- All 8 capture files exist at 454×454, one per the correct theme×mode face.
- `hero.png` is exactly 1440×720; `gen_hero.sh` reproduces it from the 3 hero
  captures.
- `description.md` and `README.md` render cleanly and contain the required
  sections (pitch, features, devices, "What's changed").

## Scope

`store/` assets only. No app, theme, settings, or device changes. The store
`.iq` package build and the actual store submission are out of scope (release-
time steps; build command documented in `README.md`).
