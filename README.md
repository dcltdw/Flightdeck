# Flightdeck

A customizable, **full-screen run data field** for Garmin watches (Connect IQ /
Monkey C). It's an *additive* data screen for a run profile — you add it to a run
activity and swipe to it like any other data page; it doesn't replace the native
screens. No buttons or touch are captured.

Each face shows a **configurable** metric set: pick a layout of 5, 4, 3, 2 or
1 fields, and choose the metric shown in each of that layout's positions
independently — the 5-field layout's fields don't affect the 3-field one's. A
fresh install starts on the 4-field compass, a large centred hero clock with
one metric on each side:

```
              0:00                    (elapsed time — hero, top)
   0.00                --:--          (lap distance / lap pace)
              0.00                    (distance, bottom)
```

## Themes

Four looks, each in **dark** and **light** mode (8 faces), chosen in the app's
settings (Garmin Connect / Connect IQ store app). Dark is the default and the
battery-smart choice on AMOLED.

| Theme | Look |
|---|---|
| **Cockpit** | warm HUD — diagonal corner reticles, dashed rim, broken scan line |
| **Bridge** | octagon frame + console bars |
| **Bulkhead** | bold striping in the outer thirds |
| **Phosphor** | green-CRT palette over a faint radar/scope watermark |

## Settings

- **Theme** — Cockpit / Bridge / Bulkhead / Phosphor
- **Mode** — Dark / Light
- **Layout (field count)** — 5 / 4 / 3 / 2 / 1 fields, each with its own field
  configuration
- **Fields** — the metric shown in each position of the selected layout (Off
  is available)
- **Show labels** — short metric names above each value

Set these from the Garmin Connect app (**Connect IQ Store → Flightdeck →
Settings**) or the Connect IQ store app, then sync.

## Adding it to a run

Flightdeck is a **data field**, not a watch face or a full app — you add it to
an activity profile's data screens. Because it's full-screen, give it a screen of
its own (a **single-field** layout).

**On the watch:**

1. Hold **MENU** → **Settings** → **Activities & Apps**.
2. Pick your run profile (e.g. **Run**) → open its settings.
3. **Data Screens** → **Add New** (or edit an existing screen).
4. **Layout** → choose the **single field** layout — this is what lets Flightdeck
   fill the screen.
5. Select that field → **Connect IQ Fields** → **Flightdeck**.

**From the Garmin Connect phone app:** your device → **Activities & App Settings**
→ the run profile → **Data Screens** → add a **single-field** screen → set it to
**Connect IQ → Flightdeck**, then sync.

During a run it sits in your data-screen rotation — scroll/swipe to it like any
other page. If **Flightdeck** doesn't appear in the Connect IQ Fields list, open
Connect IQ in the phone app, confirm it's installed, and re-sync.

## Building

A standard Connect IQ build (`monkeyc` needs a Java runtime and the Connect IQ
SDK on `PATH`). See [docs/installing.md](docs/installing.md) for the full build +
sideload walkthrough, [docs/publishing-to-connect-iq-store.md](docs/publishing-to-connect-iq-store.md)
for store submission, and [docs/releasing.md](docs/releasing.md) for cutting a
tagged release.

```sh
SDK=~/Library/Application\ Support/Garmin/ConnectIQ/Sdks/<your-sdk>
"$SDK/bin/monkeyc" -f monkey.jungle -o /tmp/check.prg -y <developer_key> -d <device> -w
```

The custom bitmap fonts, launcher icon, and Phosphor radar watermark are checked
in under `resources/`; the generators in `tools/` reproduce them.

The bitmap fonts are rasterised from **Roboto Mono** (Apache-2.0), vendored at
[tools/fonts/](tools/fonts/) so the atlases are reproducible on any machine.
`Theme.mc` hardcodes each font's ascent, so those constants and the generated
`base=` values have to agree — `tools/check_font_metrics.py` verifies that, and
`tools/gen_fonts.py` prints the table to reconcile against after a font change.

## Power note (AMOLED)

On AMOLED panels, black pixels draw ~nothing and white pixels draw the most, so
the **dark** themes (mostly-black ground, sparse coloured data) are the efficient
default; **light** themes light most of the panel and cost more battery. (On
transflective MIP displays, background colour is power-neutral.)

## License

GPL-3.0-or-later — see [LICENSE](LICENSE).

The repository carried no licence before, which meant "all rights reserved" by
default; this grants rights rather than removing any. Copyleft applies to the
source: a fork distributed to others has to ship its source under the same
terms. Running the app, and anything you do with the data it displays, is
unrestricted.

Third-party material bundled here: **Roboto Mono** (Apache-2.0, see
[tools/fonts/](tools/fonts/)), from which the bitmap atlases are rasterised.
Everything else — source, launcher icons, theme artwork, store assets — is
original.

Contributions are accepted under the same licence as the project.
