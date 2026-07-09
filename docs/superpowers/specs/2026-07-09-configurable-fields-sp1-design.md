# Configurable fields — SP1 (configurable content) — design

**Date:** 2026-07-09
**Status:** approved (brainstorm)

## Why

On the FR70 (and every 390 px device — the layout reference, so it renders the
smallest) Flightdeck's value font is 34 px ≈ the system `FONT_TINY`; native data
fields put values in the NUMBER fonts (~80–120 px). The values are simply too
small. The fix has two halves; this spec is the **first**:

- **SP1 (this spec):** make the five fields **configurable** — any metric in any
  slot, from a ~18-metric menu — in the **current** 4-corner + center layout. No
  font or position changes.
- **SP2 (separate spec, later):** layout **presets** (5/4/3/2/1) with larger
  regenerated fonts — the actual "fewer → bigger" legibility win.

Both land on `main` as separate PRs; **no store release is cut until SP2 is in**
(SP1 alone leaves bare small values — an intermediate that must not ship).

## Locked decisions (from brainstorm)

- Layout **presets** are SP2; SP1 keeps today's positions/sizes/colors.
- Metric menu is **comprehensive** (~18 + Off).
- Labels: a **single global `showLabels` toggle, default OFF**.
- Color stays **positional / theme-driven** (center = warm-white, top row =
  white, bottom row = accent) regardless of the metric — no new color settings.

## Metric registry

`Metrics.mc` changes from "compute 5 fixed strings" to a **registry**: it holds
the current `Activity.Info` plus the lap baseline, and exposes

- `format(id as Number) as String` — the formatted value for metric `id`.
- `label(id as Number) as String` — its short label.

One `switch` per method. Lap metrics reuse the baseline `Metrics` already
captures in `onLap` (called from `onTimerLap` / `onWorkoutStepComplete`).

**Metric ids** (the `list` value stored per slot; `0` = Off):

| id | Metric | Label | Source (`Activity.Info` unless noted) | Format |
|----|--------|-------|----------------------------------------|--------|
| 0  | Off | — | — | (slot draws nothing) |
| 1  | Timer (elapsed) | `TIMER` | `timerTime` | `formatClock` → `M:SS` / `H:MM:SS` |
| 2  | Clock (time of day) | `CLOCK` | `System.getClockTime()` | `H:MM`, honor `is24Hour` |
| 3  | Distance | `DIST` | `elapsedDistance` | `formatDistance` → `X.XX` (km/mi) |
| 4  | Lap distance | `LAP DST` | `elapsedDistance` − baseline | `formatDistance` |
| 5  | Lap time | `LAP TM` | `timerTime` − baseline | `formatClock` |
| 6  | Avg pace | `PACE` | `averageSpeed` | `formatPace` → `M:SS` (/km /mi) |
| 7  | Lap pace | `LAP PC` | lap dist ÷ lap time | `formatPace` |
| 8  | Current pace | `PACE •` | `currentSpeed` | `formatPace` |
| 9  | Avg speed | `SPEED` | `averageSpeed` | `formatSpeed` → `X.X` (km/h, mph) |
| 10 | Current speed | `SPD •` | `currentSpeed` | `formatSpeed` |
| 11 | Heart rate | `HR` | `currentHeartRate` | int bpm |
| 12 | Avg heart rate | `AVG HR` | `averageHeartRate` | int bpm |
| 13 | HR zone | `ZONE` | `currentHeartRate` vs `UserProfile` zones | `1`–`5` (see permission note) |
| 14 | Cadence | `CAD` | `currentCadence` | int, shown as reported (no doubling) |
| 15 | Avg cadence | `AVG CAD` | `averageCadence` | int |
| 16 | Calories | `CAL` | `calories` | int kcal |
| 17 | Total ascent | `ASCENT` | `totalAscent` | int (m/ft, unit-aware) |
| 18 | Altitude | `ALT` | `altitude` | int (m/ft, unit-aware) |

**Labels are finalized (the label bitmap font is UPPER-only — no digits, spaces,
or punctuation)** to short alpha forms, prefix convention `L`=lap / `C`=current /
`A`=avg: `TIMER CLOCK DIST LDIST LTIME PACE LPACE CPACE SPEED CSPD HR AHR ZONE
CAD ACAD CAL ASC ALT` (ids 1–18). The **value** font is `DIGITS + ":.-"`, which
covers every value format (pace `5:14`, dist `8.20`, HR `148`, negative altitude
`-12`); the clock shows `H:MM` with no AM/PM marker (the value font has no
letters) but honours the device's 24-hour setting for the hour.

