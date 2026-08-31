# Per-Layout Metric Slots Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give each of the five layout presets its own independent metric
slots and defaults, rename `slot0..slot4` to per-layout self-describing
property ids, and flip the shipped `layout` default from 5 to 4 (#49).

**Architecture:** All selection logic lands in `FlightdeckView.readSettings`,
which reads `layout` first and then only the active layout's properties into
the existing positional `_slots` array (now variable-length); `Theme` and
every theme subclass already index into whatever array they are handed and
are untouched apart from comments. The 15-picker `settings.xml` becomes the
output of a new deterministic generator, `tools/gen_settings.py`. No
migration shim — the old properties are deleted outright (pinned decision).

**Tech Stack:** Monkey C (Connect IQ SDK 9.1.0), Python 3 stdlib, CIQ
resource XML.

**Spec:** `docs/superpowers/specs/2026-08-30-per-layout-slots-design.md`

**Execution style (decided):** **Subagent-driven** (superpowers:
subagent-driven-development). The plan carries complete code and exact file
content, so implementer subagents run at the Sonnet tier with Opus-tier
reviewers, per the machine-global subagent-tier rule. **Exception: Task 3
(simulator verification) runs inline in the controller session** — it needs
the interactive Connect IQ simulator and its settings editor, which a
dispatched subagent cannot drive.

## Global Constraints

- `monkeyc -w` clean (warnings-as-errors) on **fr70 / fr265s / fr265 /
  fr965** after every task that touches code or resources.
- Build environment: `export PATH="/usr/local/opt/openjdk/bin:$PATH"`;
  SDK at `~/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.1.0-2026-03-09-6a872a80b`;
  signing key `~/Github/Flightdeck/developer_key.der` (outside the repo,
  never committed).
- `python3 tools/check_font_metrics.py` stays green.
- `resources/settings/settings.xml` must be byte-identical to a fresh
  `python3 tools/gen_settings.py` run.
- Defaults (metric id per slot, in slot-index order):
  layout 5 = `1,6,3,7,5` · layout 4 = `1,7,3,4` · layout 3 = `1,7,3` ·
  layout 2 = `1,7` · layout 1 = `1`. `layout` defaults to `4`.
- No changes to `Theme.mc` logic, theme subclasses, fonts, manifest, or
  `store/description.txt`.
- Commits: stamp `Co-Authored-By:` with the current AI model; confirm
  `git branch --show-current` prints `49-per-layout-slots` before each
  commit.

---

### Task 1: Per-layout properties, generated settings, and the view read path

One atomic commit: resources and the view must change together (the resource
compiler fails if `settings.xml` references deleted properties, and the app
crashes at runtime if the view reads properties that no longer exist), so
this is the smallest unit that builds and runs.

**Files:**
- Create: `tools/gen_settings.py`
- Modify (regenerate): `resources/settings/settings.xml`
- Modify: `resources/settings/properties.xml` (full replacement below)
- Modify: `resources/strings/strings.xml` (one block replaced)
- Modify: `source/FlightdeckView.mc` (fields + `readSettings`)
- Modify: `source/Theme.mc` (two comment lines), `source/Metrics.mc` (one
  comment block)

**Interfaces:**
- Consumes: `Theme.draw(dc, m, fonts, light, slots, showLabels, layout)` —
  unchanged; `slots` is `Array<Number>` indexed by `PresetSlot.slot`
  (layout 4: 0→N, 1→E, 2→S, 3→W) and by `drawGrid` (layout 5: 0→centre,
  1→TL, 2→TR, 3→BL, 4→BR).
- Produces: the 15 property ids `l5_c,l5_tl,l5_tr,l5_bl,l5_br,l4_n,l4_e,
  l4_s,l4_w,l3_top,l3_mid,l3_bot,l2_top,l2_bot,l1_c` and the 15 string ids
  used below — Task 2's docs and Task 3's checks refer to these.

- [ ] **Step 1: Write `tools/gen_settings.py`** with exactly this content:

```python
#!/usr/bin/env python3
"""Regenerate resources/settings/settings.xml (the Garmin Connect settings UI).

Four global settings plus 15 metric pickers -- one per slot of each layout
preset -- where every picker repeats the same metric list. Hand-editing 15
copies invites drift, so this script owns the file: edit the tables below,
re-run, commit the result. Deterministic; running it twice is a no-op.

Property ids and defaults live in resources/settings/properties.xml and
titles in resources/strings/strings.xml (both hand-written); this file only
wires property ids to title strings and repeats the metric list.
"""

import os

# Metric entries shared by every slot picker: (value, string id), in display
# order. Value 13 is historically unused and intentionally absent.
METRICS = [
    (0, "MetricOff"), (1, "MetricTimer"), (2, "MetricClock"),
    (3, "MetricDist"), (4, "MetricLDist"), (5, "MetricLTime"),
    (6, "MetricPace"), (7, "MetricLPace"), (8, "MetricCPace"),
    (9, "MetricSpeed"), (10, "MetricCSpd"), (11, "MetricHR"),
    (12, "MetricAHR"), (14, "MetricCad"), (15, "MetricACad"),
    (16, "MetricCal"), (17, "MetricAsc"), (18, "MetricAlt"),
]

# Slot pickers: (property id, title string id), in display order -- the
# shipped-default layout (4) first, then the rest by descending field count.
# Within a layout, the order matches Theme's slot indices (#49 spec).
SLOTS = [
    ("l4_n", "SettingL4N"), ("l4_e", "SettingL4E"),
    ("l4_s", "SettingL4S"), ("l4_w", "SettingL4W"),
    ("l5_c", "SettingL5C"), ("l5_tl", "SettingL5TL"),
    ("l5_tr", "SettingL5TR"), ("l5_bl", "SettingL5BL"),
    ("l5_br", "SettingL5BR"),
    ("l3_top", "SettingL3Top"), ("l3_mid", "SettingL3Mid"),
    ("l3_bot", "SettingL3Bot"),
    ("l2_top", "SettingL2Top"), ("l2_bot", "SettingL2Bot"),
    ("l1_c", "SettingL1C"),
]

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), os.pardir,
                   "resources", "settings", "settings.xml")


def list_setting(prop, title, entries):
    lines = ['        <setting propertyKey="@Properties.%s" title="@Strings.%s">'
             % (prop, title),
             '            <settingConfig type="list">']
    for value, sid in entries:
        lines.append('                <listEntry value="%d">@Strings.%s</listEntry>'
                     % (value, sid))
    lines.append('            </settingConfig>')
    lines.append('        </setting>')
    return lines


def toggle_setting(prop, title):
    return ['        <setting propertyKey="@Properties.%s" title="@Strings.%s">'
            % (prop, title),
            '            <settingConfig type="boolean" />',
            '        </setting>']


def main():
    lines = ['<resources>',
             '    <!-- Generated by tools/gen_settings.py; edit that script, not this file. -->',
             '    <settings>']
    lines += list_setting("theme", "SettingTheme",
                          [(0, "ThemeCockpit"), (1, "ThemeBridge"),
                           (2, "ThemeWall"), (3, "ThemePhosphor")])
    lines += list_setting("mode", "SettingMode",
                          [(0, "ModeDark"), (1, "ModeLight")])
    lines += list_setting("layout", "SettingLayout",
                          [(5, "Layout5"), (4, "Layout4"), (3, "Layout3"),
                           (2, "Layout2"), (1, "Layout1")])
    lines += toggle_setting("showLabels", "SettingLabels")
    for prop, title in SLOTS:
        lines += list_setting(prop, title, METRICS)
    lines += ['    </settings>', '</resources>', '']
    with open(OUT, "w") as f:
        f.write("\n".join(lines))
    print("wrote " + os.path.normpath(OUT))


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Run the generator**

Run: `python3 tools/gen_settings.py`
Expected: prints `wrote .../resources/settings/settings.xml`;
`git diff --stat resources/settings/settings.xml` shows the file rewritten.
Spot-check: `grep -c '<setting ' resources/settings/settings.xml` prints
**19** (theme, mode, layout, showLabels + 15 pickers), and the file contains
no `slot0`.

- [ ] **Step 3: Replace `resources/settings/properties.xml`** with exactly:

```xml
<resources>
    <properties>
        <!-- 0 Cockpit, 1 Bridge, 2 Bulkhead, 3 Phosphor -->
        <property id="theme" type="number">0</property>
        <!-- 0 dark, 1 light -->
        <property id="mode" type="number">0</property>
        <!-- field-count layout preset: 5,4,3,2,1 -->
        <property id="layout" type="number">4</property>
        <!-- show short metric labels -->
        <property id="showLabels" type="boolean">false</property>

        <!-- Per-layout metric slots: metric id per position, 0 = Off. Each
             layout preset has its own independent set (#49); order within a
             layout matches Theme's slot indices. Ids used below: 1 Timer,
             3 Dist, 4 LDist, 5 LTime, 6 Pace, 7 LPace (full vocabulary in
             settings.xml). -->
        <!-- 4-field compass N/E/S/W: Timer / LPace / Dist / LDist -->
        <property id="l4_n" type="number">1</property>
        <property id="l4_e" type="number">7</property>
        <property id="l4_s" type="number">3</property>
        <property id="l4_w" type="number">4</property>
        <!-- 5-field grid C/TL/TR/BL/BR: Timer / Pace / Dist / LPace / LTime -->
        <property id="l5_c" type="number">1</property>
        <property id="l5_tl" type="number">6</property>
        <property id="l5_tr" type="number">3</property>
        <property id="l5_bl" type="number">7</property>
        <property id="l5_br" type="number">5</property>
        <!-- 3-field column: Timer / LPace / Dist -->
        <property id="l3_top" type="number">1</property>
        <property id="l3_mid" type="number">7</property>
        <property id="l3_bot" type="number">3</property>
        <!-- 2-field: Timer / LPace -->
        <property id="l2_top" type="number">1</property>
        <property id="l2_bot" type="number">7</property>
        <!-- 1-field: Timer -->
        <property id="l1_c" type="number">1</property>
    </properties>
</resources>
```

- [ ] **Step 4: Update `resources/strings/strings.xml`** — replace exactly
this block (currently under `<!-- field configuration -->`):

```xml
    <string id="SettingSlot0">Field 1 (center)</string>
    <string id="SettingSlot1">Field 2 (top-left)</string>
    <string id="SettingSlot2">Field 3 (top-right)</string>
    <string id="SettingSlot3">Field 4 (bottom-left)</string>
    <string id="SettingSlot4">Field 5 (bottom-right)</string>
```

with (keep the surrounding `SettingLabels`/`SettingLayout` lines where they
are):

```xml
    <string id="SettingL4N">4 fields · North (top)</string>
    <string id="SettingL4E">4 fields · East (right)</string>
    <string id="SettingL4S">4 fields · South (bottom)</string>
    <string id="SettingL4W">4 fields · West (left)</string>
    <string id="SettingL5C">5 fields · Center</string>
    <string id="SettingL5TL">5 fields · Top left</string>
    <string id="SettingL5TR">5 fields · Top right</string>
    <string id="SettingL5BL">5 fields · Bottom left</string>
    <string id="SettingL5BR">5 fields · Bottom right</string>
    <string id="SettingL3Top">3 fields · Top</string>
    <string id="SettingL3Mid">3 fields · Middle</string>
    <string id="SettingL3Bot">3 fields · Bottom</string>
    <string id="SettingL2Top">2 fields · Top</string>
    <string id="SettingL2Bot">2 fields · Bottom</string>
    <string id="SettingL1C">1 field · Center</string>
```

(These titles render only in the Garmin Connect app, never through the
watch's bitmap fonts; `strings.xml` is UTF-8, so `·` is safe.)

- [ ] **Step 5: Update `source/FlightdeckView.mc`.** Replace the two field
declarations

```monkeyc
    private var _slots as Array<Number> = [1, 6, 3, 7, 5];
```
and
```monkeyc
    private var _layout as Number = 5;
```

with

```monkeyc
    // The active layout's metric ids, in slot-index order (see the layout
    // tables in Theme.presetSlots / drawGrid). Length tracks the layout.
    private var _slots as Array<Number> = [1, 7, 3, 4];
```
and
```monkeyc
    private var _layout as Number = 4;
```

and replace the whole `readSettings` function with:

```monkeyc
    private function readSettings() as Void {
        _themeIdx = numProp("theme", 0);
        _light = (numProp("mode", 0) == 1);
        _layout = numProp("layout", 4);
        // Each layout has its own independent property set (#49). Read only
        // the active layout's, positionally ordered to match Theme's slot
        // indices. Fallback defaults mirror properties.xml.
        if (_layout == 5) {
            _slots = [numProp("l5_c", 1), numProp("l5_tl", 6), numProp("l5_tr", 3),
                      numProp("l5_bl", 7), numProp("l5_br", 5)];
        } else if (_layout == 4) {
            _slots = [numProp("l4_n", 1), numProp("l4_e", 7),
                      numProp("l4_s", 3), numProp("l4_w", 4)];
        } else if (_layout == 3) {
            _slots = [numProp("l3_top", 1), numProp("l3_mid", 7), numProp("l3_bot", 3)];
        } else if (_layout == 2) {
            _slots = [numProp("l2_top", 1), numProp("l2_bot", 7)];
        } else {
            // 1, and any out-of-range stored value: Theme.presetSlots'
            // else-branch draws 1-field for those too, so stay in step.
            _slots = [numProp("l1_c", 1)];
        }
        _showLabels = boolProp("showLabels", false);
    }
```

- [ ] **Step 6: Comment-only updates.** In `source/Theme.mc`:
line 112's `// One field slot within a preset: which config slot it draws, …`
→ `// One field slot within a preset: which slot of the active layout's
slots array it draws, …` (keep the rest of the line), and line 115's
trailing comment `// config slot index 0..4` → `// index into the active
layout's slots array`. In `source/Metrics.mc`, replace the three comment
lines

```
// Default slot map (settings defaults, reproducing the original layout):
//   centre = Timer     top-left = Avg pace   top-right = Distance
//                      bot-left = Lap pace   bot-right = Lap time
```

with

```
// Default metric ids per layout live in resources/settings/properties.xml —
// each layout preset carries its own independent slot set (#49).
```

- [ ] **Step 7: Build, warnings-as-errors, all four devices**

```sh
export PATH="/usr/local/opt/openjdk/bin:$PATH"
SDK="$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.1.0-2026-03-09-6a872a80b"
for d in fr70 fr265s fr265 fr965; do
  "$SDK/bin/monkeyc" -f monkey.jungle -o /tmp/check-$d.prg \
    -y ~/Github/Flightdeck/developer_key.der -d $d -w || break
done
```

Expected: `BUILD SUCCESSFUL` four times, no warnings.

- [ ] **Step 8: Guards**

Run: `python3 tools/check_font_metrics.py`
Expected: green (unchanged by this task, run anyway).
Run: `python3 tools/gen_settings.py && git diff --stat resources/settings/settings.xml`
Expected: prints the `wrote` line and the diff is **empty** (byte-stable).
Run: `grep -rn "slot0\|slot1\|slot2\|slot3\|slot4" resources ./source` (from
the repo root; keep the `./` — a bare `source` argument trips the session's
Bash guard)
Expected: no matches.

- [ ] **Step 9: Commit**

```bash
git add tools/gen_settings.py resources/settings/settings.xml \
    resources/settings/properties.xml resources/strings/strings.xml \
    source/FlightdeckView.mc source/Theme.mc source/Metrics.mc
git commit -m "feat: independent per-layout metric slots, default layout 4 (#49)"
```

---

### Task 2: Documentation — CHANGELOG and CLAUDE.md

**Files:**
- Modify: `CHANGELOG.md` (append to the `## [Unreleased]` section)
- Modify: `CLAUDE.md` (two generator mentions)

**Interfaces:**
- Consumes: the Task 1 property scheme and defaults (named in prose only).
- Produces: the `[Unreleased]` bullets #50 will fold into the release notes;
  the store "What's changed" draft stays in the spec's Migration section for
  #50 to carry.

- [ ] **Step 1: Append to `CHANGELOG.md`'s `## [Unreleased]` list** (after
the existing compass bullet):

```markdown
- Each layout now has its own field configuration with its own defaults:
  choosing metrics for one layout no longer changes any other. The 4-field
  compass starts as Timer / Lap pace / Distance / Lap distance.
- New installs start on the 4-field compass layout instead of the 5-field
  grid.
- One-time reset: because the field settings changed shape, custom field
  choices from earlier versions revert to the new defaults — set them again
  in Garmin Connect. Theme, mode, layout and label settings are kept.
```

- [ ] **Step 2: Update `CLAUDE.md`.** In the Architecture bullet for
`tools/`, change `` (`gen_fonts.py`, `gen_icon.py`, `gen_phosphor_watermark.sh`) ``
to `` (`gen_fonts.py`, `gen_icon.py`, `gen_settings.py`, `gen_phosphor_watermark.sh`) ``.
In the "Regenerate assets:" paragraph, extend the sentence so it ends:
`` `tools/gen_phosphor_watermark.sh` needs ImageMagick; `python3 tools/gen_settings.py` (pure stdlib) emits `resources/settings/settings.xml`. ``

- [ ] **Step 3: Commit**

```bash
git add CHANGELOG.md CLAUDE.md
git commit -m "docs: changelog + CLAUDE.md for per-layout slots (#49)"
```

---

### Task 3: Simulator verification (controller-run, inline)

Interactive — needs the Connect IQ simulator and its settings editor; run in
the controller session, not a subagent. No commit unless a defect forces a
fix (a defect loops back through Task 1's build/guard steps).

**Files:** none (verification only).

**Interfaces:**
- Consumes: `/tmp/check-fr965.prg` from Task 1 Step 7 (rebuild if stale).

- [ ] **Step 1: Launch** — start the simulator (`connectiq`), then
`"$SDK/bin/monkeydo" /tmp/check-fr965.prg fr965`, add Flightdeck to a run
data screen if prompted, start the activity simulation.

- [ ] **Step 2: Fresh-install default** — with no saved settings, the field
comes up on the **4-field compass** showing Timer (N), Lap pace (E),
Distance (S), Lap distance (W); labels off; no clipping.

- [ ] **Step 3: Per-layout defaults** — via Settings → Edit Application
Settings, switch `layout` to 5, 3, 2, 1 in turn and confirm each shows its
spec defaults: 5 = Timer/Pace/Dist/LPace/LTime, 3 = Timer/LPace/Dist,
2 = Timer/LPace, 1 = Timer.

- [ ] **Step 4: Independence** — set the 3-field top picker to Clock, then
confirm: layout 3 shows Clock on top, layouts 4 and 5 still show their
defaults (switch to each). Set it back.

- [ ] **Step 5: Off + labels** — set the 4-field East picker to Off:
E blanks and W renders at its own best cut (no group partner). Toggle
`Show labels` on briefly to confirm labels still draw (the known layout-4
overlap from #47 is expected and out of scope), then off.

- [ ] **Step 6: Themes** — cycle the four themes in dark and light on
layout 4 defaults; confirm no decoration regressions (blips absent, Bridge
reticle absent, per #47).

- [ ] **Step 7: Record results** — note each check's outcome in the session
transcript / PR `Test expectations` section; any failure is a defect to fix
before the PR opens.

---

## PR notes (for the executor)

Open with the `dcltdw:opening-a-pr` skill; base `main`; body must carry
`Closes #49` and, in `Operational impact`: no rebuild/re-add needed (the
field set is unchanged), but **existing users' custom field choices reset to
the new defaults** (no migration shim — pinned decision), and fresh installs
now land on the 4-field compass. The store "What's changed" wording for #50
is drafted in the spec's Migration section — do not edit
`store/description.txt` in this PR.
