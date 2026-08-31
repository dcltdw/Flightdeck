import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Theme framework shared by every face. A concrete theme supplies a Palette
// (colours for the active mode), a Layout (geometry + which fonts each slot
// uses), and optional decorate() background art. The base draw() lays the
// four-corner metric grid + hero clock identically for all themes, so adding a
// theme is "subclass Theme", not new layout code.

// Scale + round a reference-design (@390) coordinate to the active screen.
function scN(v as Number, s as Float) as Number { return rnd(v * s); }
// Scale a pen width, never below 1px.
function scP(v as Number, s as Float) as Number { var w = rnd(v * s); return w < 1 ? 1 : w; }
// Round a Float to nearest Number.
function rnd(v as Float) as Number { return (v + 0.5).toNumber(); }

// ---------------------------------------------------------------------------
// Loaded font resources, shared by all themes (load once in the view).
class Fonts {
    public var label as WatchUi.FontResource;  // regular, 30px  (ascent 28)
    public var value as WatchUi.FontResource;  // regular, 34px  (ascent 31)
    public var hero  as WatchUi.FontResource;  // regular, 60px  (ascent 55)
    public var title as WatchUi.FontResource;  // regular, 13px  (ascent 12)

    // Bigger value cuts, loaded lazily — only when a preset that needs them is
    // actually drawn, to spare the 256 KB data-field budget.
    private var _v52 as WatchUi.FontResource?;
    private var _v76 as WatchUi.FontResource?;
    private var _v88 as WatchUi.FontResource?;
    private var _v104 as WatchUi.FontResource?;
    private var _v64 as WatchUi.FontResource?;
    private var _v60 as WatchUi.FontResource?;
    private var _v40 as WatchUi.FontResource?;
    private var _v44 as WatchUi.FontResource?;

    function initialize() {
        label = WatchUi.loadResource(Rez.Fonts.LabelFont) as WatchUi.FontResource;
        value = WatchUi.loadResource(Rez.Fonts.ValueFont) as WatchUi.FontResource;
        hero  = WatchUi.loadResource(Rez.Fonts.HeroFont)  as WatchUi.FontResource;
        title = WatchUi.loadResource(Rez.Fonts.TitleFont) as WatchUi.FontResource;
    }

    function value52()  as WatchUi.FontResource { if (_v52 == null)  { _v52  = WatchUi.loadResource(Rez.Fonts.Value52Font)  as WatchUi.FontResource; } return _v52; }
    function value76()  as WatchUi.FontResource { if (_v76 == null)  { _v76  = WatchUi.loadResource(Rez.Fonts.Value76Font)  as WatchUi.FontResource; } return _v76; }
    function value88()  as WatchUi.FontResource { if (_v88 == null)  { _v88  = WatchUi.loadResource(Rez.Fonts.Value88Font)  as WatchUi.FontResource; } return _v88; }
    function value104() as WatchUi.FontResource { if (_v104 == null) { _v104 = WatchUi.loadResource(Rez.Fonts.Value104Font) as WatchUi.FontResource; } return _v104; }
    function value64()  as WatchUi.FontResource { if (_v64 == null)  { _v64  = WatchUi.loadResource(Rez.Fonts.Value64Font)  as WatchUi.FontResource; } return _v64; }
    function value60() as WatchUi.FontResource { if (_v60 == null) { _v60 = WatchUi.loadResource(Rez.Fonts.Value60Font) as WatchUi.FontResource; } return _v60; }
    function value40() as WatchUi.FontResource { if (_v40 == null) { _v40 = WatchUi.loadResource(Rez.Fonts.Value40Font) as WatchUi.FontResource; } return _v40; }
    function value44() as WatchUi.FontResource { if (_v44 == null) { _v44 = WatchUi.loadResource(Rez.Fonts.Value44Font) as WatchUi.FontResource; } return _v44; }
}

// ---------------------------------------------------------------------------
// Colour roles for one theme in one mode. Decorative colours (reticles, frame,
// stripes, ...) live in each theme's decorate(); these are the shared roles.
class Palette {
    public var ground as Number;  // the colour the screen is cleared to
    public var label  as Number;
    public var sval   as Number;  // session value (top row) — white on the dark faces
    public var lap    as Number;  // lap value (bottom row) — a per-theme accent colour
    public var hero   as Number;
    public var title  as Number;

