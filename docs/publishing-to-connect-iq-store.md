# Publishing Flightdeck to the Connect IQ Store

How to package and submit the app to the Garmin **Connect IQ Store**. For local
build/sideload (no store) see [installing.md](installing.md).

The Connect IQ submission flow covers all app types, including **data fields** —
not just watch faces.

## Prerequisites

- A free **Garmin Connect IQ developer account** — sign in at the
  [developer portal](https://developer.garmin.com/connect-iq/) /
  [apps.garmin.com](https://apps.garmin.com/).
- The **same developer key** (`developer_key.der`) you build with locally; the
  store ties the app's identity to this key. Back it up — losing it means you can
  never update the listing.
- A clean build (`BUILD SUCCESSFUL`) and at least one **device screenshot** for
  the listing (capture from the simulator: **File → Save Screenshot**).

## 1. Export the store package (`.iq`)

The upload artifact is a signed `.iq` bundle (not the `.prg`):

```sh
export PATH="$(brew --prefix openjdk)/bin:$PATH"
SDK="$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks/<your-sdk>"

"$SDK/bin/monkeyc" -e -f monkey.jungle -o flightdeck.iq -y developer_key.der -w
```

- `-e` packages for the store (bundles every device in the manifest).
- `tools/release.sh` does this as part of cutting a tagged release.
- `.iq` files are build artifacts and are `.gitignore`d — don't commit them.

## 2. Create the store listing

In the developer dashboard at [apps.garmin.com](https://apps.garmin.com/):

1. **Upload an App → Data Field** (this app's type is `datafield`).
2. Upload `flightdeck.iq`. The store reads supported devices from the package —
   verify the device list matches the manifest.
3. Fill in the listing: name, description, category, icon, and at least one
   screenshot per supported display.
4. Set pricing, languages, and the permissions summary (this app requests **no**
   permissions).

## 3. Submit for review

- Garmin runs an automated + manual review (typically a few days): it checks the
  app installs and follows store policy, including that you hold the rights to all
  content you publish. Flightdeck ships only original, non-trademarked names and
  art, so there's nothing brand-encumbered to clear.
- On approval the app is installable via the **Connect IQ Store** app or
  **Garmin Express**.
- **Updates:** bump the app, re-export the `.iq` with the *same* key, and upload a
  new version to the existing listing.

## Operational notes

- Supported devices come from `manifest.xml` (`<iq:product>` entries). Adding a
  device = add an entry, rebuild, re-upload.
- **Key custody.** The signing key is the app's identity *and* its update
  credential. Keep `developer_key.der`/`.pem` safe and backed up, never in the
  repo.
