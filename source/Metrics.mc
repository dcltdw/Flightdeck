import Toybox.Activity;
import Toybox.Lang;
import Toybox.System;

enum {
    METRIC_OFF = 0,
    METRIC_TIMER, METRIC_CLOCK, METRIC_DIST, METRIC_LDIST, METRIC_LTIME,
    METRIC_PACE, METRIC_LPACE, METRIC_CPACE, METRIC_SPEED, METRIC_CSPD,
    METRIC_HR, METRIC_AHR, METRIC_ZONE, // reserved: HR zone dropped (needs UserProfile permission)
    METRIC_CAD, METRIC_ACAD,
    METRIC_CAL, METRIC_ASC, METRIC_ALT
}

// Metric registry: holds the current Activity.Info + lap baseline and answers
// format(id)/label(id) for the configurable field slots. Which metric each slot
// shows (and its position/label) is decided by settings — see FlightdeckView and
// Theme.draw; Metrics itself is position-agnostic. Pace/distance honour the
// device's unit setting; lap figures derive from a baseline captured at each lap
// boundary — a manual/auto lap or a structured-workout step (see onLap, called
// from FlightdeckView's onTimerLap / onWorkoutStepComplete).
//
// Default slot map (settings defaults, reproducing the original layout):
//   centre = Timer     top-left = Avg pace   top-right = Distance
//                      bot-left = Lap pace   bot-right = Lap time
class Metrics {
    private const _METERS_PER_MILE = 1609.344;
    private const _STOPPED_SPEED = 0.2; // m/s; below this we show no pace

    private var _statute as Boolean = false;
    private var _info as Activity.Info?;
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
        _info = info;
    }

    function format(id as Number) as String {
        var info = _info;
        if (info == null) { return "--"; }
        switch (id) {
            case METRIC_TIMER: return formatClock(timerMs(info));
            case METRIC_DIST:  return formatDistance(distM(info));
            case METRIC_LDIST: return formatDistance(distM(info) - _lapStartDist);
            case METRIC_LTIME: return formatClock(timerMs(info) - _lapStartMs);
            case METRIC_PACE:  return formatPace(info.averageSpeed);
            case METRIC_LPACE: return lapPaceStr(info);
            case METRIC_CPACE: return formatPace(info.currentSpeed);
            case METRIC_CLOCK: return formatClockTime();
            case METRIC_SPEED: return formatSpeed(info.averageSpeed);
            case METRIC_CSPD:  return formatSpeed(info.currentSpeed);
            case METRIC_HR:    return formatInt(info.currentHeartRate);
            case METRIC_AHR:   return formatInt(info.averageHeartRate);
            case METRIC_CAD:   return formatInt(info.currentCadence);
            case METRIC_ACAD:  return formatInt(info.averageCadence);
            case METRIC_CAL:   return formatInt(info.calories);
            case METRIC_ASC:   return formatElevation(info.totalAscent);
            case METRIC_ALT:   return formatElevation(info.altitude);
            default:           return "--";
        }
    }

    function label(id as Number) as String {
        switch (id) {
            case METRIC_TIMER: return "TIMER";
            case METRIC_CLOCK: return "CLOCK";
            case METRIC_DIST:  return "DIST";
            case METRIC_LDIST: return "LDIST";
            case METRIC_LTIME: return "LTIME";
            case METRIC_PACE:  return "PACE";
            case METRIC_LPACE: return "LPACE";
            case METRIC_CPACE: return "CPACE";
            case METRIC_SPEED: return "SPEED";
            case METRIC_CSPD:  return "CSPD";
            case METRIC_HR:    return "HR";
            case METRIC_AHR:   return "AHR";
            case METRIC_CAD:   return "CAD";
            case METRIC_ACAD:  return "ACAD";
            case METRIC_CAL:   return "CAL";
            case METRIC_ASC:   return "ASC";
            case METRIC_ALT:   return "ALT";
            default:           return "";
        }
    }

    // ---- helpers ----

    private function lapPaceStr(info as Activity.Info) as String {
        var lapMs = timerMs(info) - _lapStartMs;
        var lapDist = distM(info) - _lapStartDist;
        if (lapMs > 0 && lapDist > 0.0) {
            return formatPace(lapDist / (lapMs / 1000.0));
        }
        return "--:--";
    }

    private function formatSpeed(speed as Float or Null) as String {
        if (speed == null || speed < 0.0) { return "--"; }
        var unit = _statute ? 2.236936 : 3.6; // m/s -> mph / km/h
        return (speed * unit).format("%.1f");
    }

    private function formatInt(v as Number or Null) as String {
        return (v == null) ? "--" : v.format("%d");
    }

    private function formatElevation(m as Lang.Numeric or Null) as String {
        if (m == null) { return "--"; }
        var v = _statute ? (m * 3.28084) : m;
        return v.toNumber().format("%d");
    }

    private function formatClockTime() as String {
        var t = System.getClockTime();
        var h = t.hour;
        if (!System.getDeviceSettings().is24Hour) {
            h = h % 12;
            if (h == 0) { h = 12; }
        }
        return h.format("%d") + ":" + t.min.format("%02d");
    }

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
