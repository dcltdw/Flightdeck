# Per-Size Launcher Icons Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Provide a launcher icon at each device's exact expected size (54/60/65/70) so Connect IQ no longer warns that the icon must be scaled.

**Architecture:** Per-size vector `launcher_icon.svg` (each declared at its own size) in icon-size resource folders `resources-icon{54,60,65,70}/`, wired per-device in the jungle as a second `resourcePath` append (after the resolution bucket). The icon declaration moves out of base into the folders. Mirrors the font/watermark bucketing, keyed by icon size.

**Tech Stack:** SVG (basic shapes), Python (generator), Connect IQ jungle resource paths.

**Starting state:** the branch currently has a single `resources/drawables/launcher_icon.svg` + the old `launcher_icon.png`, with `LauncherIcon` declared in base `resources/drawables/drawables.xml`. This plan restructures that into per-size icon folders.

## Global Constraints

- No Monkey C unit-test framework. Gate is `monkeyc -w`. Build command (substitute `<dev>`):
  ```sh
  export PATH="/usr/local/opt/openjdk/bin:$PATH"
  SDK="/Users/dcltdw/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.1.0-2026-03-09-6a872a80b"
  cd /Users/dcltdw/Github/Flightdeck
  "$SDK/bin/monkeyc" -f monkey.jungle -o /tmp/fd-<dev>.prg -y ~/Github/swarsy-face/developer_key.der -d <dev> -w
  ```
