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
For each face, build a throwaway `.prg` with the theme/mode and the sample pose
forced in code (force `source/FlightdeckView.mc` `_themeIdx`/`_light` and the
body of `source/Metrics.mc` `update()`), build for `fr965`, load with `monkeydo`,
and capture the simulator window with `screencapture` (Screen Recording
permission) or **File → Save Screen Shot**; crop to the round screen and
normalize to 454×454. The forced edits are never committed.

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
