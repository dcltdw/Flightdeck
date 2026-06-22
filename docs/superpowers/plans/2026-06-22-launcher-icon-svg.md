# Launcher Icon (Vector SVG) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the raster 54×54 launcher icon with a single vector `launcher_icon.svg` so every device gets a crisp, exact-size icon with no Connect IQ scaling warning.

**Architecture:** Connect IQ rasterizes a vector launcher icon at each device's expected size. Repoint `gen_icon.py` to emit the same HUD-reticle art as SVG, declare it with `dithering="none"`, drop the PNG. No folders, jungle, or manifest changes (mirrors the Understated peer project).

**Tech Stack:** SVG (basic shapes), Python (generator, no Pillow needed anymore), Connect IQ resources.

## Global Constraints

- No Monkey C unit-test framework. The gate is `monkeyc -w` (warnings-as-errors). Build command (substitute `<dev>`):
  ```sh
  export PATH="/usr/local/opt/openjdk/bin:$PATH"
  SDK="/Users/dcltdw/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.1.0-2026-03-09-6a872a80b"
  cd /Users/dcltdw/Github/Flightdeck
  "$SDK/bin/monkeyc" -f monkey.jungle -o /tmp/fd-<dev>.prg -y ~/Github/swarsy-face/developer_key.der -d <dev> -w
  ```
- **Success criterion beyond `BUILD SUCCESSFUL`:** the build output must **no longer contain** `launcher icon ... isn't compatible ... will be scaled`. That warning is not `-w`-promoted, so check for its *absence* explicitly.
- Artwork unchanged: dark dial `#0D0A07`, teal ring `#3FB6D6`, amber centre `#FFC890`, transparent background.
- `drawables.xml` declaration uses `dithering="none"` (matches Understated).
- No `monkey.jungle` or `manifest.xml` changes; `LauncherIcon` stays in base `resources/drawables/`.
- Never copy the developer key into the repo. `.superpowers/` is gitignored — don't stage it. Scan diffs for secrets. Stamp commits `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.

## File Structure

- `tools/gen_icon.py` (modify) — emit `launcher_icon.svg` instead of `.png`.
- `resources/drawables/launcher_icon.svg` (new, generated) — the vector icon.
- `resources/drawables/launcher_icon.png` (deleted).
- `resources/drawables/drawables.xml` (modify) — point `LauncherIcon` at the SVG.

---

## Task 1: Rewrite gen_icon.py to emit SVG and generate the asset

**Files:**
- Modify: `tools/gen_icon.py`
- Create (generated): `resources/drawables/launcher_icon.svg`

**Interfaces:**
- Produces: `resources/drawables/launcher_icon.svg` — a `54×54` viewBox SVG with the HUD-reticle art; consumed by Task 2's `drawables.xml`.

- [ ] **Step 1: Replace `tools/gen_icon.py` with the SVG generator**

Full new file contents:

```python
#!/usr/bin/env python3
"""Generate the Flightdeck launcher icon as a vector SVG.

An abstract cockpit-HUD reticle in the Cockpit (dark) palette: a dark dial, a
teal ring with corner ticks, and an amber centre. Vector, so Connect IQ
rasterizes it at each device's exact launcher-icon size (no scaling warning).
Reproducible like the other assets.

Output: resources/drawables/launcher_icon.svg
"""

import os

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "resources", "drawables"))

S = 54.0  # viewBox size (preserves the original icon proportions)
DIAL = "#0D0A07"
TEAL = "#3FB6D6"
AMBER = "#FFC890"


def f(x):
    """Format a coordinate compactly (trim trailing zeros)."""
    return ("%.3f" % x).rstrip("0").rstrip(".")


def main():
    os.makedirs(OUT, exist_ok=True)
    c = S / 2.0
    stroke = 0.045 * S
    off = 0.27 * S
    tick = 0.12 * S

    parts = [
        '<svg xmlns="http://www.w3.org/2000/svg" width="%s" height="%s" '
        'viewBox="0 0 %s %s" fill="none">' % (f(S), f(S), f(S), f(S)),
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
    svg = "\n".join(parts) + "\n"

    with open(os.path.join(OUT, "launcher_icon.svg"), "w") as fh:
        fh.write(svg)
    print("wrote %s/launcher_icon.svg (viewBox %sx%s)" % (OUT, f(S), f(S)))


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Run the generator**

Run:
```sh
cd /Users/dcltdw/Github/Flightdeck
python3 tools/gen_icon.py
```
Expected: `wrote .../resources/drawables/launcher_icon.svg (viewBox 54x54)`.

- [ ] **Step 3: Verify the SVG is well-formed and has the expected shapes**

Run:
```sh
python3 -c "import xml.dom.minidom,sys; d=xml.dom.minidom.parse('resources/drawables/launcher_icon.svg'); print('circles', len(d.getElementsByTagName('circle')), 'lines', len(d.getElementsByTagName('line')))"
```
Expected: `circles 3 lines 8` (dial + ring + centre = 3 circles; 4 corners × 2 = 8 lines). Well-formed parse = no XML error.

- [ ] **Step 4: Commit**

```sh
git add tools/gen_icon.py resources/drawables/launcher_icon.svg
git commit -m "gen_icon: emit vector launcher_icon.svg (HUD reticle, same art)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: Point LauncherIcon at the SVG, drop the PNG, verify warning-free

