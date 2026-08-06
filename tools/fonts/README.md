# Vendored source font

`gen_fonts.py` rasterises this TTF into the committed BMFont atlases under
`resources-<bucket>/fonts/`. It is vendored rather than resolved from the host
so the generated atlases are reproducible on any machine, and so the licence of
everything we redistribute is unambiguous.

| | |
|---|---|
| Font | Roboto Mono, Regular |
| Copyright | Copyright 2015 The Roboto Mono Project Authors |
| Licence | Apache License 2.0 — `LICENSE-Apache-2.0.txt` |
| Upstream | https://github.com/googlefonts/RobotoMono |

Apache-2.0 permits redistribution and imposes no reserved-font-name clause, so
the rasterised glyph atlases we ship in the `.iq` carry no naming or
redistribution constraint.

## Why not the host system font

The atlases were previously generated from macOS's **Andale Mono**, a
proprietary Monotype face bundled with the OS. The rendered `.png`/`.fnt`
artifacts are committed and ship inside the Connect IQ build, so we were
redistributing output derived from a font we hold no redistribution rights to.
Replaced rather than argued about — the swap costs nothing and the ambiguity
was not worth carrying.

## Replacing the font again

Metrics are load-bearing. The app positions text by baseline and subtracts a
hardcoded per-font ascent to reach the `drawText` cell top, so every `base=`
value in the generated `.fnt` files has a matching constant in `source/`. After
changing the font, run `gen_fonts.py` and reconcile the ascent table it prints
against those constants — see the table in `../gen_fonts.py`.
