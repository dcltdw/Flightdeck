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

## Cutting a release

1. Land the work for the version on `main` (via PRs) and pull it locally.
2. Add a `## [X.Y.Z] — DATE` section to `CHANGELOG.md` (move items out of
   `Unreleased`), and merge that. **Required:** `release.sh` refuses to run if
   there's no CHANGELOG section matching the version (it's the notes source).
3. From a clean, up-to-date `main`:

   ```sh
   tools/release.sh v0.1.1
   ```

   The script verifies the tree is clean and on `main`, builds
   `dist/flightdeck-vX.Y.Z.iq` (signed with `developer_key.der`), creates the
   annotated tag, pushes it, and publishes the GitHub Release with the `.iq`
   attached. Toolchain is auto-detected; override with `CIQ_SDK`, `JAVA_BIN`, or
   `DEV_KEY` env vars if needed.

## Rolling back

1. Find the good version on the [Releases page](https://github.com/dcltdw/Flightdeck/releases).
2. Download its `flightdeck-vX.Y.Z.iq` asset.
3. Reinstall it (sideload — see [installing.md](installing.md)).

## Key custody

Releases are signed with `developer_key.der`. It is gitignored and must stay
private and backed up: it is the app's identity for the store **and** the
credential for publishing updates.
