import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

// Entry point. A data field app hands back its single DataField view.
class FlightdeckApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        return [ new FlightdeckView() ];
    }

    // Theme/mode changed in Garmin Connect/Express — repaint with the new choice
    // (the view re-reads the settings in compute()).
    function onSettingsChanged() as Void {
        WatchUi.requestUpdate();
    }
}
