#!/usr/bin/env bash
#
# Generate the Phosphor theme's radar/scope watermark (dark + light) for the
# de-themed (publishable) variant. Fully procedural — no source image: concentric
# rings, a crosshair, a sweep line and a blip. Tinted per mode and composited
# OPAQUE over each theme ground (fr70 doesn't reliably blend partial bitmap
# alpha). Fills the screen; the theme centres it by the bitmap's own size.
#
# Output: resources/drawables/phosphor_dark.png, phosphor_light.png
# Deps: ImageMagick 7 (magick).
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/resources/drawables"
S=390
OPACITY=0.62
GROUND_DARK="#03110a"     # must match PhosphorTheme dark ground
GROUND_LIGHT="#E6ECF0"    # must match PhosphorTheme light ground
TINT_DARK="#E0457A"       # magenta
TINT_LIGHT="#B0335A"      # rose

command -v magick >/dev/null || { echo "magick (ImageMagick 7) not found." >&2; exit 1; }
mkdir -p "$OUT"
B="$(mktemp -d)"
trap 'rm -rf "$B"' EXIT

# radar intensity: white shapes on black
magick -size ${S}x${S} xc:black -fill none -stroke white \
    -strokewidth 2 -draw "circle 195,195 365,195" -draw "circle 195,195 310,195" -draw "circle 195,195 255,195" \
    -strokewidth 1 -draw "line 25,195 365,195" -draw "line 195,25 195,365" \
    -strokewidth 2 -draw "line 195,195 334,98" \
    -fill white -stroke none -draw "circle 300,150 305,150" \
    "$B/rad.png"

# fade the very edge, scale opacity
magick -size ${S}x${S} radial-gradient:white-black -level 0%,98% "$B/vig.png"
magick "$B/rad.png" "$B/vig.png" -compose Multiply -composite -evaluate multiply "$OPACITY" "$B/a.png"

# tint + composite OPAQUE over each ground
magick \( -size ${S}x${S} "xc:${TINT_DARK}" \) "$B/a.png" -alpha off -compose CopyOpacity -composite \
    -background "$GROUND_DARK" -compose over -alpha remove -alpha off -strip "$OUT/phosphor_dark.png"
magick \( -size ${S}x${S} "xc:${TINT_LIGHT}" \) "$B/a.png" -alpha off -compose CopyOpacity -composite \
    -background "$GROUND_LIGHT" -compose over -alpha remove -alpha off -strip "$OUT/phosphor_light.png"

echo "wrote $OUT/phosphor_dark.png and phosphor_light.png (${S}x${S})"
