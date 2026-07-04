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
        ThemeRegistry.get(_themeIdx).draw(dc, _m, fonts, _light);
    }

    private function readSettings() as Void {
        _themeIdx = numProp("theme", 0);
        _light = (numProp("mode", 0) == 1);
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
}
