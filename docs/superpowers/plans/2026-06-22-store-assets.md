# Store Assets Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **Note:** Tasks 1–2 are INTERACTIVE (drive the simulator, capture screenshots, visually refine the hero) and are controller-led, not subagent work. Task 3 (listing/readme text) is deterministic. Inline execution fits this plan better than subagent fan-out.

**Goal:** Build a `store/` directory for the Connect IQ listing — a 1440×720 hero banner, 5 preview screenshots, `description.md`, and `README.md` — using real simulator captures of all 8 theme×mode faces.

**Architecture:** Per-face throwaway builds force theme/mode + a fixed running pose so captures are clean and consistent. Capture 8 faces on fr965 (454×454) → 3 feed a composited hero banner, 5 are store previews. Text files are hand-authored; the hero is reproducible via `gen_hero.sh` (ImageMagick).

**Tech Stack:** Connect IQ simulator + `monkeydo`, `screencapture`/Save Screen Shot, ImageMagick (`magick`), Markdown.

## Global Constraints

- **Assets only — no app/source changes are committed.** The forced edits used for capture builds (theme/mode in `source/FlightdeckView.mc`, pose in `source/Metrics.mc`) are temporary and MUST be reverted (`git checkout -- source/`) before any commit.
- Build command for throwaway capture builds:
  ```sh
  export PATH="/usr/local/opt/openjdk/bin:$PATH"
  SDK="/Users/dcltdw/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.1.0-2026-03-09-6a872a80b"
  cd /Users/dcltdw/Github/Flightdeck
  "$SDK/bin/monkeyc" -f monkey.jungle -o /tmp/cap-<face>.prg -y <developer_key> -d fr965 -w
  ```
- **Capture device:** fr965 (454×454). Every screenshot is normalized to 454×454.
- **The 8 faces (all distinct):**
  - Hero (3): `cockpit-dark`, `bulkhead-dark`, `bridge-light`
  - Preview (5): `cockpit-light`, `bridge-dark`, `bulkhead-light`, `phosphor-dark`, `phosphor-light`
- Theme index map: Cockpit=0, Bridge=1, Bulkhead=2, Phosphor=3. Mode: Dark=false, Light=true.
- **Fixed pose** (forced into `Metrics.update`): `sessionPace="5:14"`, `sessionDist="8.20"`, `heroTime="28:13"`, `lapPace="5:02"`, `lapTime="9:48"`.
- **Hero:** exactly 1440×720. **Tagline:** `Full-screen run metrics — four ways to fly casual, four ways to stay on target.` Wordmark: `FLIGHTDECK`.
- Never copy the developer key into the repo. `.superpowers/` is gitignored. Scan diffs for secrets. Stamp commits `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.

## File Structure

```
store/
  README.md
  description.md
  gen_hero.sh
  hero.png                       (generated)
  screenshots/hero/{cockpit-dark,bulkhead-dark,bridge-light}.png
  screenshots/preview/{cockpit-light,bridge-dark,bulkhead-light,phosphor-dark,phosphor-light}.png
