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

    // Bold weights (Wall) are larger and loaded lazily — only when a theme that
    // needs them is actually selected, to spare the 256 KB data-field budget.
    private var _heroB as WatchUi.FontResource?;
    private var _valueB as WatchUi.FontResource?;
    private var _labelB as WatchUi.FontResource?;
    private var _v52 as WatchUi.FontResource?;
    private var _v76 as WatchUi.FontResource?;
    private var _v104 as WatchUi.FontResource?;
    private var _v52b as WatchUi.FontResource?;
    private var _v76b as WatchUi.FontResource?;
    private var _v104b as WatchUi.FontResource?;

    function initialize() {
        label = WatchUi.loadResource(Rez.Fonts.LabelFont) as WatchUi.FontResource;
        value = WatchUi.loadResource(Rez.Fonts.ValueFont) as WatchUi.FontResource;
        hero  = WatchUi.loadResource(Rez.Fonts.HeroFont)  as WatchUi.FontResource;
        title = WatchUi.loadResource(Rez.Fonts.TitleFont) as WatchUi.FontResource;
    }

    function heroB() as WatchUi.FontResource {
        var f = _heroB;
        if (f == null) { f = WatchUi.loadResource(Rez.Fonts.HeroBoldFont) as WatchUi.FontResource; _heroB = f; }
        return f;
    }

    function valueB() as WatchUi.FontResource {
        var f = _valueB;
        if (f == null) { f = WatchUi.loadResource(Rez.Fonts.ValueBoldFont) as WatchUi.FontResource; _valueB = f; }
        return f;
    }

    function labelB() as WatchUi.FontResource {
        var f = _labelB;
        if (f == null) { f = WatchUi.loadResource(Rez.Fonts.LabelBoldFont) as WatchUi.FontResource; _labelB = f; }
        return f;
    }

    function value52()  as WatchUi.FontResource { if (_v52 == null)  { _v52  = WatchUi.loadResource(Rez.Fonts.Value52Font)  as WatchUi.FontResource; } return _v52; }
    function value76()  as WatchUi.FontResource { if (_v76 == null)  { _v76  = WatchUi.loadResource(Rez.Fonts.Value76Font)  as WatchUi.FontResource; } return _v76; }
    function value104() as WatchUi.FontResource { if (_v104 == null) { _v104 = WatchUi.loadResource(Rez.Fonts.Value104Font) as WatchUi.FontResource; } return _v104; }
    function value52B()  as WatchUi.FontResource { if (_v52b == null)  { _v52b  = WatchUi.loadResource(Rez.Fonts.Value52BoldFont)  as WatchUi.FontResource; } return _v52b; }
    function value76B()  as WatchUi.FontResource { if (_v76b == null)  { _v76b  = WatchUi.loadResource(Rez.Fonts.Value76BoldFont)  as WatchUi.FontResource; } return _v76b; }
    function value104B() as WatchUi.FontResource { if (_v104b == null) { _v104b = WatchUi.loadResource(Rez.Fonts.Value104BoldFont) as WatchUi.FontResource; } return _v104b; }
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
    public var font as WatchUi.FontResource;
    public var widthBudget as Number;
    public var role as Number;       // 0=hero(warm) 1=sval(white) 2=lap(accent)
    public var just as Graphics.TextJustification;
    public var labelX as Number;
    public var labelBaseY as Number;
    function initialize(slot, x, baseY, asc, font, widthBudget, role, just, labelX, labelBaseY) {
        self.slot = slot; self.x = x; self.baseY = baseY; self.asc = asc;
        self.font = font; self.widthBudget = widthBudget; self.role = role;
        self.just = just; self.labelX = labelX; self.labelBaseY = labelBaseY;
    }
}

// ---------------------------------------------------------------------------
// Base theme. Subclasses override buildPalette / buildLayout / decorate.
class Theme {

    // Subclass hooks (base returns harmless defaults).
    function buildPalette(light as Boolean) as Palette {
        return new Palette(0x000000, 0xFFFFFF, 0xFFFFFF, 0xFFFFFF, 0xFFFFFF, 0xFFFFFF);
    }

    function buildLayout(fonts as Fonts) as Layout {
        return new Layout();
    }

    // Theme-specific background art, drawn after clear, before the metrics.
    function decorate(dc as Graphics.Dc, light as Boolean, s as Float) as Void {}

    // Whether this theme's preset value font should be the bold weight
    // (Bulkhead only; base false).
    function usesBold() as Boolean { return false; }

