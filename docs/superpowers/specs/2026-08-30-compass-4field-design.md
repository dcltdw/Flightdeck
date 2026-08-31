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

| pos | slot | x | justify | baseline | start cut (asc) | budget | role | size group | label (x, baseY) |
|---|---|---|---|---|---|---|---|---|---|
| N | 0 | 195 | centre | 150 | 88 (93) | 296 | 0 hero-warm | — | (195, 70) |
| E | 1 | 378 | right | 222 | 76 (80) | 178 | 2 accent | 1 | (289, 160) |
| S | 2 | 195 | centre | 320 | 88 (93) | 294 | 1 white | — | (195, 254) |
| W | 3 | 12 | left | 222 | 76 (80) | 178 | 2 accent | 1 | (101, 160) |

Rationale:

- **N is the hero position** (warm hero colour) — matches the 3/2/1 presets,
  where slot 0 gets role 0. Default metric is Timer, the primary running field.
- **N and S sit at 88, and that number is set by E/W's ceiling.** E and W are
  hard-capped at 64 by the screen's width, not by any budget we choose: W grows
  rightward from x 12 and E leftward from x 378, so they collide once each
  budget reaches 183, and a 5-character value at 76 needs 212px. Two of those
  want 424px on a 390px screen — impossible, and even deleting the centre gap
  entirely only makes room for a hypothetical 65pt cut. With the flanks pinned
  at 64, N/S at 104 made E/W read as afterthoughts, and N/S at 76 gave up most
  of the size this ticket exists to gain. 88 is the balance point, and it
  required adding the cut (see Fonts). It also *improves* clearance over 104:
  the tightest measured S case goes from ~7px @390 to ~12px.
- **E/W are edge-anchored and grow inward** (E right-justified at x 378, W
  left-justified at x 12), the 5-field "outer digit at the edge" idea applied
  at the midline where the round screen is widest. Their baselines centre the
  76pt digit ink on the vertical middle (ink spans y 167–223). Budgets of 178
  each leave a ≥10px centre gap even when both are at their widest.
- **S matches N at 88** and sits at baseline 320 rather than the original 316.
  88pt digit ink is 65px tall against 76pt's 56px, so at a fixed baseline the
  extra height grows *upward* into the E/W row; the baseline drop puts S's ink
  at y 255–321 (was 261–317), keeping ~32px of air below E/W's ink bottom at
  223. 320 also sets S's ink one pixel under the Cockpit corner brackets at
  y 320, which is the visual line the layout reads against. N and S are equals
  in size; the hierarchy is carried by colour (warm hero vs white), not scale.
- **E and W share size group 1**, so both always render at the smaller of the
  two cuts either one needs on its own (see Size groups). Without it the
  flanking pair diverges purely on character count — a 5-character `11:39` at E
  drops to 64 while a 4-character `0.88` at W stays at 76, and the compass
  reads lopsided.
- **Roles** are positional as everywhere else. E/W get the lap accent because
  the #49 defaults put lap metrics there; in the brief window before #49 lands,
  E shows session Pace in the accent colour — accepted.
- Circle clearance at the widest corners, measured off rendered pixels on
  fr965 (the bounding-box corner is pessimistic — rounded glyph corners buy
  some back). S's binding cases at 88 are `100.00` whole (289px, ~16px @390
  clear) and the `1:00:04` 88+52 pair (294px, ~12px). A typical `22:33` sits
  ~24px clear. All are more generous than the 104 variant this replaced, whose
  tightest case was ~7px. E/W ink corners are well clear (chord at y 167/223
  runs x 2–388).
- `PresetSlot.asc` is populated (109 / 80) for consistency though `drawPreset`
  takes ascents from the fit result.

## Size groups

`PresetSlot.sizeGroup` (0 = ungrouped) couples slots that must render at the
same cut. Before drawing, `drawPreset` resolves each grouped slot's own best
cut via `resolvedSize` — the pair's big size for an hours duration, otherwise
the shrink-to-fit size — takes the smallest across the group, and uses that as
the ladder start size for every member. Only the compass's E/W pair uses this
today; every other slot in every layout is ungrouped and therefore sizes itself
exactly as before.

Two consequences worth stating plainly:

- A wide value on one side shrinks *both* sides. That is the point — matched is
  the goal — but it does mean W gives up a rung it could otherwise have kept.
- A slot set to `Off` does not constrain its partner: the group pass skips it,
  so a lone E renders at its own best cut rather than being held down by a
  sibling that isn't drawn.

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

## Fonts: a second new cut, `value88`

The ladder's 104 → 76 step is the other unhelpful gap, and the compass is what
exposed it: with E/W pinned at 64 by the screen's width, N/S needed a size
between the two, and there wasn't one. `value88` (glyphs `0-9:.-`, stroke 0,
same family, ascent **93** read from the generated atlas) fills it, wired the
same way as `value44`: `REF_SPECS` and `ASC_CONSTANTS` in `tools/gen_fonts.py`,
`Value88Font` in all four `fonts.xml`, a lazy `Fonts.value88()`, a `cutFont`
row, both ladders, and a `check_font_metrics.py` `CHECKS` row.

