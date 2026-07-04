# Releasing Flightdeck

How versions are cut and how to roll back. Flightdeck has **no CI**, so releases
are produced locally and published to GitHub.

## What a release is

- A **semver git tag** `vX.Y.Z` on `main`.
- A **GitHub Release** for that tag with the built **`.iq`** attached as an asset.
  The `.iq` is a build artifact (gitignored), so the Release is where each
  version's installable bundle lives — this is what makes **rollback** fast:
  download the `.iq` for any past version and sideload it
  (see [installing.md](installing.md)).
- A matching section in [CHANGELOG.md](../CHANGELOG.md).

There is no version field in the Connect IQ manifest, so the git tag is the
source of truth.

## When to release

**Only when explicitly asked.** Building an `.iq` and marking a release is a
deliberate, owner-initiated step — not something done automatically when a
feature branch merges.

## Before releasing — listing assets

Release notes and store assets live in **three** places; keep them in sync
*before* cutting the tag, so the tagged tree matches the shipped build (don't
refresh them after the fact — that forces a tag re-cut):

- **`CHANGELOG.md`** — the GitHub Release notes source. Add a `## [X.Y.Z]`
  section (move items out of `Unreleased`). *`release.sh` refuses to run
  without it.*
- **`store/description.txt`** — the store-facing "What's changed" history
  (separate copy from CHANGELOG). Add a `X.Y.Z — <summary>` line at the top of
  the "What's changed" section. *`release.sh` refuses to run without it.*
- **`store/screenshots/` + `store/hero.png`** — regenerate if the app's
  appearance changed this version, then rebuild the hero (`store/gen_hero.sh`).
  Not machine-checkable — this one is on you.

## Cutting a release

1. Land the work for the version on `main` (via PRs) and pull it locally,
   including the listing-asset updates above.
2. Merge the `CHANGELOG.md` + `store/description.txt` entries for this version.
   **Required:** `release.sh` refuses to run unless *both* carry the version.
3. From a clean, up-to-date `main`:

   ```sh
   tools/release.sh v0.1.1
   ```

   The script verifies the tree is clean and on `main`, **verifies the signing
   key** (below), builds `store/flightdeck-vX.Y.Z.iq` (signed with the key;
   git-ignored), creates the annotated tag, pushes it, and publishes the GitHub
   Release with the `.iq` attached. Toolchain is auto-detected; override with
   `CIQ_SDK`, `JAVA_BIN`, or `DEV_KEY` env vars if needed.

## Rolling back

1. Find the good version on the [Releases page](https://github.com/dcltdw/Flightdeck/releases).
2. Download its `flightdeck-vX.Y.Z.iq` asset.
3. Reinstall it (sideload — see [installing.md](installing.md)).

## Key custody

Releases are signed with `developer_key.der`. It is gitignored and must stay
private and backed up: it is the app's identity for the store **and** the
credential for publishing updates.

The Connect IQ store binds the app to the key pair of its **first** published
version and rejects any build signed with a different key — and Flightdeck's key
lives outside this repo, so "wrong key" is an easy mistake. `release.sh`
therefore verifies the key automatically (per the shared
`garmin-release.md`): it RSA-modulus-matches `DEV_KEY` against the earliest
published Release `.iq` (the store anchor) *before* building, and re-checks the
built `.iq` afterward. A mismatch aborts the release; if no prior release exists
(a hypothetical first cut) the pre-build check is skipped with a warning.
