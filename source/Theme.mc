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
    private var _v104 as WatchUi.FontResource?;
    private var _v64 as WatchUi.FontResource?;
    private var _v60 as WatchUi.FontResource?;
    private var _v40 as WatchUi.FontResource?;

    function initialize() {
        label = WatchUi.loadResource(Rez.Fonts.LabelFont) as WatchUi.FontResource;
        value = WatchUi.loadResource(Rez.Fonts.ValueFont) as WatchUi.FontResource;
        hero  = WatchUi.loadResource(Rez.Fonts.HeroFont)  as WatchUi.FontResource;
        title = WatchUi.loadResource(Rez.Fonts.TitleFont) as WatchUi.FontResource;
    }

    function value52()  as WatchUi.FontResource { if (_v52 == null)  { _v52  = WatchUi.loadResource(Rez.Fonts.Value52Font)  as WatchUi.FontResource; } return _v52; }
    function value76()  as WatchUi.FontResource { if (_v76 == null)  { _v76  = WatchUi.loadResource(Rez.Fonts.Value76Font)  as WatchUi.FontResource; } return _v76; }
    function value104() as WatchUi.FontResource { if (_v104 == null) { _v104 = WatchUi.loadResource(Rez.Fonts.Value104Font) as WatchUi.FontResource; } return _v104; }
    function value64()  as WatchUi.FontResource { if (_v64 == null)  { _v64  = WatchUi.loadResource(Rez.Fonts.Value64Font)  as WatchUi.FontResource; } return _v64; }
    function value60() as WatchUi.FontResource { if (_v60 == null) { _v60 = WatchUi.loadResource(Rez.Fonts.Value60Font) as WatchUi.FontResource; } return _v60; }
    function value40() as WatchUi.FontResource { if (_v40 == null) { _v40 = WatchUi.loadResource(Rez.Fonts.Value40Font) as WatchUi.FontResource; } return _v40; }
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
// One field slot within a preset: which config slot it draws, where, at what
// size/role. x/baseY/asc/widthBudget/labelX/labelY are @390 (scaled at draw).
class PresetSlot {
    public var slot as Number;      // config slot index 0..4
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
    // @390, scaled at draw. Returns 0 only for unknown layouts (none drawn).
    function blipCy(layout as Number) as Number {
        if (layout == 5) { return 248; } // between hero and bottom row
        if (layout == 4) { return 205; }
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
            var vf = fonts.value64(); var a = 68;
            return [
                new PresetSlot(0, 108, 146, a, 64, vf, 170, 1, C, 108, 94),
                new PresetSlot(1, 282, 146, a, 64, vf, 170, 1, C, 282, 94),
                new PresetSlot(2, 108, 300, a, 64, vf, 170, 2, C, 108, 248),
                new PresetSlot(3, 282, 300, a, 64, vf, 170, 2, C, 282, 248),
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

    // Draw a two-colon duration as [40pt prefix][60pt MM:SS], the two vertically
    // centred together (their cap-centres aligned), justified as one group about
    // `anchorX`. `just` selects group left/right/centre. baseY/anchorX are device px.
    private function drawDurationGroup(dc as Graphics.Dc, s as Float, str as String,
                                       anchorX as Number, baseY as Number,
                                       just as Graphics.TextJustification,
                                       fonts as Fonts, color as Number) as Void {
        var first = str.find(":");
        var pre = str.substring(0, first + 1);            // "1:" / "12:"
        var rest = str.substring(first + 1, str.length()); // "MM:SS"
        var fp = fonts.value40();
        var fb = fonts.value60();
        var wp = dc.getTextWidthInPixels(pre, fp);
        var wr = dc.getTextWidthInPixels(rest, fb);
        var total = wp + wr;
        var left;
        if (just == Graphics.TEXT_JUSTIFY_RIGHT) { left = anchorX - total; }
        else if (just == Graphics.TEXT_JUSTIFY_CENTER) { left = anchorX - total / 2.0; }
        else { left = anchorX; }
        // baseY is the 60pt baseline; the 40pt prefix baseline shifts up so the
        // two cap-centres align: delta = (asc60 - asc40)/2, scaled.
        var preBaseY = baseY - rnd(((VAL60_ASC - VAL40_ASC) / 2.0) * s);
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(rnd(left), preBaseY - rnd(VAL40_ASC * s), fp, pre, Graphics.TEXT_JUSTIFY_LEFT);
        dc.drawText(rnd(left + wp), baseY - rnd(VAL60_ASC * s), fb, rest, Graphics.TEXT_JUSTIFY_LEFT);
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
                drawDurationGroup(dc, s, hstr, L.ctr, scN(GRID_HERO_Y, s), C, fonts, p.hero);
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
            drawDurationGroup(dc, s, str, rnd(groupAnchor), baseY, gjust, fonts, color);
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

    // Largest ladder size <= target whose rendered width fits budgetPx. Shrink-only.
    // Returns [font, ascent390]. Ladder: 104,76,64,52,34.
    private function fitValueFont(dc as Graphics.Dc, str as String, budgetPx as Number,
                                  startSize as Number, fonts as Fonts) as Array {
        var sizes = [104, 76, 64, 52, 34];
        for (var i = 0; i < sizes.size(); i++) {
            var sz = sizes[i];
            if (sz > startSize) { continue; }
            var f; var a;
            if (sz == 104) { f = fonts.value104(); a = 109; }
            else if (sz == 76) { f = fonts.value76(); a = 80; }
            else if (sz == 64) { f = fonts.value64(); a = 68; }
            else if (sz == 52) { f = fonts.value52(); a = 55; }
            else { f = fonts.value; a = 36; }
            if (dc.getTextWidthInPixels(str, f) <= budgetPx) { return [f, a]; }
        }
        // even the floor overflows: use the floor (34) and let it clip minimally
        return [fonts.value, 36];
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
        for (var i = 0; i < ps.size(); i++) {
            var d = ps[i];
            var id = slots[d.slot];
            if (id == 0) { continue; } // Off
            var color = (d.role == 0) ? p.hero : (d.role == 1 ? p.sval : p.lap);
            var vstr = m.format(id);
            var fit = fitValueFont(dc, vstr, rnd(d.widthBudget * s), d.size, fonts);
            txt(dc, rnd(d.x * s), rnd(d.baseY * s), rnd((fit[1] as Number) * s), fit[0] as WatchUi.FontResource, color, vstr, d.just);
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
