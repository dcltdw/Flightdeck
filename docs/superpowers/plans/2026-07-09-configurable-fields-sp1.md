# Configurable Fields — SP1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Flightdeck's five fields configurable — any of 18 metrics (or Off) per slot, in today's 4-corner + center layout, with a global labels-off-by-default toggle.

**Architecture:** `Metrics.mc` becomes a registry that stores the current `Activity.Info` + lap baseline and answers `format(id)` / `label(id)`. Settings gain five `slot` list-pickers + a `showLabels` boolean. `Theme.draw()` loops the five fixed positions, resolving each slot's metric through `Metrics`, keeping today's positions, fonts, and positional palette roles (center = warm-white, top row = white, bottom row = accent).

**Tech Stack:** Monkey C / Connect IQ (SDK 9.1.0). No unit-test framework — **verification is `monkeyc -w` (type-checked compile) across the four resolution buckets, plus simulator observation** for behaviour (per CLAUDE.md).

**Spec:** `docs/superpowers/specs/2026-07-09-configurable-fields-sp1-design.md`.

## Global Constraints

- `monkeyc -w` (warnings-as-errors) must stay clean on `fr70`, `fr265s`, `fr265`, `fr965`.
- **No new manifest permissions** — verified: all 18 metrics (incl. HR zone via `UserProfile.getHeartRateZones`) are permission-free. Re-confirm the manifest declares zero permissions.
- Metric ids (enum, 0-based): `OFF=0, TIMER=1, CLOCK=2, DIST=3, LDIST=4, LTIME=5, PACE=6, LPACE=7, CPACE=8, SPEED=9, CSPD=10, HR=11, AHR=12, ZONE=13, CAD=14, ACAD=15, CAL=16, ASC=17, ALT=18`. **`ZONE` (13) is DROPPED and reserved** — `UserProfile.getHeartRateZones` requires the `UserProfile` permission, which would break the "Requests no permissions" claim. Keep the enum constant (so 14–18 don't shift) but implement no `format`/`label` case for it and do NOT offer it in settings. **17 selectable metrics.**
- Labels are UPPER-only (label font glyph set = `A–Z` + space): `TIMER CLOCK DIST LDIST LTIME PACE LPACE CPACE SPEED CSPD HR AHR CAD ACAD CAL ASC ALT` (no `ZONE`).
- Defaults reproduce today's face: `slot0=TIMER(1) slot1=PACE(6) slot2=DIST(3) slot3=LPACE(7) slot4=LTIME(5)`, `showLabels=false`.
- SP1 adds **no fonts / bitmaps**. Layout presets and bigger fonts are SP2. **No store release until SP2.**
- Repo conventions: branch → PR → wait; board Todo→In Progress→Done; PR bodies per `universal.md` (incl. `Provenance`); commits stamped `Co-Authored-By`.

**Compile command** (used in every task's verify step):

```sh
SDK="$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.1.0-2026-03-09-6a872a80b"
export PATH="$(brew --prefix openjdk)/bin:$PATH"
KEY="$HOME/Github/swarsy-face/developer_key.der"
"$SDK/bin/monkeyc" -f monkey.jungle -o /tmp/check.prg -y "$KEY" -d fr70 -w
```

Expected: `BUILD SUCCESSFUL`.

## File structure

- `source/Metrics.mc` (modify) — from "compute 5 fixed strings" to the registry (`_info`, `format`, `label`, formatters). Owns all metric logic.
- `resources/settings/settings.xml` (modify) — five `slot` list settings + `showLabels` boolean.
- `resources/settings/properties.xml` (modify) — the six new properties with defaults.
- `resources/strings/strings.xml` (modify) — metric names + setting titles.
- `source/Theme.mc` (modify) — `draw()` gains `slots` + `showLabels`, loops positions via helpers.
- `source/FlightdeckView.mc` (modify) — read the new settings; pass them to `draw()`.

Themes under `source/themes/`, `ThemeRegistry.mc`, `decorate()`, and the title banners are **unchanged**.

---

### Task 1: Metrics registry structure (ids + `format`/`label` for existing-helper metrics)

**Files:**
- Modify: `source/Metrics.mc`

**Interfaces:**
- Produces: `Metrics.format(id as Number) as String`, `Metrics.label(id as Number) as String`, the `METRIC_*` enum, and `Metrics` stores `_info` in `update()`. Lap baseline (`_lapStartMs`, `_lapStartDist`) already set in `onLap()`. This task wires only the metrics that reuse existing helpers; the rest return `"--"` until Task 2.

- [ ] **Step 1: Add the metric-id enum** at the top of `source/Metrics.mc`, after the imports:

```monkeyc
enum {
    METRIC_OFF = 0,
    METRIC_TIMER, METRIC_CLOCK, METRIC_DIST, METRIC_LDIST, METRIC_LTIME,
    METRIC_PACE, METRIC_LPACE, METRIC_CPACE, METRIC_SPEED, METRIC_CSPD,
    METRIC_HR, METRIC_AHR, METRIC_ZONE, METRIC_CAD, METRIC_ACAD,
    METRIC_CAL, METRIC_ASC, METRIC_ALT
}
```

- [ ] **Step 2: Store the latest info.** In the `Metrics` class add a field near `_lapStartMs`:

```monkeyc
    private var _info as Activity.Info?;
```

And at the **top** of `update(info)` add (leave the existing body for now — the view still reads the old vars until Task 4):

```monkeyc
        _info = info;
```

- [ ] **Step 3: Add a private `lapPaceStr` helper** (extracts the existing lap-pace logic). **Name it `lapPaceStr`, not `lapPace`** — the class still has a public `lapPace` field until Task 4, and a method + field can't share a name. Add to the `Metrics` class:

```monkeyc
    private function lapPaceStr(info as Activity.Info) as String {
        var lapMs = timerMs(info) - _lapStartMs;
        var lapDist = distM(info) - _lapStartDist;
        if (lapMs > 0 && lapDist > 0.0) {
            return formatPace(lapDist / (lapMs / 1000.0));
        }
        return "--:--";
    }
```

- [ ] **Step 4: Add `format` and `label`** as public methods on `Metrics`:

```monkeyc
    function format(id as Number) as String {
        var info = _info;
        if (info == null) { return "--"; }
        switch (id) {
            case METRIC_TIMER: return formatClock(timerMs(info));
            case METRIC_DIST:  return formatDistance(distM(info));
            case METRIC_LDIST: return formatDistance(distM(info) - _lapStartDist);
            case METRIC_LTIME: return formatClock(timerMs(info) - _lapStartMs);
            case METRIC_PACE:  return formatPace(info.averageSpeed);
            case METRIC_LPACE: return lapPaceStr(info);
            case METRIC_CPACE: return formatPace(info.currentSpeed);
            default:           return "--";
        }
    }

    function label(id as Number) as String {
        switch (id) {
            case METRIC_TIMER: return "TIMER";
            case METRIC_CLOCK: return "CLOCK";
            case METRIC_DIST:  return "DIST";
            case METRIC_LDIST: return "LDIST";
            case METRIC_LTIME: return "LTIME";
            case METRIC_PACE:  return "PACE";
            case METRIC_LPACE: return "LPACE";
            case METRIC_CPACE: return "CPACE";
            case METRIC_SPEED: return "SPEED";
            case METRIC_CSPD:  return "CSPD";
            case METRIC_HR:    return "HR";
            case METRIC_AHR:   return "AHR";
            case METRIC_ZONE:  return "ZONE";
            case METRIC_CAD:   return "CAD";
            case METRIC_ACAD:  return "ACAD";
            case METRIC_CAL:   return "CAL";
            case METRIC_ASC:   return "ASC";
            case METRIC_ALT:   return "ALT";
            default:           return "";
        }
    }
```

- [ ] **Step 5: Compile-verify.** Run the compile command. Expected: `BUILD SUCCESSFUL`.

- [ ] **Step 6: Commit.**

```sh
git add source/Metrics.mc
git commit -m "feat: Metrics registry scaffold (ids, format/label for existing-helper metrics)"
```

---

### Task 2: New formatter helpers (speed, int, elevation, clock, HR zone)

**Files:**
- Modify: `source/Metrics.mc`

**Interfaces:**
- Consumes: the `METRIC_*` enum, `_info`, `_statute` from Task 1.
- Produces: `format(id)` now handles ids `CLOCK, SPEED, CSPD, HR, AHR, ZONE, CAD, ACAD, CAL, ASC, ALT`.

- [ ] **Step 1: Add `Toybox.UserProfile` import** at the top of `source/Metrics.mc`:

```monkeyc
import Toybox.UserProfile;
```

- [ ] **Step 2: Add the formatter helpers** to the `Metrics` class:

```monkeyc
    private function formatSpeed(speed as Float or Null) as String {
        if (speed == null || speed < 0.0) { return "--"; }
        var unit = _statute ? 2.236936 : 3.6; // m/s -> mph / km/h
        return (speed * unit).format("%.1f");
    }

    private function formatInt(v as Number or Null) as String {
        return (v == null) ? "--" : v.format("%d");
    }

    private function formatElevation(m as Lang.Numeric or Null) as String {
        if (m == null) { return "--"; }
        var v = _statute ? (m * 3.28084) : m;
        return v.toNumber().format("%d");
    }

    private function formatClockTime() as String {
        var t = System.getClockTime();
        var h = t.hour;
        if (!System.getDeviceSettings().is24Hour) {
            h = h % 12;
            if (h == 0) { h = 12; }
        }
        return h.format("%d") + ":" + t.min.format("%02d");
    }

    private function hrZone(hr as Number or Null) as String {
        if (hr == null) { return "--"; }
        var z = UserProfile.getHeartRateZones(UserProfile.HR_ZONE_SPORT_RUNNING);
        if (z == null || z.size() < 2) { return "--"; }
        var zone = 1;
        for (var i = 1; i < z.size() && i <= 5; i++) {
            if (hr >= z[i]) { zone = i + 1; }
        }
        if (zone > 5) { zone = 5; }
        return zone.format("%d");
    }
```

- [ ] **Step 3: Wire the remaining ids into `format`.** Add these cases to the `format(id)` switch (before `default`):

```monkeyc
            case METRIC_CLOCK: return formatClockTime();
            case METRIC_SPEED: return formatSpeed(info.averageSpeed);
            case METRIC_CSPD:  return formatSpeed(info.currentSpeed);
            case METRIC_HR:    return formatInt(info.currentHeartRate);
            case METRIC_AHR:   return formatInt(info.averageHeartRate);
            case METRIC_ZONE:  return hrZone(info.currentHeartRate);
            case METRIC_CAD:   return formatInt(info.currentCadence);
            case METRIC_ACAD:  return formatInt(info.averageCadence);
            case METRIC_CAL:   return formatInt(info.calories);
            case METRIC_ASC:   return formatElevation(info.totalAscent);
            case METRIC_ALT:   return formatElevation(info.altitude);
```

- [ ] **Step 4: Compile-verify.** Run the compile command. Expected: `BUILD SUCCESSFUL`. (If a field name is rejected by the type checker, cross-check it against `Activity.Info` in `api.debug.xml`.)

- [ ] **Step 5: Commit.**

```sh
git add source/Metrics.mc
git commit -m "feat: Metrics formatters for speed/int/elevation/clock/HR-zone"
```

---

### Task 3: Settings, properties, and strings

**Files:**
- Modify: `resources/settings/settings.xml`
- Modify: `resources/settings/properties.xml`
- Modify: `resources/strings/strings.xml`

**Interfaces:**
- Produces: properties `slot0..slot4` (number) and `showLabels` (boolean), read by the view in Task 4.

- [ ] **Step 1: Add the properties.** In `resources/settings/properties.xml`, inside `<properties>`, after the `mode` property:

```xml
        <!-- field slots: metric id per position (0 = Off) -->
        <property id="slot0" type="number">1</property>
        <property id="slot1" type="number">6</property>
        <property id="slot2" type="number">3</property>
        <property id="slot3" type="number">7</property>
        <property id="slot4" type="number">5</property>
        <!-- show short metric labels -->
        <property id="showLabels" type="boolean">false</property>
```

- [ ] **Step 2: Add the strings.** In `resources/strings/strings.xml`, inside `<resources>`, after the existing settings strings:

```xml
    <!-- field configuration -->
    <string id="SettingSlot0">Field 1 (center)</string>
    <string id="SettingSlot1">Field 2 (top-left)</string>
    <string id="SettingSlot2">Field 3 (top-right)</string>
    <string id="SettingSlot3">Field 4 (bottom-left)</string>
    <string id="SettingSlot4">Field 5 (bottom-right)</string>
    <string id="SettingLabels">Show labels</string>
    <string id="MetricOff">Off</string>
    <string id="MetricTimer">Timer (elapsed)</string>
    <string id="MetricClock">Clock</string>
    <string id="MetricDist">Distance</string>
    <string id="MetricLDist">Lap distance</string>
    <string id="MetricLTime">Lap time</string>
    <string id="MetricPace">Avg pace</string>
    <string id="MetricLPace">Lap pace</string>
    <string id="MetricCPace">Current pace</string>
    <string id="MetricSpeed">Avg speed</string>
    <string id="MetricCSpd">Current speed</string>
    <string id="MetricHR">Heart rate</string>
    <string id="MetricAHR">Avg heart rate</string>
    <string id="MetricCad">Cadence</string>
    <string id="MetricACad">Avg cadence</string>
    <string id="MetricCal">Calories</string>
    <string id="MetricAsc">Total ascent</string>
    <string id="MetricAlt">Altitude</string>
```

- [ ] **Step 3: Add `slot0` and the `showLabels` settings.** In `resources/settings/settings.xml`, inside `<settings>`, after the `mode` setting, add the `slot0` list. The 18 `<listEntry>` lines below are the **metric list** (Off + 17 metrics — HR zone / value 13 is intentionally omitted) — reuse them verbatim for slots 1–4 in the next step.

```xml
        <setting propertyKey="@Properties.slot0" title="@Strings.SettingSlot0">
            <settingConfig type="list">
                <listEntry value="0">@Strings.MetricOff</listEntry>
                <listEntry value="1">@Strings.MetricTimer</listEntry>
                <listEntry value="2">@Strings.MetricClock</listEntry>
                <listEntry value="3">@Strings.MetricDist</listEntry>
                <listEntry value="4">@Strings.MetricLDist</listEntry>
                <listEntry value="5">@Strings.MetricLTime</listEntry>
                <listEntry value="6">@Strings.MetricPace</listEntry>
                <listEntry value="7">@Strings.MetricLPace</listEntry>
                <listEntry value="8">@Strings.MetricCPace</listEntry>
                <listEntry value="9">@Strings.MetricSpeed</listEntry>
                <listEntry value="10">@Strings.MetricCSpd</listEntry>
                <listEntry value="11">@Strings.MetricHR</listEntry>
                <listEntry value="12">@Strings.MetricAHR</listEntry>
                <listEntry value="14">@Strings.MetricCad</listEntry>
                <listEntry value="15">@Strings.MetricACad</listEntry>
                <listEntry value="16">@Strings.MetricCal</listEntry>
                <listEntry value="17">@Strings.MetricAsc</listEntry>
                <listEntry value="18">@Strings.MetricAlt</listEntry>
            </settingConfig>
        </setting>
        <setting propertyKey="@Properties.showLabels" title="@Strings.SettingLabels">
            <settingConfig type="boolean" />
        </setting>
```

- [ ] **Step 4: Add slots 1–4.** Immediately after the `slot0` setting block (before `showLabels` is fine too), add four more `<setting>` blocks **identical to `slot0`** except:
  - `slot1`: `propertyKey="@Properties.slot1" title="@Strings.SettingSlot1"`
  - `slot2`: `propertyKey="@Properties.slot2" title="@Strings.SettingSlot2"`
  - `slot3`: `propertyKey="@Properties.slot3" title="@Strings.SettingSlot3"`
  - `slot4`: `propertyKey="@Properties.slot4" title="@Strings.SettingSlot4"`

  Each contains the **same 18 `<listEntry>` lines** as `slot0`.

- [ ] **Step 5: Compile-verify.** Run the compile command. Expected: `BUILD SUCCESSFUL` (resource compiler validates the settings/strings). Then confirm no permissions crept in:

```sh
grep -A3 "iq:permissions" manifest.xml || echo "no permissions block (good)"
```

Expected: `no permissions block (good)` (or an empty permissions element — must not list any permission).

- [ ] **Step 6: Commit.**

```sh
git add resources/settings/settings.xml resources/settings/properties.xml resources/strings/strings.xml
git commit -m "feat: slot0-4 + showLabels settings, metric strings"
```

---

### Task 4: Wire the view + theme to the config; remove the old fixed fields

**Files:**
- Modify: `source/FlightdeckView.mc`
- Modify: `source/Theme.mc`
- Modify: `source/Metrics.mc`

**Interfaces:**
- Consumes: `Metrics.format`/`label` (Tasks 1–2); `slot0..slot4`, `showLabels` (Task 3).
- Produces: the running field, driven entirely by settings.

- [ ] **Step 1: Read the new settings in the view.** In `source/FlightdeckView.mc` add fields near `_light`:

```monkeyc
    private var _slots as Array<Number> = [1, 6, 3, 7, 5];
    private var _showLabels as Boolean = false;
```

Add a `boolProp` helper next to `numProp`:

```monkeyc
    private function boolProp(key as String, dflt as Boolean) as Boolean {
        var v = Application.Properties.getValue(key);
        return (v instanceof Boolean) ? v : dflt;
    }
```

Replace the body of `readSettings()` with:

```monkeyc
    private function readSettings() as Void {
        _themeIdx = numProp("theme", 0);
        _light = (numProp("mode", 0) == 1);
        _slots = [numProp("slot0", 1), numProp("slot1", 6), numProp("slot2", 3),
                  numProp("slot3", 7), numProp("slot4", 5)];
        _showLabels = boolProp("showLabels", false);
    }
```

- [ ] **Step 2: Pass the config into `draw()`.** In `onUpdate`, change the draw call to:

```monkeyc
        ThemeRegistry.get(_themeIdx).draw(dc, _m, fonts, _light, _slots, _showLabels);
```

- [ ] **Step 3: Simplify `Metrics.update` and drop the old public vars.** In `source/Metrics.mc`, replace the whole `update(info)` method with:

```monkeyc
    function update(info as Activity.Info) as Void {
        _info = info;
    }
```

Delete the now-unused public fields `sessionPace`, `sessionDist`, `heroTime`, `lapPace`, `lapTime`. Keep `_statute`, `_lapStartMs`, `_lapStartDist`, `_info`, `onLap`, `timerMs`, `distM`, and all the formatter/helper methods.

- [ ] **Step 4: Rewrite `Theme.draw()` to loop the slots.** In `source/Theme.mc` replace the `draw(...)` method with:

```monkeyc
    function draw(dc as Graphics.Dc, m as Metrics, fonts as Fonts, light as Boolean,
                  slots as Array<Number>, showLabels as Boolean) as Void {
        var p = buildPalette(light);
        var L = buildLayout(fonts);
        var s = dc.getWidth() / 390.0;
        L.scale(s);

        dc.setColor(Graphics.COLOR_WHITE, p.ground);
        dc.clear();
        decorate(dc, light, s);

        var lf = L.lblFont;
        var vf = L.valFont;
        var hf = L.heroFont;
        if (lf == null || vf == null || hf == null) {
            return; // misconfigured layout; nothing to draw
        }

        var C = Graphics.TEXT_JUSTIFY_CENTER;
        var Lj = Graphics.TEXT_JUSTIFY_LEFT;
        var Rj = Graphics.TEXT_JUSTIFY_RIGHT;

        var tf = L.titleFont;
        var tt = L.title;
        if (tf != null && tt != null) {
            txt(dc, L.ctr, L.titleY, L.titleAsc, tf, p.title, tt, C);
        }

        // Values grow toward centre: the anchor sits half a 4-char value in
        // from the column centre (left column left-justified, right right).
        var vHalf = dc.getTextWidthInPixels("0:00", vf) / 2;

        drawValue(dc, m, slots[0], L.ctr,          L.heroY, L.heroAsc, hf, p.hero, C);
        drawValue(dc, m, slots[1], L.colL - vHalf, L.valY1, L.valAsc,  vf, p.sval, Lj);
        drawValue(dc, m, slots[2], L.colR + vHalf, L.valY1, L.valAsc,  vf, p.sval, Rj);
        drawValue(dc, m, slots[3], L.colL - vHalf, L.valY2, L.valAsc,  vf, p.lap,  Lj);
        drawValue(dc, m, slots[4], L.colR + vHalf, L.valY2, L.valAsc,  vf, p.lap,  Rj);

        if (showLabels) {
            drawLabel(dc, m, slots[1], L.colL, L.lblY1, L.lblAsc, lf, p.label);
            drawLabel(dc, m, slots[2], L.colR, L.lblY1, L.lblAsc, lf, p.label);
            drawLabel(dc, m, slots[3], L.colL, L.lblY2, L.lblAsc, lf, p.label);
            drawLabel(dc, m, slots[4], L.colR, L.lblY2, L.lblAsc, lf, p.label);
        }
    }

    private function drawValue(dc as Graphics.Dc, m as Metrics, id as Number,
                               x as Number, baseY as Number, ascent as Number,
                               font as WatchUi.FontResource, color as Number,
                               just as Graphics.TextJustification) as Void {
        if (id == 0) { return; } // Off
        txt(dc, x, baseY, ascent, font, color, m.format(id), just);
    }

    private function drawLabel(dc as Graphics.Dc, m as Metrics, id as Number,
                               x as Number, baseY as Number, ascent as Number,
                               font as WatchUi.FontResource, color as Number) as Void {
        if (id == 0) { return; } // Off
        txt(dc, x, baseY, ascent, font, color, m.label(id), Graphics.TEXT_JUSTIFY_CENTER);
    }
```

(Leave the `txt(...)` helper as-is.)

- [ ] **Step 5: Compile-verify across all four buckets.**

```sh
for d in fr70 fr265s fr265 fr965; do
  "$SDK/bin/monkeyc" -f monkey.jungle -o /tmp/check_$d.prg -y "$KEY" -d $d -w \
    && echo "$d OK" || echo "$d FAIL"
done
```

Expected: `fr70 OK` … `fr965 OK`.

- [ ] **Step 6: Simulator behaviour check.** Build for `fr965`, load in the simulator, and start a running activity simulation (Simulation → Activity Data / FIT playback). Verify:
  1. **Default:** center shows the elapsed timer; top-left/right show pace/distance; bottom-left/right show lap pace/time — **no labels**. (Matches today's content, labels off.)
  2. In **Connect IQ → Edit Settings**, set Field 2 to **Heart rate** and toggle **Show labels** on → top-left shows an `HR` label over a heart-rate value; the other corners show their labels.
  3. Set a field to **Off** → that position is blank.
  4. Before an activity / with no HR sensor, affected fields show `--` / `--:--` (placeholders), no crash.

- [ ] **Step 7: Commit.**

```sh
git add source/FlightdeckView.mc source/Theme.mc source/Metrics.mc
git commit -m "feat: drive fields from slot settings; drop the fixed 5-field layout"
```

---

## Self-review notes (author)

- **Spec coverage:** metric registry (T1–T2), settings (T3), wiring + defaults + positional colour + labels-off + Off-blanks + placeholders (T4). No-new-permissions re-checked in T3 step 5. Presets/fonts explicitly out of scope (SP2).
- **Types:** `format(id as Number) as String`, `label(id as Number) as String`, `draw(dc, m, fonts, light, slots as Array<Number>, showLabels as Boolean)`, `boolProp(key, dflt) as Boolean` — consistent across tasks.
- **No release** is cut in this plan (SP1 is the intermediate; release waits for SP2).
