import Toybox.Activity;
import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Full-screen data field view. compute() (~1/sec) refreshes the metric strings
// and the selected theme/mode; onUpdate() repaints the chosen face. No input.
class FlightdeckView extends WatchUi.DataField {

    private var _m as Metrics;
    private var _info as Activity.Info?;
    private var _fonts as Fonts?;
    private var _themeIdx as Number = 0;
    private var _light as Boolean = false;
    // The active layout's metric ids, in slot-index order (see the layout
    // tables in Theme.presetSlots / drawGrid). Length tracks the layout.
    private var _slots as Array<Number> = [1, 7, 3, 4];
    private var _showLabels as Boolean = false;
    private var _layout as Number = 4;

    function initialize() {
        DataField.initialize();
        _m = new Metrics();
        readSettings();
    }

    function onLayout(dc as Graphics.Dc) as Void {
        _fonts = new Fonts();
    }

    function compute(info as Activity.Info) as Void {
        _info = info;
        _m.update(info);
        readSettings();
    }

    // A manual/auto lap and a structured-workout step boundary (e.g. an interval
    // fast->recovery transition) are distinct CIQ events but both start a fresh
    // "lap" for our bottom-row metrics, so re-baseline on either.
    function onTimerLap() as Void {
        markLap();
    }

    function onWorkoutStepComplete() as Void {
        markLap();
    }

    private function markLap() as Void {
        if (_info != null) {
            _m.onLap(_info);
        }
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var fonts = _fonts;
        if (fonts == null) {
            return; // fonts not loaded yet (onLayout runs before first onUpdate)
        }
        ThemeRegistry.get(_themeIdx).draw(dc, _m, fonts, _light, _slots, _showLabels, _layout);
    }

    private function readSettings() as Void {
        _themeIdx = numProp("theme", 0);
        _light = (numProp("mode", 0) == 1);
        _layout = numProp("layout", 4);
        // Each layout has its own independent property set (#49). Read only
        // the active layout's, positionally ordered to match Theme's slot
        // indices. Fallback defaults mirror properties.xml.
        if (_layout == 5) {
            _slots = [numProp("l5_c", 1), numProp("l5_tl", 6), numProp("l5_tr", 3),
                      numProp("l5_bl", 7), numProp("l5_br", 5)];
        } else if (_layout == 4) {
            _slots = [numProp("l4_n", 1), numProp("l4_e", 7),
                      numProp("l4_s", 3), numProp("l4_w", 4)];
        } else if (_layout == 3) {
            _slots = [numProp("l3_top", 1), numProp("l3_mid", 7), numProp("l3_bot", 3)];
        } else if (_layout == 2) {
            _slots = [numProp("l2_top", 1), numProp("l2_bot", 7)];
        } else {
            // 1, and any out-of-range stored value: Theme.presetSlots'
            // else-branch draws 1-field for those too, so stay in step.
            _slots = [numProp("l1_c", 1)];
        }
        _showLabels = boolProp("showLabels", false);
    }

    private function numProp(key as String, dflt as Number) as Number {
        var v = Application.Properties.getValue(key);
        if (v instanceof Number) {
            return v;
        }
        if (v instanceof Float) {
            return v.toNumber();
        }
        return dflt;
    }

    private function boolProp(key as String, dflt as Boolean) as Boolean {
        var v = Application.Properties.getValue(key);
        return (v instanceof Boolean) ? v : dflt;
    }
}
