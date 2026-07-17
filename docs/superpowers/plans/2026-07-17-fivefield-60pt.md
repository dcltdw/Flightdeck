# 5-Field 60pt Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the 5-field default legible — all five values at 60pt, corners run to the edges with decoration behind the outer digits, durations use a small hours-prefix, per-theme decorations retuned.

**Architecture:** Only the `Theme.drawGrid` (5-field) path changes. Two new bitmap font cuts (`value60`, `value40`) join the existing family. `drawGrid` renders every field at `value60`; corner values anchor their outer digit on a fixed edge target and grow inward; a two-colon duration splits into a 40pt prefix + 60pt `MM:SS`; a wide non-duration shrinks 60→52→34. Per-theme `decorate()`/palette colours are retuned (both modes). The 4/3/2/1 presets (`drawPreset`) are untouched.

**Tech Stack:** Connect IQ / Monkey C (SDK 9.1.0); custom BMFont bitmap fonts via `tools/gen_fonts.py` (Pillow); Phosphor radar via `tools/gen_phosphor_watermark.sh` (ImageMagick). No unit-test framework — the verification gate is `monkeyc -w` (warnings-as-errors) compiling clean; behaviour is checked in the simulator.

## Global Constraints

- `monkeyc -w` must compile clean on **fr70, fr265s, fr265, fr965** after every task. Build command (from CLAUDE.md), with the real key path substituted:
  ```sh
  SDK="$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.1.0-2026-03-09-6a872a80b"
  export PATH="$(brew --prefix openjdk)/bin:$PATH"
  "$SDK/bin/monkeyc" -f monkey.jungle -o /tmp/check.prg -y <developer_key> -d <device> -w
  ```
  A clean build prints `BUILD SUCCESSFUL`.
- **No new manifest permissions** — the app stays "Requests no permissions".
- All geometry expressed at the **@390** reference and scaled at draw via `scN(v,s)` / `scP(v,s)` / `rnd(v)` (existing helpers in `Theme.mc`; `s = dc.getWidth()/390.0`).
- **5-field only** (`drawGrid`). Do not touch `drawPreset`, `presetSlots`, `fitValueFont`, or the 4/3/2/1 behaviour.
- Never commit the developer key or `.prg`/`.iq` artifacts.

## File Structure

- `tools/gen_fonts.py` — add `value60`, `value40` to `REF_SPECS` (regenerates atlases).
- `resources-{360,390,416,454}x…/fonts/*.fnt|*.png` — regenerated atlases (new `value60.*`, `value40.*`).
- `resources-{360,390,416,454}x…/fonts/fonts.xml` — add `Value60Font`, `Value40Font` ids.
- `source/Theme.mc` — `Fonts` accessors `value60()`/`value40()`; rework `drawGrid` + its corner/duration/shrink helpers. `Fonts` fields, `drawGrid`, and new private helpers are the only touch points; `drawPreset`/`fitValueFont` untouched.
- `source/themes/{Cockpit,Bridge,Wall,Phosphor}Theme.mc` — decoration colour changes (both modes); Bridge `><` colour split.
- `tools/gen_phosphor_watermark.sh` + `resources-*/drawables/*` — Phosphor pip recolour, regenerated.

---

### Task 1: Generate and wire the `value60` + `value40` font cuts

**Files:**
- Modify: `tools/gen_fonts.py` (REF_SPECS list)
- Modify: `resources-360x360/fonts/fonts.xml`, `resources-390x390/fonts/fonts.xml`, `resources-416x416/fonts/fonts.xml`, `resources-454x454/fonts/fonts.xml`
- Modify: `source/Theme.mc` (`Fonts` class)
- Generated: `resources-*/fonts/value60.fnt|png`, `value40.fnt|png` (from gen_fonts)

**Interfaces:**
- Produces: `Fonts.value60() as WatchUi.FontResource` (60pt, glyphs `0-9 : . -`), `Fonts.value40() as WatchUi.FontResource` (40pt). Later tasks call these. `value60`'s @390 ascent is **55** (same 60px Andale as the existing `hero`, whose ascent is 55).

- [ ] **Step 1: Add the two cuts to `gen_fonts.py` REF_SPECS**

In `tools/gen_fonts.py`, in the `REF_SPECS` list, after the `("value64", 64, DIGITS + ":.-", 0),` line add:

