#!/usr/bin/env bash
#
# Cut a flightdeck release: build a signed .iq, tag the repo, and publish a
# GitHub Release with the .iq attached so any version can be retrieved quickly
# for rollback (download the .iq, sideload it — see docs/installing-on-fr70.md).
#
# Releases are cut ONLY on explicit instruction (same convention as Understated).
#
# Usage:
#   tools/release.sh vX.Y.Z
#
# Environment overrides (auto-detected if unset):
#   CIQ_SDK   path to a Connect IQ SDK (defaults to the newest installed)
#   JAVA_BIN  directory holding `java` (defaults to Homebrew openjdk)
#   DEV_KEY   developer key (defaults to ./developer_key.der)
#
set -euo pipefail

VERSION="${1:-}"
if [[ ! "$VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "usage: tools/release.sh vX.Y.Z   (got: '${VERSION}')" >&2
    exit 2
fi

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

# --- preflight ---------------------------------------------------------------
if [[ -n "$(git status --porcelain)" ]]; then
    echo "working tree is dirty; commit or stash before releasing." >&2
    exit 1
fi
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [[ "$BRANCH" != "main" ]]; then
    echo "releases are cut from main (on '$BRANCH')." >&2
    exit 1
fi
git fetch --quiet origin main
if [[ "$(git rev-parse HEAD)" != "$(git rev-parse origin/main)" ]]; then
    echo "local main is not in sync with origin/main; pull/push first." >&2
    exit 1
fi
if git rev-parse "$VERSION" >/dev/null 2>&1; then
    echo "tag $VERSION already exists." >&2
    exit 1
fi

# CHANGELOG must already document this version — it is the release-notes source.
VER_NUM="${VERSION#v}"
CHANGELOG_NOTES="$(awk -v v="$VER_NUM" '
    $0 ~ "^## \\[?" v "\\]?" { f=1; next }
    /^## / { f=0 }
    f' CHANGELOG.md 2>/dev/null || true)"
if [[ -z "${CHANGELOG_NOTES//[[:space:]]/}" ]]; then
    echo "CHANGELOG.md has no section for ${VERSION}." >&2
    echo "Add a '## [${VER_NUM}] - <date>' section (move items out of Unreleased) first." >&2
    exit 1
fi

# The store description carries its own "What's changed" history (separate from
# CHANGELOG.md — it's the store-facing copy). Require an entry for this version
# so the listing text ships in sync with the build. See docs/releasing.md.
if ! grep -qE "^${VER_NUM}[[:space:][:punct:]]" store/description.txt 2>/dev/null; then
    echo "store/description.txt has no \"What's changed\" entry for ${VER_NUM}." >&2
    echo "Add a '${VER_NUM} — <summary>' line under \"What's changed\" first." >&2
    exit 1
fi

# --- toolchain ---------------------------------------------------------------
JAVA_BIN="${JAVA_BIN:-$(brew --prefix openjdk 2>/dev/null)/bin}"
export PATH="$JAVA_BIN:$PATH"
command -v java >/dev/null || { echo "no java on PATH (set JAVA_BIN)." >&2; exit 1; }

if [[ -z "${CIQ_SDK:-}" ]]; then
    CIQ_SDK="$(ls -d "$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks"/connectiq-sdk-* 2>/dev/null | sort | tail -1)"
fi
[[ -x "$CIQ_SDK/bin/monkeyc" ]] || { echo "monkeyc not found under CIQ_SDK ($CIQ_SDK)." >&2; exit 1; }

DEV_KEY="${DEV_KEY:-developer_key.der}"
[[ -f "$DEV_KEY" ]] || { echo "developer key not found: $DEV_KEY" >&2; exit 1; }

# --- signing-key verification ------------------------------------------------
# The Connect IQ store binds the app to the key pair of its FIRST published
# version and rejects any build signed with a different key. Flightdeck's key
# lives outside this repo, so "signed with the wrong key" is an easy mistake.
# Verify DEV_KEY's RSA modulus is present in the earliest published Release .iq
# (the store anchor) BEFORE building, and re-check the built .iq afterward.
# (.iq is a 7-zip container, but the key modulus occurs verbatim in the bytes,
# so a raw search needs no extraction.) See garmin-release.md / docs/releasing.md.
key_modulus() {  # DER private key -> uppercase hex modulus ("" on failure)
    openssl pkey -inform DER -in "$1" -pubout 2>/dev/null \
        | openssl rsa -pubin -modulus -noout 2>/dev/null | sed 's/^Modulus=//'
}
modulus_in_file() {  # $1 = hex modulus, $2 = artifact; exit 0 if bytes present
    python3 - "$1" "$2" <<'PY'
import sys
mod = bytes.fromhex(sys.argv[1])
sys.exit(0 if mod in open(sys.argv[2], "rb").read() else 1)
PY
}

DEV_MOD="$(key_modulus "$DEV_KEY")" || true
[[ -n "$DEV_MOD" ]] || { echo "could not read an RSA modulus from $DEV_KEY." >&2; exit 1; }

ANCHOR_TAG="$(gh release list --json tagName,createdAt -q 'sort_by(.createdAt)[0].tagName' 2>/dev/null || true)"
if [[ -n "$ANCHOR_TAG" ]]; then
    ANCHOR_DIR="$(mktemp -d)"
    gh release download "$ANCHOR_TAG" --pattern '*.iq' --dir "$ANCHOR_DIR" 2>/dev/null || true
    ANCHOR_IQ="$(ls "$ANCHOR_DIR"/*.iq 2>/dev/null | head -1 || true)"
    if [[ -n "$ANCHOR_IQ" ]] && modulus_in_file "$DEV_MOD" "$ANCHOR_IQ"; then
        rm -rf "$ANCHOR_DIR"
        echo ">> signing key verified against published $ANCHOR_TAG"
    elif [[ -n "$ANCHOR_IQ" ]]; then
        rm -rf "$ANCHOR_DIR"
        echo "DEV_KEY ($DEV_KEY) does not match the key of the published $ANCHOR_TAG .iq." >&2
        echo "The store binds the app to its first key pair — this would sign with the WRONG key." >&2
        exit 1
    else
        rm -rf "$ANCHOR_DIR"
        echo ">> WARNING: could not fetch $ANCHOR_TAG .iq; signing key NOT verified." >&2
    fi
else
    echo ">> no prior release found; skipping pre-build signing-key check (first release?)." >&2
fi

# --- build -------------------------------------------------------------------
mkdir -p store
IQ="store/flightdeck-${VERSION}.iq"
echo ">> building $IQ with SDK $(basename "$CIQ_SDK")"
"$CIQ_SDK/bin/monkeyc" -e -f monkey.jungle -o "$IQ" -y "$DEV_KEY" -w
echo ">> BUILD OK"

# Re-verify the built artifact carries DEV_KEY's modulus (not just the key we
# intended) before it gets tagged and published.
modulus_in_file "$DEV_MOD" "$IQ" \
    || { echo "built $IQ is not signed with $DEV_KEY (modulus mismatch)." >&2; exit 1; }
echo ">> artifact signing key re-verified"

# --- release notes (the CHANGELOG section validated in preflight) -------------
NOTES_FILE="$(mktemp)"
trap 'rm -f "$NOTES_FILE"' EXIT
printf '%s\n' "$CHANGELOG_NOTES" > "$NOTES_FILE"

# --- tag + publish -----------------------------------------------------------
echo ">> tagging $VERSION"
git tag -a "$VERSION" -m "$VERSION"
git push origin "$VERSION"

echo ">> publishing GitHub Release $VERSION"
gh release create "$VERSION" "$IQ" --title "$VERSION" --notes-file "$NOTES_FILE"

echo ">> done: $(gh release view "$VERSION" --json url -q .url)"
