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
        L.titleY = 74; L.titleAsc = 12; L.titleFont = fonts.title; L.title = "COMBAT CONSOLE";
        L.lblY1 = 121; L.valY1 = 154;
        L.heroY = 234;
        L.lblY2 = 290; L.valY2 = 322;
        L.lblAsc = 28; L.valAsc = 31; L.heroAsc = 55;
        L.lblFont = fonts.label; L.valFont = fonts.value; L.heroFont = fonts.hero;
        return L;
    }

    function decorate(dc as Graphics.Dc, light as Boolean) as Void {
        var band  = light ? 0xEAD2CE : 0x2a1210;
        var frame = light ? 0xBE3A2C : 0xB0392E;
        var fw    = light ? 3 : 2;

        // console bars centred on the two label rows
        dc.setColor(band, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(40, 98, 310, 26);
        dc.fillRectangle(40, 267, 310, 26);

        // octagon frame (radius 176, flat-top via +22.5° offset)
        dc.setColor(frame, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(fw);
        var r = 176.0;
        var prevX = 0; var prevY = 0; var firstX = 0; var firstY = 0;
        for (var k = 0; k < 8; k++) {
            var a = (Math.PI * (k * 45 + 22.5)) / 180.0;
            var x = (195 + r * Math.cos(a)).toNumber();
            var y = (195 + r * Math.sin(a)).toNumber();
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
