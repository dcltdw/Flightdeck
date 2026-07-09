import Toybox.Graphics;
import Toybox.Lang;

// Bulkhead — wall striping in the outer thirds (thick rounded "pills", offset
// between adjacent columns), bold large type, no title. Edge columns.
// Geometry/colours mirror docs/mockups/scripts/gen_wall.py.
class WallTheme extends Theme {

    function initialize() {
        Theme.initialize();
    }

    function usesBold() as Boolean { return false; }

    function buildPalette(light as Boolean) as Palette {
        if (light) {
            return new Palette(0xE7EBF0, 0x2F6076, 0xC62828, 0xC62828, 0xB06A0C, 0x000000);
        }
        return new Palette(0x060709, 0x8AA9C2, 0xFFFFFF, 0xFF6B52, 0xFFC890, 0x000000);
    }

    function buildLayout(fonts as Fonts) as Layout {
        var L = new Layout();
        L.colL = 112; L.colR = 278; L.ctr = 195;
        // no title
        L.lblY1 = 103; L.valY1 = 135;
        L.heroY = 217;
        L.lblY2 = 273; L.valY2 = 305;
        L.lblAsc = 28; L.valAsc = 48; L.heroAsc = 55;
        L.lblFont = fonts.label; L.valFont = fonts.value52(); L.heroFont = fonts.hero;
        return L;
    }

    function decorate(dc as Graphics.Dc, light as Boolean, s as Float, layout as Number) as Void {
        var grey  = light ? 0xA2ABB7 : 0x404750;  // even columns
        var greyd = light ? 0xBEC5CE : 0x2b3037;  // odd columns
        var cols = [6, 28, 50, 72, 94, 116, 260, 282, 304, 326, 348, 370];
        var w = scN(17, s);
        var radius = scN(8, s);
        for (var i = 0; i < cols.size(); i++) {
            var x = scN(cols[i], s);
            var even = (i % 2 == 0);
            var gapC = scN(even ? 130 : 260, s);   // gap centre offset between columns
            dc.setColor(even ? grey : greyd, Graphics.COLOR_TRANSPARENT);
            pill(dc, x, scN(3, s), gapC - scN(7, s), w, radius);
            pill(dc, x, gapC + scN(7, s), scN(387, s), w, radius);
        }
    }

    private function pill(dc as Graphics.Dc, x as Number, y0 as Number, y1 as Number,
                          w as Number, radius as Number) as Void {
        var h = y1 - y0;
        if (h < 6) {
            return;
        }
        dc.fillRoundedRectangle(x, y0, w, h, radius);
    }
}