```python
    ("value60", 60, DIGITS + ":.-", 0),
    ("value40", 40, DIGITS + ":.-", 0),
```

- [ ] **Step 2: Regenerate the atlases**

Run: `python3 tools/gen_fonts.py`
Expected: prints a `value60 …` and `value40 …` line per bucket; `git status` shows **only new** `value60.*`/`value40.*` files under `resources-*/fonts/` (existing atlases are byte-identical — gen_fonts is deterministic). If any pre-existing atlas shows as modified, stop and investigate.

- [ ] **Step 3: Note the generated ascents**

Run: `grep -h '^common' resources-390x390/fonts/value60.fnt resources-390x390/fonts/value40.fnt`
Expected: `value60` `base=55` (confirm it is 55; if it differs, use the actual value as `VAL60_ASC` in Task 2). Record `value40`'s `base=` as `VAL40_ASC` (≈37) for Task 3.

- [ ] **Step 4: Declare the fonts in each `fonts.xml`**

In **each** of the four `resources-*/fonts/fonts.xml`, add after the `Value64Font` line:

```xml
    <font id="Value60Font" filename="value60.fnt"/>
    <font id="Value40Font" filename="value40.fnt"/>
```

- [ ] **Step 5: Add lazy accessors to the `Fonts` class**

In `source/Theme.mc`, in the `Fonts` class, add fields alongside the other `_v*` fields:

```monkeyc
    private var _v60 as WatchUi.FontResource?;
    private var _v40 as WatchUi.FontResource?;
```

and add accessors alongside `value64()`:

```monkeyc
    function value60() as WatchUi.FontResource { if (_v60 == null) { _v60 = WatchUi.loadResource(Rez.Fonts.Value60Font) as WatchUi.FontResource; } return _v60; }
    function value40() as WatchUi.FontResource { if (_v40 == null) { _v40 = WatchUi.loadResource(Rez.Fonts.Value40Font) as WatchUi.FontResource; } return _v40; }
```

- [ ] **Step 6: Compile-gate all four buckets**

Run the Global-Constraints build for `fr70`, `fr265s`, `fr265`, `fr965`.
Expected: `BUILD SUCCESSFUL` each (this verifies the `Rez.Fonts.Value60Font`/`Value40Font` symbols resolve, i.e. `fonts.xml` is wired correctly, since the accessors reference them).

- [ ] **Step 7: Commit**

```sh
git add tools/gen_fonts.py resources-*/fonts/ source/Theme.mc
git commit -m "feat: generate + wire value60 and value40 font cuts"
```

---

### Task 2: 5-field uniform 60pt + edge-anchored, grow-inward geometry

Renders every 5-field value at `value60`, hero centred, corners anchored so the **outer digit** sits on a fixed edge target and the value grows **inward**. Normal values only — durations and wide-value shrink come in Tasks 3–4. Exact @390 numbers here are **starting values**; Task 7 tunes them in the simulator.

**Files:**
- Modify: `source/Theme.mc` — replace `drawGrid`'s corner block and the `drawCorner` helper.

**Interfaces:**
- Consumes: `Fonts.value60()` (Task 1), `scN`/`scP`/`rnd`/`txt` (existing in `Theme.mc`).
- Produces: `drawGrid` renders 5 fields at 60pt with the new placement. `drawCorner(dc, s, m, id, edgeX, ctr, growRight, baseY, fonts, color)` where `edgeX`/`ctr`/`baseY` are **device px** (already scaled). Tasks 3–4 extend `drawCorner`.

- [ ] **Step 1: Add tunable geometry constants**

In `source/Theme.mc`, in the base `Theme` class (near the top, before `draw`), add:

```monkeyc
    // 5-field geometry @390 — tuned in the simulator (Task 7).
    hidden const GRID_TOP_Y = 120;   // top-row baseline
    hidden const GRID_HERO_Y = 217;  // hero baseline (unchanged)
    hidden const GRID_BOT_Y = 305;   // bottom-row baseline
    hidden const GRID_EDGE_L = 70;   // left outer-digit target x (Cockpit reticle bar)
    hidden const GRID_EDGE_R = 320;  // right outer-digit target x
    hidden const VAL60_ASC = 55;     // value60 @390 ascent
```