    function initialize(ground as Number, label as Number, sval as Number,
                        lap as Number, hero as Number, title as Number) {
        self.ground = ground;
        self.label = label;
        self.sval = sval;
        self.lap = lap;
        self.hero = hero;
        self.title = title;
    }
}

// ---------------------------------------------------------------------------
// Geometry + font selection for the metric grid. Baselines are SVG-style (the
// glyph baseline); the per-font ascent converts each to a drawText cell-top.
class Layout {
    public var colL as Number = 112;
    public var colR as Number = 278;
    public var ctr  as Number = 195;
    public var lblY1 as Number = 0;
    public var valY1 as Number = 0;
    public var heroY as Number = 0;
    public var lblY2 as Number = 0;
    public var valY2 as Number = 0;
    public var lblAsc as Number = 0;
    public var valAsc as Number = 0;
    public var heroAsc as Number = 0;
    public var titleY as Number = 0;
    public var titleAsc as Number = 0;
    public var lblFont as WatchUi.FontResource?;
    public var valFont as WatchUi.FontResource?;
    public var heroFont as WatchUi.FontResource?;
    public var titleFont as WatchUi.FontResource?;
    public var title as String?;

    function initialize() {}

    // Scale every geometric field from the 390 reference to this screen.
    function scale(s as Float) as Void {
        colL = rnd(colL * s); colR = rnd(colR * s); ctr = rnd(ctr * s);
        lblY1 = rnd(lblY1 * s); valY1 = rnd(valY1 * s); heroY = rnd(heroY * s);
        lblY2 = rnd(lblY2 * s); valY2 = rnd(valY2 * s);
        lblAsc = rnd(lblAsc * s); valAsc = rnd(valAsc * s); heroAsc = rnd(heroAsc * s);
        titleY = rnd(titleY * s); titleAsc = rnd(titleAsc * s);
    }
}

// ---------------------------------------------------------------------------
// One field slot within a preset: which slot of the active layout's slots
// array it draws, where, at what size/role.
// x/baseY/asc/widthBudget/labelX/labelY are @390 (scaled at draw).
class PresetSlot {
    public var slot as Number;      // index into the active layout's slots array
    public var x as Number;
    public var baseY as Number;
    public var asc as Number;
    public var size as Number;       // ladder start size (52/64/76/104); shrink target
    public var font as WatchUi.FontResource;
    public var widthBudget as Number;
    public var role as Number;       // 0=hero(warm) 1=sval(white) 2=lap(accent)
    public var just as Graphics.TextJustification;
    public var labelX as Number;
    public var labelBaseY as Number;
    // Slots sharing a non-zero group all render at the smallest cut any of
    // them needs, so a wide value on one side shrinks its partners to match.
    // 0 = ungrouped (each slot sizes itself).
    public var sizeGroup as Number = 0;
    function initialize(slot, x, baseY, asc, size, font, widthBudget, role, just, labelX, labelBaseY) {
        self.slot = slot; self.x = x; self.baseY = baseY; self.asc = asc; self.size = size;
        self.font = font; self.widthBudget = widthBudget; self.role = role;
        self.just = just; self.labelX = labelX; self.labelBaseY = labelBaseY;
    }
}

// ---------------------------------------------------------------------------
// Base theme. Subclasses override buildPalette / buildLayout / decorate.
class Theme {

    // 5-field geometry @390 — tuned in the simulator (Task 7).
    hidden const GRID_TOP_Y = 120;   // top-row baseline
    hidden const GRID_HERO_Y = 217;  // hero baseline (unchanged)
    hidden const GRID_BOT_Y = 305;   // bottom-row baseline
    hidden const GRID_EDGE_L = 70;   // left outer-digit target x (Cockpit reticle bar)
    hidden const GRID_EDGE_R = 320;  // right outer-digit target x
    hidden const VAL60_ASC = 63;     // value60 @390 ascent
    hidden const VAL40_ASC = 42;     // value40 @390 ascent
    hidden const GRID_GAP = 14;      // half centre safety gap @390
    // Highest PresetSlot.sizeGroup any layout uses (0 means ungrouped, so the
    // cap array holds this many entries plus one). Raise it if a layout adds
    // a group; a group id above it degrades silently to ungrouped.
    hidden const MAX_SIZE_GROUP = 1;

