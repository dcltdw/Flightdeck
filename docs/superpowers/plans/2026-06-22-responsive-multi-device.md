# Responsive Multi-Device (v0.1.1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Flightdeck render correctly across the four AMOLED runner resolutions (390/360/416/454) while staying pixel-identical at 390.

**Architecture:** Keep the existing 390-based numbers as a reference design and apply one uniform per-draw scale factor `s = dc.getWidth() / 390.0` to all geometry; ship four size-scaled bitmap-font sets in resolution-qualified resource folders, bundled per-device via the jungle so each device carries only its own assets.

**Tech Stack:** Connect IQ / Monkey C (SDK 9.1.0), Python+Pillow (font generation), ImageMagick 7 (watermark generation), jungle build config.

## Global Constraints

These apply to **every** task:

- **No unit-test framework exists for Monkey C here.** The verification gate is a clean `monkeyc -w` (warnings-as-errors → a warning fails the build) plus, where noted, a manual simulator render check. "Run the test" means "run the build command and confirm `BUILD SUCCESSFUL`".
- **Build command** (substitute the one device id named in each task for `<dev>`):
  ```sh
  export PATH="/usr/local/opt/openjdk/bin:$PATH"
  SDK="/Users/dcltdw/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.1.0-2026-03-09-6a872a80b"
  cd /Users/dcltdw/Github/Flightdeck
  "$SDK/bin/monkeyc" -f monkey.jungle -o /tmp/fd-<dev>.prg -y ~/Github/swarsy-face/developer_key.der -d <dev> -w
  ```
  Expected on success: `BUILD SUCCESSFUL` (exit 0). The developer key lives in the sibling `swarsy-face` repo and must never be copied into this repo (`.gitignore` blocks `*.der`/`*.pem`).
- **390 invariant:** at 390×390, `s == 1.0`; every scaled value must round back to its original. Any 390 render change is a regression.
- **Scope:** round AMOLED only. No rectangle/edge handling, no MIP devices.
- **Font ids never change** (`HeroFont`, `ValueFont`, `LabelFont`, `TitleFont`, `HeroBoldFont`, `ValueBoldFont`, `LabelBoldFont`) — only the underlying atlas sizes differ per bucket.
- `minApiLevel` stays `3.2.0`; `<iq:permissions/>` stays empty.
- Stamp every commit with `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`. Scan each diff for secrets before committing.
- DRY, YAGNI, frequent commits.

### Resolution buckets → device ids (resolutions verified from SDK `compiler.json`)

| Bucket | Device ids |
|---|---|
| 390×390 | `fr70`, `fr165`, `fr165m`, `fr170`, `fr170m`, `venu3s` |
| 360×360 | `fr265s` |
| 416×416 | `fr265`, `fenix843mm`, `epix2` |
| 454×454 | `fr965`, `fr970`, `fenix847mm`, `venu3` |

### Target resource layout (end state)

```
resources/                     # shared, all devices
  strings/strings.xml
  settings/settings.xml, properties.xml
  drawables/drawables.xml      # LauncherIcon ONLY
  drawables/launcher_icon.png
resources-390x390/
  fonts/  (fonts.xml + 7 atlases @390)
  drawables/ (drawables.xml: PhosphorDark/Light + 2 PNGs @390)
resources-360x360/  (same shape, scaled assets)
resources-416x416/  (same shape, scaled assets)
resources-454x454/  (same shape, scaled assets)
```

---

## Task 1: Resource reorg + jungle wiring (390 only)

De-risks the riskiest unknown — the per-device resource-qualifier mechanism — with **zero new assets**. Pure refactor: 390 output must be unchanged.

**Files:**
- Create: `resources-390x390/fonts/fonts.xml` (move), `resources-390x390/fonts/*.fnt|*.png` (move), `resources-390x390/drawables/drawables.xml` (new), `resources-390x390/drawables/phosphor_dark.png`, `phosphor_light.png` (move)
- Modify: `resources/drawables/drawables.xml` (drop Phosphor entries), `monkey.jungle`
- Delete (after move): `resources/fonts/`, `resources/drawables/phosphor_*.png`

