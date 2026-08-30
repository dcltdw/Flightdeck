# 4-Field Compass (N/E/S/W) Redesign — Design

**Status:** designed per the #47 brief in an autonomous design session (2026-08-30);
geometry derived from measured atlas advances (`resources-*/fonts/*.fnt`), to be
confirmed/tuned in the simulator during execution.

## Goal

Rearrange the **4-field** preset from its four-corner grid (2×2 at 64pt, 170px
budgets) to a **compass layout — N / E / S / W** — and make the type much
larger: N starts at **104pt**, E/S/W at **76pt**. Every position's width budget
admits at least one hours-prefix ladder pair, so an `H:MM:SS` value renders as
a small prefix + full-size `MM:SS` instead of shrinking whole (the #46
mechanism, which today's 170px budgets lock out of layout 4). Issue: #47.

## Scope

- **In:** the `layout == 4` branch of `Theme.presetSlots` (positions, budgets,
  start sizes, roles, label anchors); one new font cut (**`value44`**) plus its
  ladder/pair wiring; layout-4 decoration gating (blips, Bridge reticle);
  `tools/check_font_metrics.py` additions; sim verification across 4 themes ×
  dark/light at wide poses.
- **Out:** the 5/3/2/1 layouts' geometry (untouched; they see `value44` only as
  a new fallback rung strictly larger than the 34 floor — behaviour-preserving
  in practice, see Fonts). No settings/properties changes (#49 renames the
  slots; this ticket keeps `slot0..slot3`). No store release (#50). No manifest
  changes — still "Requests no permissions".

## Global constraints

- `monkeyc -w` clean on fr70 / fr265s / fr265 / fr965.
- All geometry @390, scaled at draw (`scN`/`scP`, `s = dc.getWidth()/390.0`).
- `tools/check_font_metrics.py` stays green (it gains a `value44` row).
- `Off` (id 0) still blanks a slot; `showLabels` still works per-slot.

## Slot geometry (@390)

Slot order keeps today's config indices: `slot0`→N, `slot1`→E, `slot2`→S,
`slot3`→W (under current defaults: Timer / Pace / Dist / LPace; #49 later maps
these to Timer / LPace / Dist / LDist).

| pos | slot | x | justify | baseline | start cut (asc) | budget | role | label (x, baseY) |
|---|---|---|---|---|---|---|---|---|
| N | 0 | 195 | centre | 150 | 104 (109) | 296 | 0 hero-warm | (195, 70) |
| E | 1 | 378 | right | 222 | 76 (80) | 178 | 2 accent | (289, 160) |
| S | 2 | 195 | centre | 316 | 76 (80) | 294 | 1 white | (195, 254) |
| W | 3 | 12 | left | 222 | 76 (80) | 178 | 2 accent | (101, 160) |

Rationale:

- **N is the hero position** (biggest cut, warm hero colour) — matches the
  3/2/1 presets, where slot 0 gets role 0. Default metric is Timer, the primary
  running field. A sub-hour `MM:SS` renders at the full 104pt.
- **E/W are edge-anchored and grow inward** (E right-justified at x 378, W
  left-justified at x 12), the 5-field "outer digit at the edge" idea applied
  at the midline where the round screen is widest. Their baselines centre the
  76pt digit ink on the vertical middle (ink spans y 167–223). Budgets of 178
  each leave a ≥10px centre gap even when both are at their widest.
- **S mirrors N's width** but starts at 76: a 104 start would push its ink top
  to ~y 241 and its label into the E/W row; 76 keeps a clean label band
  (S ink spans y 261–317) and still doubles today's effective size for wide
  values. N-over-S asymmetry is deliberate hierarchy, not an oversight.
- **Roles** are positional as everywhere else. E/W get the lap accent because
  the #49 defaults put lap metrics there; in the brief window before #49 lands,
  E shows session Pace in the accent colour — accepted.
- Circle clearance at the widest corners: N ink corners (±148, y 75) sit at
  r ≈ 190.5, S ink corners (±147, y 317) at r ≈ 191 — inside the r 195 edge
  with ~4px margin. E/W ink corners are well clear (chord at y 167/223 runs
  x 2–388).
- `PresetSlot.asc` is populated (109 / 80) for consistency though `drawPreset`
  takes ascents from the fit result.

## Fonts: one new cut, `value44`

The ladder's 52 → 34 step is the unhelpful gap the ticket anticipated: at the
E/W budget (178) the smallest existing pair (52+34) measures 175–179px
worst-case across buckets — a per-bucket coin flip, and on the 454 bucket
`1:00:04` finds **no** pair and collapses to 34pt whole, which is exactly the
#46 defect resurfacing. Fix by adding a **`value44`** cut (glyphs `0-9:.-`,
stroke 0, same family):

- `tools/gen_fonts.py` `REF_SPECS` gains `("value44", 44, DIGITS + ":.-", 0)`;
  atlases regenerated for all four buckets (existing atlases must stay
  byte-identical — the generator is deterministic).