```

---

## Task 1: Capture the 8 simulator faces (INTERACTIVE)

**Files:**
- Create: `store/screenshots/hero/*.png` (3), `store/screenshots/preview/*.png` (5)

**Interfaces:**
- Produces: 8 PNGs at 454×454, named per the face map, consumed by Task 2 (hero) and uploaded directly (previews).

- [ ] **Step 1: Add the forced-build helper (temporary, not committed)**

Write `/tmp/cap-build.sh`:

```sh
#!/usr/bin/env bash
set -euo pipefail
export PATH="/usr/local/opt/openjdk/bin:$PATH"
SDK="/Users/dcltdw/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.1.0-2026-03-09-6a872a80b"
KEY=<developer_key>
cd /Users/dcltdw/Github/Flightdeck
# args: face theme(0-3) light(true|false)
build() {
  local face=$1 t=$2 light=$3
  git checkout -- source/FlightdeckView.mc source/Metrics.mc
  LC_ALL=C sed -i '' "s|_themeIdx = numProp(\"theme\", 0);|_themeIdx = $t;|" source/FlightdeckView.mc
  LC_ALL=C sed -i '' "s|_light = (numProp(\"mode\", 0) == 1);|_light = $light;|" source/FlightdeckView.mc
  # force a fixed pose: replace the body of Metrics.update via a Python rewrite
  python3 - "$face" <<'PY'
import re,sys
p="source/Metrics.mc"
s=open(p).read()
body=('    function update(info as Activity.Info) as Void {\n'
      '        sessionPace = "5:14"; sessionDist = "8.20"; heroTime = "28:13";\n'
      '        lapPace = "5:02"; lapTime = "9:48";\n'
      '    }')
s=re.sub(r'    function update\(info as Activity\.Info\) as Void \{.*?\n    \}', body, s, count=1, flags=re.S)
open(p,"w").write(s)
PY
  "$SDK/bin/monkeyc" -f monkey.jungle -o /tmp/cap-$face.prg -y "$KEY" -d fr965 -w >/tmp/cap.log 2>&1 \
    && echo "built /tmp/cap-$face.prg ($face)" || { echo "FAIL $face"; tail -3 /tmp/cap.log; }
  git checkout -- source/FlightdeckView.mc source/Metrics.mc
}
build cockpit-dark   0 false
build bulkhead-dark  2 false
build bridge-light   1 true
build cockpit-light  0 true
build bridge-dark    1 false
build bulkhead-light 2 true
build phosphor-dark  3 false
build phosphor-light 3 true
```

Run: `bash /tmp/cap-build.sh`
Expected: 8 `built /tmp/cap-<face>.prg` lines, then `git status --porcelain` shows **no** changes under `source/` (forcing reverted).

- [ ] **Step 2: Launch the simulator (once)**

```sh
export PATH="/usr/local/opt/openjdk/bin:$PATH"
SDK="/Users/dcltdw/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.1.0-2026-03-09-6a872a80b"
pgrep -f "ConnectIQ.app/Contents/MacOS/simulator" >/dev/null || nohup "$SDK/bin/connectiq" >/tmp/connectiq.log 2>&1 &
```

- [ ] **Step 3: For each face — load, capture, normalize to 454×454**

For each of the 8 faces, load it and capture. Kill stale loaders first to avoid the pile-up that blocks reloads:

```sh
pkill -f monkeydodeux 2>/dev/null; pkill -f "bin/monkeydo " 2>/dev/null
nohup "$SDK/bin/monkeydo" /tmp/cap-<face>.prg fr965 >/tmp/md.log 2>&1 &
```
Then capture the watch face. **Preferred (scriptable):** `screencapture` the sim window region and crop to the round face, then normalize:
```sh
# capture sim window by id, then center-crop to 454x454
WID=$(/usr/bin/osascript -e 'tell app "System Events" to id of window 1 of (first process whose name contains "simulator")' 2>/dev/null)
screencapture -x -o ${WID:+-l$WID} /tmp/shot-<face>.png
magick /tmp/shot-<face>.png -gravity center -crop 454x454+0+0 +repage store/screenshots/<dir>/<face>.png
```
**Fallback (if `screencapture` is blocked by Screen Recording permission):** in the sim use **File → Save Screen Shot**, save to `/tmp/shot-<face>.png`, then run the `magick` crop line above. Place into `store/screenshots/hero/` for the 3 hero faces and `store/screenshots/preview/` for the 5 previews.

> Controller note: this step needs an awake, capturable display and (for `screencapture`) Screen Recording permission. Attempt `screencapture`; for any face it can't grab, hand the loaded build to the user for File → Save Screen Shot. Do not fabricate images.

- [ ] **Step 4: Verify all 8 exist at 454×454**

```sh
cd /Users/dcltdw/Github/Flightdeck
for f in screenshots/hero/cockpit-dark screenshots/hero/bulkhead-dark screenshots/hero/bridge-light \
         screenshots/preview/cockpit-light screenshots/preview/bridge-dark screenshots/preview/bulkhead-light \
         screenshots/preview/phosphor-dark screenshots/preview/phosphor-light; do
  echo -n "$f: "; file "store/$f.png" | sed 's/.*PNG image data, //; s/,.*//'