    // Subclass hooks (base returns harmless defaults).
    function buildPalette(light as Boolean) as Palette {
        return new Palette(0x000000, 0xFFFFFF, 0xFFFFFF, 0xFFFFFF, 0xFFFFFF, 0xFFFFFF);
    }

    function buildLayout(fonts as Fonts) as Layout {
        return new Layout();
    }

    // Theme-specific background art, drawn after clear, before the metrics.
    function decorate(dc as Graphics.Dc, light as Boolean, s as Float, layout as Number) as Void {}

    // Two small diamond "blips" at a layout-dependent y (Cockpit/Bridge use them).
    // @390, scaled at draw. Returns 0 to mean "none drawn" — for unknown
    // layouts, and deliberately for layout 4, whose compass E/W values own
    // the midline the blips would otherwise sit on.
    function blipCy(layout as Number) as Number {
        if (layout == 5) { return 248; } // between hero and bottom row
        if (layout == 4) { return 0; }  // compass: E/W own the midline; no blip band
        if (layout == 3) { return 140; } // above the middle (centre) field
        if (layout == 2) { return 180; }
        if (layout == 1) { return 110; } // above the single centre value
        return 0;
    }
    function drawBlips(dc as Graphics.Dc, s as Float, layout as Number, color as Number) as Void {
        var cy = blipCy(layout);
        if (cy == 0) { return; }
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        var y = scN(cy, s); var r = scP(7, s); var gap = scN(15, s); var cx = scN(195, s); var stag = scN(9, s);
        for (var k = -1; k <= 1; k += 2) {
            var bx = cx + k * gap;
            var by = y + k * stag; // vertical stagger: left up, right down
            dc.fillPolygon([[bx, by - r], [bx + r, by], [bx, by + r], [bx - r, by]]);
        }
    }

    // Shared preset geometry (4/3/2/1). @390; scaled at draw. Positions are
    // starting values tuned in the sim. role: 0 hero/warm, 1 white, 2 accent.
    function presetSlots(layout as Number, fonts as Fonts) as Array<PresetSlot> {
        var C = Graphics.TEXT_JUSTIFY_CENTER;
        if (layout == 4) {
            // Compass N/E/S/W. N and S are both 88pt; E/W hug the midline
            // edges and grow inward. 88 is the balance point: E/W are hard
            // capped at 64 by the screen's width (two 5-char values at 76 want
            // 424px on a 390px screen), so 104 on N/S made the flanks look like
            // afterthoughts, while 76 gave up too much. S's baseline sits at
            // 320, one pixel under the Cockpit corner brackets, which is the
            // line the layout reads against. E and W share a size group so the
            // two flanking values always render at the same cut even when one
            // side's string is wider. Budgets are sized so every position fits
            // an hours-prefix pair — see
            // docs/superpowers/specs/2026-08-30-compass-4field-design.md.
            var e = new PresetSlot(1, 378, 222, 80, 76, fonts.value76(), 178, 2, Graphics.TEXT_JUSTIFY_RIGHT, 289, 160);
            var w = new PresetSlot(3, 12, 222, 80, 76, fonts.value76(), 178, 2, Graphics.TEXT_JUSTIFY_LEFT, 101, 160);
            e.sizeGroup = 1; w.sizeGroup = 1;
            return [
                new PresetSlot(0, 195, 150, 93, 88, fonts.value88(), 296, 0, C, 195, 70),
                e,
                new PresetSlot(2, 195, 320, 93, 88, fonts.value88(), 294, 1, C, 195, 254),
                w,
            ];
        } else if (layout == 3) {
            var vf = fonts.value76(); var a = 80;
            return [
                new PresetSlot(0, 195, 118, a, 76, vf, 360, 0, C, 195, 70),
                new PresetSlot(1, 195, 218, a, 76, vf, 360, 1, C, 195, 170),
                new PresetSlot(2, 195, 318, a, 76, vf, 360, 2, C, 195, 270),
            ];
        } else if (layout == 2) {
            var vf = fonts.value104(); var a = 109;
            return [
                new PresetSlot(0, 195, 160, a, 104, vf, 360, 0, C, 195, 95),
                new PresetSlot(1, 195, 285, a, 104, vf, 360, 2, C, 195, 220),
            ];
        } else { // 1
            var vf = fonts.value104(); var a = 109;
            return [
                new PresetSlot(0, 195, 220, a, 104, vf, 360, 0, C, 195, 120),
            ];
        }
    }

