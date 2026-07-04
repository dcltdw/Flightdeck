import Toybox.Activity;
import Toybox.Lang;
import Toybox.System;

// Pulls the four-corner + hero metrics out of Activity.Info and keeps them as
// ready-to-draw strings. Pace/distance honour the device's unit setting; lap
// figures are derived from a baseline captured at each lap boundary — a manual/
// auto lap or a structured-workout step (see FlightdeckView.markLap).
//
// Field map (matches the Cockpit mockup):
//   top-left  PACE  = session (average) pace      top-right DIST = session distance
//   centre    hero  = elapsed timer time
//   bot-left  PACE  = lap pace                     bot-right TIME = lap time
class Metrics {
    public var sessionPace as String = "--:--";
    public var sessionDist as String = "0.00";
    public var heroTime as String = "0:00";
    public var lapPace as String = "--:--";
    public var lapTime as String = "0:00";

    private const _METERS_PER_MILE = 1609.344;
    private const _STOPPED_SPEED = 0.2; // m/s; below this we show no pace

    private var _statute as Boolean = false;
    private var _lapStartMs as Number = 0;
    private var _lapStartDist as Float = 0.0;

    function initialize() {
        var ds = System.getDeviceSettings();
        _statute = (ds.distanceUnits == System.UNIT_STATUTE);
    }

    // Re-baseline the lap counters at the moment a lap is taken.
    function onLap(info as Activity.Info) as Void {
        _lapStartMs = timerMs(info);
        _lapStartDist = distM(info);
    }

    function update(info as Activity.Info) as Void {
        var totalMs = timerMs(info);
        var totalDist = distM(info);

        sessionDist = formatDistance(totalDist);
        sessionPace = formatPace(info.averageSpeed);
        heroTime = formatClock(totalMs);

        var lapMs = totalMs - _lapStartMs;
        var lapDist = totalDist - _lapStartDist;
        lapTime = formatClock(lapMs);
        if (lapMs > 0 && lapDist > 0.0) {
            lapPace = formatPace(lapDist / (lapMs / 1000.0));
        } else {
            lapPace = "--:--";
        }
    }

    // ---- helpers ----

    private function timerMs(info as Activity.Info) as Number {
        var t = info.timerTime;
        return (t == null) ? 0 : t;
    }

    private function distM(info as Activity.Info) as Float {
        var d = info.elapsedDistance;
        return (d == null) ? 0.0 : d;
    }

    private function formatDistance(meters as Float) as String {
        var units = _statute ? _METERS_PER_MILE : 1000.0;
        return (meters / units).format("%.2f");
    }

    private function formatPace(speed as Float or Null) as String {
        if (speed == null || speed <= _STOPPED_SPEED) {
            return "--:--";
        }
        var unitMeters = _statute ? _METERS_PER_MILE : 1000.0;
        var secPerUnit = unitMeters / speed;
        if (secPerUnit > 5999.0) { // slower than 99:59 -> not meaningful
            return "--:--";
        }
        var mins = (secPerUnit / 60).toNumber();
        var secs = (secPerUnit - mins * 60).toNumber();
        return mins.format("%d") + ":" + secs.format("%02d");
    }

    private function formatClock(ms as Number) as String {
        var total = ms / 1000;
        var h = total / 3600;
        var m = (total % 3600) / 60;
        var s = total % 60;
        if (h > 0) {
            return h.format("%d") + ":" + m.format("%02d") + ":" + s.format("%02d");
        }
        return m.format("%d") + ":" + s.format("%02d");
    }
}
