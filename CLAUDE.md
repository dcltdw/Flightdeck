# CLAUDE.md

Guidance for working in this repo. See [README.md](README.md) for the
user-facing description.

## What this is

**Flightdeck** is a customizable, full-screen run **data field** for Garmin
watches (Connect IQ / Monkey C). It's an additive run screen (does not replace
native screens). Four themes × two modes (dark/light), selectable via app
settings: **Cockpit / Bridge / Bulkhead / Phosphor**.

This is the public, trademark-clean variant. (It originated from a private,
themed prototype; all faction/brand references were removed here.)

## Architecture

- `source/FlightdeckApp.mc` — AppBase entry; returns the data field view.
- `source/FlightdeckView.mc` — DataField: reads Theme/Mode settings, draws.
- `source/Metrics.mc` — pulls metrics from `Activity.Info` (unit-aware; lap via
  `onTimerLap`).
- `source/Theme.mc` — Fonts/Palette/Layout + base `Theme` that lays the shared
  four-corner grid + hero. Each face is a subclass under `source/themes/`.
- `source/ThemeRegistry.mc` — maps the `theme` setting index to a Theme.
- `resources/` — custom bitmap fonts, drawables (radar watermark, icon),
  settings, strings.
- `tools/` — reproducible asset generators (`gen_fonts.py`, `gen_icon.py`,
  `gen_phosphor_watermark.sh`) and `release.sh`.

## Build / verify

`monkeyc` is type-checked at compile time, so compiling is the cheapest
verification. There is no CI; behaviour beyond "it compiles" must be checked in
the simulator / on device. A clean build prints `BUILD SUCCESSFUL`.

```sh
SDK=~/Library/Application\ Support/Garmin/ConnectIQ/Sdks/<your-sdk>
"$SDK/bin/monkeyc" -f monkey.jungle -o /tmp/check.prg -y <developer_key> -d <device> -w
```

Regenerate assets: `pip install Pillow` then `python3 tools/gen_fonts.py` /
`python3 tools/gen_icon.py`; `tools/gen_phosphor_watermark.sh` needs ImageMagick.

## Versioning & releases

Versions are semver git tags (`vX.Y.Z`); there is no version field in the CIQ
manifest. Each release also gets a GitHub Release with the built `.iq` attached
for fast rollback. Cut one with `tools/release.sh vX.Y.Z` — **only when
explicitly asked**. It requires a matching `CHANGELOG.md` section. Full process:
[docs/releasing.md](docs/releasing.md).

## AI-collaboration conventions

Follows the same subset of `~/Github/annotated-maps/docs/AI-COLLABORATION-CONVENTIONS.md`
used by the sibling projects:

- **Rule 1** — size each ticket to one PR.
- **Rule 2 / 3** — every issue lives on the project board; Todo → In Progress
  (PR opens) → Done (PR merges).
- **Rule 4** — PR bodies include `Files changed` (annotate `(new)`/`(deleted)`/
  (modified)), `Work breakdown`, `Test expectations` (only when failures are
  expected), and `Operational impact`.
- **Rule 5** — stamp commits with the current AI model in `Co-Authored-By:`.
- **Rule 6** — scan each diff for secrets before pushing.

End PR bodies with `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.

## Housekeeping

- Never commit developer keys or `.iq`/`.prg` build artifacts (see `.gitignore`).