done
```
Expected: each line reports `454 x 454`.

- [ ] **Step 5: Confirm source untouched, then commit**

```sh
git status --porcelain source/   # expect empty
git add store/screenshots
git commit -m "store: 8 simulator captures (4 themes x dark/light) on fr965

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: Hero banner (`gen_hero.sh` + `hero.png`) (INTERACTIVE refine)

**Files:**
- Create: `store/gen_hero.sh`, `store/hero.png` (generated)

**Interfaces:**
- Consumes: `store/screenshots/hero/{cockpit-dark,bulkhead-dark,bridge-light}.png` (Task 1).
- Produces: `store/hero.png` at exactly 1440×720.

- [ ] **Step 1: Write `store/gen_hero.sh` (first-draft compositor)**

```sh
#!/usr/bin/env bash
#
# Compose the 1440x720 Connect IQ store hero banner from the three hero
# captures (store/screenshots/hero/). Dark banner, FLIGHTDECK wordmark + tagline
# over the three faces. Reproducible. Deps: ImageMagick 7 (magick).
#
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="$HERE/screenshots/hero"
OUT="$HERE/hero.png"
BG="#060B12"
INK="#CDE6EF"
ACCENT="#3FB6D6"
FONT="Helvetica-Bold"   # adjust if magick cannot resolve it on this host
TAGLINE="Full-screen run metrics — four ways to fly casual, four ways to stay on target."

command -v magick >/dev/null || { echo "magick (ImageMagick 7) not found." >&2; exit 1; }

# faces: 360x360, evenly spaced across the lower band
faces=(cockpit-dark bulkhead-dark bridge-light)
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
i=0
for f in "${faces[@]}"; do
  magick "$SRC/$f.png" -resize 360x360 "$tmp/f$i.png"; i=$((i+1))
done

# base canvas
magick -size 1440x720 "xc:$BG" "$tmp/base.png"

# place the three faces: y=300, x=120 / 540 / 960 (360 wide, ~60 gaps)
magick "$tmp/base.png" \
  "$tmp/f0.png" -geometry +120+300 -composite \
  "$tmp/f1.png" -geometry +540+300 -composite \
  "$tmp/f2.png" -geometry +960+300 -composite \
  "$tmp/comp.png"

# wordmark + tagline
magick "$tmp/comp.png" \
  -font "$FONT" -fill "$INK" -gravity North -pointsize 96 -annotate +0+70 "FLIGHTDECK" \
  -font "$FONT" -fill "$ACCENT" -gravity North -pointsize 30 -annotate +0+185 "$TAGLINE" \
  "$OUT"

echo "wrote $OUT ($(magick identify -format '%wx%h' "$OUT"))"
```

- [ ] **Step 2: Generate and verify size**

```sh
cd /Users/dcltdw/Github/Flightdeck
bash store/gen_hero.sh
magick identify -format '%wx%h\n' store/hero.png
```
Expected: `wrote .../hero.png (1440x720)` and `1440x720`. If `magick` cannot resolve `Helvetica-Bold`, set `FONT` to a TTF path that exists (e.g. `/System/Library/Fonts/Supplemental/Arial Bold.ttf`) and re-run.

- [ ] **Step 3: Visual refine with the user**

The first draft will need eyeballing (face spacing, wordmark size/position, tagline fit, colours). Open `store/hero.png`, present it, and iterate on `gen_hero.sh` values until the user approves. (Interactive — same loop used for the watermark.)

- [ ] **Step 4: Commit**

```sh
git add store/gen_hero.sh store/hero.png
git commit -m "store: hero banner (1440x720) + gen_hero.sh

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: Listing text (`description.md` + `README.md`)

**Files:**
- Create: `store/description.md`, `store/README.md`

**Interfaces:**
- Standalone; `README.md` documents the procedures from Tasks 1–2.

- [ ] **Step 1: Write `store/description.md`**

```markdown
# Flightdeck — store description

