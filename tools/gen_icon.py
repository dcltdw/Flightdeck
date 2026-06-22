#!/usr/bin/env python3
"""Generate the flightdeck launcher icon (54x54 for FR70).

An abstract cockpit-HUD reticle in the Cockpit (dark) palette: a
dark dial, a teal ring with corner ticks, and an amber centre. Deliberately
abstract (no trademarked imagery). Reproducible like the other assets.

Deps: Pillow (pip install Pillow). Output: resources/drawables/launcher_icon.png
"""

import os

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "resources", "drawables"))

SIZE = 54
SS = 8  # supersample factor for smooth edges
DIAL = (0x0D, 0x0A, 0x07, 255)
TEAL = (0x3F, 0xB6, 0xD6, 255)
AMBER = (0xFF, 0xC8, 0x90, 255)


def main():
    os.makedirs(OUT, exist_ok=True)
    n = SIZE * SS
    img = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c = n / 2.0

    # dark dial disc
    r = n * 0.48
    d.ellipse([c - r, c - r, c + r, c + r], fill=DIAL)

    # teal ring
    rr = n * 0.40
    d.ellipse(
        [c - rr, c - rr, c + rr, c + rr],
        outline=TEAL,
        width=int(n * 0.045),
    )

    # four corner ticks (HUD reticle)
    tick = n * 0.12
    off = n * 0.27
    w = int(n * 0.045)
    for sx in (-1, 1):
        for sy in (-1, 1):
            x = c + sx * off
            y = c + sy * off
            d.line([x, y, x - sx * tick, y], fill=TEAL, width=w)
            d.line([x, y, x, y - sy * tick], fill=TEAL, width=w)

    # amber centre
    cr = n * 0.10
    d.ellipse([c - cr, c - cr, c + cr, c + cr], fill=AMBER)

    img = img.resize((SIZE, SIZE), Image.LANCZOS)
    img.save(os.path.join(OUT, "launcher_icon.png"))
    print("wrote %s/launcher_icon.png (%dx%d)" % (OUT, SIZE, SIZE))


if __name__ == "__main__":
    main()