- **Success criterion beyond `BUILD SUCCESSFUL`:** the build output must **no longer contain** `launcher icon ... isn't compatible ... will be scaled`. Capture and check the text; the warning is not `-w`-promoted. Verified fact: an icon whose declared size equals the device's required size clears the warning; a mismatch (any format, incl. SVG) warns.
- Icon size → device map (each device's icon folder must match this):
  - 54: fr70, fr165, fr165m, fr170, fr170m
  - 60: fr265s, fr265, fenix843mm, epix2
  - 65: fr965, fr970, fenix847mm
  - 70: venu3s, venu3
- Artwork/colours unchanged: dark dial `#0D0A07`, teal ring `#3FB6D6`, amber centre `#FFC890`, transparent background.
- Icon `drawables.xml` declaration uses `dithering="none"`.
- No `manifest.xml` change (`launcherIcon="@Drawables.LauncherIcon"` stays).
- Never copy the developer key into the repo. `.superpowers/` is gitignored — don't stage it. Scan diffs for secrets. Stamp commits `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.

## File Structure

- `tools/gen_icon.py` (modify) — loop sizes; emit `resources-icon<N>/drawables/launcher_icon.svg` + `drawables.xml` per size.
- `resources-icon{54,60,65,70}/drawables/launcher_icon.svg` (new, generated).
- `resources-icon{54,60,65,70}/drawables/drawables.xml` (new, generated).
- `resources/drawables/launcher_icon.svg`, `resources/drawables/launcher_icon.png`, `resources/drawables/drawables.xml` (deleted — base no longer carries the icon).
- `monkey.jungle` (modify) — second per-device `resourcePath` append for the icon folder.

---

## Task 1: Generate per-size icons into icon folders

**Files:**
- Modify: `tools/gen_icon.py`
- Create (generated): `resources-icon{54,60,65,70}/drawables/launcher_icon.svg` and `.../drawables.xml`

**Interfaces:**
- Produces: four `resources-icon<N>/drawables/` folders, each with a `launcher_icon.svg` declared at size `<N>` and a `drawables.xml` declaring `LauncherIcon`. Consumed by Task 2's jungle wiring.

- [ ] **Step 1: Replace `tools/gen_icon.py` with the per-size generator**

Full new file contents:

```python
#!/usr/bin/env python3
"""Generate the Flightdeck launcher icon as per-size vector SVGs.

An abstract cockpit-HUD reticle in the Cockpit (dark) palette: a dark dial, a
teal ring with corner ticks, and an amber centre. One SVG per device launcher-
icon size, each DECLARED at that size so Connect IQ does not warn/scale. Each
lands in resources-icon<N>/drawables/ with a matching drawables.xml.
Reproducible like the other assets.
"""

import os

HERE = os.path.dirname(os.path.abspath(__file__))
RES_ROOT = os.path.normpath(os.path.join(HERE, ".."))

SIZES = [54, 60, 65, 70]
DIAL = "#0D0A07"
TEAL = "#3FB6D6"
AMBER = "#FFC890"

DRAWABLES_XML = (
    "<resources>\n"
    '    <bitmap id="LauncherIcon" filename="launcher_icon.svg" dithering="none"/>\n'
    "</resources>\n"
)


def f(x):
    """Format a coordinate compactly (trim trailing zeros)."""
    return ("%.3f" % x).rstrip("0").rstrip(".")


def svg_for(size):
    S = float(size)
    c = S / 2.0
    stroke = 0.045 * S
    off = 0.27 * S
    tick = 0.12 * S
    parts = [
        '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" '
        'viewBox="0 0 %d %d" fill="none">' % (size, size, size, size),
        '<circle cx="%s" cy="%s" r="%s" fill="%s"/>'
        % (f(c), f(c), f(0.48 * S), DIAL),
        '<circle cx="%s" cy="%s" r="%s" fill="none" stroke="%s" stroke-width="%s"/>'
        % (f(c), f(c), f(0.40 * S), TEAL, f(stroke)),
    ]
    for sx in (-1, 1):
        for sy in (-1, 1):
            x = c + sx * off
            y = c + sy * off
            parts.append(
                '<line x1="%s" y1="%s" x2="%s" y2="%s" stroke="%s" stroke-width="%s"/>'
                % (f(x), f(y), f(x - sx * tick), f(y), TEAL, f(stroke))
            )
            parts.append(
                '<line x1="%s" y1="%s" x2="%s" y2="%s" stroke="%s" stroke-width="%s"/>'
                % (f(x), f(y), f(x), f(y - sy * tick), TEAL, f(stroke))
            )
    parts.append(
        '<circle cx="%s" cy="%s" r="%s" fill="%s"/>'
        % (f(c), f(c), f(0.10 * S), AMBER)
    )
    parts.append("</svg>")
    return "\n".join(parts) + "\n"


def main():
    for size in SIZES:
        out = os.path.join(RES_ROOT, "resources-icon%d" % size, "drawables")
        os.makedirs(out, exist_ok=True)
        with open(os.path.join(out, "launcher_icon.svg"), "w") as fh:
            fh.write(svg_for(size))
        with open(os.path.join(out, "drawables.xml"), "w") as fh:
            fh.write(DRAWABLES_XML)
        print("wrote %s/launcher_icon.svg + drawables.xml (%dx%d)" % (out, size, size))


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Run the generator**

```sh
cd /Users/dcltdw/Github/Flightdeck
python3 tools/gen_icon.py
```
Expected: four `wrote .../resources-icon<N>/drawables/launcher_icon.svg + drawables.xml (<N>x<N>)` lines for 54, 60, 65, 70.

- [ ] **Step 3: Verify each SVG declares its own size and is well-formed**

```sh
for n in 54 60 65 70; do
  echo -n "icon$n: "; head -1 resources-icon$n/drawables/launcher_icon.svg | grep -o "width=\"$n\" height=\"$n\" viewBox=\"0 0 $n $n\"" || echo "WRONG SIZE";
done
python3 -c "import glob,xml.dom.minidom; [xml.dom.minidom.parse(p) for p in glob.glob('resources-icon*/drawables/launcher_icon.svg')]; print('all well-formed')"
```
Expected: each line echoes its matching `width="N" height="N" viewBox="0 0 N N"`, then `all well-formed`.

- [ ] **Step 4: Commit**

```sh
git add tools/gen_icon.py resources-icon54 resources-icon60 resources-icon65 resources-icon70
git commit -m "gen_icon: emit per-size launcher SVGs (54/60/65/70) into icon folders

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: Remove base icon, wire jungle per-device, verify warning-free

**Files:**
- Delete: `resources/drawables/launcher_icon.svg`, `resources/drawables/launcher_icon.png`, `resources/drawables/drawables.xml`
- Modify: `monkey.jungle`

**Interfaces:**
- Consumes: the four `resources-icon<N>/drawables/` folders from Task 1.

- [ ] **Step 1: Remove the base icon files and declaration**

Base `resources/drawables/` held only the launcher icon, so remove the whole folder's contents:

```sh
cd /Users/dcltdw/Github/Flightdeck
git rm resources/drawables/launcher_icon.svg resources/drawables/launcher_icon.png resources/drawables/drawables.xml
```
(`LauncherIcon` is now declared only in the icon folders. `manifest.xml` still references `@Drawables.LauncherIcon` — unchanged.)

- [ ] **Step 2: Add icon-size vars + second per-device append in `monkey.jungle`**

After the existing `res454 = ...` line, add the icon-size variables:

```
icon54 = resources-icon54
icon60 = resources-icon60
icon65 = resources-icon65
icon70 = resources-icon70
```

Then append the matching icon folder to each device's existing `resourcePath` line (append `;$(iconNN)` to what is already there — do not drop the resolution bucket). Final state per device:

```
fr70.resourcePath       = $(fr70.resourcePath);$(res390);$(icon54)
fr165.resourcePath      = $(fr165.resourcePath);$(res390);$(icon54)
fr165m.resourcePath     = $(fr165m.resourcePath);$(res390);$(icon54)
fr170.resourcePath      = $(fr170.resourcePath);$(res390);$(icon54)
fr170m.resourcePath     = $(fr170m.resourcePath);$(res390);$(icon54)
venu3s.resourcePath     = $(venu3s.resourcePath);$(res390);$(icon70)
fr265s.resourcePath     = $(fr265s.resourcePath);$(res360);$(icon60)
fr265.resourcePath      = $(fr265.resourcePath);$(res416);$(icon60)
fenix843mm.resourcePath = $(fenix843mm.resourcePath);$(res416);$(icon60)
epix2.resourcePath      = $(epix2.resourcePath);$(res416);$(icon60)
fr965.resourcePath      = $(fr965.resourcePath);$(res454);$(icon65)
fr970.resourcePath      = $(fr970.resourcePath);$(res454);$(icon65)
fenix847mm.resourcePath = $(fenix847mm.resourcePath);$(res454);$(icon65)
venu3.resourcePath      = $(venu3.resourcePath);$(res454);$(icon70)
```

- [ ] **Step 3: Build one device per icon size and check for the warning**

```sh
export PATH="/usr/local/opt/openjdk/bin:$PATH"
SDK="/Users/dcltdw/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.1.0-2026-03-09-6a872a80b"
cd /Users/dcltdw/Github/Flightdeck
for d in fr70 fr265 fr965 venu3; do
  echo "=== $d ==="
  "$SDK/bin/monkeyc" -f monkey.jungle -o /tmp/fd-$d.prg -y ~/Github/swarsy-face/developer_key.der -d $d -w 2>&1 | grep -iE "launcher|isn't compatible|BUILD"
done
```
Expected: each device prints `BUILD SUCCESSFUL` and **no** `launcher icon ... isn't compatible` line. (fr70=54, fr265=60, fr965=65, venu3=70 — each now matches its icon folder.)

- [ ] **Step 4: Confirm base icon fully gone, no stale references**

```sh
ls resources/drawables 2>&1   # expect: no such file/dir, or empty
grep -rn "launcher_icon" resources resources-icon* manifest.xml monkey.jungle | grep -v "resources-icon"; echo "exit $?"
```
Expected: `resources/drawables` gone/empty; the only `launcher_icon` references are inside `resources-icon*` (grep of the rest exits 1 / no matches).

- [ ] **Step 5: Commit**

```sh
git add -A
git commit -m "Per-device exact-size launcher icons via icon folders + jungle wiring

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Self-Review (completed by plan author)

- **Spec coverage:** per-size generator → Task 1; icon folders + drawables.xml → Task 1; base removal → Task 2 Step 1; jungle 2nd append per device (size map) → Task 2 Step 2; warning-absence verification on fr70/fr265/fr965/venu3 → Task 2 Step 3; manifest unchanged → honored. All spec sections covered.
- **Placeholder scan:** none — full generator code, exact jungle lines for all 14 devices, exact verification commands/expected output.
- **Type/name consistency:** folder names `resources-icon{54,60,65,70}` and jungle vars `icon54/60/65/70` are consistent between Task 1 (creates them) and Task 2 (references them); the icon→device map matches the Global Constraints table.