- [ ] **Step 2: Rewrite the corner + hero block in `drawGrid`**

In `source/Theme.mc` `drawGrid`, replace the comment + five draw calls (the block from `// Hero is centred` through the `drawCorner(... slots[4] ...)` line) with:

```monkeyc
        // Hero centred at 60pt; corners anchor their outer digit on the edge
        // target and grow inward. value60 uniformly.
        var vf60 = fonts.value60();
        txt(dc, scN(L.ctr, s), scN(GRID_HERO_Y, s), rnd(VAL60_ASC * s), vf60, p.hero, m.format(slots[0]), C);
        drawCorner(dc, s, m, slots[1], scN(GRID_EDGE_L, s), scN(L.ctr, s), true,  scN(GRID_TOP_Y, s), fonts, p.sval);
        drawCorner(dc, s, m, slots[2], scN(GRID_EDGE_R, s), scN(L.ctr, s), false, scN(GRID_TOP_Y, s), fonts, p.sval);
        drawCorner(dc, s, m, slots[3], scN(GRID_EDGE_L, s), scN(L.ctr, s), true,  scN(GRID_BOT_Y, s), fonts, p.lap);
        drawCorner(dc, s, m, slots[4], scN(GRID_EDGE_R, s), scN(L.ctr, s), false, scN(GRID_BOT_Y, s), fonts, p.lap);
```

Note: `slots[0]==0` (hero Off) must still blank — guard it by wrapping the hero `txt` in `if (slots[0] != 0)`. `hf`/`vf` are now unused, so delete their declarations (lines `var vf = L.valFont;` and `var hf = L.heroFont;`) and drop them from the null-guard, leaving `if (lf == null) { return; }`. The old per-value helpers `drawValue`/`drawCorner` are being replaced: `drawCorner` is rewritten in Step 3; `drawValue` (previously used only for the hero) is now unused — if `monkeyc -w` flags it, delete it. `drawLabel` stays (used by the labels block).

- [ ] **Step 3: Replace `drawCorner` with the edge-anchored, grow-inward version**

Replace the whole `drawCorner` function with:

```monkeyc
    // One 5-field corner value. The outer digit is centred on `edgeX`; the value
    // is edge-justified so it grows inward (toward `ctr`). value60 uniformly.
    // (Task 3 adds the hours-prefix for durations; Task 4 adds shrink-to-fit.)
    private function drawCorner(dc as Graphics.Dc, s as Float, m as Metrics, id as Number,
                                edgeX as Number, ctr as Number, growRight as Boolean,
                                baseY as Number, fonts as Fonts, color as Number) as Void {
        if (id == 0) { return; } // Off
        var str = m.format(id);
        var f = fonts.value60();
        var digW = dc.getTextWidthInPixels("0", f);   // one monospace digit, device px
        var anchorX = growRight ? (edgeX - digW / 2.0) : (edgeX + digW / 2.0);
        var just = growRight ? Graphics.TEXT_JUSTIFY_LEFT : Graphics.TEXT_JUSTIFY_RIGHT;
        txt(dc, rnd(anchorX), baseY, rnd(VAL60_ASC * s), f, color, str, just);
    }
```

- [ ] **Step 4: Compile-gate all four buckets**

Run the build for all four devices. Expected: `BUILD SUCCESSFUL` each.

- [ ] **Step 5: Commit**

```sh
git add source/Theme.mc
git commit -m "feat: 5-field uniform 60pt, edge-anchored grow-inward corners"
```

---

### Task 3: Hours-prefix render for durations

A value formatted as `H:MM:SS` (**two colons** — elapsed timer or lap time past an hour; wall clock is one colon and is unaffected) draws its prefix (up to and including the first colon) at `value40`, vertically centred against the `MM:SS` remainder at `value60`, as one group with the same edge anchoring.

**Files:**
- Modify: `source/Theme.mc` — add `isDuration`, `drawDurationGroup`; branch `drawCorner` and the hero draw.

**Interfaces:**
- Consumes: `Fonts.value40()`/`value60()` (Task 1), `VAL60_ASC` (Task 2), `VAL40_ASC` from Task 1 Step 3.
- Produces: `isDuration(str)`, `drawDurationGroup(...)` used by `drawCorner` and the hero.

- [ ] **Step 1: Add `VAL40_ASC` constant**

