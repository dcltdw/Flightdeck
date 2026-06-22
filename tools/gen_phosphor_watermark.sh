#!/usr/bin/env bash
#
# Generate the Phosphor theme's radar/scope watermark (dark + light) for the
# de-themed (publishable) variant. Fully procedural — no source image: concentric
# rings, a crosshair, a sweep line and a blip. Each element group is composited
# in its own subtly-varied colour, OPAQUE over each theme ground (fr70 doesn't
# reliably blend partial bitmap alpha). Fills the screen; the theme centres it
# by the bitmap's own size.
#
# Output: resources-<WxW>/drawables/phosphor_dark.png, phosphor_light.png
# Deps: ImageMagick 7 (magick).
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OPACITY=0.72
BLIP_OP=0.95               # blip is brighter than the rest of the radar
GROUND_DARK="#03110a"      # must match PhosphorTheme dark ground
GROUND_LIGHT="#E6ECF0"     # must match PhosphorTheme light ground

# Per-element colours (subtle variance off each mode's base). Each element
# group is composited over the ground in its own colour rather than one flat
# tint. Both axis lines share LINE so the crosshair reads as one colour.
DARK_CIRC="#E0457A";  DARK_LINE="#EC6E98";  DARK_SWEEP="#FF6188";  DARK_BLIP="#4DFF93"
LIGHT_CIRC="#B0335A"; LIGHT_LINE="#C4576F"; LIGHT_SWEEP="#CE3D62"; LIGHT_BLIP="#109A52"

command -v magick >/dev/null || { echo "magick (ImageMagick 7) not found." >&2; exit 1; }
B="$(mktemp -d)"
trap 'rm -rf "$B"' EXIT

# integer-scale a 390-reference coordinate to size S
sc() { awk "BEGIN{printf \"%d\", ($1)*$S/390 + 0.5}"; }

# Build an alpha mask: white shapes (passed as -draw args) on black, faded at
# the edge by the vignette and scaled by OPACITY. Writes $1; rest are draw args.
mask() {
    local out=$1; shift
    magick -size ${S}x${S} xc:black -fill none -stroke white "$@" "$B/m.png"
    magick "$B/m.png" "$B/vig.png" -compose Multiply -composite -evaluate multiply "$OPACITY" "$out"
}

# Composite a solid $colour over $result using grayscale $alpha as its opacity.
overlay() { # result colour alpha
    magick "$1" \( -size ${S}x${S} "xc:$2" "$3" -alpha off -compose CopyOpacity -composite \) \
        -compose over -composite "$1"
}

# Render one watermark: result starts as the opaque ground, then each element
# group is overlaid in its own colour. Later groups paint over earlier ones at
# intersections (sweep over circles, etc.).
render() { # out ground c_circ c_line c_sweep c_blip
    local out=$1 ground=$2 cc=$3 cl=$4 cs=$5 cb=$6
    magick -size ${S}x${S} "xc:$ground" -strip "$out"
    mask "$B/ac.png" -strokewidth $SW2 -draw "circle $C,$C $R1,$C" -draw "circle $C,$C $R2,$C" -draw "circle $C,$C $R3,$C"
    overlay "$out" "$cc" "$B/ac.png"
    mask "$B/al.png" -strokewidth $SW1 -draw "line $L0,$C $L1,$C" -draw "line $C,$L0 $C,$L1"
    overlay "$out" "$cl" "$B/al.png"
    mask "$B/as.png" -strokewidth $SW2 -draw "line $C,$C $SX,$SY"
    overlay "$out" "$cs" "$B/as.png"
    # blip is filled, not stroked
    magick -size ${S}x${S} xc:black -fill white -stroke none -draw "circle $BX,$BY $BR,$BY" "$B/mb.png"
    magick "$B/mb.png" "$B/vig.png" -compose Multiply -composite -evaluate multiply "$BLIP_OP" "$B/ab.png"
    overlay "$out" "$cb" "$B/ab.png"
    magick "$out" -alpha remove -alpha off -strip "$out"
}

for S in 390 360 416 454; do
    OUT="$ROOT/resources-${S}x${S}/drawables"
    mkdir -p "$OUT"
    C=$(sc 195)
    R1=$(sc 365); R2=$(sc 310); R3=$(sc 255)
    L0=$(sc 25); L1=$(sc 365)
    SX=$(sc 360); SY=$(sc 168)                # sweep end (clockwise of the blip)
    BX=$(sc 270); BY=$(sc 163); BR=$(sc 275)  # blip centre + radius point (pulled in off the ring)
    SW2=$(sc 2); SW1=$(sc 1)

    # edge vignette (shared by every element mask this bucket)
    magick -size ${S}x${S} radial-gradient:white-black -level 0%,98% "$B/vig.png"

    render "$OUT/phosphor_dark.png"  "$GROUND_DARK"  "$DARK_CIRC"  "$DARK_LINE"  "$DARK_SWEEP"  "$DARK_BLIP"
    render "$OUT/phosphor_light.png" "$GROUND_LIGHT" "$LIGHT_CIRC" "$LIGHT_LINE" "$LIGHT_SWEEP" "$LIGHT_BLIP"

    echo "wrote $OUT/phosphor_{dark,light}.png (${S}x${S})"
done
