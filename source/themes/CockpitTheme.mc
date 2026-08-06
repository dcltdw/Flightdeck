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
            return new Palette(0xEADFC8, 0x8A6A3A, 0xB5530E, 0x1F7A45, 0xA8460A, 0x0D4655);
        }
        return new Palette(0x0d0a07, 0x9a6428, 0xFFFFFF, 0x3BE06E, 0xFFC890, 0xA0D8EE);
    }

    function buildLayout(fonts as Fonts) as Layout {
        var L = new Layout();
        L.colL = 112; L.colR = 278; L.ctr = 195;
        L.titleY = 62;  L.titleAsc = 14; L.titleFont = fonts.title; L.title = "FLIGHT OPS";
        L.lblY1 = 103; L.valY1 = 135;
        L.heroY = 217;
        L.lblY2 = 273; L.valY2 = 305;
        L.lblAsc = 32; L.valAsc = 55; L.heroAsc = 63;
        L.lblFont = fonts.label; L.valFont = fonts.value52(); L.heroFont = fonts.hero;
        return L;
    }

    function decorate(dc as Graphics.Dc, light as Boolean, s as Float, layout as Number) as Void {
        var ground   = light ? 0xEADFC8 : 0x0d0a07;
        var rim      = light ? 0xB9A988 : 0x1f4954;
        var reticle  = light ? 0x8FB8C4 : 0x2A7085;
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
        dc.drawLine(scN(94,s),scN(70,s),  scN(70,s), scN(70,s));   dc.drawLine(scN(70,s), scN(70,s),  scN(70,s), scN(94,s));
        dc.drawLine(scN(296,s),scN(70,s),  scN(320,s),scN(70,s));   dc.drawLine(scN(320,s),scN(70,s),  scN(320,s),scN(94,s));
        dc.drawLine(scN(94,s),scN(320,s), scN(70,s), scN(320,s));  dc.drawLine(scN(70,s), scN(320,s), scN(70,s), scN(296,s));
        dc.drawLine(scN(296,s),scN(320,s), scN(320,s),scN(320,s));  dc.drawLine(scN(320,s),scN(320,s), scN(320,s),scN(296,s));

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

        drawBlips(dc, s, layout, light ? 0xC42E9A : 0xE64DBF); // two diamond blips (warm, contrasts the teal)
    }
}
