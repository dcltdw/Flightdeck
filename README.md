# Flightdeck

A customizable, **full-screen run data field** for Garmin watches (Connect IQ /
Monkey C). It's an *additive* data screen for a run profile — you add it to a run
activity and swipe to it like any other data page; it doesn't replace the native
screens. No buttons or touch are captured.

Each face shows the same metric set, arranged as a four-corner grid around a
large centred hero clock:

```
   PACE                 DIST          (session pace / distance)
            24:18                     (elapsed time — hero)
   PACE                 TIME          (lap pace / lap time)
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

## Power note (AMOLED)

On AMOLED panels, black pixels draw ~nothing and white pixels draw the most, so
the **dark** themes (mostly-black ground, sparse coloured data) are the efficient
default; **light** themes light most of the panel and cost more battery. (On
transflective MIP displays, background colour is power-neutral.)
