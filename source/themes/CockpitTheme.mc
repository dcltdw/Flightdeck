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
        L.colL = 127; L.colR = 263; L.ctr = 195;
        L.titleY = 62;  L.titleAsc = 12; L.titleFont = fonts.title; L.title = "FLIGHT OPS";
        L.lblY1 = 116; L.valY1 = 148;
        L.heroY = 222;
        L.lblY2 = 263; L.valY2 = 295;
        L.lblAsc = 28; L.valAsc = 31; L.heroAsc = 55;
        L.lblFont = fonts.label; L.valFont = fonts.value; L.heroFont = fonts.hero;
        return L;
    }

    function decorate(dc as Graphics.Dc, light as Boolean, s as Float) as Void {
        var ground   = light ? 0xEADFC8 : 0x0d0a07;
        var rim      = light ? 0xB9A988 : 0x1f4954;
        var reticle  = light ? 0x1E7088 : 0x3fb6d6;
        var scanDim  = light ? 0xC7B89B : 0x2c6675;
        var scanBrt  = light ? 0x1E7088 : 0x4fc8ec;
        var cx = scN(195, s); var cy = scN(195, s);

        // dashed rim (fine dotted ring) at r=180
        dc.setColor(rim, Graphics.COLOR_TRANSPARENT);
        var n = 120;
        var r = 180.0 * s;
        for (var i = 0; i < n; i++) {
            var a = (Math.PI * 2.0 * i) / n;
            dc.drawPoint((cx + r * Math.cos(a)).toNumber(), (cy + r * Math.sin(a)).toNumber());
        }

        // four diagonal corner reticle brackets
        dc.setColor(reticle, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(scP(3, s));
        dc.drawLine(scN(104,s),scN(80,s),  scN(80,s), scN(80,s));   dc.drawLine(scN(80,s), scN(80,s),  scN(80,s), scN(104,s));
        dc.drawLine(scN(286,s),scN(80,s),  scN(310,s),scN(80,s));   dc.drawLine(scN(310,s),scN(80,s),  scN(310,s),scN(104,s));
        dc.drawLine(scN(104,s),scN(310,s), scN(80,s), scN(310,s));  dc.drawLine(scN(80,s), scN(310,s), scN(80,s), scN(286,s));
        dc.drawLine(scN(286,s),scN(310,s), scN(310,s),scN(310,s));  dc.drawLine(scN(310,s),scN(310,s), scN(310,s),scN(286,s));

        // broken centre scan line: dim full-width, bright middle, masked gap
        dc.setColor(scanDim, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(scP(1, s));
        dc.drawLine(scN(58,s), scN(181,s), scN(332,s), scN(181,s));
        dc.setColor(scanBrt, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(scP(2, s));
        dc.drawLine(scN(150,s), scN(181,s), scN(240,s), scN(181,s));
        dc.setColor(ground, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(scP(9, s));
        dc.drawLine(scN(186,s), scN(181,s), scN(204,s), scN(181,s));
        dc.setPenWidth(1);
    }
}
