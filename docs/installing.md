# Building and installing Flightdeck

How to build the data field from source and get it onto a watch (or the
simulator). This is the **sideload** path — for personal/dev use, before a store
release. For store publishing see
[publishing-to-connect-iq-store.md](publishing-to-connect-iq-store.md).

## Prerequisites

| Need | Notes |
|---|---|
| **Java runtime** | `monkeyc` needs a JRE/JDK. On macOS, Homebrew's `openjdk` works (`brew install openjdk`); it's keg-only, so prepend it to `PATH`. |
| **Connect IQ SDK** | Install via the [Connect IQ SDK Manager](https://developer.garmin.com/connect-iq/sdk/), and add the device profiles you want to target. |
| **A developer key** | A one-time RSA key that signs your builds. Keep it out of git (`*.der`/`*.pem` are `.gitignore`d). |

Set up your shell for a build session:

```sh
export PATH="$(brew --prefix openjdk)/bin:$PATH"
SDK="$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks/<your-sdk>"
```

## 1. Generate a developer key (once)

```sh
openssl genrsa -out developer_key.pem 4096
openssl pkcs8 -topk8 -inform PEM -outform DER -in developer_key.pem -out developer_key.der -nocrypt
```

Reuse the **same** key for every build and for store submission — Garmin ties an
app's identity to its signing key.

## 2. Build the `.prg`

```sh
"$SDK/bin/monkeyc" -f monkey.jungle -o flightdeck.prg -y developer_key.der -d <device> -w
```

`<device>` is a product id from `manifest.xml` (e.g. `fr165`). A clean build
prints `BUILD SUCCESSFUL`; add `-l 3` for strict type checking. The custom fonts,
icon, and radar watermark are checked in under `resources/`; regenerate them with
the `tools/` scripts (needs Python + Pillow, and ImageMagick for the watermark).

## 3a. Run in the simulator (no hardware needed)

```sh
"$SDK/bin/connectiq" &                       # launch the simulator
"$SDK/bin/monkeydo" flightdeck.prg <device>  # load the build into it
```

Use **Simulation → Activity Data / FIT** playback so pace/distance/timer values
populate. Note: the simulator can't edit a *data field's* settings — to preview a
specific Theme/Mode, change the defaults in `resources/settings/properties.xml`
and rebuild.

## 3b. Sideload onto a watch

1. Connect the watch by USB; it mounts as a drive named **GARMIN**.
2. Copy `flightdeck.prg` into the **`GARMIN/Apps/`** folder.
3. Eject and disconnect.

## 4. Add it to a run profile

Flightdeck is an **additive full-screen data field** — add it as an extra page:

1. On the watch: **Settings → Activities & Apps → Run → Data Screens**.
2. **Add New → Connect IQ Field** (or edit a screen), choose **Flightdeck**, and
   pick the full-screen / single-field layout.
3. Start a run and swipe to the Flightdeck page.

Theme and Mode are set in the app's settings via **Garmin Connect** (Connect IQ
app settings) on a real device.

## Troubleshooting

- **`Unable to locate a Java Runtime`** — `openjdk` isn't on `PATH`.
- **`Could not find device '<id>'`** — add that device in the SDK Manager.
- **Field missing on the watch** — confirm `flightdeck.prg` is in `GARMIN/Apps/`
  and the watch ejected cleanly.