    // Lay the whole face. Called from the view's onUpdate.
    function draw(dc as Graphics.Dc, m as Metrics, fonts as Fonts, light as Boolean,
                  slots as Array<Number>, showLabels as Boolean, layout as Number) as Void {
        var p = buildPalette(light);
        var L = buildLayout(fonts);
        var s = dc.getWidth() / 390.0;
        L.scale(s);
        dc.setColor(Graphics.COLOR_WHITE, p.ground);
        dc.clear();
        decorate(dc, light, s, layout);

        if (layout == 5) {
            drawGrid(dc, p, L, s, m, slots, showLabels, fonts);   // existing 5-field path
        } else {
            drawPreset(dc, p, L, s, m, slots, showLabels, layout, fonts);
        }
    }

    // A duration with an hours part formats as H:MM:SS (two colons); wall clock
    // is H:MM (one). Only two-colon strings get the hours-prefix treatment.
    private function isDuration(str as String) as Boolean {
        var first = str.find(":");
        if (first == null) { return false; }
        return (str.substring(first + 1, str.length()) as String).find(":") != null;
    }

    // Draw a two-colon duration as [small prefix][big MM:SS], the two vertically
    // centred together (their cap-centres aligned), justified as one group about
    // `anchorX`. `just` selects group left/right/centre. baseY/anchorX are device px.
    // The two cuts are parameters, not fixed: the 5-field grid passes 60/40, the
    // preset layouts pass a pair off their own ladder.
    private function drawDurationGroup(dc as Graphics.Dc, s as Float, str as String,
                                       anchorX as Number, baseY as Number,
                                       just as Graphics.TextJustification,
                                       color as Number,
                                       fb as WatchUi.FontResource, bigAsc as Number,
                                       fp as WatchUi.FontResource, smallAsc as Number) as Void {
        var first = str.find(":");
        var pre = str.substring(0, first + 1);            // "1:" / "12:"
        var rest = str.substring(first + 1, str.length()); // "MM:SS"
        var wp = dc.getTextWidthInPixels(pre, fp);
        var wr = dc.getTextWidthInPixels(rest, fb);
        var total = wp + wr;
        var left;
        if (just == Graphics.TEXT_JUSTIFY_RIGHT) { left = anchorX - total; }
        else if (just == Graphics.TEXT_JUSTIFY_CENTER) { left = anchorX - total / 2.0; }
        else { left = anchorX; }
        // baseY is the big cut's baseline; the prefix baseline shifts up so the
        // two cap-centres align: delta = (bigAsc - smallAsc)/2, scaled.
        var preBaseY = baseY - rnd(((bigAsc - smallAsc) / 2.0) * s);
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(rnd(left), preBaseY - rnd(smallAsc * s), fp, pre, Graphics.TEXT_JUSTIFY_LEFT);
        dc.drawText(rnd(left + wp), baseY - rnd(bigAsc * s), fb, rest, Graphics.TEXT_JUSTIFY_LEFT);
    }

    private function drawGrid(dc as Graphics.Dc, p as Palette, L as Layout, s as Float,
                              m as Metrics, slots as Array<Number>, showLabels as Boolean,
                              fonts as Fonts) as Void {
        var lf = L.lblFont;
        if (lf == null) { return; }

        var C = Graphics.TEXT_JUSTIFY_CENTER;

        var tf = L.titleFont;
        var tt = L.title;
        if (tf != null && tt != null) {
            txt(dc, L.ctr, L.titleY, L.titleAsc, tf, p.title, tt, C);
        }

        // Hero centred at 60pt; corners anchor their outer digit on the edge
        // target and grow inward. value60 uniformly.
        if (slots[0] != 0) {
            var hstr = m.format(slots[0]);
            if (isDuration(hstr)) {
                drawDurationGroup(dc, s, hstr, L.ctr, scN(GRID_HERO_Y, s), C, p.hero,
                                  fonts.value60(), VAL60_ASC, fonts.value40(), VAL40_ASC);
            } else {
                txt(dc, L.ctr, scN(GRID_HERO_Y, s), rnd(VAL60_ASC * s), fonts.value60(), p.hero, hstr, C);
            }
        }
        drawCorner(dc, s, m, slots[1], scN(GRID_EDGE_L, s), L.ctr, true,  scN(GRID_TOP_Y, s), fonts, p.sval);
        drawCorner(dc, s, m, slots[2], scN(GRID_EDGE_R, s), L.ctr, false, scN(GRID_TOP_Y, s), fonts, p.sval);
        drawCorner(dc, s, m, slots[3], scN(GRID_EDGE_L, s), L.ctr, true,  scN(GRID_BOT_Y, s), fonts, p.lap);
        drawCorner(dc, s, m, slots[4], scN(GRID_EDGE_R, s), L.ctr, false, scN(GRID_BOT_Y, s), fonts, p.lap);

        if (showLabels) {
            drawLabel(dc, m, slots[1], L.colL, L.lblY1, L.lblAsc, lf, p.label);
            drawLabel(dc, m, slots[2], L.colR, L.lblY1, L.lblAsc, lf, p.label);
            drawLabel(dc, m, slots[3], L.colL, L.lblY2, L.lblAsc, lf, p.label);
            drawLabel(dc, m, slots[4], L.colR, L.lblY2, L.lblAsc, lf, p.label);
        }
    }

