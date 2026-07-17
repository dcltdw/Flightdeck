#!/usr/bin/env bash
#
# Generate the Phosphor theme's radar/scope watermark (dark + light) for the
# de-themed (publishable) variant. Fully procedural — no source image: concentric
# rings, a crosshair, a 1-o'clock sweep line, and a 3-arrowhead blip (a staggered
# V on the 11:45 radial, all facing the centre). Each element group is composited
# in its own subtly-varied colour, OPAQUE over each theme ground (fr70 doesn't
# reliably blend partial bitmap alpha). Fills the screen; the theme centres it
# by the bitmap's own size.
#
# Output: resources-<WxW>/drawables/phosphor_dark.png, phosphor_light.png
# Deps: ImageMagick 7 (magick), Pillow (the arrowhead polygons).
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
DARK_CIRC="#E0457A";  DARK_LINE="#EC6E98";  DARK_SWEEP="#FF6188";  DARK_BLIP="#E64DBF"
LIGHT_CIRC="#B0335A"; LIGHT_LINE="#C4576F"; LIGHT_SWEEP="#CE3D62"; LIGHT_BLIP="#E8621F"

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
    # blip: three arrowheads in a staggered V on the 11:45 radial, all facing
    # the centre (white polygons on black; PIL handles the per-head rotation).
    python3 - "$S" "$B/mb.png" <<'PY'
import sys, math
from PIL import Image, ImageDraw
S = int(sys.argv[1]); out = sys.argv[2]; k = S / 390.0
C = 195 * k
ang = math.radians(7.5)                  # 11:45 = 7.5deg left of 12 o'clock
radx, rady = -math.sin(ang), -math.cos(ang)   # outward along the 11:45 radial
D = 120 * k                              # formation distance from centre
Px, Py = C + radx * D, C + rady * D      # formation centroid
ux, uy = -radx, -rady                    # forward = toward centre
px, py = -uy, ux                         # perpendicular (right of forward)
A, Bb, G = 10 * k, 8 * k, 15 * k         # lead-forward, wing-back, wing-lateral
H, W = 18 * k, 12 * k                    # arrowhead length / width
img = Image.new("L", (S, S), 0); d = ImageDraw.Draw(img)
def head(cx, cy):
    fx, fy = C - cx, C - cy
    L = math.hypot(fx, fy); fx, fy = fx / L, fy / L     # face the centre
    rx, ry = -fy, fx
    tip   = (cx + fx * 0.6 * H,              cy + fy * 0.6 * H)
    rb    = (cx + rx * 0.5 * W - fx * 0.4 * H, cy + ry * 0.5 * W - fy * 0.4 * H)
    notch = (cx - fx * 0.1 * H,              cy - fy * 0.1 * H)
    lb    = (cx - rx * 0.5 * W - fx * 0.4 * H, cy - ry * 0.5 * W - fy * 0.4 * H)
    d.polygon([tip, rb, notch, lb], fill=255)
head(Px + ux * A,        Py + uy * A)            # lead (front, toward centre)
head(Px - ux * Bb + px * G, Py - uy * Bb + py * G)   # left wing (behind)
head(Px - ux * Bb - px * G, Py - uy * Bb - py * G)   # right wing (behind)
img.save(out)
PY
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
    SX=$(sc 238); SY=$(sc 33)                 # sweep end (12:30)
    SW2=$(sc 2); SW1=$(sc 1)

    # edge vignette (shared by every element mask this bucket)
    magick -size ${S}x${S} radial-gradient:white-black -level 0%,98% "$B/vig.png"

    render "$OUT/phosphor_dark.png"  "$GROUND_DARK"  "$DARK_CIRC"  "$DARK_LINE"  "$DARK_SWEEP"  "$DARK_BLIP"
    render "$OUT/phosphor_light.png" "$GROUND_LIGHT" "$LIGHT_CIRC" "$LIGHT_LINE" "$LIGHT_SWEEP" "$LIGHT_BLIP"

    echo "wrote $OUT/phosphor_{dark,light}.png (${S}x${S})"
done
