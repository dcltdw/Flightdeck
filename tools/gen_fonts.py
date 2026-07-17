#!/usr/bin/env python3
"""Generate Connect IQ custom bitmap fonts for flightdeck.

Connect IQ accepts fonts in the AngelCode **BMFont** text format: a ``.fnt``
descriptor plus a PNG glyph atlas. We render **white glyphs on a transparent
ground** so the device can tint each font with ``dc.setColor`` at draw time —
that lets one atlas per *size* serve every colour role (label / value / hero /
lap / title).

One font is emitted per size, each with the minimal glyph set it needs, to keep
the atlases small. Output lands in ``resources/fonts/``; the committed
``.fnt``/``.png`` are the canonical artifacts (this script reproduces them).

Dependencies:
  * Pillow with freetype  ->  ``pip install Pillow``
  * a monospace TTF. Defaults to the macOS system Andale Mono; override with
    the ``FLIGHTDECK_FONT`` environment variable to point at any monospace TTF.

Usage:
  python3 tools/gen_fonts.py
"""

import os

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
RES_ROOT = os.path.normpath(os.path.join(HERE, ".."))

FONT_TTF = os.environ.get(
    "FLIGHTDECK_FONT", "/System/Library/Fonts/Supplemental/Andale Mono.ttf"
)

DIGITS = "0123456789"
UPPER = "ABCDEFGHIJKLMNOPQRSTUVWXYZ "

# Reference design sizes @390. Per-bucket size = round(size * bucketW / 390).
REF_W = 390
BUCKETS = [390, 360, 416, 454]

# id, reference pixel size @390, glyph set, stroke.
REF_SPECS = [
    ("hero", 60, DIGITS + ":", 0),
    ("value", 34, DIGITS + ":.-", 0),
    ("label", 30, UPPER, 0),
    ("title", 13, UPPER, 0),
    ("herob", 72, DIGITS + ":", 1),
    ("valueb", 42, DIGITS + ":.-", 0),
    ("labelb", 36, UPPER, 0),
    ("value52", 52, DIGITS + ":.-", 0),
    ("value76", 76, DIGITS + ":.-", 0),
    ("value104", 104, DIGITS + ":.-", 0),
    ("value64", 64, DIGITS + ":.-", 0),
    ("value60", 60, DIGITS + ":.-", 0),
    ("value40", 40, DIGITS + ":.-", 0),
    ("valueb52", 52, DIGITS + ":.-", 1),
    ("valueb76", 76, DIGITS + ":.-", 1),
    ("valueb104", 104, DIGITS + ":.-", 1),
    ("valueb64", 64, DIGITS + ":.-", 1),
]

# transparent margin baked around each rendered glyph before trimming
TOP_MARGIN = 6
SIDE_MARGIN = 4
ATLAS_MAX_W = 512  # shelf-pack wrap width


def render_glyph(font, ch, ascent, descent, stroke=0):
    """Return (coverage_image_or_None, xoffset, yoffset, xadvance).

    coverage is an 'L' image of the trimmed ink; None for whitespace.
    Offsets follow BMFont semantics: where to place the glyph relative to the
    line cell (top-left), with the baseline sitting at ``base`` from the top.
    A non-zero ``stroke`` outlines the glyph (fake-bold); xadvance is unchanged
    (monospace) so the grid stays aligned.
    """
    advance = round(font.getlength(ch))
    pad_x = SIDE_MARGIN + stroke
    pad_y = TOP_MARGIN + stroke
    cell_w = advance + 2 * pad_x
    cell_h = ascent + descent + 2 * pad_y
    tile = Image.new("L", (cell_w, cell_h), 0)
    draw = ImageDraw.Draw(tile)
    # anchor "la" = left / ascender-top; ascender line sits at y=pad_y
    draw.text((pad_x, pad_y), ch, fill=255, font=font, anchor="la",
              stroke_width=stroke, stroke_fill=255)
    ink = tile.getbbox()
    if ink is None:  # whitespace: no pixels, advance only
        return None, 0, 0, advance
    left, top, right, bottom = ink
    glyph = tile.crop(ink)
    xoffset = left - pad_x
    yoffset = top - pad_y  # distance from line top (ascender) to ink top
    return glyph, xoffset, yoffset, advance


