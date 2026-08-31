# 4-Field Compass (N/E/S/W) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the 4-field preset as a compass — N at 104pt (hero), E/W edge-anchored at 76pt on the midline, S centred at 76pt — with width budgets that admit an hours-prefix pair at every position. Closes #47.

**Architecture:** Only the preset machinery in `source/Theme.mc` changes: a new `value44` bitmap cut joins the ladder (`fitValueFont`, `fitDurationPair`, `prefixCut`, `cutFont`), the `layout == 4` branch of `presetSlots` gets the four compass slots, and two layout-4 decoration gates land (`blipCy(4) → 0`; Bridge skips its `><` reticle). The 5/3/2/1 layouts are geometry-untouched. All numbers @390, scaled at draw.

**Tech Stack:** Connect IQ / Monkey C (SDK 9.1.0); BMFont bitmap fonts via `tools/gen_fonts.py` (Pillow). No unit-test framework — the gates are `monkeyc -w` clean, `tools/check_font_metrics.py` green, a mechanical width check, and simulator captures.

**Spec:** `docs/superpowers/specs/2026-08-30-compass-4field-design.md` — read it first; the fit matrix and geometry rationale live there.

## Global Constraints

- Build gate after **every** task, all four devices — a clean build prints `BUILD SUCCESSFUL`:
  ```sh
  export PATH="/usr/local/opt/openjdk/bin:$PATH"   # Java is NOT on the default PATH; monkeyc fails without this
  SDK="$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.1.0-2026-03-09-6a872a80b"
  for d in fr70 fr265s fr265 fr965; do "$SDK/bin/monkeyc" -f monkey.jungle -o /tmp/check.prg -y ./developer_key.der -d $d -w || break; done
  ```
- `python3 tools/check_font_metrics.py` must exit 0 whenever fonts or ascent literals change.
- All geometry @390, scaled at draw via the existing `scN`/`scP`/`rnd` helpers.
- **Do not touch** `drawGrid` (5-field), the layout 3/2/1 branches of `presetSlots`, or `fitGridFont`.
- No manifest changes; never commit `developer_key.der` or `.prg`/`.iq` artifacts; never commit pose-forcing edits (Task 4).
- Commits carry `Co-Authored-By:` with the model that was requested for the seat.

## File Structure

- `tools/gen_fonts.py` — `REF_SPECS` + `ASC_CONSTANTS` gain `value44`.
- `resources-{360x360,390x390,416x416,454x454}/fonts/` — generated `value44.fnt|png`; `fonts.xml` gains `Value44Font` (×4).
- `source/Theme.mc` — `Fonts` accessor `value44()`; `cutFont`/`prefixCut`/`fitValueFont`/`fitDurationPair` ladder rows; `presetSlots` layout-4 branch; `blipCy`.
- `source/themes/BridgeTheme.mc` — reticle gate.
- `tools/check_font_metrics.py` — `CHECKS` row for `value44`.

---

### Task 1: The `value44` font cut, wired into the ladder

**Files:**
- Modify: `tools/gen_fonts.py` (REF_SPECS ~line 50, ASC_CONSTANTS ~line 217)
- Modify: `resources-360x360/fonts/fonts.xml`, `resources-390x390/fonts/fonts.xml`, `resources-416x416/fonts/fonts.xml`, `resources-454x454/fonts/fonts.xml`
- Modify: `source/Theme.mc` (`Fonts` class; `cutFont`, `prefixCut`, `fitValueFont`, `fitDurationPair`)
- Modify: `tools/check_font_metrics.py` (CHECKS list)
- Generated: `resources-*/fonts/value44.fnt|png`

**Interfaces:**
- Produces: `Fonts.value44() as WatchUi.FontResource`; `cutFont(44, fonts)` → `[value44 font, <BASE44>]`; `prefixCut(44) == 34`; ladders that include 44. Task 2's slots rely on the pair `44+34` fitting a 178 budget.

- [ ] **Step 1: Add the cut to `gen_fonts.py`**