    // Shared preset geometry (4/3/2/1). @390; scaled at draw. Positions are
    // starting values tuned in the sim. role: 0 hero/warm, 1 white, 2 accent.
    function presetSlots(layout as Number, fonts as Fonts, bold as Boolean) as Array<PresetSlot> {
        var C = Graphics.TEXT_JUSTIFY_CENTER;
        if (layout == 4) {
            var vf = bold ? fonts.value52B() : fonts.value52(); var a = 48;
            return [
                new PresetSlot(0, 108, 175, a, vf, 170, 1, C, 108, 120),
                new PresetSlot(1, 282, 175, a, vf, 170, 1, C, 282, 120),
                new PresetSlot(2, 108, 285, a, vf, 170, 2, C, 108, 230),
                new PresetSlot(3, 282, 285, a, vf, 170, 2, C, 282, 230),
            ];
        } else if (layout == 3) {
            var vf = bold ? fonts.value76B() : fonts.value76(); var a = 69;
            return [
                new PresetSlot(0, 195, 118, a, vf, 360, 0, C, 195, 70),
                new PresetSlot(1, 195, 218, a, vf, 360, 1, C, 195, 170),
                new PresetSlot(2, 195, 318, a, vf, 360, 2, C, 195, 270),
            ];
        } else if (layout == 2) {
            var vf = bold ? fonts.value104B() : fonts.value104(); var a = 95;
            return [
                new PresetSlot(0, 195, 160, a, vf, 360, 0, C, 195, 95),
                new PresetSlot(1, 195, 285, a, vf, 360, 2, C, 195, 220),
            ];
        } else { // 1
            var vf = bold ? fonts.value104B() : fonts.value104(); var a = 95;
            return [
                new PresetSlot(0, 195, 220, a, vf, 360, 0, C, 195, 120),
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
        decorate(dc, light, s);

        if (layout == 5) {
            drawGrid(dc, p, L, s, m, slots, showLabels);   // existing 5-field path
        } else {
            drawPreset(dc, p, L, s, m, slots, showLabels, layout, fonts);
        }
    }

    private function drawGrid(dc as Graphics.Dc, p as Palette, L as Layout, s as Float,
                              m as Metrics, slots as Array<Number>, showLabels as Boolean) as Void {
        var lf = L.lblFont;
        var vf = L.valFont;
        var hf = L.heroFont;
        if (lf == null || vf == null || hf == null) {
            return; // misconfigured layout; nothing to draw
        }

        var C = Graphics.TEXT_JUSTIFY_CENTER;
        var Lj = Graphics.TEXT_JUSTIFY_LEFT;
        var Rj = Graphics.TEXT_JUSTIFY_RIGHT;

        var tf = L.titleFont;
        var tt = L.title;
        if (tf != null && tt != null) {
            txt(dc, L.ctr, L.titleY, L.titleAsc, tf, p.title, tt, C);
        }

        // Values grow toward centre: the anchor sits half a 4-char value in
        // from the column centre (left column left-justified, right right).
        var vHalf = dc.getTextWidthInPixels("0:00", vf) / 2;

        drawValue(dc, m, slots[0], L.ctr,          L.heroY, L.heroAsc, hf, p.hero, C);
        drawValue(dc, m, slots[1], L.colL - vHalf, L.valY1, L.valAsc,  vf, p.sval, Lj);
        drawValue(dc, m, slots[2], L.colR + vHalf, L.valY1, L.valAsc,  vf, p.sval, Rj);
        drawValue(dc, m, slots[3], L.colL - vHalf, L.valY2, L.valAsc,  vf, p.lap,  Lj);
        drawValue(dc, m, slots[4], L.colR + vHalf, L.valY2, L.valAsc,  vf, p.lap,  Rj);

        if (showLabels) {
            drawLabel(dc, m, slots[1], L.colL, L.lblY1, L.lblAsc, lf, p.label);
            drawLabel(dc, m, slots[2], L.colR, L.lblY1, L.lblAsc, lf, p.label);
            drawLabel(dc, m, slots[3], L.colL, L.lblY2, L.lblAsc, lf, p.label);
            drawLabel(dc, m, slots[4], L.colR, L.lblY2, L.lblAsc, lf, p.label);
        }
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
        var ps = presetSlots(layout, fonts, usesBold());
        for (var i = 0; i < ps.size(); i++) {
            var d = ps[i];
            var id = slots[d.slot];
            if (id == 0) { continue; } // Off
            var color = (d.role == 0) ? p.hero : (d.role == 1 ? p.sval : p.lap);
            txt(dc, rnd(d.x * s), rnd(d.baseY * s), rnd(d.asc * s), d.font, color, m.format(id), d.just);
            if (showLabels && lf != null) {
                // L.lblAsc is already scaled by L.scale(s); d.labelX/labelBaseY are @390 so scale them.
                txt(dc, rnd(d.labelX * s), rnd(d.labelBaseY * s), L.lblAsc, lf, p.label, m.label(id), Graphics.TEXT_JUSTIFY_CENTER);
            }
        }
    }

    private function drawValue(dc as Graphics.Dc, m as Metrics, id as Number,
                               x as Number, baseY as Number, ascent as Number,
                               font as WatchUi.FontResource, color as Number,
                               just as Graphics.TextJustification) as Void {
        if (id == 0) { return; } // Off
        txt(dc, x, baseY, ascent, font, color, m.format(id), just);
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
