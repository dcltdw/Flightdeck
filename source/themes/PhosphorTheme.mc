import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Caches the watermark bitmaps at module scope so they survive theme-instance
// churn and load only when Phosphor is actually shown (memory budget).
module PhosphorArt {
    var _dark as WatchUi.BitmapResource?;
    var _light as WatchUi.BitmapResource?;

    function scope(light as Boolean) as WatchUi.BitmapResource {
        if (light) {
            var f = _light;
            if (f == null) {
                f = WatchUi.loadResource(Rez.Drawables.PhosphorLight) as WatchUi.BitmapResource;
                _light = f;
            }
            return f;
        }
        var d = _dark;
        if (d == null) {
            d = WatchUi.loadResource(Rez.Drawables.PhosphorDark) as WatchUi.BitmapResource;
            _dark = d;
        }
        return d;
    }
}

// Phosphor — green-CRT palette over a faint radar/scope watermark (procedural,
// tinted per mode by tools/gen_phosphor_watermark.sh). Edge layout, hero exactly
// centred, no title.
class PhosphorTheme extends Theme {

    function initialize() {
        Theme.initialize();
    }

    function buildPalette(light as Boolean) as Palette {
        if (light) {
            // Light mode used to set hero/sval/lap to two near-identical teals
            // (pairwise dE 4.7/4.7/0.0), so every value role read as one colour —
            // the only palette in the app that separated nothing. Session now
            // shares the hero teal and lap takes #B0335A, the radar watermark's
            // own circle colour (5.1:1 on this ground, dE 76 off the teal). The
            // watermark's orange blip #E8621F was the other candidate and fails:
            // 2.8:1 against a near-white ground.
            return new Palette(0xE6ECF0, 0x1F7A45, 0x0E7488, 0xB0335A, 0x0E7488, 0x000000);
        }
        return new Palette(0x03110a, 0x4CF08C, 0xFFFFFF, 0x00FFFF, 0xFFC890, 0x000000);
    }

    function buildLayout(fonts as Fonts) as Layout {
        var L = new Layout();
        L.colL = 112; L.colR = 278; L.ctr = 195;
        // no title
        L.lblY1 = 103; L.valY1 = 135;
        L.heroY = 217;   // exactly centred
        L.lblY2 = 273; L.valY2 = 305;
        L.lblAsc = 32; L.valAsc = 55; L.heroAsc = 63;
        L.lblFont = fonts.label; L.valFont = fonts.value52(); L.heroFont = fonts.hero;
        return L;
    }

    function decorate(dc as Graphics.Dc, light as Boolean, s as Float, layout as Number) as Void {
        // radar watermark, centred by its own size
        var art = PhosphorArt.scope(light);
        dc.drawBitmap((dc.getWidth() - art.getWidth()) / 2,
                      (dc.getHeight() - art.getHeight()) / 2, art);
    }
}
