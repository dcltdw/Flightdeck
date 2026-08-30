# Changelog

All notable changes to Flightdeck. The format follows
[Keep a Changelog](https://keepachangelog.com/), and versions are
[semantic](https://semver.org/) git tags (`vX.Y.Z`). Each tagged release also
has a [GitHub Release](https://github.com/dcltdw/Flightdeck/releases) with the
built `.iq` attached for quick rollback — see [docs/releasing.md](docs/releasing.md).

There is no version field in the Connect IQ manifest; the git tag is the version.

## [Unreleased]

- Times past an hour keep their size on the 3-, 2- and 1-field layouts: the
  hours now render as a small prefix (`1:` beside a full-size `00:04`) instead
  of the whole value shrinking to fit. The 5-field layout already did this. The
  4-field layout still shrinks the whole value — its slots are too narrow for
  the prefix at any size, and it picks the behaviour up when those slots are
  redesigned.

## [0.1.5] - 2026-08-06

- New digit typeface. The bitmap fonts are now rasterised from Roboto Mono; the
  most visible difference is a slashed zero. Sizes, spacing, and positions are
  unchanged — every value sits where it did before. The previous source face was
  bundled with macOS and not ours to redistribute, which is why it changed.
- Flightdeck is now open source under GPL-3.0-or-later. The repository
  previously carried no licence at all. Nothing about the app changes; it still
  requests no permissions.
- Internal: pruned unused bold font atlases and tightened the preset slot model.

## [0.1.4] - 2026-07-18

- Bigger, bolder 5-field default: every field now renders at a large uniform
  size (up from the smaller corner values) and is pushed to the screen edges for
  maximum legibility — the fix for values being too small on smaller watches.
- Long elapsed/lap times past an hour keep the minutes:seconds full-size with a
  smaller hours prefix (e.g. `1:23:45`) instead of shrinking the whole value;
  wide values (e.g. distance past 100) shrink only as much as needed to fit.
- Refreshed per-theme detailing: dimmed background framing (reticles, octagon,
  wall striping) so the numbers stand out, and new contrasting accent pips
  (Cockpit magenta, Bridge cyan, Phosphor magenta/orange). Still requests no
  permissions.

## [0.1.3] - 2026-07-09

- Configurable fields: pick any of 17 metrics (or Off) for each of the five
  positions — pace, distance, heart rate, cadence, elevation, calories, speed,
  clock, and their lap/average variants — from the Garmin Connect app, with an
  optional field-label toggle (default off).
- Layout presets: a new Layout setting (5 / 4 / 3 / 2 / 1 fields). Fewer fields
  render larger type, so you can trade detail for legibility — the fix for
  small values on smaller screens. Values auto-shrink to fit their slot, so a
  long value (a multi-hour time, or distance past 100) never clips.
- Refreshed look: larger 5-field values, retuned per-theme decorations
  (Cockpit/Bridge blips, a Bridge centre reticle, Cockpit reticles pulled to
  the bezel), and tighter number kerning. Still requests no permissions.

## [0.1.2] - 2026-07-04

- Brighter, more legible metric values on the dark faces: the session (top) row
  is now white and the lap (bottom) row a distinct per-theme accent — Cockpit
  green, Bridge yellow, Bulkhead red, Phosphor cyan — with a shared warm-white
  elapsed-time hero across all four. Light modes unchanged.
- Fixed lap pace/time not resetting at structured-workout step boundaries
  (interval transitions fire `onWorkoutStepComplete`, now handled alongside
  `onTimerLap`).

## [0.1.1] - 2026-06-22

- Initial public, trademark-clean variant: four themes (Cockpit / Bridge /
  Bulkhead / Phosphor) × dark/light, selectable via app settings; live metrics
  from `Activity.Info` (session pace/distance, elapsed hero, lap pace/time);
  custom bitmap fonts; procedural radar watermark for Phosphor.
- Responsive multi-device support: renders across AMOLED running watches at
  390×390, 360×360, 416×416, and 454×454 (Forerunner 70/165/170/265/265s/965/970,
  Fenix 8, Epix 2, Venu 3/3s). Layout and bitmap fonts scale from a 390 reference;
  each device bundles only its resolution's assets.
- Per-device exact-size launcher icons (no scaling warning across the roster).
