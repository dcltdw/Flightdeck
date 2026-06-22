#!/usr/bin/env bash
#
# Compose the 1440x720 Connect IQ store hero banner from the three hero
# captures (store/screenshots/hero/). Dark banner, FLIGHTDECK wordmark + tagline
# over the three faces. Reproducible. Deps: ImageMagick 7 (magick).
#
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="$HERE/screenshots/hero"
OUT="$HERE/hero.png"
BG="#000000"        # black: the captures are circles on black, so corners blend
INK="#CDE6EF"
ACCENT="#3FB6D6"
FONT="Helvetica-Bold"   # adjust if magick cannot resolve it on this host
TAGLINE="Full-screen run metrics — four ways to fly casual, four ways to stay on target."

command -v magick >/dev/null || { echo "magick (ImageMagick 7) not found." >&2; exit 1; }

faces=(cockpit-dark bulkhead-dark bridge-light)
D=420               # face diameter on the banner
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
i=0
for f in "${faces[@]}"; do
  # the captures are already round faces on black; just resize. On a black
  # banner the square corners blend invisibly, so no masking is needed here.
  magick "$SRC/$f.png" -resize ${D}x${D} "$tmp/f$i.png"; i=$((i+1))
done

magick -size 1440x720 "xc:$BG" "$tmp/base.png"

# three circles evenly spaced: x = 45 / 510 / 975, y = 250
magick "$tmp/base.png" \
  "$tmp/f0.png" -geometry +45+250  -composite \
  "$tmp/f1.png" -geometry +510+250 -composite \
  "$tmp/f2.png" -geometry +975+250 -composite \
  "$tmp/comp.png"

magick "$tmp/comp.png" \
  -font "$FONT" -fill "$INK"    -gravity North -pointsize 96 -annotate +0+70  "FLIGHTDECK" \
  -font "$FONT" -fill "$ACCENT" -gravity North -pointsize 30 -annotate +0+185 "$TAGLINE" \
  "$OUT"

echo "wrote $OUT ($(magick identify -format '%wx%h' "$OUT"))"
