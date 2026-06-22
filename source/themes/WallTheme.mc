import Toybox.Graphics;
import Toybox.Lang;

// Bulkhead — wall striping in the outer thirds (thick rounded "pills", offset
// between adjacent columns), bold large type, no title. Edge columns.
// Geometry/colours mirror docs/mockups/scripts/gen_wall.py.
class WallTheme extends Theme {

    function initialize() {
        Theme.initialize();
    }

    function buildPalette(light as Boolean) as Palette {
        if (light) {
            return new Palette(0xE7EBF0, 0x2F6076, 0xC62828, 0xC62828, 0xB06A0C, 0x000000);
        }
        return new Palette(0x060709, 0x8AA9C2, 0xE63A28, 0xE63A28, 0xE0A23A, 0x000000);
    }

    function buildLayout(fonts as Fonts) as Layout {
        var L = new Layout();
        L.colL = 98; L.colR = 292; L.ctr = 195;
        // no title
        L.lblY1 = 94; L.valY1 = 134;
        L.heroY = 216;
        L.lblY2 = 274; L.valY2 = 314;
        L.lblAsc = 33; L.valAsc = 39; L.heroAsc = 66;  // bold .fnt base= values
        L.lblFont = fonts.labelB(); L.valFont = fonts.valueB(); L.heroFont = fonts.heroB();
        return L;
    }

    function decorate(dc as Graphics.Dc, light as Boolean) as Void {
        var grey  = light ? 0xA2ABB7 : 0x404750;  // even columns
        var greyd = light ? 0xBEC5CE : 0x2b3037;  // odd columns
        var cols = [6, 28, 50, 72, 94, 116, 260, 282, 304, 326, 348, 370];
        var w = 17;
        var radius = 8;
        for (var i = 0; i < cols.size(); i++) {
            var x = cols[i];
            var even = (i % 2 == 0);
            var gapC = even ? 130 : 260;       // gap centre offset between columns
            dc.setColor(even ? grey : greyd, Graphics.COLOR_TRANSPARENT);
            pill(dc, x, 3, gapC - 7, w, radius);
            pill(dc, x, gapC + 7, 387, w, radius);
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