**Formatter helpers to add** to `Metrics` (alongside the existing `formatPace` /
`formatDistance` / `formatClock`): `formatSpeed`, `formatInt` (HR / cadence /
calories), `formatElevation` (ascent / altitude, unit-aware), `formatClockTime`,
`hrZone`. Every formatter returns a placeholder (`--` or `--:--`) when its source
is `null` (activity not started, sensor absent, zones unavailable).

**Units** reuse the existing statute/metric flag (`System.getDeviceSettings().
distanceUnits`). Ascent/altitude add a metres↔feet conversion (`× 3.28084`).

## Settings

Added to `resources/settings/settings.xml` + `resources/settings/properties.xml`
(configured from the Garmin Connect phone app; no on-device menu):

- `slot0`…`slot4` — five `list` settings, each listing `Off` + the 18 metrics,
  stored as a `number` property = the metric id.
- `showLabels` — a `boolean` setting/property, default `false`.
- `theme`, `mode` — unchanged.

Total 8 settings. New strings for each metric name + the two new setting titles
go in `resources/strings/strings.xml`.

## Slot → position, palette, defaults

The slot-index → position mapping is fixed now and **reused unchanged by SP2**
(so switching presets later never reshuffles a user's slots):

| Slot | Position (today's layout) | Palette role | Default metric (id) |
|------|---------------------------|--------------|---------------------|
| `slot0` | center (hero) | warm-white (`hero`) | Timer (1) |
| `slot1` | top-left | white (`sval`) | Avg pace (6) |
| `slot2` | top-right | white (`sval`) | Distance (3) |
| `slot3` | bottom-left | accent (`lap`) | Lap pace (7) |
| `slot4` | bottom-right | accent (`lap`) | Lap time (5) |

Defaults reproduce today's face content exactly; the only visible change is that
**labels are off by default**.

## Wiring

- `FlightdeckView.compute(info)` → `Metrics.update(info)` now only stores `info`
  and refreshes the lap baseline. `readSettings()` also reads `slot0..slot4`
  (via the existing `numProp`) into a `Number[5]` and `showLabels` into a
  `Boolean`.
- `Theme.draw(dc, m, fonts, light)` gains the slot array + `showLabels` (passed
  from the view). It loops the five positions instead of drawing five hardcoded
  fields:
  - resolve the slot's metric id; if `0` (Off), draw nothing for that position;
  - else draw `m.format(id)` at the position, edge-justified as today, in the
    position's palette role (center→`hero`, top→`sval`, bottom→`lap`);
  - if `showLabels` **and** the position is a corner (not center), draw
    `m.label(id)` at the existing corner label baseline.
- Themes' `buildLayout` position tables, `decorate()`, `ThemeRegistry`, and the
  Cockpit/Bridge title banners are **unchanged** — only base `draw()` changes.

## Deliberate SP1 simplifications (resolved by SP2; SP1 is not released)

1. Labels-on labels only the **four corners**; the center slot stays unlabeled
   (today's layout has no center-label baseline).
2. With labels off, a corner value keeps its current Y (a small gap where the
   label was) rather than re-centering in the cell.

## Global constraints

- `monkeyc -w` (warnings-as-errors) must stay clean across all four resolution
  buckets; behaviour beyond "it compiles" is checked in the simulator (no CI).
- **No new manifest permissions** (verified against `api.debug.xml`):
  `UserProfile.getHeartRateZones` carries no permission annotation and
  `UserProfile` is not a manifest permission; `Activity.Info` sensor fields (HR,
  cadence, …) are permission-free for a data field. So all 18 metrics keep the
  "Requests no permissions" claim intact. Re-confirm at build that the manifest
  still declares zero permissions. (`getHeartRateZones` takes a
  `UserProfile.HR_ZONE_SPORT_*` argument, e.g. `HR_ZONE_SPORT_RUNNING`; the array
  is `[minZ1, maxZ1, maxZ2, maxZ3, maxZ4, maxZ5]`.)
- SP1 adds **no fonts** and no bitmap resources (values use the existing 34 px
  value font, labels the 30 px label font) — negligible impact on the 256 KB
  data-field memory budget.
- Follow repo conventions: branch → PR → wait; board Todo→In Progress→Done; PR
  bodies per `universal.md` (incl. the `Provenance` section); commits stamped
  `Co-Authored-By`.

## Out of scope (SP2)

Layout presets, larger regenerated fonts, per-preset positions/sizes, re-centering
values when unlabeled, and any center-slot label. No store release until SP2.

## Verification

1. `monkeyc -w` clean on `fr70` / `fr265s` / `fr265` / `fr965`.
2. Confirm the manifest still declares zero permissions after adding the
   sensor-backed metrics.
3. Simulator: each of the four themes renders the default five slots correctly;
   change a couple of slots (e.g. HR, cadence) and toggle `showLabels`; verify
   `Off` blanks a slot and null sources show placeholders.