**Files:**
- Modify: `resources/drawables/drawables.xml`
- Delete: `resources/drawables/launcher_icon.png`

**Interfaces:**
- Consumes: `resources/drawables/launcher_icon.svg` (Task 1).

- [ ] **Step 1: Repoint the LauncherIcon declaration**

In `resources/drawables/drawables.xml`, replace the line:
```xml
    <bitmap id="LauncherIcon" filename="launcher_icon.png"/>
```
with:
```xml
    <bitmap id="LauncherIcon" filename="launcher_icon.svg" dithering="none"/>
```

- [ ] **Step 2: Delete the old raster icon**

```sh
cd /Users/dcltdw/Github/Flightdeck
git rm resources/drawables/launcher_icon.png
```

- [ ] **Step 3: Build one device per former icon-size class and capture warnings**

Run (using the Global build command), for `<dev>` = `fr70`, `fr265`, `fr965`, `venu3`, capturing output:
```sh
export PATH="/usr/local/opt/openjdk/bin:$PATH"
SDK="/Users/dcltdw/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.1.0-2026-03-09-6a872a80b"
cd /Users/dcltdw/Github/Flightdeck
for d in fr70 fr265 fr965 venu3; do
  "$SDK/bin/monkeyc" -f monkey.jungle -o /tmp/fd-$d.prg -y ~/Github/swarsy-face/developer_key.der -d $d -w 2>&1 | sed "s/^/[$d] /"
done
```
Expected: each device prints `[<dev>] BUILD SUCCESSFUL` and **no** line containing `isn't compatible` / `launcher icon`.

> Contingency: if Connect IQ rejects an SVG primitive (stroke/line), the build will error here. Fallback within the same art: render the ring as two filled `<circle>`s (outer teal, inner dial-colour) and the corner ticks as thin filled `<rect>`s, then re-run. Note any such change in the report.

- [ ] **Step 4: Confirm no residual PNG reference**

```sh
grep -rn "launcher_icon.png" resources/ manifest.xml monkey.jungle ; echo "exit $?"
```
Expected: no matches (grep exit 1).

- [ ] **Step 5: Commit**

```sh
git add -A
git commit -m "Use vector launcher_icon.svg; drop the 54x54 PNG (no scaling warning)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Self-Review (completed by plan author)

- **Spec coverage:** Generator→SVG → Task 1. drawables.xml repoint + PNG delete → Task 2. Warning-absence verification on fr70/fr265/fr965/venu3 → Task 2 Step 3. No jungle/manifest change → honored (not touched). Artwork colours/transparency → Task 1 code. `dithering="none"` → Task 2 Step 1. All spec sections covered.
- **Placeholder scan:** none — full generator code and exact commands/expected output provided; the contingency names a concrete fallback, not a TODO.
- **Type consistency:** the SVG filename `launcher_icon.svg` and shape counts (3 circles / 8 lines) are consistent between Task 1's output and Task 2's consumption/verification.
