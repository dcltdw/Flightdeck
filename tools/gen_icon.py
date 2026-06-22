#!/usr/bin/env python3
"""Generate the Flightdeck launcher icon as per-size vector SVGs.

An abstract cockpit-HUD reticle in the Cockpit (dark) palette: a dark dial, a
teal ring with corner ticks, and an amber centre. One SVG per device launcher-
icon size, each DECLARED at that size so Connect IQ does not warn/scale. Each
lands in resources-icon<N>/drawables/ with a matching drawables.xml.
Reproducible like the other assets.
"""

import os

HERE = os.path.dirname(os.path.abspath(__file__))
RES_ROOT = os.path.normpath(os.path.join(HERE, ".."))

SIZES = [54, 60, 65, 70]
DIAL = "#0D0A07"
TEAL = "#3FB6D6"
AMBER = "#FFC890"

DRAWABLES_XML = (
    "<resources>\n"
    '    <bitmap id="LauncherIcon" filename="launcher_icon.svg" dithering="none"/>\n'
    "</resources>\n"
)


def f(x):
    """Format a coordinate compactly (trim trailing zeros)."""
    return ("%.3f" % x).rstrip("0").rstrip(".")


def svg_for(size):
    S = float(size)
    c = S / 2.0
    stroke = 0.045 * S
    off = 0.27 * S
    tick = 0.12 * S
    parts = [
        '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" '
        'viewBox="0 0 %d %d" fill="none">' % (size, size, size, size),
        '<circle cx="%s" cy="%s" r="%s" fill="%s"/>'
        % (f(c), f(c), f(0.48 * S), DIAL),
        '<circle cx="%s" cy="%s" r="%s" fill="none" stroke="%s" stroke-width="%s"/>'
        % (f(c), f(c), f(0.40 * S), TEAL, f(stroke)),
    ]
    for sx in (-1, 1):
        for sy in (-1, 1):
            x = c + sx * off
            y = c + sy * off
            parts.append(
                '<line x1="%s" y1="%s" x2="%s" y2="%s" stroke="%s" stroke-width="%s"/>'
                % (f(x), f(y), f(x - sx * tick), f(y), TEAL, f(stroke))
            )
            parts.append(
                '<line x1="%s" y1="%s" x2="%s" y2="%s" stroke="%s" stroke-width="%s"/>'
                % (f(x), f(y), f(x), f(y - sy * tick), TEAL, f(stroke))
            )
    parts.append(
        '<circle cx="%s" cy="%s" r="%s" fill="%s"/>'
        % (f(c), f(c), f(0.10 * S), AMBER)
    )
    parts.append("</svg>")
    return "\n".join(parts) + "\n"


def main():
    for size in SIZES:
        out = os.path.join(RES_ROOT, "resources-icon%d" % size, "drawables")
        os.makedirs(out, exist_ok=True)
        with open(os.path.join(out, "launcher_icon.svg"), "w") as fh:
            fh.write(svg_for(size))
        with open(os.path.join(out, "drawables.xml"), "w") as fh:
            fh.write(DRAWABLES_XML)
        print("wrote %s/launcher_icon.svg + drawables.xml (%dx%d)" % (out, size, size))


if __name__ == "__main__":
    main()
