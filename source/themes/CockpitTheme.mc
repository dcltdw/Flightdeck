import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;

// Cockpit — warm HUD with diagonal corner reticles, a dashed teal rim, and a
// broken centre scan line. Standard layout; distinct green lap values.
// Geometry/colours mirror docs/mockups/scripts/gen_cockpit.py.
class CockpitTheme extends Theme {

    function initialize() {
        Theme.initialize();
    }

    function buildPalette(light as Boolean) as Palette {
        if (light) {
            // parchment ground approximated as a solid (mockup uses a radial gradient)
            return new Palette(0xEADFC8, 0x8A6A3A, 0xB5530E, 0x1F7A45, 0xA8460A, 0x1E7088);
        }
        return new Palette(0x0d0a07, 0x9a6428, 0xFFB066, 0x5FD98E, 0xFFC890, 0x6FAFC2);
    }

    function buildLayout(fonts as Fonts) as Layout {
        var L = new Layout();
        L.colL = 112; L.colR = 278; L.ctr = 195;
        L.titleY = 74;  L.titleAsc = 12; L.titleFont = fonts.title; L.title = "FLIGHT OPS";
        L.lblY1 = 121; L.valY1 = 154;
        L.heroY = 234;
        L.lblY2 = 290; L.valY2 = 322;
        L.lblAsc = 28; L.valAsc = 31; L.heroAsc = 55;
        L.lblFont = fonts.label; L.valFont = fonts.value; L.heroFont = fonts.hero;
        return L;
    }

    function decorate(dc as Graphics.Dc, light as Boolean) as Void {
        var ground   = light ? 0xEADFC8 : 0x0d0a07;
        var rim      = light ? 0xB9A988 : 0x1f4954;
        var reticle  = light ? 0x1E7088 : 0x3fb6d6;
        var scanDim  = light ? 0xC7B89B : 0x2c6675;
        var scanBrt  = light ? 0x1E7088 : 0x4fc8ec;

        // dashed rim (SVG dasharray "1 9" ~ a fine dotted ring) at r=180
        dc.setColor(rim, Graphics.COLOR_TRANSPARENT);
        var n = 120;
        var r = 180.0;
        for (var i = 0; i < n; i++) {
            var a = (Math.PI * 2.0 * i) / n;
            dc.drawPoint((195 + r * Math.cos(a)).toNumber(), (195 + r * Math.sin(a)).toNumber());
        }

        // four diagonal corner reticle brackets
        dc.setColor(reticle, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(3);
        dc.drawLine(84, 60, 60, 60);   dc.drawLine(60, 60, 60, 84);
        dc.drawLine(306, 60, 330, 60); dc.drawLine(330, 60, 330, 84);
        dc.drawLine(84, 330, 60, 330); dc.drawLine(60, 330, 60, 306);
        dc.drawLine(306, 330, 330, 330); dc.drawLine(330, 330, 330, 306);

        // broken centre scan line: dim full-width, bright middle, masked gap
        dc.setColor(scanDim, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawLine(58, 181, 332, 181);
        dc.setColor(scanBrt, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawLine(150, 181, 240, 181);
        dc.setColor(ground, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(9);
        dc.drawLine(186, 181, 204, 181);
        dc.setPenWidth(1);
    }
}
