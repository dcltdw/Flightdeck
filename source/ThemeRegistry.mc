import Toybox.Lang;

// Maps the `theme` setting index to a Theme instance. Order matches the
// list entries in resources/settings/settings.xml:
//   0 Cockpit   1 Bridge   2 Bulkhead   3 Phosphor
// Unknown values fall back to Cockpit.
module ThemeRegistry {
    function get(index as Number) as Theme {
        switch (index) {
            case 1:
                return new BridgeTheme();
            case 2:
                return new WallTheme();
            case 3:
                return new PhosphorTheme();
            default:
                return new CockpitTheme();
        }
    }
}