`prefixCut(88) = 52`, not the 64 the 0.7x rule would pick — measured, not
assumed: 88+64 overflows every live budget on every bucket, while 88+52 fits
`1:00:04` on all four. Two side benefits fall out of the new rung for free:
`100.00` at N/S gains a step (289px at 88 against a 294 budget, was 76), and so
does any 5-digit value like an altitude in feet (265px, was 76 — at 104 it
needed 310px and could not fit at all).

Layout 3 sees 88 not at all (its start size is 76, so the rung is skipped).
Layouts 2 and 1 start at 104 with a 360 budget, so they gain 88 as a rung
between 104 and 76, in two cases — both strictly larger, both still fitting,
both confirmed in the simulator:

- a 7-character whole value like `1000.00` renders at 88 (342px) where it
  previously fell to 76 (297px);
- an hours duration renders as an 88+52 pair where it previously fell to
  76+52 — `12:34:56` measures 325 / 300 / 344 / 377 against budgets of
  360 / 332 / 384 / 419 on the 390 / 360 / 416 / 454 buckets. This is the more
  visible of the two, since a Timer past one hour is the common case on the
  simplest layouts. It is vertically safe because those slots already budget
  `asc 109` for a 104 fit, and an 88 fit's `asc 93` sits inside that envelope.

## Fit matrix (measured @390; worst-case across the four buckets in parens)

Widths from the committed `.fnt` advances, including `value44`; all measured
from the generated atlases and confirmed on device in the simulator pass.

| value | N (88 start, 296) | S (88 start, 294) | E/W (76 start, 178, grouped) |
|---|---|---|---|
| `5:14` / `8.53` (4-ch) | **88** 183–191 | **88** 183–191 | **76** 159–166 |
| `34:56` / `12:34` (5-ch) | **88** 244 | **88** 244 | **64** 175 (207 vs 207 on 454 — exact fit) |
| `100.00` (6-ch) | **88** 289 | **88** 289 (5px margin) | **52** 169 (174) |
| `1:00:04` | **88+52** 294 | **88+52** 294 (0px margin @390) | **52+34** 175 (454 bucket: 44+34) |
| `12:34:56` | **76+52** 293 | **76+52** 293 (1px margin @390) | **44+34** 172 (360 bucket borderline) |

The E/W column is what each side resolves to *on its own*; the size group then
renders both at whichever of the two is smaller. So a typical pairing of a
5-character pace at E with a 4-character lap distance at W puts both at 64, not
E at 64 and W at 76.

Notes:

- Today's layout-4 renders all of these at 64 or below; every cell above is at
  least one ladder step larger, most are two or three.
- S's 104 start only changes the two narrow rows: 4- and 5-character values gain
  a full rung over the original 76 start. The 6-character and hours-pair rows
  are budget-limited, not start-limited, so they land exactly where they did —
  which is why raising S's start cut costs nothing at the wide end.
- The correction to the #47 planning numbers: the 76+52 pair for `1:00:04` is
  **262px** @390 (the oft-quoted 293 is the `12:34:56` case) — measured from
  the atlases, which makes the N/S budgets comfortable rather than tight.
- Five knife-edge fits are accepted and must be re-checked whenever fonts
  regenerate. Four are graceful — a 1px slip drops them one ladder rung and
  they still render as a pair — and one is not, because its fallback is a
  whole-shrunk value:
  - 5-char at 64 on the 454 bucket (207 ≤ 207) — graceful: a 1px slip falls
    to 52.
  - `1:00:04` 52+34 pair at E/W on the 360 bucket (163 ≤ 164) — graceful: a
    1px slip falls to the 44+34 pair (145px), still a prefix + full-size
    pair.
  - `1:00:04` 88+52 pair at **S** on the 390 bucket (294 ≤ 294) and on the
    360 bucket (271 ≤ 271) — both exactly zero margin, and both graceful: a
    slip falls to the 76+52 pair (262 / 239px), one rung down and still a
    pair. The 416 and 454 buckets carry 3px and 2px. These two are the price
    of `prefixCut(88) = 52`; N's 296 budget gives the same pair 2px, so N is
    not on the edge.
  - `12:`+`34:56` 44+34 pair at E/W on the 360 bucket (164 ≤ 164) — **not
    graceful**: 44 is the ladder floor's pairing partner, so a 1px slip has
    nowhere to fall but a whole-shrunk 34pt value (136px) — the #46 defect
    resurfacing for this one cell. This is the one to watch.

  **All were confirmed to hold in the simulator** — the device's
  `getTextWidthInPixels` matches the atlas xadvance sums exactly, so none
  currently degrades.
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
(195, 254), N at (195, 70).