In the base `Theme` class constants (with `VAL60_ASC`), add (using the `value40.fnt` `base=` recorded in Task 1 Step 3; ≈37):

```monkeyc
    hidden const VAL40_ASC = 37;     // value40 @390 ascent
```

- [ ] **Step 2: Add the duration helpers**

Add to the base `Theme` class:

```monkeyc
    // A duration with an hours part formats as H:MM:SS (two colons); wall clock
    // is H:MM (one). Only two-colon strings get the hours-prefix treatment.
    private function isDuration(str as String) as Boolean {
        var first = str.find(":");
        if (first == null) { return false; }
        return (str.substring(first + 1, str.length()) as String).find(":") != null;
    }

    // Draw a two-colon duration as [40pt prefix][60pt MM:SS], the two vertically
    // centred together (their cap-centres aligned), justified as one group about
    // `anchorX`. `just` selects group left/right/centre. baseY/anchorX are device px.
    private function drawDurationGroup(dc as Graphics.Dc, s as Float, str as String,
                                       anchorX as Number, baseY as Number,
                                       just as Graphics.TextJustification,
                                       fonts as Fonts, color as Number) as Void {
        var first = str.find(":");
        var pre = str.substring(0, first + 1);            // "1:" / "12:"
        var rest = str.substring(first + 1, str.length()); // "MM:SS"
        var fp = fonts.value40();
        var fb = fonts.value60();
        var wp = dc.getTextWidthInPixels(pre, fp);
        var wr = dc.getTextWidthInPixels(rest, fb);
        var total = wp + wr;
        var left;
        if (just == Graphics.TEXT_JUSTIFY_RIGHT) { left = anchorX - total; }
        else if (just == Graphics.TEXT_JUSTIFY_CENTER) { left = anchorX - total / 2.0; }
        else { left = anchorX; }
        // baseY is the 60pt baseline; the 40pt prefix baseline shifts up so the
        // two cap-centres align: delta = (asc60 - asc40)/2, scaled.
        var preBaseY = baseY - rnd(((VAL60_ASC - VAL40_ASC) / 2.0) * s);
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(rnd(left), preBaseY - rnd(VAL40_ASC * s), fp, pre, Graphics.TEXT_JUSTIFY_LEFT);
        dc.drawText(rnd(left + wp), baseY - rnd(VAL60_ASC * s), fb, rest, Graphics.TEXT_JUSTIFY_LEFT);
    }
```

- [ ] **Step 3: Branch the hero for durations**

In `drawGrid`, replace the hero `txt(...)` line from Task 2 with:

```monkeyc
        if (slots[0] != 0) {
            var hstr = m.format(slots[0]);
            if (isDuration(hstr)) {
                drawDurationGroup(dc, s, hstr, scN(L.ctr, s), scN(GRID_HERO_Y, s), C, fonts, p.hero);
            } else {
                txt(dc, scN(L.ctr, s), scN(GRID_HERO_Y, s), rnd(VAL60_ASC * s), fonts.value60(), p.hero, hstr, C);
            }
        }
```

- [ ] **Step 4: Branch `drawCorner` for durations**

In `drawCorner` (Task 2), immediately after `var str = m.format(id);` add:

```monkeyc
        if (isDuration(str)) {
            var groupAnchor = growRight ? (edgeX - dc.getTextWidthInPixels("0", fonts.value60()) / 2.0) : (edgeX + dc.getTextWidthInPixels("0", fonts.value60()) / 2.0);
            var gjust = growRight ? Graphics.TEXT_JUSTIFY_LEFT : Graphics.TEXT_JUSTIFY_RIGHT;
            drawDurationGroup(dc, s, str, rnd(groupAnchor), baseY, gjust, fonts, color);
            return;
        }
```

(The outer digit of a duration is the first prefix digit for a left corner, or the last `MM:SS` digit for a right corner; anchoring the group edge on `edgeX` keeps the outer digit on the reticle bar. Task 7 fine-tunes if needed.)

- [ ] **Step 5: Compile-gate all four buckets.** Expected `BUILD SUCCESSFUL` each.

- [ ] **Step 6: Commit**

```sh
git add source/Theme.mc
git commit -m "feat: hours-prefix render for 5-field durations"
```

---

### Task 4: Shrink-to-fit for wide non-duration values