Flightdeck turns your run screen into a heads-up data field. Add it to a run
profile and swipe to it like any other data page — it's *additive* and doesn't
replace Garmin's native screens.

**Live metrics, at a glance**
- Session pace and distance
- Elapsed time, front and centre
- Lap pace and lap time

**Four themes, dark or light**
- **Cockpit** — warm HUD with corner reticles and a scan line
- **Bridge** — an octagon console frame
- **Bulkhead** — bold type with wall striping
- **Phosphor** — a green-CRT radar scope

Pick your theme and dark/light mode from the Garmin Connect app.

- Custom bitmap typography for a crisp, distinctive look
- Requests **no** permissions
- Runs on AMOLED running watches: Forerunner 70 / 165 / 170 / 265 / 265S / 965 /
  970, Fenix 8, Epix 2, Venu 3 / 3S

————————————————————————————

## What's changed

**0.1.1** — Initial public release. Four themes (Cockpit / Bridge / Bulkhead /
Phosphor) × dark/light; live session pace & distance, elapsed time, and lap
pace/time; responsive rendering across AMOLED running watches (390×390, 360×360,
416×416, 454×454); custom bitmap fonts; per-device launcher icons.
```

- [ ] **Step 2: Write `store/README.md`**

```markdown
# Store assets

Assets for the Connect IQ store listing.

## `description.md`
Listing copy (cut-and-paste). Its tail carries the **What's changed** release
notes — there is no separate changelog in the listing.

## `hero.png` — 1440×720 store banner
Dark banner: the FLIGHTDECK wordmark + tagline over the three hero faces
(Cockpit Dark, Bulkhead Dark, Bridge Light). Rebuild from the captures in
`screenshots/hero/`:

```sh
bash store/gen_hero.sh
```

## `screenshots/`
Real Connect IQ simulator captures on the **Forerunner 965** (454×454), one per
theme×mode face. The store accepts 5 preview images and the hero shows 3 — across
the 8, every theme×mode combination appears once.

- `screenshots/hero/` — the 3 faces composited into the banner.
- `screenshots/preview/` — the 5 store preview uploads.

All show a fixed sample pose (pace 5:14, 8.20 km, 28:13 elapsed, lap 5:02 / 9:48).

### Recapturing
For each face, build a throwaway `.prg` with the theme/mode and the sample pose
forced in code (forcing `source/FlightdeckView.mc` `_themeIdx`/`_light` and the
body of `source/Metrics.mc` `update()`), build for `fr965`, load with `monkeydo`,
and capture via `screencapture` (Screen Recording permission) or the simulator's
**File → Save Screen Shot**; crop/normalize to 454×454. The forced edits are
never committed.

## App package (`.iq`) — release-time, not in this directory
The multi-device store package is a build artifact (git-ignored). Build from
`main` and upload it with the screenshots above:

```sh
export PATH="$(brew --prefix openjdk)/bin:$PATH"
SDK="$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks/<sdk>"
"$SDK/bin/monkeyc" -e -f monkey.jungle -o flightdeck.iq -y developer_key.der -w
```
```

- [ ] **Step 3: Commit**

```sh
git add store/description.md store/README.md
git commit -m "store: listing description.md + README

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Self-Review (completed by plan author)

- **Spec coverage:** 8 captures (hero 3 + preview 5, the theme×mode map) → Task 1; fr965/454 + forced pose → Task 1 Global Constraints + helper; hero 1440×720 + gen_hero.sh + tagline/wordmark → Task 2; description.md (pitch/features/devices/"What's changed") + README → Task 3; "assets only, source reverted" → Global Constraints + Task 1 Steps 1/5. All spec sections covered.
- **Placeholder scan:** none — full helper script, full `gen_hero.sh`, full `description.md`/`README.md` content, exact verification commands. The interactive capture step names a concrete fallback (Save Screen Shot), not a TODO.
- **Type/name consistency:** face names and theme indices (Cockpit=0/Bridge=1/Bulkhead=2/Phosphor=3) are consistent across the helper, the face map, and the hero `faces=()` array; the pose values match between the forced `Metrics.update` and the README description.