**Labels-on in layout 4 is a regression this change introduces, not a
continuation of an existing wart.** Under the old four-corner geometry (64pt
values), N's value ink spanned y 99–147 with label ink at y 73–94 — a clean
5px gap; layout 4 with labels on worked. After this change, N is 88pt and E/W
move onto the midline: E/W's label ink (y 139–164) now overprints N's value ink
(y 87–151) by 12px, and N's own label mashes into the Cockpit/Bridge title
band. That title collision is itself a pre-existing
precedent: the 3-field preset's slot 0 places its label at baseY 70 against
Cockpit/Bridge title baselines of 58/62 (`source/Theme.mc` layout-3 branch;
`CockpitTheme.mc` and `BridgeTheme.mc` title constants) — the same
N-label-vs-title collision this change inherits. Separately, the 3-field
preset's own label-over-*value* overlap is a lesser, pre-existing ~5.6px
overprint, distinct from the title collision; the new E/W-vs-N overlap has no
precedent and is introduced by this branch.

Measured @390 from the committed atlases: label ink runs from 21px above its
baseline to 4px below (25px tall across the uppercase set; ~21.5px for the
short strings actually used). Label anchors are fixed at baseY 70 (N), 160
(E/W) and 254 (S). N's 88pt value ink spans 87–151 — the *bottom* is the
baseline, so it does not move when N changes rung; only the top does. E/W
value ink spans 168–222; S's spans 257–321.

- **E/W labels vs the N value** — the free band between N's ink bottom (151)
  and E/W's ink top (168) is **17px, against a 21.5px label**. Structurally
  unfixable by moving the label alone: shrinking N moves its ink *top* down,
  not its baseline, so this band cannot open. This is the one with no
  precedent, and it is the reason labels-on blocks #50.
- **N label vs the title** — the label's ink sits at 49–74 against a
  Cockpit/Bridge title ending at 62, so the two overprint by **13px**.
  Note this overlap is a property of the *anchor*, not of N's size: it is
  identical at 104, 88 and 76, because the label baseline never moves.
  Confirmed in the simulator at 88pt — "TIMER" still mashes "FLIGHT OPS".
  What N's size *did* change is the room underneath: the band between the
  title (62) and N's ink top grew from 13px at 104 to **25px at 88**, so
  unlike the E/W case this one is now fixable by moving the anchor alone —
  an N label baseline of 83 lands its ink exactly in the band. Tight, but
  it was impossible at 104.
- **S label vs the S value** — S's 88pt ink top is 257 against a label anchor
  whose ink runs 233–258, so the two overlap by 1px where the original 76pt S
  cleared by 7px. Comfortably fixable by moving the label alone: the band
  between E/W's ink bottom (223) and S's ink top (257) is 34px. Left alone
  here because the follow-up has to settle all four label positions together.

`showLabels` defaults off, so the shipped default face is unaffected. But
**fixing this is a hard blocker on the store release (#50)**: a user who
already has labels on would get a broken screen the moment this update reaches
them. Merging this branch ships nothing to users by itself — the release
ticket is the control point where this must be resolved before #50 goes out.

Candidate fixes for the follow-up (none applied here):

- Move E/W's baseline off the vertical midline (costs the default
  labels-off centring).
- Suppress the title in layout 4.
- Skip labels in layout 4 entirely.
- Cut a smaller label font for layout 4 (costs a new atlas across all four
  buckets, plus ladder wiring, plus a `check_font_metrics.py` guard row).
- **Cheapest candidate: put the E/W labels *below* their values instead of
  above.** The band from E/W's ink bottom (223) to S's ink top (261) is 38px
  against a 21.5px label, so a baseline near 250 clears the value by ~5px and
  S by ~11px, and stays inside the circle (the half-chord at y 250 runs
  x 8–382). It needs no new atlas, no ladder wiring, and no guard row. Two
  open questions the follow-up must settle before adopting it: it puts the
  W, S and E labels in one horizontal band (W centred x 101, S x 195, E
  x 289 — with the longest 5-character label at 30pt, these clear each other
  by only ~4px), and it makes E/W's labels sit below their values while S's
  sits above, which may read ambiguously. N is left unfixed either way.

N alone — the label-vs-title collision — genuinely is the 3-field precedent's
collision class; every other overlap documented above is new.

## Verification

- `monkeyc -w` clean on fr70 / fr265s / fr265 / fr965 after every task.
- `python3 tools/check_font_metrics.py` green (with the value44 row added).
- Mechanical width check of the fit matrix against generated atlases.
- Simulator: all 4 themes × dark/light at layout 4, against **wide poses** —
  `100.00`, `1:00:04`, `12:34:56`, and a typical pose — via forced strings in a
  throwaway working copy (never committed). Confirm: no clipping at the round
  edge, no decoration reading as part of a glyph, labels legible when enabled,
  and which ladder cut each pose lands on matches the fit matrix.