def pack(glyphs):
    """Shelf-pack (id -> coverage image) into one atlas; return (atlas, places).

    places: id -> (x, y, w, h)
    """
    items = [(cid, g) for cid, g in glyphs if g is not None]
    items.sort(key=lambda kv: kv[1].height, reverse=True)
    places = {}
    x = y = shelf_h = 0
    atlas_w = 0
    for cid, g in items:
        w, h = g.width, g.height
        if x + w > ATLAS_MAX_W and x > 0:
            x = 0
            y += shelf_h + 1
            shelf_h = 0
        places[cid] = (x, y, w, h)
        atlas_w = max(atlas_w, x + w)
        shelf_h = max(shelf_h, h)
        x += w + 1
    atlas_h = y + shelf_h
    atlas = Image.new("RGBA", (max(1, atlas_w), max(1, atlas_h)), (255, 255, 255, 0))
    for cid, g in items:
        px, py, w, h = places[cid]
        white = Image.new("L", g.size, 255)
        rgba = Image.merge("RGBA", (white, white, white, g))  # white tinted by alpha
        atlas.paste(rgba, (px, py))
    return atlas, places


def write_fnt(path, face, size, ascent, descent, atlas_size, chars, png_name):
    line_height = ascent + descent
    lines = [
        'info face="%s" size=%d bold=0 italic=0 charset="" unicode=1 '
        "stretchH=100 smooth=1 aa=1 padding=0,0,0,0 spacing=1,1 outline=0"
        % (face, size),
        "common lineHeight=%d base=%d scaleW=%d scaleH=%d pages=1 packed=0 "
        "alphaChnl=1 redChnl=0 greenChnl=0 blueChnl=0"
        % (line_height, ascent, atlas_size[0], atlas_size[1]),
        'page id=0 file="%s"' % png_name,
        "chars count=%d" % len(chars),
    ]
    for c in chars:
        lines.append(
            "char id=%d x=%d y=%d width=%d height=%d xoffset=%d yoffset=%d "
            "xadvance=%d page=0 chnl=15"
            % (
                c["id"],
                c["x"],
                c["y"],
                c["w"],
                c["h"],
                c["xoff"],
                c["yoff"],
                c["xadv"],
            )
        )
    with open(path, "w") as fh:
        fh.write("\n".join(lines) + "\n")


def build_one(fid, size, glyph_set, stroke, outdir):
    if not os.path.exists(FONT_TTF):
        raise SystemExit(
            "Source font not found: %s\nSet FLIGHTDECK_FONT to a monospace TTF." % FONT_TTF
        )
    font = ImageFont.truetype(FONT_TTF, size)
    ascent, descent = font.getmetrics()

    rendered = {}  # ch -> (glyph|None, xoff, yoff, xadv)
    for ch in glyph_set:
        rendered[ch] = render_glyph(font, ch, ascent, descent, stroke)

    atlas, places = pack([(ch, rendered[ch][0]) for ch in glyph_set])

    chars = []
    for ch in glyph_set:
        glyph, xoff, yoff, xadv = rendered[ch]
        if glyph is None:
            x = y = w = h = 0
        else:
            x, y, w, h = places[ch]
        # Tighten the colon and period: the monospace cell leaves wide side
        # bearing, so pull the advance in and recentre the glyph — digits close
        # up on both sides of ":" / "." (e.g. 5:14, 8.20) without affecting other
        # glyphs. The period is narrower, so tighten it harder.
        if ch == ":" or ch == ".":
            frac = 0.4 if ch == ":" else 0.55
            shrink = int(round(xadv * frac))
            xoff -= shrink // 2
            xadv = max(1, xadv - shrink)  # clamp guards hypothetical tiny sizes
        chars.append(
            dict(id=ord(ch), x=x, y=y, w=w, h=h, xoff=xoff, yoff=yoff, xadv=xadv)
        )

    png_name = "%s.png" % fid
    atlas.save(os.path.join(outdir, png_name))
    write_fnt(
        os.path.join(outdir, "%s.fnt" % fid),
        os.path.basename(FONT_TTF),
        size,
        ascent,
        descent,
        atlas.size,
        chars,
        png_name,
    )
    print(
        "  %-6s size=%2d  glyphs=%2d  atlas=%dx%d"
        % (fid, size, len(glyph_set), atlas.size[0], atlas.size[1])
    )


def main():
    print("Generating bitmap fonts from %s" % FONT_TTF)
    for bw in BUCKETS:
        outdir = os.path.join(RES_ROOT, "resources-%dx%d" % (bw, bw), "fonts")
        os.makedirs(outdir, exist_ok=True)
        print("bucket %dx%d -> %s" % (bw, bw, outdir))
        for fid, ref_size, glyph_set, stroke in REF_SPECS:
            size = round(ref_size * bw / REF_W)
            build_one(fid, size, glyph_set, stroke, outdir)
    print("Done.")


if __name__ == "__main__":
    main()