In `REF_SPECS`, after the `("value40", 40, DIGITS + ":.-", 0),` line, add:

```python
    ("value44", 44, DIGITS + ":.-", 0),
```

In `ASC_CONSTANTS`, after the `"value40"` entry, add:

```python
    "value44": "Theme.mc cutFont() ladder",
```

- [ ] **Step 2: Regenerate the atlases**

Run: `python3 tools/gen_fonts.py` (needs `pip install Pillow`).
Expected: a `value44 …` line per bucket; `git status` shows **only new** `value44.*` files under `resources-*/fonts/` plus the two edited `.py` files. The generator is deterministic — if any pre-existing atlas shows as modified, stop and investigate.

- [ ] **Step 3: Read the generated ascent**

Run: `grep -o 'base=[0-9]*' resources-390x390/fonts/value44.fnt`
Expected: `base=46` or within a point of it. Whatever it prints is **`<BASE44>`** below — use the actual value everywhere, never the prediction.

- [ ] **Step 4: Declare the font in each `fonts.xml`**

In **each** of the four `resources-*/fonts/fonts.xml`, after the `Value40Font` line, add:

```xml
    <font id="Value44Font" filename="value44.fnt"/>
```

- [ ] **Step 5: Wire `source/Theme.mc`**

In the `Fonts` class, alongside the other `_v*` fields add:

```monkeyc
    private var _v44 as WatchUi.FontResource?;
```

and alongside the other accessors:

```monkeyc
    function value44() as WatchUi.FontResource { if (_v44 == null) { _v44 = WatchUi.loadResource(Rez.Fonts.Value44Font) as WatchUi.FontResource; } return _v44; }
```

In `cutFont`, before the final `return [fonts.value, 36];`, add (substituting `<BASE44>`):

```monkeyc
        else if (sz == 44) { return [fonts.value44(), <BASE44>]; }
```

In `prefixCut`, after the `bigSize == 52` branch, add:

```monkeyc
        else if (bigSize == 44) { return 34; }
```

In `fitDurationPair`, change `var sizes = [104, 76, 64, 52];` to:

```monkeyc
        var sizes = [104, 76, 64, 52, 44];
```

In `fitValueFont`, change `var sizes = [104, 76, 64, 52, 34];` to:

```monkeyc
        var sizes = [104, 76, 64, 52, 44, 34];
```

- [ ] **Step 6: Extend the metrics guard**

In `tools/check_font_metrics.py`, in `CHECKS`, after the `("value52", "cutFont ladder", …)` row, add:

```python
    ("value44", "cutFont ladder", r"fonts\.value44\(\), (\d+)\]"),
```

