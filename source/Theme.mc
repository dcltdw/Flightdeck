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

    // Lay the whole face. Called from the view's onUpdate.
    function draw(dc as Graphics.Dc, m as Metrics, fonts as Fonts, light as Boolean) as Void {
        var p = buildPalette(light);
        var L = buildLayout(fonts);
        var s = dc.getWidth() / 390.0;
        L.scale(s);

        dc.setColor(Graphics.COLOR_WHITE, p.ground);
        dc.clear();

        decorate(dc, light, s);

        var lf = L.lblFont;
        var vf = L.valFont;
        var hf = L.heroFont;
        if (lf == null || vf == null || hf == null) {
            return; // misconfigured layout; nothing to draw
        }

        var C = Graphics.TEXT_JUSTIFY_CENTER;
        var tf = L.titleFont;
        var tt = L.title;
        if (tf != null && tt != null) {
            txt(dc, L.ctr, L.titleY, L.titleAsc, tf, p.title, tt, C);
        }

        // Corner values are edge-justified so they grow toward centre (never off
        // the round edge): right column right-justified, left column left-
        // justified. The anchor sits at a 4-char value's current edge (half a
        // 4-char value from the column centre), so typical values stay put.
        // Labels remain centred on the column.
        var vHalf = dc.getTextWidthInPixels("0:00", vf) / 2;
        var L_ = Graphics.TEXT_JUSTIFY_LEFT;
        var R_ = Graphics.TEXT_JUSTIFY_RIGHT;

        // top row — session
        txt(dc, L.colL, L.lblY1, L.lblAsc, lf, p.label, "PACE", C);
        txt(dc, L.colL - vHalf, L.valY1, L.valAsc, vf, p.sval, m.sessionPace, L_);
        txt(dc, L.colR, L.lblY1, L.lblAsc, lf, p.label, "DIST", C);
        txt(dc, L.colR + vHalf, L.valY1, L.valAsc, vf, p.sval, m.sessionDist, R_);

        // hero — elapsed
        txt(dc, L.ctr, L.heroY, L.heroAsc, hf, p.hero, m.heroTime, C);

        // bottom row — lap
        txt(dc, L.colL, L.lblY2, L.lblAsc, lf, p.label, "PACE", C);
        txt(dc, L.colL - vHalf, L.valY2, L.valAsc, vf, p.lap, m.lapPace, L_);
        txt(dc, L.colR, L.lblY2, L.lblAsc, lf, p.label, "TIME", C);
        txt(dc, L.colR + vHalf, L.valY2, L.valAsc, vf, p.lap, m.lapTime, R_);
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
