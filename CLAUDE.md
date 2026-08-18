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

Regenerate assets: `python3 tools/gen_fonts.py` (needs `pip install Pillow`);
`python3 tools/gen_icon.py` (pure stdlib, emits per-size launcher SVGs);
`tools/gen_phosphor_watermark.sh` needs ImageMagick.

## Collaboration & release

Universal collaboration rules — clarify-before-proceeding, branch→PR→wait, small
single-purpose PRs, the PR-body sections (`Files changed` annotated
`(new)`/`(deleted)`/(modified), `Work breakdown`, `Test expectations`,
`Operational impact`, `Provenance`), the board flow, the `Co-Authored-By` model
stamp, secret-scan-before-push, and verify-before-done — come from the
machine-global import in `~/.claude/CLAUDE.md`
(`@~/.claude/dcltdw/AGENTS.md`), so they are not duplicated here. For
Flightdeck, a PR's **Operational impact** section means rebuild / reinstall
notes (it's a data field; users re-add it to a data screen only if the field set
changes).

Store releases: use the `dcltdw:garmin-release` skill; project specifics in
the release supplement below.

### Flightdeck release supplement

- **Versioning:** semver git tags `vX.Y.Z` are the version — there is no version
  field in the CIQ manifest. Each release also gets a GitHub Release with the
  built `.iq` attached for fast rollback.
- **Signing key:** kept outside this repo (never committed; `DEV_KEY` env var,
  defaults to `./developer_key.der`). `tools/release.sh` auto-verifies it by
  RSA-modulus match against the earliest published Release `.iq` (the store
  anchor) before building, and re-checks the built `.iq`, so a wrong key aborts
  the release.
- **Targets:** the ~17-product `.iq` via `monkeyc -e` (AMOLED runners —
  Forerunner 70 / 165 / 170 / 265 / 265S / 965 / 970, Fenix 8, Epix 2,
  Venu 3 / 3S); primary sim test device `fr965` (454×454).
- **Store copy:** `store/description.txt` (the listing text + its "What's
  changed" history — note `>` is **not** allowed in it) and `CHANGELOG.md` (the
  GitHub Release notes); screenshots per `store/README.md`; hero via
  `store/gen_hero.sh`.
- **Release automation:** `tools/release.sh vX.Y.Z` (only when explicitly asked)
  builds the signed `.iq` into `store/`, tags, and publishes the GitHub Release.
  It refuses to run without matching `CHANGELOG.md` and `store/description.txt`
  "What's changed" entries. Regenerate `store/screenshots/` first if the look
  changed. Full process + pre-release checklist:
  [docs/releasing.md](docs/releasing.md).

### Project board

- Board: https://github.com/users/dcltdw/projects/5 (`PVT_kwHOAAdfes4BbXAc`)
- Status field `PVTSSF_lAHOAAdfes4BbXAczhWIC1k`:
  Todo `f75ad846`, In Progress `47fc9ee4`, Done `98236657`

Re-derive if these drift:

```sh
gh api graphql -f query='{ user(login:"dcltdw"){ projectV2(number:5){ id
  field(name:"Status"){ ... on ProjectV2SingleSelectField { id options { id name } } } } } }'
```

## Housekeeping

- Never commit developer keys or `.iq`/`.prg` build artifacts (see `.gitignore`).