- `fonts.xml` (×4 buckets) gains `Value44Font`; `Fonts` gains a lazy
  `value44()` accessor.
- `cutFont` gains the 44 row with the ascent read from the generated `.fnt`
  `base=` (predicted ≈46 — use the actual value).
- `fitValueFont` ladder becomes `104, 76, 64, 52, 44, 34`.
- `fitDurationPair` sizes become `104, 76, 64, 52, 44`; `prefixCut(44) = 34`
  (ratio 0.77, in family with 52→34). `prefixCut(64)` stays 34: no live budget
  lands on the 64-pair (needs 211–260px; budgets are 178/294/296/360), so the
  minimal diff wins.
- `tools/check_font_metrics.py` `CHECKS` gains the `value44` cutFont row.

Layouts 3/2/1 see 44 only as an extra shrink rung between 52 and 34 — reachable
only by strings too wide for 52 within a 360 budget (none of our formats), so
their behaviour is unchanged in practice, and where it ever did trigger it
renders strictly larger than before.

## Fit matrix (measured @390; worst-case across the four buckets in parens)

Widths from the committed `.fnt` advances; `value44` rows are projections to be
re-verified from its generated atlas.

| value | N (296) | S (294) | E/W (178) |
|---|---|---|---|
| `5:14` / `8.53` (4-ch) | **104** 223 (226) | **76** 166 | **76** 166 |
| `34:56` / `12:34` (5-ch) | **104** 285 (289) | **76** 212 | **64** 175 (207 vs 207 on 454 — exact fit) |
| `100.00` (6-ch) | **76** 251 | **76** 251 | **52** 169 (174) |
| `1:00:04` | **76+52** 262 | **76+52** 262 | **44+34** ≈152 |
| `12:34:56` | **76+52** 293 | **76+52** 293 (1px margin @390) | **44+34** ≈172 (360 bucket borderline) |

Notes:

- Today's layout-4 renders all of these at 64 or below; every cell above is at
  least one ladder step larger, most are two or three.
- The correction to the #47 planning numbers: the 76+52 pair for `1:00:04` is
  **262px** @390 (the oft-quoted 293 is the `12:34:56` case) — measured from
  the atlases, which makes the N/S budgets comfortable rather than tight.
- Two knife-edge fits are accepted and must be re-checked whenever fonts
  regenerate: 5-char at 64 on the 454 bucket (207 ≤ 207), and the projected
  `12:`+`34:56` 44+34 pair on the 360 bucket. If the generated `value44` atlas
  misses on 360, the 12-hour pose alone degrades to whole-shrink there — an
  accepted edge case (sub-13-hour activities on one bucket).
- Execution adds a small width-check step (compute pair widths from the
  generated `.fnt`s against the budgets, per bucket) so these fits are verified
  mechanically, not eyeballed.

## Decorations (per theme × mode)

The 5-field precedent — decoration draws first and sits *behind* the digits —
carries over. Two elements can't just sit behind and are gated off for
layout 4 (both draws already receive `layout`):

- **Blips:** `blipCy(4)` changes 205 → **0** (none drawn in layout 4). The
  midline band they occupied is now E/W territory, and the worst-case centre
  gap (10px) can't hold their 44px extent. Affects Cockpit + Bridge, both
  modes.
- **Bridge `><` reticle** (x 140–250, y 173–217): sits directly under E/W's
  inner digits at typical poses; skip it when `layout == 4`.

Kept as-is, drawn behind, confirmed in the sim pass: Cockpit rim / corner
brackets / scan line (the scan line crosses E/W ink exactly as it crosses the
5-field hero today), Bridge octagon + console bars (bars underlay N's
midsection and the S label band), Bulkhead stripes (E/W values overlay them
like 5-field corners do), Phosphor watermark.

## Labels

`showLabels` (default off) draws each label above its value, as today. E/W
labels centre over their budget midpoints (x 101 / 289) at baseline 160, S at
(195, 254). N's label at (195, 70) sits in the Cockpit/Bridge title band when
labels are on — the same collision class the 3-field preset ships today
(label baseY 70, titles 58/62); accept, or nudge during sim tuning if it reads
worse at 104pt.

## Verification

- `monkeyc -w` clean on fr70 / fr265s / fr265 / fr965 after every task.
- `python3 tools/check_font_metrics.py` green (with the value44 row added).
- Mechanical width check of the fit matrix against generated atlases.
- Simulator: all 4 themes × dark/light at layout 4, against **wide poses** —
  `100.00`, `1:00:04`, `12:34:56`, and a typical pose — via forced strings in a
  throwaway working copy (never committed). Confirm: no clipping at the round
  edge, no decoration reading as part of a glyph, labels legible when enabled,
  and which ladder cut each pose lands on matches the fit matrix.