    // One 5-field corner value. The outer digit is centred on `edgeX`; the value
    // is edge-justified so it grows inward (toward `ctr`). value60 uniformly.
    // (Task 3 adds the hours-prefix for durations; Task 4 adds shrink-to-fit.)
    private function drawCorner(dc as Graphics.Dc, s as Float, m as Metrics, id as Number,
                                edgeX as Number, ctr as Number, growRight as Boolean,
                                baseY as Number, fonts as Fonts, color as Number) as Void {
        if (id == 0) { return; } // Off
        var str = m.format(id);
        if (isDuration(str)) {
            var groupAnchor = growRight ? (edgeX - dc.getTextWidthInPixels("0", fonts.value60()) / 2.0) : (edgeX + dc.getTextWidthInPixels("0", fonts.value60()) / 2.0);
            var gjust = growRight ? Graphics.TEXT_JUSTIFY_LEFT : Graphics.TEXT_JUSTIFY_RIGHT;
            drawDurationGroup(dc, s, str, rnd(groupAnchor), baseY, gjust, color,
                              fonts.value60(), VAL60_ASC, fonts.value40(), VAL40_ASC);
            return;
        }
        // Inward room from the outer edge to a small centre gap. The outer digit
        // is centred on edgeX, so it sits half a 60pt digit outside edgeX — add
        // that half back so a value that just fits at 60pt isn't shrunk falsely.
        var half60 = dc.getTextWidthInPixels("0", fonts.value60()) / 2.0;
        var budget = growRight ? (ctr - scN(GRID_GAP, s) - edgeX + half60) : (edgeX + half60 - ctr - scN(GRID_GAP, s));
        var fit = fitGridFont(dc, str, budget.toNumber(), fonts);
        var f = fit[0] as WatchUi.FontResource;
        var a = fit[1] as Number;
        var digW = dc.getTextWidthInPixels("0", f);
        var anchorX = growRight ? (edgeX - digW / 2.0) : (edgeX + digW / 2.0);
        var just = growRight ? Graphics.TEXT_JUSTIFY_LEFT : Graphics.TEXT_JUSTIFY_RIGHT;
        txt(dc, rnd(anchorX), baseY, rnd(a * s), f, color, str, just);
    }

    // 5-field shrink ladder for wide NON-duration values: 60 -> 52 -> 34.
    // Largest cut whose width fits budgetPx; shrink-only. Returns [font, asc390].
    private function fitGridFont(dc as Graphics.Dc, str as String, budgetPx as Number,
                                 fonts as Fonts) as Array {
        var f60 = fonts.value60();
        if (dc.getTextWidthInPixels(str, f60) <= budgetPx) { return [f60, VAL60_ASC]; }
        var f52 = fonts.value52();
        if (dc.getTextWidthInPixels(str, f52) <= budgetPx) { return [f52, 55]; }
        return [fonts.value, 36];
    }

    // [font, ascent@390] for one cut of the preset ladder. 34 is the floor and
    // the default, so an unknown size lands there rather than failing.
    private function cutFont(sz as Number, fonts as Fonts) as Array {
        if (sz == 104) { return [fonts.value104(), 109]; }
        else if (sz == 88) { return [fonts.value88(), 93]; }
        else if (sz == 76) { return [fonts.value76(), 80]; }
        else if (sz == 64) { return [fonts.value64(), 68]; }
        else if (sz == 52) { return [fonts.value52(), 55]; }
        else if (sz == 44) { return [fonts.value44(), 47]; }
        return [fonts.value, 36];
    }

