#!/usr/bin/env bash
#
# Generate the Phosphor theme's radar/scope watermark (dark + light) for the
# de-themed (publishable) variant. Fully procedural — no source image: concentric
# rings, a crosshair, a sweep line and a blip. Tinted per mode and composited
# OPAQUE over each theme ground (fr70 doesn't reliably blend partial bitmap
# alpha). Fills the screen; the theme centres it by the bitmap's own size.
#
# Output: resources-<WxW>/drawables/phosphor_dark.png, phosphor_light.png
# Deps: ImageMagick 7 (magick).
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OPACITY=0.62
GROUND_DARK="#03110a"     # must match PhosphorTheme dark ground
GROUND_LIGHT="#E6ECF0"    # must match PhosphorTheme light ground
TINT_DARK="#E0457A"       # magenta
TINT_LIGHT="#B0335A"      # rose

command -v magick >/dev/null || { echo "magick (ImageMagick 7) not found." >&2; exit 1; }
B="$(mktemp -d)"
trap 'rm -rf "$B"' EXIT

# integer-scale a 390-reference coordinate to size S
sc() { awk "BEGIN{printf \"%d\", ($1)*$S/390 + 0.5}"; }

for S in 390 360 416 454; do
    OUT="$ROOT/resources-${S}x${S}/drawables"
    mkdir -p "$OUT"
    C=$(sc 195)
    R1=$(sc 365); R2=$(sc 310); R3=$(sc 255)
    L0=$(sc 25); L1=$(sc 365)
    SX=$(sc 334); SY=$(sc 98)            # sweep end
    BX=$(sc 300); BY=$(sc 150); BR=$(sc 305)  # blip centre + radius point
    SW2=$(sc 2); SW1=$(sc 1)

    # radar intensity: white shapes on black
    magick -size ${S}x${S} xc:black -fill none -stroke white \
        -strokewidth $SW2 -draw "circle $C,$C $R1,$C" -draw "circle $C,$C $R2,$C" -draw "circle $C,$C $R3,$C" \
        -strokewidth $SW1 -draw "line $L0,$C $L1,$C" -draw "line $C,$L0 $C,$L1" \
        -strokewidth $SW2 -draw "line $C,$C $SX,$SY" \
        -fill white -stroke none -draw "circle $BX,$BY $BR,$BY" \
        "$B/rad.png"

    # fade the very edge, scale opacity
    magick -size ${S}x${S} radial-gradient:white-black -level 0%,98% "$B/vig.png"
    magick "$B/rad.png" "$B/vig.png" -compose Multiply -composite -evaluate multiply "$OPACITY" "$B/a.png"

    # tint + composite OPAQUE over each ground
    magick \( -size ${S}x${S} "xc:${TINT_DARK}" \) "$B/a.png" -alpha off -compose CopyOpacity -composite \
        -background "$GROUND_DARK" -compose over -alpha remove -alpha off -strip "$OUT/phosphor_dark.png"
    magick \( -size ${S}x${S} "xc:${TINT_LIGHT}" \) "$B/a.png" -alpha off -compose CopyOpacity -composite \
        -background "$GROUND_LIGHT" -compose over -alpha remove -alpha off -strip "$OUT/phosphor_light.png"

    echo "wrote $OUT/phosphor_{dark,light}.png (${S}x${S})"
done