**Interfaces:**
- Produces: the `resources-390x390/` bucket folder and the jungle `resourcePath` pattern that Tasks 4–6 replicate for other buckets.

- [ ] **Step 1: Move the 390 fonts and watermark into the bucket folder**

```sh
cd /Users/dcltdw/Github/Flightdeck
mkdir -p resources-390x390/fonts resources-390x390/drawables
git mv resources/fonts/* resources-390x390/fonts/
git mv resources/drawables/phosphor_dark.png  resources-390x390/drawables/
git mv resources/drawables/phosphor_light.png resources-390x390/drawables/
rmdir resources/fonts
```

- [ ] **Step 2: Create the bucket's drawables.xml for the watermark**

Create `resources-390x390/drawables/drawables.xml`:

```xml
<resources>
    <!-- Phosphor radar watermark @390 (loaded lazily by the theme) -->
    <bitmap id="PhosphorDark" filename="phosphor_dark.png"/>
    <bitmap id="PhosphorLight" filename="phosphor_light.png"/>
</resources>
```

- [ ] **Step 3: Strip the watermark from the base drawables.xml**

Replace `resources/drawables/drawables.xml` with (LauncherIcon only):

```xml
<resources>
    <bitmap id="LauncherIcon" filename="launcher_icon.png"/>
</resources>
```

- [ ] **Step 4: Wire the jungle so fr70 sees base + the 390 bucket**

Replace `monkey.jungle` with:

```
# Build configuration for Flightdeck.
# Base resources (strings/settings/icon) are shared; each device also gets its
# resolution bucket folder appended so it bundles only its own fonts + watermark.
project.manifest = manifest.xml

# Resolution bucket folders (one set of fonts + watermark each).
res390 = resources-390x390

# 390x390 AMOLED runners.
fr70.resourcePath = $(fr70.resourcePath);$(res390)
```

- [ ] **Step 5: Build fr70 and confirm clean**

Run the Global build command with `<dev>` = `fr70`.
Expected: `BUILD SUCCESSFUL`. (If it cannot resolve `HeroFont`/`PhosphorDark`, the `resourcePath` append form is wrong — this is the flagged verification point; fix the jungle syntax here before proceeding.)

- [ ] **Step 6: Simulator sanity (390 unchanged)**

```sh
connectiq &              # launch simulator (once)
"$SDK/bin/monkeydo" /tmp/fd-fr70.prg fr70
```
Expected: face renders exactly as before this task across all four themes (this is a refactor; no visual change).

- [ ] **Step 7: Commit**

```sh
git add -A
git commit -m "Reorg resources into 390 bucket + per-device jungle resourcePath

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: Responsive geometry in the base Theme

Add the scale factor and apply it to the four-corner grid + hero + title, and scale the three coordinate-based `decorate()` themes. Still only fr70 exists, so this proves **no 390 regression** (`s == 1.0`); actual scaling is exercised in Task 4.

**Files:**
- Modify: `source/Theme.mc`, `source/themes/CockpitTheme.mc`, `source/themes/BridgeTheme.mc`, `source/themes/WallTheme.mc`, `source/themes/PhosphorTheme.mc`

**Interfaces:**
- Produces:
  - `Layout.scale(s as Float) as Void` — multiplies all geometric fields in place.
  - Module helpers in `Theme.mc`: `scN(v as Number, s as Float) as Number` (scale + round a coordinate), `scP(v as Number, s as Float) as Number` (scale a pen width, floor of 1).
  - New `decorate` signature: `decorate(dc as Graphics.Dc, light as Boolean, s as Float) as Void` (all themes).
- Consumes: `dc.getWidth()` from the data-field `Dc`.

- [ ] **Step 1: Add `scale()` to `Layout` and helpers to `Theme.mc`**

In `source/Theme.mc`, add to class `Layout` (after `initialize`):

```monkeyc
    // Scale every geometric field from the 390 reference to this screen.
    function scale(s as Float) as Void {
        colL = rnd(colL * s); colR = rnd(colR * s); ctr = rnd(ctr * s);
        lblY1 = rnd(lblY1 * s); valY1 = rnd(valY1 * s); heroY = rnd(heroY * s);
        lblY2 = rnd(lblY2 * s); valY2 = rnd(valY2 * s);
        lblAsc = rnd(lblAsc * s); valAsc = rnd(valAsc * s); heroAsc = rnd(heroAsc * s);
        titleY = rnd(titleY * s); titleAsc = rnd(titleAsc * s);
    }
