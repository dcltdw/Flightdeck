import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;

// Bridge — an octagon frame (flat-top) and two faint console bars centred on
// the label rows. Standard layout, white values. Geometry/colours mirror
// docs/mockups/scripts/gen_bridge.py.
class BridgeTheme extends Theme {

    function initialize() {
        Theme.initialize();
    }

    function buildPalette(light as Boolean) as Palette {
        if (light) {
            return new Palette(0xE7EBF0, 0x2F6076, 0x16202A, 0x16202A, 0xB06A0C, 0xB0392E);
        }
        return new Palette(0x080b12, 0x8AA9C2, 0xFFFFFF, 0xFFFFFF, 0xE0A23A, 0xC8554A);
    }

    function buildLayout(fonts as Fonts) as Layout {
        var L = new Layout();
        L.colL = 112; L.colR = 278; L.ctr = 195;
        L.titleY = 58; L.titleAsc = 12; L.titleFont = fonts.title; L.title = "COMBAT CONSOLE";
        L.lblY1 = 118; L.valY1 = 150;
        L.heroY = 217;
        L.lblY2 = 256; L.valY2 = 288;
        L.lblAsc = 28; L.valAsc = 31; L.heroAsc = 55;
        L.lblFont = fonts.label; L.valFont = fonts.value; L.heroFont = fonts.hero;
        return L;
    }

    function decorate(dc as Graphics.Dc, light as Boolean, s as Float) as Void {
        var band  = light ? 0xEAD2CE : 0x2a1210;
        var frame = light ? 0xBE3A2C : 0xB0392E;
        var fw    = light ? 3 : 2;

        // console bars centred on the two label rows
        dc.setColor(band, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(scN(40,s), scN(95,s),  scN(310,s), scN(26,s));
        dc.fillRectangle(scN(40,s), scN(233,s), scN(310,s), scN(26,s));

        // octagon frame (radius 176, flat-top via +22.5° offset)
        dc.setColor(frame, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(scP(fw, s));
        var r = 176.0 * s;
        var cx = scN(195, s); var cy = scN(195, s);
        var prevX = 0; var prevY = 0; var firstX = 0; var firstY = 0;
        for (var k = 0; k < 8; k++) {
            var a = (Math.PI * (k * 45 + 22.5)) / 180.0;
            var x = (cx + r * Math.cos(a)).toNumber();
            var y = (cy + r * Math.sin(a)).toNumber();
            if (k == 0) {
                firstX = x; firstY = y;
            } else {
                dc.drawLine(prevX, prevY, x, y);
            }
            prevX = x; prevY = y;
        }
        dc.drawLine(prevX, prevY, firstX, firstY);
        dc.setPenWidth(1);
    }
}