Run: `python3 tools/check_font_metrics.py`
Expected: exit 0. (If it flags `value44`, the `<BASE44>` literal in `cutFont` doesn't match the atlas — fix the literal.)

- [ ] **Step 7: Verify the pair fits mechanically**

Run this from the repo root (throwaway; do not commit):

```sh
python3 - <<'EOF'
import re
def adv(bucket, cut):
    txt = open("resources-%s/fonts/%s.fnt" % (bucket, cut)).read()
    return {chr(int(m.group(1))): int(m.group(2)) for m in
            re.finditer(r'char id=(\d+)\s+x=\d+\s+y=\d+\s+width=\d+\s+height=\d+\s+'
                        r'xoffset=-?\d+\s+yoffset=-?\d+\s+xadvance=(\d+)', txt)}
w = lambda a, s: sum(a[c] for c in s)
for b, sc in (("360x360",360/390),("390x390",1.0),("416x416",416/390),("454x454",454/390)):
    v44, v34 = adv(b,"value44"), adv(b,"value")
    for pose in ("1:00:04","12:34:56"):
        i = pose.find(":")+1
        tot = w(v34,pose[:i]) + w(v44,pose[i:])
        bud = round(178*sc)
        print(b, pose, "44+34 =", tot, "budget", bud, "FIT" if tot<=bud else "MISS")
EOF
```

Expected: `FIT` on all rows for `1:00:04`, and for `12:34:56` on at least the 390/416/454 buckets. The spec accepts a `12:34:56` MISS on 360 only (record it in the commit message if so); any other MISS means the budget/pair design is broken — stop and re-derive before proceeding.

- [ ] **Step 8: Build gate (all four devices) and commit**

Run the Global Constraints build loop. Expected: 4× `BUILD SUCCESSFUL`.

```sh
git add tools/gen_fonts.py tools/check_font_metrics.py resources-*/fonts/ source/Theme.mc
git commit -m "feat: add value44 font cut to the preset ladder (44+34 hours pair)"
```

---

### Task 2: Compass geometry in `presetSlots`

**Files:**
- Modify: `source/Theme.mc` (`presetSlots`, the `layout == 4` branch, ~line 181)

**Interfaces:**
- Consumes: `Fonts.value104()/value76()` (existing), `PresetSlot` (existing ctor: slot, x, baseY, asc, size, font, widthBudget, role, just, labelX, labelBaseY — all @390).
- Produces: the four compass slots Task 4 tunes. Slot order stays `slot0..slot3` = N, E, S, W.

- [ ] **Step 1: Replace the `layout == 4` branch**

Replace the entire current block:

```monkeyc
        if (layout == 4) {
            var vf = fonts.value64(); var a = 68;
            return [
                new PresetSlot(0, 108, 146, a, 64, vf, 170, 1, C, 108, 94),
                new PresetSlot(1, 282, 146, a, 64, vf, 170, 1, C, 282, 94),
                new PresetSlot(2, 108, 300, a, 64, vf, 170, 2, C, 108, 248),
                new PresetSlot(3, 282, 300, a, 64, vf, 170, 2, C, 282, 248),
            ];
        } else if (layout == 3) {
```

with:

```monkeyc
        if (layout == 4) {
            // Compass N/E/S/W. N is the hero (104pt); E/W hug the midline
            // edges and grow inward; S mirrors N's width at 76pt. Budgets are
            // sized so every position fits an hours-prefix pair — see
            // docs/superpowers/specs/2026-08-30-compass-4field-design.md.
            return [
                new PresetSlot(0, 195, 150, 109, 104, fonts.value104(), 296, 0, C, 195, 70),
                new PresetSlot(1, 378, 222, 80, 76, fonts.value76(), 178, 2, Graphics.TEXT_JUSTIFY_RIGHT, 289, 160),
                new PresetSlot(2, 195, 316, 80, 76, fonts.value76(), 294, 1, C, 195, 254),
                new PresetSlot(3, 12, 222, 80, 76, fonts.value76(), 178, 2, Graphics.TEXT_JUSTIFY_LEFT, 101, 160),
            ];
        } else if (layout == 3) {
```

- [ ] **Step 2: Build gate and commit**

Run the Global Constraints build loop, then `python3 tools/check_font_metrics.py`.
Expected: 4× `BUILD SUCCESSFUL`; guard exit 0 (its `value64` row still matches `cutFont`'s ladder, which keeps carrying 64).

```sh
git add source/Theme.mc
git commit -m "feat: reformat the 4-field preset to a N/E/S/W compass (#47)"
```

---

### Task 3: Layout-4 decoration gates

**Files:**
- Modify: `source/Theme.mc` (`blipCy`)
- Modify: `source/themes/BridgeTheme.mc` (`decorate`)

**Interfaces:**
- Consumes: `decorate(dc, light, s, layout)` already receives `layout`; `blipCy(layout)` already treats 0 as "draw none".
- Produces: no blips and no Bridge reticle in layout 4; every other theme/layout combination unchanged.

- [ ] **Step 1: Silence the blips for layout 4**

In `blipCy`, change:

```monkeyc
        if (layout == 4) { return 205; }
```

to:

```monkeyc
        if (layout == 4) { return 0; }  // compass: E/W own the midline; no blip band
```

- [ ] **Step 2: Gate the Bridge reticle**

In `BridgeTheme.decorate`, wrap the `>< centre targeting reticle` block (the `setColor`/`setPenWidth`/four `drawLine` calls and the closing `setPenWidth(1)`) in a layout guard:

```monkeyc
        if (layout != 4) {
            // >< centre targeting reticle (two chevrons pointing inward) —
            // skipped in the compass layout, where E/W values own the midline.
            dc.setColor(light ? 0xD9A099 : 0x6E2A22, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(scP(2, s));
            dc.drawLine(scN(140,s),scN(173,s), scN(162,s),scN(195,s)); dc.drawLine(scN(162,s),scN(195,s), scN(140,s),scN(217,s));
            dc.drawLine(scN(250,s),scN(173,s), scN(228,s),scN(195,s)); dc.drawLine(scN(228,s),scN(195,s), scN(250,s),scN(217,s));
            dc.setPenWidth(1);
        }
```

- [ ] **Step 3: Build gate and commit**

Run the Global Constraints build loop. Expected: 4× `BUILD SUCCESSFUL`.

```sh
git add source/Theme.mc source/themes/BridgeTheme.mc
git commit -m "feat: gate blips and Bridge reticle off in the compass layout"
```

---

### Task 4: Simulator verification and tuning

The @390 numbers in Task 2 are measured starting values; this task proves them on pixels and adjusts. **Pose-forcing edits are throwaway and must never be committed** — do them in a detached scratch worktree (per `store/README.md` convention).

**Files:**
- Modify (only if tuning demands it): `source/Theme.mc` (the Task 2 numbers), and the spec's fit matrix to match.
- Throwaway (scratch worktree only): `source/Metrics.mc`, `source/FlightdeckView.mc`.

**Interfaces:**
- Consumes: everything from Tasks 1–3.
- Produces: sim-verified geometry; capture set for the PR body.

- [ ] **Step 1: Make a detached scratch worktree**

```sh
git worktree add --detach ~/Github/.worktrees/Flightdeck/47-compass-sim HEAD
cd ~/Github/.worktrees/Flightdeck/47-compass-sim
```

- [ ] **Step 2: Force layout + pose**

In the scratch copy only — in `source/FlightdeckView.mc`, at the end of `readSettings()`, append (edit theme/mode per capture):

```monkeyc
        _layout = 4; _themeIdx = 0; _light = false; // POSE FORCE — throwaway
```

In `source/Metrics.mc`, at the very top of `format(id)` (before the `_info` null-check), insert the pose's block — pose A shown; substitute the strings per the table:

```monkeyc
        // POSE FORCE — throwaway
        switch (id) {
            case METRIC_TIMER: return "34:56";
            case METRIC_PACE:  return "5:14";
            case METRIC_DIST:  return "8.53";
            case METRIC_LPACE: return "12:34";
        }
```

The four poses (slot map is default: Timer→N, Pace→E, Dist→S, LPace→W):

| pose | N (TIMER) | E (PACE) | S (DIST) | W (LPACE) | proves |
|---|---|---|---|---|---|
| A typical | `34:56` | `5:14` | `8.53` | `12:34` | N@104 5-char, E@76, S@76, W@64 |
| B wide | `100.00` | `100.00` | `100.00` | `100.00` | N/S@76, E/W@52, no edge clipping |
| C hours | `1:00:04` | `1:00:04` | `1:00:04` | `1:00:04` | 76+52 pair N/S, 44+34 pair E/W |
| D 12-hour | `12:34:56` | `12:34:56` | `12:34:56` | `12:34:56` | widest pairs; S's 1px margin; E/W 44+34 |

- [ ] **Step 3: Build, run, capture (per theme × mode × pose)**

```sh
export PATH="/usr/local/opt/openjdk/bin:$PATH"
SDK="$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.1.0-2026-03-09-6a872a80b"
"$SDK/bin/connectiq" &    # once; wait for the sim window
"$SDK/bin/monkeyc" -f monkey.jungle -o /tmp/pose.prg -y <path-to-developer_key.der> -d fr965 -w
"$SDK/bin/monkeydo" /tmp/pose.prg fr965
WID=$(python3 -c "import Quartz;
print([w['kCGWindowNumber'] for w in Quartz.CGWindowListCopyWindowInfo(Quartz.kCGWindowListOptionOnScreenOnly,0) if 'CIQ Simulator' in (w.get('kCGWindowOwnerName') or '')][0])")
screencapture -x -o -l$WID /tmp/full.png
# crop the watch face out of the window shot (offsets per store/README.md):
magick /tmp/full.png -crop 454x454+114+262 /tmp/cap.png
```

Coverage: pose C across all 4 themes × dark/light (8 captures — the richest pose: every position shows a pair); poses A, B, D on Cockpit dark. Also build for **fr265s** and capture poses A and D there (the 360 bucket carries the borderline 44+34 fit; the 454 exact 64 fit is covered by fr965 pose A).

- [ ] **Step 4: Judge each capture**

For every capture confirm: (1) no glyph clipped by the round edge; (2) no decoration reads as part of a digit (Cockpit scan line and brackets behind ink are expected and fine); (3) the cut each pose lands on matches the spec's fit matrix; (4) N/E/S/W read as a compass — values visually anchored top / right / bottom / left; (5) one labels-on spot check (`showLabels` forced true, pose A, Cockpit dark): labels legible, N-label-vs-title acceptable.

- [ ] **Step 5: Tune if needed**

Any misfit → adjust the @390 constants in the real worktree's `source/Theme.mc` (Task 2 block), keeping every budget ≥ its pair width from the spec's fit matrix (or consciously downgrading that cell), update the spec's table to match, rebuild, re-capture. Repeat until Step 4 passes.

- [ ] **Step 6: Tear down the scratch worktree and commit any tuning**

```sh
cd ~/Github/Flightdeck/.claude/worktrees/47-compass-4field   # back to the real worktree
git worktree remove --force ~/Github/.worktrees/Flightdeck/47-compass-sim
git status   # must show, at most, Theme.mc + the spec as modified — no Metrics.mc/FlightdeckView.mc changes
```

If tuning changed anything:

```sh
git add source/Theme.mc docs/superpowers/specs/2026-08-30-compass-4field-design.md
git commit -m "tune: sim-adjusted compass geometry"
```

Keep the pose-C capture set for the PR body.

---

### Task 5: Final verification and PR

- [ ] **Step 1: Full gate from a clean state**

```sh
git status                                  # clean tree, branch 47-compass-4field
python3 tools/check_font_metrics.py         # exit 0
python3 tools/gen_fonts.py && git status    # regeneration is a no-op: tree still clean
```

Then the Global Constraints build loop: 4× `BUILD SUCCESSFUL`.

- [ ] **Step 2: Open the PR**

Use the `dcltdw:opening-a-pr` skill. Base `main`, `Closes #47`. Body sections per the skill: `Files changed` annotated `(new)`/`(modified)`; `Work breakdown`; `Test expectations` — name the four poses and the capture evidence; `Operational impact` — existing layout-4 users see the compass on update, no re-add of the data field needed (the field set is unchanged), other layouts unaffected; `Provenance`. Attach representative pose-C captures. **Wait for approval — do not merge.** On merge, `dcltdw:cleaning-up-after-pr-merge` handles branch/worktree cleanup and the board card.

---

## Execution style

**Subagent-driven (`superpowers:subagent-driven-development`), recommended.** Tasks 1–3 and 5 carry exact code and commands — cheap-tier implementer seats (Sonnet) transcribe and gate them. Task 4 is judgement work (reading captures, nudging geometry): give its implementer seat the top of the seat range (Opus). Reviewers sit one tier above the implementer per the standing rule, saturating at Opus. Inline execution via `superpowers:executing-plans` is acceptable if the sim capture loop proves awkward across subagent dispatches, but the default is subagent-driven.