```

Add module-level free functions at the top of `source/Theme.mc` (after the imports, before `class Fonts`):

```monkeyc
// Scale + round a reference-design (@390) coordinate to the active screen.
function scN(v as Number, s as Float) as Number { return rnd(v * s); }
// Scale a pen width, never below 1px.
function scP(v as Number, s as Float) as Number { var w = rnd(v * s); return w < 1 ? 1 : w; }
// Round a Float to nearest Number.
function rnd(v as Float) as Number { return (v + 0.5).toNumber(); }
```

- [ ] **Step 2: Apply the scale factor in `Theme.draw` and pass it to `decorate`**

In `source/Theme.mc`, replace the body of `draw` from its start through the `decorate(...)` call with:

```monkeyc
    function draw(dc as Graphics.Dc, m as Metrics, fonts as Fonts, light as Boolean) as Void {
        var p = buildPalette(light);
        var L = buildLayout(fonts);
        var s = dc.getWidth() / 390.0;
        L.scale(s);

        dc.setColor(Graphics.COLOR_WHITE, p.ground);
        dc.clear();

        decorate(dc, light, s);
```

(The rest of `draw` — the `txt(...)` calls — is unchanged; it now reads the already-scaled `L`.) Update the base stub signature:

```monkeyc
    function decorate(dc as Graphics.Dc, light as Boolean, s as Float) as Void {}
```

- [ ] **Step 3: Scale Cockpit's `decorate`**

Replace `CockpitTheme.decorate` with:

```monkeyc
    function decorate(dc as Graphics.Dc, light as Boolean, s as Float) as Void {
        var ground   = light ? 0xEADFC8 : 0x0d0a07;
        var rim      = light ? 0xB9A988 : 0x1f4954;
        var reticle  = light ? 0x1E7088 : 0x3fb6d6;
        var scanDim  = light ? 0xC7B89B : 0x2c6675;
        var scanBrt  = light ? 0x1E7088 : 0x4fc8ec;
        var cx = scN(195, s); var cy = scN(195, s);

        // dashed rim (fine dotted ring) at r=180
        dc.setColor(rim, Graphics.COLOR_TRANSPARENT);
        var n = 120;
        var r = 180.0 * s;
        for (var i = 0; i < n; i++) {
            var a = (Math.PI * 2.0 * i) / n;
            dc.drawPoint((cx + r * Math.cos(a)).toNumber(), (cy + r * Math.sin(a)).toNumber());
        }

        // four diagonal corner reticle brackets
        dc.setColor(reticle, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(scP(3, s));
        dc.drawLine(scN(84,s), scN(60,s), scN(60,s), scN(60,s));   dc.drawLine(scN(60,s), scN(60,s), scN(60,s), scN(84,s));
        dc.drawLine(scN(306,s),scN(60,s), scN(330,s),scN(60,s));   dc.drawLine(scN(330,s),scN(60,s), scN(330,s),scN(84,s));
        dc.drawLine(scN(84,s), scN(330,s),scN(60,s), scN(330,s));  dc.drawLine(scN(60,s), scN(330,s),scN(60,s), scN(306,s));
        dc.drawLine(scN(306,s),scN(330,s),scN(330,s),scN(330,s));  dc.drawLine(scN(330,s),scN(330,s),scN(330,s),scN(306,s));

        // broken centre scan line: dim full-width, bright middle, masked gap
        dc.setColor(scanDim, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(scP(1, s));
        dc.drawLine(scN(58,s), scN(181,s), scN(332,s), scN(181,s));
        dc.setColor(scanBrt, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(scP(2, s));
        dc.drawLine(scN(150,s), scN(181,s), scN(240,s), scN(181,s));
        dc.setColor(ground, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(scP(9, s));
        dc.drawLine(scN(186,s), scN(181,s), scN(204,s), scN(181,s));
        dc.setPenWidth(1);
    }
```

- [ ] **Step 4: Scale Bridge's `decorate`**

Replace `BridgeTheme.decorate` with:

```monkeyc
    function decorate(dc as Graphics.Dc, light as Boolean, s as Float) as Void {
        var band  = light ? 0xEAD2CE : 0x2a1210;
        var frame = light ? 0xBE3A2C : 0xB0392E;
        var fw    = light ? 3 : 2;

        // console bars centred on the two label rows
        dc.setColor(band, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(scN(40,s), scN(98,s),  scN(310,s), scN(26,s));
        dc.fillRectangle(scN(40,s), scN(267,s), scN(310,s), scN(26,s));

        // octagon frame (radius 176, flat-top via +22.5° offset)
        dc.setColor(frame, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(scP(fw, s));
        var r = 176.0 * s;
        var cx = scN(195, s); var cy = scN(195, s);
        var prevX = 0; var prevY = 0; var firstX = 0; var firstY = 0;
        for (var k = 0; k < 8; k++) {
            var a = (Math.PI * (k * 45 + 22.5)) / 180.0;
            var x = (cx + r * Math.cos(a)).toNumber();
            var y = (cy + r * Math.sin(a)).toNumber();
            if (k == 0) {
                firstX = x; firstY = y;
            } else {
                dc.drawLine(prevX, prevY, x, y);
            }
            prevX = x; prevY = y;
        }
        dc.drawLine(prevX, prevY, firstX, firstY);
        dc.setPenWidth(1);
    }
```

- [ ] **Step 5: Scale Bulkhead's `decorate`**

Replace `WallTheme.decorate` with (the `pill` helper is unchanged — it receives already-scaled values):

```monkeyc
    function decorate(dc as Graphics.Dc, light as Boolean, s as Float) as Void {
        var grey  = light ? 0xA2ABB7 : 0x404750;  // even columns
        var greyd = light ? 0xBEC5CE : 0x2b3037;  // odd columns
        var cols = [6, 28, 50, 72, 94, 116, 260, 282, 304, 326, 348, 370];
        var w = scN(17, s);
        var radius = scN(8, s);
        for (var i = 0; i < cols.size(); i++) {
            var x = scN(cols[i], s);
            var even = (i % 2 == 0);
            var gapC = scN(even ? 130 : 260, s);   // gap centre offset between columns
            dc.setColor(even ? grey : greyd, Graphics.COLOR_TRANSPARENT);
            pill(dc, x, scN(3, s), gapC - scN(7, s), w, radius);
            pill(dc, x, gapC + scN(7, s), scN(387, s), w, radius);
        }
    }
```

- [ ] **Step 6: Update Phosphor's `decorate` signature only**

Phosphor self-centers the watermark by its own size, so it needs no coordinate scaling — only the new signature. Replace its `decorate` signature line:

```monkeyc
    function decorate(dc as Graphics.Dc, light as Boolean, s as Float) as Void {
```

(Body unchanged. The watermark itself becomes per-bucket in Task 5.)

- [ ] **Step 7: Build fr70 and confirm clean + unchanged**

Run the Global build command with `<dev>` = `fr70`. Expected: `BUILD SUCCESSFUL`.
Then `"$SDK/bin/monkeydo" /tmp/fd-fr70.prg fr70` and confirm all four themes look identical to Task 1 (s == 1.0 ⇒ no visual change).

- [ ] **Step 8: Commit**

```sh
git add -A
git commit -m "Responsive geometry: scale layout + decorate by dc width / 390

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: Multi-bucket font generation

Make `gen_fonts.py` emit a size-scaled font set per bucket, and generate the three new sets (360/416/454). 390 atlases are regenerated into their bucket folder too, so the tool is the single source of truth.

**Files:**
- Modify: `tools/gen_fonts.py`
- Create (generated): `resources-360x360/fonts/*`, `resources-416x416/fonts/*`, `resources-454x454/fonts/*`
- Regenerate: `resources-390x390/fonts/*`

**Interfaces:**
- Consumes: the bucket folder layout from Task 1.
- Produces: `*.fnt` + `*.png` atlases at each bucket's scaled sizes.

- [ ] **Step 1: Refactor the SPECS section of `gen_fonts.py` for buckets**

Replace the `OUT = ...` line and the `SPECS = [...]` block with:

```python
RES_ROOT = os.path.normpath(os.path.join(HERE, ".."))

# Reference design sizes @390. Per-bucket size = round(size * bucketW / 390).
REF_W = 390
BUCKETS = [390, 360, 416, 454]

# id, reference pixel size @390, glyph set, stroke.
REF_SPECS = [
    ("hero", 60, DIGITS + ":", 0),
    ("value", 34, DIGITS + ":.-", 0),
    ("label", 30, UPPER, 0),
    ("title", 13, UPPER, 0),
    ("herob", 72, DIGITS + ":", 1),
    ("valueb", 42, DIGITS + ":.-", 0),
    ("labelb", 36, UPPER, 0),
]
```

- [ ] **Step 2: Thread an output dir through `build_one`**

Change `build_one`'s signature and its two output paths to take `outdir`:

```python
def build_one(fid, size, glyph_set, stroke, outdir):
```
and inside it replace `os.path.join(OUT, ...)` (three occurrences: the `.png` save, the `.fnt` write, and any print) with `os.path.join(outdir, ...)`. The `os.makedirs(OUT, ...)` in `main` moves into the loop (below).

- [ ] **Step 3: Rewrite `main` to loop over buckets**

Replace `main` with:

```python
def main():
    print("Generating bitmap fonts from %s" % FONT_TTF)
    for bw in BUCKETS:
        outdir = os.path.join(RES_ROOT, "resources-%dx%d" % (bw, bw), "fonts")
        os.makedirs(outdir, exist_ok=True)
        print("bucket %dx%d -> %s" % (bw, bw, outdir))
        for fid, ref_size, glyph_set, stroke in REF_SPECS:
            size = round(ref_size * bw / REF_W)
            build_one(fid, size, glyph_set, stroke, outdir)
    print("Done.")
```

- [ ] **Step 4: Run the generator**

```sh
cd /Users/dcltdw/Github/Flightdeck
python3 tools/gen_fonts.py
```
Expected: prints four `bucket WxW` lines, each listing 7 fonts. Confirm the 390 sizes printed match the originals (hero=60, value=34, label=30, title=13, herob=72, valueb=42, labelb=36) and 454 are larger (hero=70, …).

- [ ] **Step 5: Confirm the 390 atlases are unchanged behaviorally**

```sh
git status --short resources-390x390/fonts
```
Expected: either no changes, or only metadata-identical regeneration. Build fr70 once more to be safe (Global build command, `<dev>` = `fr70`) → `BUILD SUCCESSFUL`.

- [ ] **Step 6: Copy the shared fonts.xml into each new bucket**

The font ids/filenames are identical across buckets, so each bucket reuses the same `fonts.xml`:

```sh
cd /Users/dcltdw/Github/Flightdeck
for b in 360x360 416x416 454x454; do cp resources-390x390/fonts/fonts.xml resources-$b/fonts/fonts.xml; done
```

- [ ] **Step 7: Commit**

```sh
git add -A
git commit -m "gen_fonts: emit size-scaled font sets per resolution bucket

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: Bring up the 416 bucket end-to-end

First real non-390 device. Proves geometry + fonts + jungle together at 416×416.

**Files:**
- Modify: `manifest.xml`, `monkey.jungle`

**Interfaces:**
- Consumes: `resources-416x416/fonts/*` (Task 3), the `res390`/`resourcePath` jungle pattern (Task 1), responsive geometry (Task 2).

- [ ] **Step 1: Add fr265 to the manifest products**

In `manifest.xml`, replace the `<iq:products>` block with:

```xml
        <iq:products>
            <iq:product id="fr70"/>
            <iq:product id="fr265"/>
        </iq:products>
```

- [ ] **Step 2: Add the 416 bucket var + fr265 mapping to the jungle**

In `monkey.jungle`, add a `res416` var beside `res390` and map fr265:

```
res390 = resources-390x390
res416 = resources-416x416

# 390x390 AMOLED runners.
fr70.resourcePath = $(fr70.resourcePath);$(res390)

# 416x416 AMOLED runners.
fr265.resourcePath = $(fr265.resourcePath);$(res416)
```

- [ ] **Step 3: Build fr265 and confirm clean**

Run the Global build command with `<dev>` = `fr265`. Expected: `BUILD SUCCESSFUL`.

- [ ] **Step 4: Simulator render check at 416 (non-Phosphor themes)**

```sh
"$SDK/bin/monkeydo" /tmp/fd-fr265.prg fr265
```
In the simulator, cycle the `theme` setting through Cockpit / Bridge / Bulkhead. Confirm: text is centered, nothing clips the round edge, the Cockpit rim/reticles and Bridge octagon are proportional. (Phosphor will show a too-small 390 watermark until Task 5 — expected.)

- [ ] **Step 5: Re-confirm fr70 still clean**

Run the Global build command with `<dev>` = `fr70`. Expected: `BUILD SUCCESSFUL`.

- [ ] **Step 6: Commit**

```sh
git add -A
git commit -m "Add 416x416 bucket (fr265) end-to-end

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: Per-bucket Phosphor watermark

Parametrize the watermark generator by screen size, emit one watermark pair per bucket into the bucket drawables folders, and add the watermark declarations to the new buckets.

**Files:**
- Modify: `tools/gen_phosphor_watermark.sh`
- Create (generated): `resources-360x360/drawables/phosphor_{dark,light}.png`, same for 416 and 454
- Regenerate: `resources-390x390/drawables/phosphor_{dark,light}.png`
- Create: `resources-360x360/drawables/drawables.xml`, `resources-416x416/drawables/drawables.xml`, `resources-454x454/drawables/drawables.xml`

**Interfaces:**
- Consumes: Phosphor's self-centering `decorate` (it draws `Rez.Drawables.PhosphorDark/Light` sized to the screen).
- Produces: a screen-filling watermark per bucket so Phosphor covers the full display.

- [ ] **Step 1: Rewrite `gen_phosphor_watermark.sh` to loop over buckets**

Replace the script body from the `S=390` line through the final `echo` with a bucket loop that scales every coordinate by `k = S/390`. Replace lines 16–46 with:

```sh
OPACITY=0.62
GROUND_DARK="#03110a"     # must match PhosphorTheme dark ground
GROUND_LIGHT="#E6ECF0"    # must match PhosphorTheme light ground
TINT_DARK="#E0457A"       # magenta
TINT_LIGHT="#B0335A"      # rose

command -v magick >/dev/null || { echo "magick (ImageMagick 7) not found." >&2; exit 1; }
B="$(mktemp -d)"
trap 'rm -rf "$B"' EXIT

# integer-scale a 390-reference coordinate to size S
sc() { awk "BEGIN{printf \"%d\", ($1)*$S/390 + 0.5}"; }

for S in 390 360 416 454; do
    OUT="$ROOT/resources-${S}x${S}/drawables"
    mkdir -p "$OUT"
    C=$(sc 195)
    R1=$(sc 365); R2=$(sc 310); R3=$(sc 255)
    L0=$(sc 25); L1=$(sc 365)
    SX=$(sc 334); SY=$(sc 98)            # sweep end
    BX=$(sc 300); BY=$(sc 150); BR=$(sc 305)  # blip centre + radius point
    SW2=$(sc 2); SW1=$(sc 1)

    # radar intensity: white shapes on black
    magick -size ${S}x${S} xc:black -fill none -stroke white \
        -strokewidth $SW2 -draw "circle $C,$C $R1,$C" -draw "circle $C,$C $R2,$C" -draw "circle $C,$C $R3,$C" \
        -strokewidth $SW1 -draw "line $L0,$C $L1,$C" -draw "line $C,$L0 $C,$L1" \
        -strokewidth $SW2 -draw "line $C,$C $SX,$SY" \
        -fill white -stroke none -draw "circle $BX,$BY $BR,$BY" \
        "$B/rad.png"

    # fade the very edge, scale opacity
    magick -size ${S}x${S} radial-gradient:white-black -level 0%,98% "$B/vig.png"
    magick "$B/rad.png" "$B/vig.png" -compose Multiply -composite -evaluate multiply "$OPACITY" "$B/a.png"

    # tint + composite OPAQUE over each ground
    magick \( -size ${S}x${S} "xc:${TINT_DARK}" \) "$B/a.png" -alpha off -compose CopyOpacity -composite \
        -background "$GROUND_DARK" -compose over -alpha remove -alpha off -strip "$OUT/phosphor_dark.png"
    magick \( -size ${S}x${S} "xc:${TINT_LIGHT}" \) "$B/a.png" -alpha off -compose CopyOpacity -composite \
        -background "$GROUND_LIGHT" -compose over -alpha remove -alpha off -strip "$OUT/phosphor_light.png"

    echo "wrote $OUT/phosphor_{dark,light}.png (${S}x${S})"
done
```

Leave lines 1–15 (shebang, comment header, `set -euo pipefail`, `ROOT=...`) intact except update the header `Output:` comment to `resources-<WxW>/drawables/`.

- [ ] **Step 2: Run the watermark generator**

```sh
cd /Users/dcltdw/Github/Flightdeck
bash tools/gen_phosphor_watermark.sh
```
Expected: four `wrote ... (WxW)` lines. Confirm each `resources-WxW/drawables/` now holds `phosphor_dark.png` + `phosphor_light.png` at the matching pixel size (`file resources-454x454/drawables/phosphor_dark.png` → 454 x 454).

- [ ] **Step 3: Add watermark declarations to the three new buckets**

The 390 bucket already has its `drawables/drawables.xml` (Task 1). Copy it into the others (identical ids/filenames):

```sh
for b in 360x360 416x416 454x454; do cp resources-390x390/drawables/drawables.xml resources-$b/drawables/drawables.xml; done
```

- [ ] **Step 4: Build fr265 (416) and confirm Phosphor now fits**

Run the Global build command with `<dev>` = `fr265` → `BUILD SUCCESSFUL`, then:
```sh
"$SDK/bin/monkeydo" /tmp/fd-fr265.prg fr265
```
Set theme to Phosphor; confirm the radar watermark fills the 416 screen (no ground-colored border ring) and the rings are centered.

- [ ] **Step 5: Re-confirm fr70 (390) Phosphor unchanged**

Global build command, `<dev>` = `fr70` → `BUILD SUCCESSFUL`; `monkeydo` and confirm Phosphor at 390 is visually identical to before.

- [ ] **Step 6: Commit**

```sh
git add -A
git commit -m "Per-bucket Phosphor watermark (scaled generator + bucket drawables)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: Full device roster + per-bucket build matrix

Add the remaining buckets (360, 454) and all device ids, then verify one build per bucket plus the extreme-resolution render checks.

**Files:**
- Modify: `manifest.xml`, `monkey.jungle`

**Interfaces:**
- Consumes: all four bucket folders (fonts + watermark), responsive geometry.

- [ ] **Step 1: Add all device ids to the manifest**

In `manifest.xml`, replace the `<iq:products>` block with the full roster:

```xml
        <iq:products>
            <!-- 390x390 -->
            <iq:product id="fr70"/>
            <iq:product id="fr165"/>
            <iq:product id="fr165m"/>
            <iq:product id="fr170"/>
            <iq:product id="fr170m"/>
            <iq:product id="venu3s"/>
            <!-- 360x360 -->
            <iq:product id="fr265s"/>
            <!-- 416x416 -->
            <iq:product id="fr265"/>
            <iq:product id="fenix843mm"/>
            <iq:product id="epix2"/>
            <!-- 454x454 -->
            <iq:product id="fr965"/>
            <iq:product id="fr970"/>
            <iq:product id="fenix847mm"/>
            <iq:product id="venu3"/>
        </iq:products>
```

Also update the manifest's targets comment (currently "Targets the Forerunner 70 only.") to note it now targets AMOLED runners across 390/360/416/454.

- [ ] **Step 2: Map every device to its bucket in the jungle**

Replace `monkey.jungle` with:

```
# Build configuration for Flightdeck.
# Base resources (strings/settings/icon) are shared; each device also gets its
# resolution bucket folder appended so it bundles only its own fonts + watermark.
project.manifest = manifest.xml

# Resolution bucket folders (one set of fonts + watermark each).
res390 = resources-390x390
res360 = resources-360x360
res416 = resources-416x416
res454 = resources-454x454

# 390x390 AMOLED runners.
fr70.resourcePath    = $(fr70.resourcePath);$(res390)
fr165.resourcePath   = $(fr165.resourcePath);$(res390)
fr165m.resourcePath  = $(fr165m.resourcePath);$(res390)
fr170.resourcePath   = $(fr170.resourcePath);$(res390)
fr170m.resourcePath  = $(fr170m.resourcePath);$(res390)
venu3s.resourcePath  = $(venu3s.resourcePath);$(res390)

# 360x360 AMOLED runners.
fr265s.resourcePath  = $(fr265s.resourcePath);$(res360)

# 416x416 AMOLED runners.
fr265.resourcePath      = $(fr265.resourcePath);$(res416)
fenix843mm.resourcePath = $(fenix843mm.resourcePath);$(res416)
epix2.resourcePath      = $(epix2.resourcePath);$(res416)

# 454x454 AMOLED runners.
fr965.resourcePath      = $(fr965.resourcePath);$(res454)
fr970.resourcePath      = $(fr970.resourcePath);$(res454)
fenix847mm.resourcePath = $(fenix847mm.resourcePath);$(res454)
venu3.resourcePath      = $(venu3.resourcePath);$(res454)
```

- [ ] **Step 3: Build one device per bucket (all must be clean)**

Run the Global build command four times, with `<dev>` = `fr70` (390), `fr265s` (360), `fr265` (416), `fr965` (454). Expected: `BUILD SUCCESSFUL` for each.

- [ ] **Step 4: Render-check the extremes + the 390 invariant**

```sh
"$SDK/bin/monkeydo" /tmp/fd-fr265s.prg fr265s   # 360 — smallest
"$SDK/bin/monkeydo" /tmp/fd-fr965.prg  fr965     # 454 — largest
"$SDK/bin/monkeydo" /tmp/fd-fr70.prg   fr70      # 390 — must be identical
```
For 360 and 454, cycle all four themes and confirm: centered, no edge clipping, watermark fills the screen, Cockpit rim/reticles and Bridge octagon proportional. For 390, confirm pixel-identical to the original build.

- [ ] **Step 5: Update CHANGELOG**

In `CHANGELOG.md`, under `## [Unreleased]`, replace the "Responsive multi-device support (in progress)" bullet with:

```markdown
- Responsive multi-device support: renders across AMOLED running watches at
  390×390, 360×360, 416×416, and 454×454 (Forerunner 70/165/170/265/265s/965/970,
  Fenix 8, Epix 2, Venu 3/3s). Layout and bitmap fonts scale from a 390 reference;
  each device bundles only its resolution's assets.
```

- [ ] **Step 6: Commit**

```sh
git add -A
git commit -m "Full AMOLED runner roster across 4 resolution buckets

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Self-Review (completed by plan author)

- **Spec coverage:** Geometry scaling → Task 2. Per-bucket fonts via qualifiers → Tasks 1+3. Jungle per-device bundling → Tasks 1/4/6. Decorate scaling → Task 2. Phosphor watermark per bucket → Task 5. Manifest device list → Tasks 4/6. Verification (build per bucket + sim at extremes + 390 invariant) → Task 6. Risk #1 (jungle syntax) front-loaded into Task 1. Risk #2 (ascent rounding) handled by scaling ascents in `Layout.scale` with fallback noted in spec. All spec sections map to a task.
- **Placeholder scan:** no TBD/TODO; every code step shows full code; commands have expected output.
- **Type consistency:** `scN`/`scP`/`rnd` defined in Task 2 and used in Tasks 2/5 generator is separate (shell); `Layout.scale`, `decorate(dc, light, s)` signature consistent across all five `.mc` files; font ids unchanged so `fonts.xml`/source loaders need no edits.
