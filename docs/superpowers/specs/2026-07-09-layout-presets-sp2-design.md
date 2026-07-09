# Layout presets + bigger fonts — SP2 — design

**Date:** 2026-07-09
**Status:** approved (brainstorm)

## Why

SP1 made the five fields configurable but left them at today's small sizes
(value ≈ 34 px ≈ system `FONT_TINY`; labels off by default). SP2 is the actual
legibility payoff: **layout presets that show fewer, bigger fields.** A new
`Layout` setting picks how many fields are shown (5/4/3/2/1); fewer fields →
larger value fonts.

This is the second (final) sub-project of the configurable-fields feature.
**When SP2 merges, the feature is complete and a store release is cut** (with
refreshed screenshots + description — see [[screenshots-before-release]]). SP1's
bare-small-values intermediate is only unblocked here.

## Locked decisions (from brainstorm)

- **Preset set:** 5 / 4 / 3 / 2 / 1 fields (a `Layout` list setting, default 5).
- **Shared slots, first K:** the active preset shows the first K of the five SP1
  slots (`slot0..slot4`); slot0 is always the primary. Reducing the count drops
  from the end (slot4 first). Users' slot metric choices persist across presets.
- **Geometry ownership — hybrid:** the **5-field preset keeps each theme's
  existing tuned `buildLayout` table** unchanged; the **4/3/2/1 presets use one
  shared base-geometry table each** (positions + target size + palette role +
  slot width budget), the same for all themes.
- **Decorations fixed:** `decorate()` draws identically in every preset (screen
  atmosphere/framing). Validate each theme×preset in the sim; only tune a
  specific combo if it genuinely looks orphaned.
- **Custom fonts** (regenerate bigger via `gen_fonts.py`), not system fonts.
- **Positional colour** preserved: slot0/primary = warm-white, upper values
  white, lower values the theme accent.
- **Fixed per-preset target size WITH universal auto-shrink** (below).

## Value sizing — fixed target + auto-shrink

Each preset defines a **target value size** (@390 reference, scaled per bucket):

| Preset | Positions (slot → place) | Target value size @390 |
|---|---|---|
| **5** | slot0=centre, 1=TL, 2=TR, 3=BL, 4=BR | 34 (centre 60) — *unchanged* |
| **4** (2×2) | slot0=TL, 1=TR, 2=BL, 3=BR | 52 |
| **3** (stack) | slot0=top, 1=mid, 2=bottom | 76 |
| **2** (stack) | slot0=top, 1=bottom | 104 |
| **1** | slot0=centre | 104 (single-metric layout; width-limited to ≈ the 2-field size) |

**Auto-shrink (always on):** a value is drawn at the **largest generated value
size ≤ its slot's target whose measured width fits the slot's width budget**. The
generated value-size ladder is `{34, 52, 76, 104}` (plus the 60 hero for the
5-field centre). At draw time, per slot: try the target size; if
`dc.getTextWidthInPixels(value, font) > slotWidth`, step down the ladder until it
fits. So a value **never overflows** — e.g. a 7-char elapsed time (`1:04:23`) in a
1-field slot (target 104) steps down to 76 to fit. Short values are **not** grown
(shrink-only, per the "fixed" choice). The ladder floor is 34 (5-field corners
already fit at 34). The 5-field **centre** keeps its own 60 px hero font and is
not shrunk (a 7-char time fits at 60); auto-shrink applies to the value-font
slots.

Each preset's shared table therefore carries, per shown slot: `(x, y baseline,
palette role, targetSizeId, slotWidthBudget, labelX, labelY)`. Exact px are tuned
in the simulator during implementation (like the SP1 face polish); the numbers
above are the design targets. Values stay edge-/centre-justified per position as
today.

## Fonts

Add value sizes **52, 76, 104** to `gen_fonts.py` `REF_SPECS` (today's 34 and 60
stay), regenerated across the four buckets (390/360/416/454). Value glyph set is
`DIGITS + ":.-"` (13 chars) — atlases are small. **Bulkhead** renders values in a
bold cut, so generate **bold** 52/76/104 too (`valueb` family) to keep its
identity in presets; otherwise Bulkhead would fall back to the regular cut in
sparse presets.

**Loading:** the value-size ladder is small; load the ladder the active preset
needs so auto-shrink can pick from it (extend the existing lazy-load pattern in
`Fonts`; today Wall's bold loads lazily). Confirm total loaded fonts stay within
the 256 KB data-field memory budget during implementation; the `.iq` package
grows by ~24 small atlases (regular + Bulkhead-bold × 3 sizes × 4 buckets).

## Labels

Reuse the existing 30 px label font. SP2 lifts the SP1 "centre never labeled"
limit: **every shown slot** (including the single/centre) can display its label
when `showLabels` is on, positioned per preset from the shared table's
`labelX/labelY`. A 30 px label under a 104 px value is small but legible; bump it
in the sim only if needed. Labels remain **default off**.

## Colour (positional, per preset)

Per shared table, each slot carries a palette role: slot0/primary → `hero`
(warm-white); upper-row values → `sval` (white); lower-row values → `lap`
(accent). Concretely: 4-field top row (slot0/1) white, bottom row (slot2/3)
accent; 3-field top warm / mid white / bottom accent; 2-field top warm / bottom
accent; 1-field warm. No new colour settings.

## Architecture

- **Setting:** add `layout` (list 5/4/3/2/1 → a preset id; default = 5) to
  `settings.xml` / `properties.xml` / `strings.xml`.
- **View:** `FlightdeckView.readSettings()` reads `layout`; `onUpdate` passes it
  into `draw()`.
- **Base `Theme`:** owns the four shared preset tables (4/3/2/1). `draw(dc, m,
  fonts, light, slots, showLabels, layout)` selects geometry: if `layout == 5`,
  use the theme's existing `buildLayout` table (unchanged path); else use the
  shared table for that preset. The slot loop, Off-blanking, positional colour,
  and label logic are shared; add the auto-shrink font pick.
- **Themes** (`source/themes/*`): `buildLayout` (the 5-field table) and
  `decorate()` are **unchanged**. `ThemeRegistry` unchanged.
- **Fonts:** `Fonts` gains accessors for the value-size ladder (lazy).

## Global constraints

- `monkeyc -w` clean on fr70/fr265s/fr265/fr965.
- **No new manifest permissions** (unchanged from SP1 — presets add none).
- Stay within the 256 KB data-field memory budget (verify loaded-font total).
- **This sub-project unblocks the release**: after SP2 merges, cut the store
  release — regenerate `store/screenshots/` + hero and the `description.txt`
  "What's changed" entry FIRST ([[screenshots-before-release]]), then
  `tools/release.sh` (which also verifies the signing key + gates on the
  CHANGELOG/description entries).
- Repo conventions: branch → PR → wait; board Todo→In Progress→Done; PR bodies
  per `universal.md` (incl. `Provenance`); commits stamped `Co-Authored-By`.

## Verification

1. `monkeyc -w` clean across all four buckets after the font regen + code.
2. Simulator, per theme × preset: fields render at the right positions/sizes/
   colours; decorations look acceptable (note any orphaned-framing combo);
   labels on/off; **auto-shrink** confirmed with a long elapsed time (`1:04:23`)
   in a 1-field slot (steps down, no clip) and a short value (no growth).
3. Confirm the manifest still declares zero permissions and the loaded-font
   memory is within budget.

## Out of scope

Per-preset decoration adaptation (decorations stay fixed), growing short values
(auto-shrink is shrink-only), and any new metrics (SP1's set stands).
