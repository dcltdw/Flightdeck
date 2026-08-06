# Store assets

Assets for the Connect IQ store listing.

## `description.txt`
Listing copy (plain text, cut-and-paste). Its tail carries the **What's changed** release
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
theme×mode face, cropped to the round screen and circle-masked on black. The
store accepts 5 preview images and the hero shows 3 — across the 8, every
theme×mode combination appears once.

- `screenshots/hero/` — the 3 faces composited into the banner.
- `screenshots/preview/` — the 5 store preview uploads.

All show a fixed sample pose (pace 5:14, 8.20 km, 28:13 elapsed, lap 5:02 / 9:48).

### Recapturing

Work in a throwaway `git worktree`, never the live checkout — the forced pose
must never be committed. Force the pose by returning fixed strings at the top of
`Metrics.format()` (`METRIC_TIMER` `28:13`, `PACE` `5:14`, `DIST` `8.20`,
`LPACE` `5:02`, `LTIME` `9:48`). Theme and mode do **not** need a code edit: set
`theme` (0 Cockpit, 1 Bridge, 2 Bulkhead, 3 Phosphor) and `mode` (0 dark,
1 light) in `resources/settings/properties.xml` and rebuild.

Then per face: build for `fr965`, `monkeydo`, and —

1. **File → Reset All App Data.** Required, and the easy thing to miss. The
   simulator persists app properties per app ID, so a rebuild with different
   `properties.xml` defaults is *ignored* until the stored values are cleared.
   Without this you get confident-looking captures of the previous face.
2. **Capture by window ID**, not by screen region:
   ```sh
   screencapture -x -o -l<windowid> raw.png     # window id via Quartz CGWindowList
   ```
   This grabs the window's own buffer, so it is immune to other windows sitting
   on top and needs no raising or focus stealing. A screen-region capture picks
   up whatever happens to overlap.
3. **Crop `454x454+114+262`** — the device screen sits at exactly that offset in
   the fr965 window, 1:1 with no scaling. (Verify after any SDK update by
   capturing the same face in light and dark mode and taking the bounding box of
   the difference; only the display area changes.)
4. **Circle-mask onto black**, matching the existing assets:
   ```sh
   magick raw.png \( -size 454x454 xc:black -fill white \
     -draw "circle 226.5,226.5 226.5,0" -alpha off \) \
     -alpha off -compose CopyOpacity -composite \
     -background black -alpha remove -alpha off out.png
   ```
   The 454×454 framebuffer's corners fall outside the round screen and show the
   simulator's bezel art, which must not ship.

Avoid the simulator's own **File → Save Screen Capture**. It does emit a true
454×454 PNG, but it opens a save panel whose "Go to folder" sheet swallows
synthetic keystrokes, so it does not automate reliably.

## App package (`.iq`) — built here at release time (git-ignored)
`tools/release.sh vX.Y.Z` builds the signed multi-device package to
`store/flightdeck-vX.Y.Z.iq` (the `.iq` is git-ignored) and attaches it to the
GitHub Release. Upload that `.iq` to the store with the screenshots above. To
build one manually:

```sh
export PATH="$(brew --prefix openjdk)/bin:$PATH"
SDK="$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks/<sdk>"
"$SDK/bin/monkeyc" -e -f monkey.jungle -o store/flightdeck.iq -y developer_key.der -w
```
