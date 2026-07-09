# Layout Presets + Bigger Fonts — SP2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
> **Note on execution:** Tasks 1–4 are deterministic (subagent-friendly). **Task 5 is an interactive controller-run sim-tuning phase** (like the SP1 face polish) — not a subagent task; the controller tunes positions visually. Then the release prep in "After the plan".

**Goal:** Add a `Layout` setting (5/4/3/2/1) that shows fewer, bigger fields — fewer fields → larger value fonts — delivering the legibility win.

**Architecture:** New value fonts (52/76/104 @390) regenerated via `gen_fonts.py`. Base `Theme` gains four shared preset-geometry tables (4/3/2/1); the 5-field preset keeps each theme's existing `buildLayout`. `draw()` branches on the layout and picks each value's font by **auto-shrink** (largest ladder size ≤ the preset target whose width fits). Decorations unchanged (fixed).

**Tech Stack:** Monkey C / Connect IQ (SDK 9.1.0), Python/Pillow for `gen_fonts.py`. No unit-test framework — verification is `monkeyc -w` (type-checked compile) across the four buckets + simulator observation.

**Spec:** `docs/superpowers/specs/2026-07-09-layout-presets-sp2-design.md`.

## Global Constraints

- `monkeyc -w` clean on fr70/fr265s/fr265/fr965.
- **No new manifest permissions.**
- **New value sizes @390:** 52, 76, 104 (regular) + bold cuts (Bulkhead). Existing 34 (value) / 60 (hero) stay.
- **Font ascents @390** (from the generated `.fnt` `base=`): value52 → 48, value76 → 69, value104 → 95, value(34) → 28. Scaled per bucket at runtime by `Layout.scale`/`s`. These are starting values; sim-tuned in Task 5.
- **Preset value targets @390:** 5-field 34 (centre 60) · 4-field 52 · 3-field 76 · 2-field 104 · 1-field 104.
- **Auto-shrink ladder (values):** `[104, 76, 52, 34]` — draw picks the largest ≤ the slot target whose `dc.getTextWidthInPixels` fits the slot's width budget. Shrink-only. The 5-field centre keeps its 60px hero (not shrunk).
- **Slot→position per preset** and **positional colour** exactly per the spec's tables.
- `Layout` setting default = 5 (reproduces today's face).
- Repo conventions: branch → PR → wait; board flow; PR bodies per `universal.md` (Provenance); commits stamped `Co-Authored-By`. **On merge, a store release is cut** (see "After the plan").

**Compile command** (each task's verify):

```sh
SDK="$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.1.0-2026-03-09-6a872a80b"
export PATH="$(brew --prefix openjdk)/bin:$PATH"
KEY="<developer_key>"   # your signing key (see docs/releasing.md; DEV_KEY)
"$SDK/bin/monkeyc" -f monkey.jungle -o /tmp/check.prg -y "$KEY" -d fr70 -w
```

## File structure

- `tools/gen_fonts.py` (modify) — add the new sizes to `REF_SPECS`.
- `resources-{360,390,416,454}/fonts/*.fnt|*.png` (generated) — new atlases.
- `resources-{360,390,416,454}/fonts/fonts.xml` (modify ×4) — declare the new fonts.
- `source/Theme.mc` (modify) — `Fonts` value-ladder accessors; base `Theme` preset tables + `draw()` branching + auto-shrink.
- `resources/settings/settings.xml`, `properties.xml`, `resources/strings/strings.xml` (modify) — the `layout` setting.
- `source/FlightdeckView.mc` (modify) — read `layout`, pass to `draw()`.

Theme subclasses' `buildLayout`/`decorate()`, `ThemeRegistry`, `Metrics`, `manifest.xml` are **unchanged**.

---

### Task 1: Generate + wire the new value fonts

**Files:** `tools/gen_fonts.py`, `resources-*/fonts/fonts.xml` (×4), generated `resources-*/fonts/value{52,76,104}.*` + `valueb{52,76,104}.*`, `source/Theme.mc` (`Fonts` class).

**Interfaces — Produces:** `Fonts` gains lazy accessors `value52()/value76()/value104()` and `value52B()/value76B()/value104B()` returning `WatchUi.FontResource`.

- [ ] **Step 1: Add the sizes to `gen_fonts.py`.** In `tools/gen_fonts.py`, append to `REF_SPECS` after the `("labelb", 36, UPPER, 0),` line:

```python
    ("value52", 52, DIGITS + ":.-", 0),
    ("value76", 76, DIGITS + ":.-", 0),
    ("value104", 104, DIGITS + ":.-", 0),
    ("valueb52", 52, DIGITS + ":.-", 1),
    ("valueb76", 76, DIGITS + ":.-", 1),
    ("valueb104", 104, DIGITS + ":.-", 1),
```

(Stroke `1` = a real stroked-bold. The existing `valueb` uses stroke **0** because it gets its weight from being a *bigger* size than the regular cut; but in presets every theme shares one size, so Bulkhead's heavier look must come from an actual stroke — hence stroke `1` here.)

- [ ] **Step 2: Regenerate.** Run `python3 tools/gen_fonts.py`. Expected: it prints `value52 … value104 … valueb52 …` lines for each of the four buckets and `Done.` New `.fnt`/`.png` appear under each `resources-*/fonts/`.

- [ ] **Step 3: Declare the fonts in each bucket's `fonts.xml`.** In **each** of `resources-360x360/fonts/fonts.xml`, `resources-390x390/…`, `resources-416x416/…`, `resources-454x454/…`, add before `</resources>`:

```xml
    <!-- preset value sizes -->
    <font id="Value52Font" filename="value52.fnt"/>
    <font id="Value76Font" filename="value76.fnt"/>
    <font id="Value104Font" filename="value104.fnt"/>
    <font id="Value52BoldFont" filename="valueb52.fnt"/>
    <font id="Value76BoldFont" filename="valueb76.fnt"/>
    <font id="Value104BoldFont" filename="valueb104.fnt"/>
```

- [ ] **Step 4: Add lazy accessors to `Fonts`** in `source/Theme.mc`. Add fields beside `_valueB`:

```monkeyc
    private var _v52 as WatchUi.FontResource?;
    private var _v76 as WatchUi.FontResource?;
    private var _v104 as WatchUi.FontResource?;
    private var _v52b as WatchUi.FontResource?;
    private var _v76b as WatchUi.FontResource?;
    private var _v104b as WatchUi.FontResource?;
```

and methods (after `labelB()`):

```monkeyc
    function value52()  as WatchUi.FontResource { if (_v52 == null)  { _v52  = WatchUi.loadResource(Rez.Fonts.Value52Font)  as WatchUi.FontResource; } return _v52; }
    function value76()  as WatchUi.FontResource { if (_v76 == null)  { _v76  = WatchUi.loadResource(Rez.Fonts.Value76Font)  as WatchUi.FontResource; } return _v76; }
    function value104() as WatchUi.FontResource { if (_v104 == null) { _v104 = WatchUi.loadResource(Rez.Fonts.Value104Font) as WatchUi.FontResource; } return _v104; }
    function value52B()  as WatchUi.FontResource { if (_v52b == null)  { _v52b  = WatchUi.loadResource(Rez.Fonts.Value52BoldFont)  as WatchUi.FontResource; } return _v52b; }
    function value76B()  as WatchUi.FontResource { if (_v76b == null)  { _v76b  = WatchUi.loadResource(Rez.Fonts.Value76BoldFont)  as WatchUi.FontResource; } return _v76b; }
    function value104B() as WatchUi.FontResource { if (_v104b == null) { _v104b = WatchUi.loadResource(Rez.Fonts.Value104BoldFont) as WatchUi.FontResource; } return _v104b; }
```

- [ ] **Step 5: Compile-verify** (all four buckets):

```sh
for d in fr70 fr265s fr265 fr965; do "$SDK/bin/monkeyc" -f monkey.jungle -o /tmp/check_$d.prg -y "$KEY" -d $d -w && echo "$d OK" || echo "$d FAIL"; done
```

Expected: four `OK`.

- [ ] **Step 6: Commit.**

```sh
git add tools/gen_fonts.py resources-*/fonts/ source/Theme.mc
git commit -m "feat: generate + wire preset value fonts (52/76/104 + bold)"
```

---

### Task 2: `Layout` setting + view wiring

**Files:** `resources/settings/settings.xml`, `resources/settings/properties.xml`, `resources/strings/strings.xml`, `source/FlightdeckView.mc`.

**Interfaces — Produces:** property `layout` (number, default 5). The view read + use is added in Task 3 (where `draw()` consumes it), to avoid an unused-field warning.

- [ ] **Step 1: Property.** In `resources/settings/properties.xml`, after `showLabels`:

```xml
        <!-- field-count layout preset: 5,4,3,2,1 -->
        <property id="layout" type="number">5</property>
```

- [ ] **Step 2: Strings.** In `resources/strings/strings.xml`, after `SettingLabels`:

```xml
    <string id="SettingLayout">Layout (field count)</string>
    <string id="Layout5">5 fields</string>
    <string id="Layout4">4 fields</string>
    <string id="Layout3">3 fields</string>
    <string id="Layout2">2 fields</string>
    <string id="Layout1">1 field</string>
```

- [ ] **Step 3: Setting.** In `resources/settings/settings.xml`, after the `showLabels` setting:

```xml
        <setting propertyKey="@Properties.layout" title="@Strings.SettingLayout">
            <settingConfig type="list">
                <listEntry value="5">@Strings.Layout5</listEntry>
                <listEntry value="4">@Strings.Layout4</listEntry>
                <listEntry value="3">@Strings.Layout3</listEntry>
                <listEntry value="2">@Strings.Layout2</listEntry>
                <listEntry value="1">@Strings.Layout1</listEntry>
            </settingConfig>
        </setting>
```

- [ ] **Step 4: Compile-verify** (fr70). Expected `BUILD SUCCESSFUL` (the resource compiler validates the new setting/strings). The view read of `layout` is deliberately added in Task 3, where `draw()` consumes it — adding it here would leave an unused field (`-w` risk).

- [ ] **Step 5: Commit.**

```sh
git add resources/settings/settings.xml resources/settings/properties.xml resources/strings/strings.xml
git commit -m "feat: Layout (field count) setting 5/4/3/2/1"
```

---

### Task 3: Preset geometry tables + `draw()` branching

**Files:** `source/Theme.mc`, `source/FlightdeckView.mc`.

**Interfaces — Consumes:** `Fonts.value52()/76()/104()` (+ bold) from Task 1; `_layout` from Task 2. **Produces:** `draw(dc, m, fonts, light, slots, showLabels, layout)` renders the active preset. A `PresetSlot` descriptor and a base `Theme.presetSlots(layout, fonts, bold)` provider.

**Design note:** positions below are **@390 starting values from the design mockup** — Task 5 tunes them in the sim. `bold` = true only for Bulkhead (its `buildLayout` sets a flag — see Step 3). Auto-shrink is added in Task 4; this task draws at the fixed preset target size.

- [ ] **Step 1: Add a `PresetSlot` class** to `source/Theme.mc` (module scope, near `Layout`):

```monkeyc
// One field slot within a preset: which config slot it draws, where, at what
// size/role. x/baseY/asc/widthBudget/labelX/labelY are @390 (scaled at draw).
class PresetSlot {
    public var slot as Number;      // config slot index 0..4
    public var x as Number;
    public var baseY as Number;
    public var asc as Number;
    public var font as WatchUi.FontResource;
    public var widthBudget as Number;
    public var role as Number;       // 0=hero(warm) 1=sval(white) 2=lap(accent)
    public var just as Graphics.TextJustification;
    public var labelX as Number;
    public var labelBaseY as Number;
    function initialize(slot, x, baseY, asc, font, widthBudget, role, just, labelX, labelBaseY) {
        self.slot = slot; self.x = x; self.baseY = baseY; self.asc = asc;
        self.font = font; self.widthBudget = widthBudget; self.role = role;
        self.just = just; self.labelX = labelX; self.labelBaseY = labelBaseY;
    }
}
```

- [ ] **Step 2: Add `presetSlots` to base `Theme`.** Returns the shared table for layouts 4/3/2/1 (5 is handled by the existing path). `vf` is the preset's value font (bold for Bulkhead), `asc` its ascent. Add to `class Theme`:

```monkeyc
    // Shared preset geometry (4/3/2/1). @390; scaled at draw. Positions are
    // starting values tuned in the sim. role: 0 hero/warm, 1 white, 2 accent.
    function presetSlots(layout as Number, fonts as Fonts, bold as Boolean) as Array<PresetSlot> {
        var C = Graphics.TEXT_JUSTIFY_CENTER;
        if (layout == 4) {
            var vf = bold ? fonts.value52B() : fonts.value52(); var a = 48;
            return [
                new PresetSlot(0, 108, 175, a, vf, 170, 1, C, 108, 120),
                new PresetSlot(1, 282, 175, a, vf, 170, 1, C, 282, 120),
                new PresetSlot(2, 108, 285, a, vf, 170, 2, C, 108, 230),
                new PresetSlot(3, 282, 285, a, vf, 170, 2, C, 282, 230),
            ];
        } else if (layout == 3) {
            var vf = bold ? fonts.value76B() : fonts.value76(); var a = 69;
            return [
                new PresetSlot(0, 195, 118, a, vf, 360, 0, C, 195, 70),
                new PresetSlot(1, 195, 218, a, vf, 360, 1, C, 195, 170),
                new PresetSlot(2, 195, 318, a, vf, 360, 2, C, 195, 270),
            ];
        } else if (layout == 2) {
            var vf = bold ? fonts.value104B() : fonts.value104(); var a = 95;
            return [
                new PresetSlot(0, 195, 160, a, vf, 360, 0, C, 195, 95),
                new PresetSlot(1, 195, 285, a, vf, 360, 2, C, 195, 220),
            ];
        } else { // 1
            var vf = bold ? fonts.value104B() : fonts.value104(); var a = 95;
            return [
                new PresetSlot(0, 195, 220, a, vf, 360, 0, C, 195, 120),
            ];
        }
    }
```

- [ ] **Step 3: Bulkhead bold flag.** In `source/Theme.mc` add a base hook `function usesBold() as Boolean { return false; }` to `class Theme`; in `source/themes/WallTheme.mc` add `function usesBold() as Boolean { return true; }`. (Bulkhead is `WallTheme`.)

- [ ] **Step 4: Branch `draw()` on layout.** In `source/Theme.mc`, change the `draw` signature and add the preset branch. Replace the current `draw(dc, m, fonts, light, slots, showLabels)` header + the slot-drawing block with:

```monkeyc
    function draw(dc as Graphics.Dc, m as Metrics, fonts as Fonts, light as Boolean,
                  slots as Array<Number>, showLabels as Boolean, layout as Number) as Void {
        var p = buildPalette(light);
        var L = buildLayout(fonts);
        var s = dc.getWidth() / 390.0;
        L.scale(s);
        dc.setColor(Graphics.COLOR_WHITE, p.ground);
        dc.clear();
        decorate(dc, light, s);

        if (layout == 5) {
            drawGrid(dc, p, L, s, m, slots, showLabels);   // existing 5-field path
        } else {
            drawPreset(dc, p, L, s, m, slots, showLabels, layout, fonts);
        }
    }
```

Move the existing 5-field body (fonts null-check, title, the 5 `drawValue`/`drawLabel` calls) into a new private `drawGrid(dc, p, L, s, m, slots, showLabels)`; keep `drawValue`/`drawLabel`/`txt` as they are.

- [ ] **Step 5: Add `drawPreset`.** In `class Theme`:

```monkeyc
    private function drawPreset(dc as Graphics.Dc, p as Palette, L as Layout, s as Float,
                                m as Metrics, slots as Array<Number>, showLabels as Boolean,
                                layout as Number, fonts as Fonts) as Void {
        // title banner (unchanged) so Cockpit/Bridge keep their header
        var tf = L.titleFont; var tt = L.title;
        if (tf != null && tt != null) {
            txt(dc, L.ctr, L.titleY, L.titleAsc, tf, p.title, tt, Graphics.TEXT_JUSTIFY_CENTER);
        }
        var lf = L.lblFont;
        var ps = presetSlots(layout, fonts, usesBold());
        for (var i = 0; i < ps.size(); i++) {
            var d = ps[i];
            var id = slots[d.slot];
            if (id == 0) { continue; } // Off
            var color = (d.role == 0) ? p.hero : (d.role == 1 ? p.sval : p.lap);
            txt(dc, rnd(d.x * s), rnd(d.baseY * s), rnd(d.asc * s), d.font, color, m.format(id), d.just);
            if (showLabels && lf != null) {
                // L.lblAsc is already scaled by L.scale(s); d.labelX/labelBaseY are @390 so scale them.
                txt(dc, rnd(d.labelX * s), rnd(d.labelBaseY * s), L.lblAsc, lf, p.label, m.label(id), Graphics.TEXT_JUSTIFY_CENTER);
            }
        }
    }
```

- [ ] **Step 6: Wire the view.** In `source/FlightdeckView.mc`, add a field beside `_showLabels`:

```monkeyc
    private var _layout as Number = 5;
```

in `readSettings()` after the `_showLabels = …` line:

```monkeyc
        _layout = numProp("layout", 5);
```

and update the `onUpdate` draw call:

```monkeyc
        ThemeRegistry.get(_themeIdx).draw(dc, _m, fonts, _light, _slots, _showLabels, _layout);
```

- [ ] **Step 7: Compile-verify** (all four buckets). Expected four `OK`.

- [ ] **Step 8: Commit.**

```sh
git add source/Theme.mc source/themes/WallTheme.mc source/FlightdeckView.mc
git commit -m "feat: layout preset geometry + draw() branching (fixed sizes)"
```

---

### Task 4: Auto-shrink value font selection

**Files:** `source/Theme.mc`.

**Interfaces — Consumes:** the preset value fonts + `PresetSlot`. **Produces:** `drawPreset` (and, optionally, the 5-field corners) pick the largest value font that fits the slot width.

- [ ] **Step 1: Add a `fitValueFont` helper** to `class Theme` — given the preset target font + ascent, the string, the scaled width budget, and `fonts`, return `[font, ascent@390]` shrunk to fit:

```monkeyc
    // Largest ladder size <= target whose rendered width fits budgetPx. Shrink-only.
    // Returns [font, ascent390]. Ladder: 104,76,52,34 (bold variants for Bulkhead).
    private function fitValueFont(dc as Graphics.Dc, str as String, budgetPx as Number,
                                  startSize as Number, fonts as Fonts, bold as Boolean) as Array {
        var sizes = [104, 76, 52, 34];
        for (var i = 0; i < sizes.size(); i++) {
            var sz = sizes[i];
            if (sz > startSize) { continue; }
            var f; var a;
            if (sz == 104) { f = bold ? fonts.value104B() : fonts.value104(); a = 95; }
            else if (sz == 76) { f = bold ? fonts.value76B() : fonts.value76(); a = 69; }
            else if (sz == 52) { f = bold ? fonts.value52B() : fonts.value52(); a = 48; }
            else { f = bold ? fonts.valueB() : fonts.value; a = (bold ? 39 : 28); }
            if (dc.getTextWidthInPixels(str, f) <= budgetPx) { return [f, a]; }
        }
        // even the floor overflows: use the floor (34) and let it clip minimally
        var f0 = bold ? fonts.valueB() : fonts.value;
        return [f0, (bold ? 39 : 28)];
    }
```

- [ ] **Step 2: Use it in `drawPreset`.** Replace the value-draw line (the `txt(... d.font ... m.format(id) ...)` call) with a fitted pick. First compute the value string, then:

```monkeyc
            var vstr = m.format(id);
            var startSize = (d.font == fonts.value104() || d.font == fonts.value104B()) ? 104
                          : (d.font == fonts.value76()  || d.font == fonts.value76B())  ? 76 : 52;
            var fit = fitValueFont(dc, vstr, rnd(d.widthBudget * s), startSize, fonts, usesBold());
            txt(dc, rnd(d.x * s), rnd(d.baseY * s), rnd((fit[1] as Number) * s), fit[0] as WatchUi.FontResource, color, vstr, d.just);
```

(Remove the old direct `txt(... d.font ...)` value line; keep the label line.)

- [ ] **Step 3: Compile-verify** (all four buckets). Expected four `OK`.

- [ ] **Step 4: Commit.**

```sh
git add source/Theme.mc
git commit -m "feat: auto-shrink preset value font to fit slot width"
```

---

### Task 5 (controller, interactive — NOT a subagent): sim-tune preset geometry

The positions in Task 3 are @390 starting estimates. The controller (not a subagent) tunes them per theme × preset in the simulator, exactly like the SP1 face polish:

- [ ] For each layout (4/3/2/1) and each theme, build a throwaway forcing `_layout`, `_themeIdx`, `_light`, and representative `_slots` (include a long elapsed value to exercise auto-shrink); capture on fr965; adjust the `presetSlots` @390 numbers (x/baseY/widthBudget/labelBaseY) until fields are centred, evenly spaced, non-overlapping, and clear of decorations; note any theme×preset where fixed decorations look orphaned (spec permits tuning only those).
- [ ] Verify labels-on placement and colours per preset.
- [ ] Commit the tuned geometry: `git commit -m "polish: tune preset geometry in the simulator"`.

## After the plan (release — controller)

SP2 completes the feature, so per the spec + [[screenshots-before-release]]:
1. Regenerate `store/screenshots/` + `store/hero.png` (the look changed) and add a `X.Y.Z` "What's changed" entry to `store/description.txt` + a `CHANGELOG.md` section.
2. Land everything on `main` via PR, then `tools/release.sh vX.Y.Z` (verifies the signing key, gates on CHANGELOG + description entries).

## Self-review notes (author)

- **Spec coverage:** fonts (T1), Layout setting (T2), preset geometry + branching + positional colour + labels-all-slots (T3), auto-shrink (T4), sim-tuning + decoration-orphan check (T5), release (After). Hybrid geometry: 5-field via existing `buildLayout`/`drawGrid`; 4/3/2/1 via shared `presetSlots`. No-permissions unchanged.
- **Types:** `draw(...ap layout as Number)`, `presetSlots(layout, fonts, bold) as Array<PresetSlot>`, `fitValueFont(...) as Array` → `[font, ascent390]`, `usesBold() as Boolean`, `_layout as Number` — consistent across tasks.
- **Ascents** (48/69/95/28) are starting values from the generated `.fnt`; sim-tuned in T5.