    // The small-prefix partner for a big cut: the largest ladder cut at or under
    // 0.7x it, which is where the 5-field pair sits (40/60 = 0.67). 34 is the
    // ladder floor and has no partner — 0 means "no pair", i.e. fall back to
    // shrinking the whole value. Three branches below deliberately break the
    // 0.7x rule: 64 stays frozen at its pre-ladder partner 34 (no live budget
    // lands in the 211-260px window where the 34-vs-44 partner choice changes
    // the outcome); 44 — the ladder floor's newest neighbour — has only
    // 34 left to pair with; and 88 takes 52 (0.59) rather than the 64 the rule
    // would pick, because 88+64 overflows every live budget on every bucket
    // while 88+52 fits `1:00:04` on all four. Don't "fix" any of them back
    // onto the ratio.
    private function prefixCut(bigSize as Number) as Number {
        if (bigSize == 104) { return 64; }
        else if (bigSize == 88) { return 52; }
        else if (bigSize == 76) { return 52; }
        else if (bigSize == 64) { return 34; }
        else if (bigSize == 52) { return 34; }
        else if (bigSize == 44) { return 34; }
        return 0;
    }

    // Largest ladder pair, at or below startSize, whose [prefix][MM:SS] total fits
    // budgetPx. This is what keeps MM:SS at the layout's own size instead of
    // shrinking the whole value to make room for the hours. Returns
    // [bigFont, bigAsc, smallFont, smallAsc, bigSize], or null when no pair fits.
    private function fitDurationPair(dc as Graphics.Dc, str as String, budgetPx as Number,
                                     startSize as Number, fonts as Fonts) as Array or Null {
        var first = str.find(":");
        if (first == null) { return null; }
        var pre = str.substring(0, first + 1);
        var rest = str.substring(first + 1, str.length()) as String;
        var sizes = [104, 88, 76, 64, 52, 44];
        for (var i = 0; i < sizes.size(); i++) {
            var sz = sizes[i];
            if (sz > startSize) { continue; }
            var ps = prefixCut(sz);
            if (ps == 0) { continue; }
            var big = cutFont(sz, fonts);
            var small = cutFont(ps, fonts);
            var fb = big[0] as WatchUi.FontResource;
            var fp = small[0] as WatchUi.FontResource;
            var w = dc.getTextWidthInPixels(pre, fp) + dc.getTextWidthInPixels(rest, fb);
            if (w <= budgetPx) { return [fb, big[1], fp, small[1], sz]; }
        }
        return null;
    }

    // Largest ladder size <= target whose rendered width fits budgetPx. Shrink-only.
    // Returns [font, ascent390, size]. Ladder: 104,88,76,64,52,44,34.
    private function fitValueFont(dc as Graphics.Dc, str as String, budgetPx as Number,
                                  startSize as Number, fonts as Fonts) as Array {
        var sizes = [104, 88, 76, 64, 52, 44, 34];
        for (var i = 0; i < sizes.size(); i++) {
            var sz = sizes[i];
            if (sz > startSize) { continue; }
            var cut = cutFont(sz, fonts);
            var f = cut[0] as WatchUi.FontResource;
            if (dc.getTextWidthInPixels(str, f) <= budgetPx) { return [cut[0], cut[1], sz]; }
        }
        // even the floor overflows: use the floor (34) and let it clip minimally
        return [fonts.value, 36, 34];
    }

    // The cut a slot will actually land on, without drawing it — the pair's big
    // size for an hours duration, otherwise the shrink-to-fit size. Size groups
    // use this to agree on a common cut before anything is drawn.
    private function resolvedSize(dc as Graphics.Dc, str as String, budgetPx as Number,
                                  startSize as Number, fonts as Fonts) as Number {
        if (isDuration(str)) {
            var pair = fitDurationPair(dc, str, budgetPx, startSize, fonts);
            if (pair != null) { return pair[4] as Number; }
        }
        return fitValueFont(dc, str, budgetPx, startSize, fonts)[2] as Number;
    }