A non-duration value too wide at 60pt (e.g. distance `100.00`) shrinks 60→52→34 to the largest cut whose rendered width fits its inward budget, so it never clips. Durations (Task 3) are unaffected.

**Files:**
- Modify: `source/Theme.mc` — add `fitGridFont`; use it in the non-duration branch of `drawCorner`.

**Interfaces:**
- Consumes: `Fonts.value60()/value52()/value` (existing), `VAL60_ASC`.
- Produces: `fitGridFont(dc, str, budgetPx, fonts) as Array` → `[font, ascent390]`.

- [ ] **Step 1: Add `fitGridFont`**

Add to the base `Theme` class (separate from `fitValueFont`, which stays for the presets):

```monkeyc
    // 5-field shrink ladder for wide NON-duration values: 60 -> 52 -> 34.
    // Largest cut whose width fits budgetPx; shrink-only. Returns [font, asc390].
    private function fitGridFont(dc as Graphics.Dc, str as String, budgetPx as Number,
                                 fonts as Fonts) as Array {
        var f60 = fonts.value60();
        if (dc.getTextWidthInPixels(str, f60) <= budgetPx) { return [f60, VAL60_ASC]; }
        var f52 = fonts.value52();
        if (dc.getTextWidthInPixels(str, f52) <= budgetPx) { return [f52, 48]; }
        return [fonts.value, 31];
    }
```

- [ ] **Step 2: Use it in `drawCorner`'s non-duration path**

In `drawCorner`, replace the normal-value tail (from `var f = fonts.value60();` to the final `txt(...)`) with:

```monkeyc
        // budget = inward room from the edge anchor to a small centre gap
        var budget = growRight ? (ctr - scN(GRID_GAP, s) - edgeX) : (edgeX - ctr - scN(GRID_GAP, s));
        var fit = fitGridFont(dc, str, budget, fonts);
        var f = fit[0] as WatchUi.FontResource;
        var a = fit[1] as Number;
        var digW = dc.getTextWidthInPixels("0", f);
        var anchorX = growRight ? (edgeX - digW / 2.0) : (edgeX + digW / 2.0);
        var just = growRight ? Graphics.TEXT_JUSTIFY_LEFT : Graphics.TEXT_JUSTIFY_RIGHT;
        txt(dc, rnd(anchorX), baseY, rnd(a * s), f, color, str, just);
```

and add the gap constant to the base `Theme` constants:

```monkeyc
    hidden const GRID_GAP = 14;      // half centre safety gap @390
```

- [ ] **Step 3: Compile-gate all four buckets.** Expected `BUILD SUCCESSFUL` each.

- [ ] **Step 4: Commit**

```sh
git add source/Theme.mc
git commit -m "feat: shrink-to-fit (60->52->34) for wide 5-field non-durations"
```

---

### Task 5: Per-theme decoration colour retuning (both modes)

Colour-only edits from the spec's approved table. These are theme colours, applied in every layout (intended). Exact values below.

**Files:**
- Modify: `source/themes/CockpitTheme.mc`, `source/themes/BridgeTheme.mc`, `source/themes/WallTheme.mc`

**Interfaces:** none (colour literals only).

- [ ] **Step 1: Cockpit**

In `source/themes/CockpitTheme.mc`:
- Palette **dark** title `0x6FAFC2` → `0xA0D8EE`; **light** title `0x1E7088` → `0x0D4655` (the last Palette arg on each `return new Palette(...)` line).
- `decorate`: `reticle = light ? 0x1E7088 : 0x3fb6d6` → `light ? 0x8FB8C4 : 0x2A7085` (change **only** `reticle`, not the `scanBrt` line that also uses `0x1E7088`).
- `drawBlips(...)` colour `light ? 0xB5530E : 0xFF8C2B` → `light ? 0xC42E9A : 0xE64DBF`.

- [ ] **Step 2: Bridge**

In `source/themes/BridgeTheme.mc`:
- Palette **dark** title `0xC8554A` → `0xE8756A`; **light** title `0xB0392E` → `0x8A2A20`.
- `decorate`: octagon `frame = light ? 0xBE3A2C : 0xB0392E` → `light ? 0xDCA49C : 0xB0392E` (light lightened; dark unchanged).
- Split the `><` reticle: immediately **before** the `// >< centre targeting reticle` comment's first `dc.setPenWidth(...)`, insert:
  ```monkeyc
        dc.setColor(light ? 0xD9A099 : 0x6E2A22, Graphics.COLOR_TRANSPARENT);
  ```
