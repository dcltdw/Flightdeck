# Per-Layout Metric Slots + Defaults (and default layout 4) — Design

**Status:** designed in an autonomous design session (2026-08-30) against
issue #49, on top of the merged #47 compass reformat (`d6958d5`). The #49
decisions of 2026-08-28 are treated as fixed inputs, not revisited here.

## Goal

Give each of the five layout presets its own independent metric slots and
defaults, rename the positional `slot0..slot4` properties to per-layout
self-describing ids, and flip the shipped `layout` default from 5 to 4.
Issue: #49.

## Fixed decisions (2026-08-28, from #49 — not relitigated)

- Defaults across layouts are independent; a separate property set per layout.
- All five layouts get their own set, including 2- and 1-field; nothing
  inherits.
- The positional `slot0..slot4` properties are renamed to per-layout,
  self-describing ids.
- The shipped `layout` default changes 5 → 4.
- **No migration shim.** The old properties are deleted outright; existing
  users' slot customisations reset to the new defaults. Accepted, and must be
  documented (see Migration).

## Scope

- **In:** `resources/settings/properties.xml` (15 new slot properties, 5 old
  ones deleted, `layout` default 5 → 4); `resources/settings/settings.xml`
  (15 pickers, reordered and regrouped — newly emitted by a generator, see
  below); `resources/strings/strings.xml` (15 new picker titles, 5 old ones
  deleted); `source/FlightdeckView.mc` (read the active layout's property
  set); comment-only updates in `source/Metrics.mc` and `source/Theme.mc`;
  a new `tools/gen_settings.py`; `CHANGELOG.md` `[Unreleased]` bullets;
  a CLAUDE.md line for the new generator.
