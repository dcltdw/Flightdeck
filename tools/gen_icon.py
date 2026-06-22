#!/usr/bin/env python3
"""Generate the Flightdeck launcher icon as a vector SVG.

An abstract cockpit-HUD reticle in the Cockpit (dark) palette: a dark dial, a
teal ring with corner ticks, and an amber centre. Vector, so Connect IQ
rasterizes it at each device's exact launcher-icon size (no scaling warning).
Reproducible like the other assets.

Output: resources/drawables/launcher_icon.svg
"""

import os

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "resources", "drawables"))

S = 54.0  # viewBox size (preserves the original icon proportions)
DIAL = "#0D0A07"
TEAL = "#3FB6D6"
AMBER = "#FFC890"


def f(x):
    """Format a coordinate compactly (trim trailing zeros)."""
    return ("%.3f" % x).rstrip("0").rstrip(".")


def main():
    os.makedirs(OUT, exist_ok=True)
    c = S / 2.0
    stroke = 0.045 * S
    off = 0.27 * S
    tick = 0.12 * S

    parts = [
        '<svg xmlns="http://www.w3.org/2000/svg" width="%s" height="%s" '
        'viewBox="0 0 %s %s" fill="none">' % (f(S), f(S), f(S), f(S)),
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
    svg = "\n".join(parts) + "\n"

    with open(os.path.join(OUT, "launcher_icon.svg"), "w") as fh:
        fh.write(svg)
    print("wrote %s/launcher_icon.svg (viewBox %sx%s)" % (OUT, f(S), f(S)))


if __name__ == "__main__":
    main()