- `drawBlips(...)` colour `light ? 0x2F6076 : 0x8AA9C2` → `light ? 0x2F6076 : 0x3FD8E6` (dark → cyan; light steel unchanged).

- [ ] **Step 3: Bulkhead**

In `source/themes/WallTheme.mc` `decorate`: `grey = light ? 0xA2ABB7 : 0x404750` → `light ? 0xC8CDD4 : 0x2a2f36`; `greyd = light ? 0xBEC5CE : 0x2b3037` → `light ? 0xD8DCE1 : 0x1b1e23`.

- [ ] **Step 4: Compile-gate all four buckets.** Expected `BUILD SUCCESSFUL` each.

- [ ] **Step 5: Commit**

```sh
git add source/themes/CockpitTheme.mc source/themes/BridgeTheme.mc source/themes/WallTheme.mc
git commit -m "feat: retune Cockpit/Bridge/Bulkhead decoration colours (dark+light)"
```

---

### Task 6: Phosphor radar pip recolour

The Phosphor contact pips live in the watermark bitmap. Recolour them via `gen_phosphor_watermark.sh` (dark → magenta, light → orange) and regenerate the drawables.

**Files:**
- Modify: `tools/gen_phosphor_watermark.sh` (BLIP colour constants)
- Generated: `resources-*/drawables/*phosphor*` (regenerated dark + light watermarks)

**Interfaces:** none.

- [ ] **Step 1: Change the blip colours**

In `tools/gen_phosphor_watermark.sh`: `DARK_BLIP="#FF8C2B"` → `DARK_BLIP="#E64DBF"`; `LIGHT_BLIP="#C2540E"` → `LIGHT_BLIP="#E8621F"`.

- [ ] **Step 2: Regenerate the watermarks**

Run: `tools/gen_phosphor_watermark.sh` (needs ImageMagick).
Expected: the Phosphor dark/light watermark drawables are rewritten; `git status` shows only those files changed.

- [ ] **Step 3: Compile-gate all four buckets.** Expected `BUILD SUCCESSFUL` each.

- [ ] **Step 4: Commit**

```sh
git add tools/gen_phosphor_watermark.sh resources-*/drawables/
git commit -m "feat: recolour Phosphor radar pips (dark magenta / light orange)"
```

---

### Task 7 (CONTROLLER — interactive simulator tuning)

**Not a subagent task.** Like SP2's Task 5, the controller runs this in the simulator, iterating with the maintainer. Mechanism from Tasks 2–4 is in place; this finalises the exact @390 geometry and confirms every theme × mode × pose.

- [ ] **Step 1:** For each theme (0–3) × mode (dark/light), force the 5-field sample pose in a throwaway build and capture on `fr965`; verify against the approved mocks (60pt values, corners' outer digit on the edge/reticle, top-row gap == bottom-row gap, decoration colours + pip colours).
- [ ] **Step 2:** Tune the `GRID_TOP_Y` / `GRID_HERO_Y` / `GRID_BOT_Y` / `GRID_EDGE_L` / `GRID_EDGE_R` / `GRID_GAP` constants until placement matches the approved mocks across themes.
- [ ] **Step 3:** Verify the hours pose (elapsed `1:23:45`, lap `1:04:23`): prefix at 40pt vertically centred, grows inward, no clip; and the wide-value pose (distance `100.00`): shrinks to fit. Adjust `GRID_GAP` if needed.
- [ ] **Step 4:** Confirm labels-on (`showLabels`) still align acceptably with the raised rows; nudge `lblY1`/`lblY2` in each theme's `buildLayout` if a label collides.
- [ ] **Step 5:** Final `monkeyc -w` clean on all four buckets; commit the tuned constants.

---

## Post-plan: review, PR, release

After Task 7: final whole-branch review (opus), then a board-tracked PR (branch `fivefield-60pt`). A store release follows separately (refresh screenshots + `description.txt` "What's changed" + `CHANGELOG.md`, then `tools/release.sh`), as with SP1/SP2 — **not** part of this plan.