- **Out:** any drawing/geometry change (`Theme.mc` logic and every theme
  subclass are untouched); the labels-on-in-layout-4 fix (stays a #50 gate —
  see Labels); `store/description.txt` (its "What's changed" entry belongs to
  the release ticket #50 — this spec drafts the wording); fonts, manifest,
  permissions.

## Property scheme (15 slot properties)

Adopts the ids proposed in #49 unchanged — reviewed here and found sound: the
prefix carries the layout, the suffix carries the position in that layout's
own vocabulary (compass points for 4-field per the #47 spec, corners for
5-field, rows for 3/2).

| layout | properties (in slot-index order) | defaults |
|---|---|---|
| 5-field | `l5_c`, `l5_tl`, `l5_tr`, `l5_bl`, `l5_br` | `1` Timer, `6` Pace, `3` Dist, `7` LPace, `5` LTime |
| 4-field | `l4_n`, `l4_e`, `l4_s`, `l4_w` | `1` Timer, `7` LPace, `3` Dist, `4` LDist |
| 3-field | `l3_top`, `l3_mid`, `l3_bot` | `1` Timer, `7` LPace, `3` Dist |
| 2-field | `l2_top`, `l2_bot` | `1` Timer, `7` LPace |
| 1-field | `l1_c` | `1` Timer |

Notes:

- **Slot-index order is load-bearing.** Each row lists the properties in the
  order the drawing code indexes them: layout 5's `drawGrid` reads
  `slots[0]`=centre, `[1]`=top-left, `[2]`=top-right, `[3]`=bottom-left,
  `[4]`=bottom-right; layout 4's `presetSlots` maps slot 0→N, 1→E, 2→S, 3→W
  (the #47 spec's "Slot geometry" table); layouts 3/2/1 are top-to-bottom.
- The 4-field defaults land the lap pair (LPace/LDist) on E/W, which is why
  the #47 spec gave E/W the lap accent role — colour and content now agree.
- 5-field defaults are today's shipped values, unchanged in meaning.
- `layout` keeps its id and values; only its default flips to `4`. `theme`,
  `mode`, `showLabels` are untouched.
- Metric id vocabulary (0=Off … 18=Alt, with 13 unused) is unchanged and
  identical across all 15 pickers.

## Read path: the view selects, the themes never know

`FlightdeckView.readSettings` reads `layout` first, then reads **only the
active layout's** properties into `_slots`, in the slot-index order above —
so `_slots` becomes a variable-length array (5/4/3/2/1 entries) of "the
active layout's metric ids, positionally ordered".

That is the entire source-code change. `Theme.draw`, `drawGrid`,
`drawPreset`, `PresetSlot.slot` and every theme subclass already index into
whatever array they are handed, and no layout branch indexes past its own
count — so they compile and behave unchanged with the shorter arrays.
Rejected alternative: passing all 15 values (or a dictionary) down into
`Theme` and selecting there — it touches every draw signature for zero
benefit, and spreads the property ids across two files.

Details:

- `_slots`' initial value becomes `[1, 7, 3, 4]` and `_layout`'s becomes `4`,
  matching the new shipped defaults (they are only ever visible for the
  frames before the first `compute`).
- The `numProp` fallback defaults passed at each read site must match the
  defaults table above (they cover a stored value of the wrong type; fresh
  installs get the `properties.xml` defaults).
- `readSettings` already runs every `compute` (~1/sec); reading 4–9
  properties per pass instead of today's flat 9 is a wash. A layout change
  from Garmin Connect takes effect on the next compute, exactly as today.
- Comment-only updates: `Metrics.mc`'s "Default slot map" header comment
  (describes the old shared defaults) and `PresetSlot.slot`'s
  "config slot index 0..4" comment (now "index into the active layout's
  slots array").

## Settings screen (the 15-picker UX)

Connect IQ app settings cannot show or hide entries by selected layout and
have no section-header element, so all 15 pickers appear at once in Garmin
Connect and the grouping must be carried entirely by **order and titles**.

**Order:** global settings first, then the per-layout groups, with the
shipped-default layout's group first and the rest by descending field count:

1. Theme, Mode, Layout, Show labels
2. 4-field group (N, E, S, W)
3. 5-field group (C, TL, TR, BL, BR)
4. 3-field group, 2-field group, 1-field group

Rationale: `Layout` and `Show labels` move up with Theme/Mode so every
global setting precedes the picker wall, and a user who opens settings sees
the pickers for the screen they actually have (fresh installs: 4-field)
immediately after choosing a layout. The `layout` picker's own entry order
stays 5/4/3/2/1 (numeric, predictable); its default merely becomes 4.

**Titles** (new string ids replacing `SettingSlot0..4`), using a `·`
separator and the on-screen position in parentheses where the compass
vocabulary needs translating:

| string id | title |
|---|---|
| `SettingL4N` / `E` / `S` / `W` | `4 fields · North (top)` / `East (right)` / `South (bottom)` / `West (left)` |
| `SettingL5C` / `TL` / `TR` / `BL` / `BR` | `5 fields · Center` / `Top left` / `Top right` / `Bottom left` / `Bottom right` |
| `SettingL3Top` / `Mid` / `Bot` | `3 fields · Top` / `Middle` / `Bottom` |
| `SettingL2Top` / `Bot` | `2 fields · Top` / `Bottom` |
| `SettingL1C` | `1 field · Center` |

These titles render only in the Garmin Connect app (never through the
watch's bitmap fonts), and `strings.xml` is UTF-8, so `·` is safe. "Center"
follows the existing settings strings' spelling.

## `tools/gen_settings.py`: generate the picker wall

`settings.xml` grows from 5 copies of the 18-entry metric list to 15 —
roughly 320 lines of pure repetition where adding one metric later means 15
hand-edits that can silently drift. Following the repo's
reproducible-generator pattern (`gen_fonts.py`, `gen_icon.py`), a new
**`tools/gen_settings.py`** (pure stdlib, deterministic, byte-stable output)
emits `resources/settings/settings.xml` from two tables in the script: the
metric list (id → string id) and the setting rows (property id → title
string id, in the order above). `properties.xml` and `strings.xml` stay
hand-maintained — they are short and hold real content (defaults, titles),
and the defaults table deliberately lives in exactly two places
(`properties.xml` + the `numProp` fallbacks), both pinned by this spec.
CLAUDE.md's tools list gains the generator. Rejected alternative:
hand-writing the XML — accepted at 5 copies, but 15 crosses the line, and
the generator is ~70 lines written once.

## Migration: existing users' fields reset (no shim — pinned)

Deleting `slot0..slot4` orphans the stored values: on update the app reads
the new ids, finds nothing, and falls back to the new defaults. Anyone who
customised fields loses that customisation. A stored `layout` value, by
contrast, survives the update and still wins over the new default —
verified in the simulator by installing the pre-change build, then updating
over its settings store — so upgraders keep the layout they had and only
fresh installs land on the 4-field compass. Accepted by decision; the
documentation obligations are part of this change's acceptance:

- **PR body:** stated in `Operational impact` (users re-add nothing — the
  field set is unchanged — but customised metrics reset to defaults).
- **`CHANGELOG.md` `[Unreleased]`:** bullets for (a) per-layout independent
  fields, (b) the new default 4-field layout, and (c) the plain-language
  reset warning.
- **Store copy:** the "What's changed" entry ships with the release ticket
  #50, per #49. Draft wording for #50 to carry (respecting the no-`>` rule):
  *"Each layout now remembers its own fields — changing the 3-field screen
  no longer touches the 5-field one — and new installs start on the big
  4-field compass layout. One-time note: this update resets any custom
  field choices to the new defaults; set them again in Garmin Connect."*
- `layout` and `showLabels` keep their ids, so any existing installation
  keeps its stored layout and label choice; only the 5 slot values reset.

## Labels-on in layout 4: unchanged calculus, still a #50 gate

#47 documented that labels-on in layout 4 is broken (E/W's labels overprint
N's value ink by 12px) and made fixing it a hard blocker on the store
release #50. **#49 does not change that calculus, and this design leaves the
fix out of scope:**

- `showLabels` still defaults **off**, so the new fresh-install default —
  layout 4, labels off — renders clean. Flipping the layout default does not
  put any defaulted user on a broken face.
- A user can only have labels on by having saved settings in Garmin Connect,
  and a save persists the whole settings sheet including `layout` — so
  labels-on users keep their stored layout and are exactly as exposed after
  #49 as they were the day #47 merged: broken only if they also chose
  layout 4. #49 widens nothing.
- The fix itself (the #47 spec lists candidates, cheapest being E/W labels
  below their values) has open questions that must be settled together for
  all four positions — a separate single-purpose change, gating #50, not
  this PR.

## Acceptance (from #49, plus this design's additions)

- A fresh install lands on the 4-field compass showing Timer / LPace / Dist
  / LDist, and each layout shows its table defaults, each independently
  configurable.
- Changing one layout's fields leaves every other layout's untouched.
- `Off` (id 0) still blanks a slot in every layout; `showLabels` still works.
- The reset is documented in the PR and `CHANGELOG.md`, with the store
  wording drafted for #50.
- `resources/settings/settings.xml` is byte-identical to a fresh
  `python3 tools/gen_settings.py` run.
- #47 is merged (satisfied — `d6958d5` is on `main`; this branch is cut from
  it).

## Verification

No unit-test framework; the gates are:

- `monkeyc -w` clean on fr70 / fr265s / fr265 / fr965.
- `python3 tools/check_font_metrics.py` stays green (untouched by this
  change, run anyway).
- Regenerating `settings.xml` via the generator is a no-op on the committed
  file.
- Simulator (fr965 primary): fresh-install defaults per layout match the
  table; setting one layout's property (sim settings editor) changes that
  layout only; `Off` blanks; labels-off default face clean in all four
  themes × dark/light.