    private function drawPreset(dc as Graphics.Dc, p as Palette, L as Layout, s as Float,
                                m as Metrics, slots as Array<Number>, showLabels as Boolean,
                                layout as Number, fonts as Fonts) as Void {
        // title banner (unchanged) so Cockpit/Bridge keep their header
        var tf = L.titleFont; var tt = L.title;
        if (tf != null && tt != null) {
            txt(dc, L.ctr, L.titleY, L.titleAsc, tf, p.title, tt, Graphics.TEXT_JUSTIFY_CENTER);
        }
        var lf = L.lblFont;
        var ps = presetSlots(layout, fonts);

        // Format each slot's value once. Both the group pre-pass and the draw
        // loop need it, and METRIC_CLOCK reads the system clock on every call —
        // formatting twice could straddle a minute rollover and size a slot
        // from a string it never draws. null marks an Off slot.
        var vals = new [ps.size()];
        for (var i = 0; i < ps.size(); i++) {
            var vid = slots[ps[i].slot];
            vals[i] = (vid == 0) ? null : m.format(vid);
        }

        // Size groups: resolve every grouped slot's own best cut first, then cap
        // the whole group at the smallest of them, so partners stay matched.
        // groupCap[g] is the agreed start size for group g; index 0 is unused
        // because 0 means "ungrouped", so the array holds MAX_SIZE_GROUP + 1
        // entries and a group id beyond it degrades to ungrouped.
        var groupCap = new [MAX_SIZE_GROUP + 1];
        for (var i = 0; i < groupCap.size(); i++) { groupCap[i] = 0; }
        for (var i = 0; i < ps.size(); i++) {
            var d = ps[i];
            if (d.sizeGroup == 0 || d.sizeGroup >= groupCap.size()) { continue; }
            if (vals[i] == null) { continue; } // Off slots don't constrain their partners
            var gsz = resolvedSize(dc, vals[i] as String, rnd(d.widthBudget * s), d.size, fonts);
            if (groupCap[d.sizeGroup] == 0 || gsz < groupCap[d.sizeGroup]) {
                groupCap[d.sizeGroup] = gsz;
            }
        }

        for (var i = 0; i < ps.size(); i++) {
            var d = ps[i];
            var id = slots[d.slot];
            if (id == 0) { continue; } // Off
            var color = (d.role == 0) ? p.hero : (d.role == 1 ? p.sval : p.lap);
            var vstr = vals[i] as String;
            var budget = rnd(d.widthBudget * s);
            var start = d.size;
            if (d.sizeGroup != 0 && d.sizeGroup < groupCap.size() && groupCap[d.sizeGroup] != 0) {
                start = groupCap[d.sizeGroup];
            }
            // A duration with an hours part draws as a small prefix + full-size
            // MM:SS; everything else (and a duration too wide for any pair)
            // shrinks whole.
            var pair = isDuration(vstr) ? fitDurationPair(dc, vstr, budget, start, fonts) : null;
            if (pair != null) {
                drawDurationGroup(dc, s, vstr, rnd(d.x * s), rnd(d.baseY * s), d.just, color,
                                  pair[0] as WatchUi.FontResource, pair[1] as Number,
                                  pair[2] as WatchUi.FontResource, pair[3] as Number);
            } else {
                var fit = fitValueFont(dc, vstr, budget, start, fonts);
                txt(dc, rnd(d.x * s), rnd(d.baseY * s), rnd((fit[1] as Number) * s), fit[0] as WatchUi.FontResource, color, vstr, d.just);
            }
            if (showLabels && lf != null) {
                // L.lblAsc is already scaled by L.scale(s); d.labelX/labelBaseY are @390 so scale them.
                txt(dc, rnd(d.labelX * s), rnd(d.labelBaseY * s), L.lblAsc, lf, p.label, m.label(id), Graphics.TEXT_JUSTIFY_CENTER);
            }
        }
    }

    private function drawLabel(dc as Graphics.Dc, m as Metrics, id as Number,
                               x as Number, baseY as Number, ascent as Number,
                               font as WatchUi.FontResource, color as Number) as Void {
        if (id == 0) { return; } // Off
        txt(dc, x, baseY, ascent, font, color, m.label(id), Graphics.TEXT_JUSTIFY_CENTER);
    }

    // Draw `str` with its baseline at design `baseY`, justified per `just`
    // about the anchor `x` (centre / left-edge / right-edge).
    function txt(dc as Graphics.Dc, x as Number, baseY as Number, ascent as Number,
                 font as WatchUi.FontResource, color as Number, str as String,
                 just as Graphics.TextJustification) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, baseY - ascent, font, str, just);
    }
}
