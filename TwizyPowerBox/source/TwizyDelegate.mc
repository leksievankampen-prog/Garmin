import Toybox.Lang;
import Toybox.WatchUi;

class TwizyDelegate extends WatchUi.BehaviorDelegate {
    hidden var _view as TwizyView;
    hidden var _app as TwizyPowerBoxApp;

    function initialize(view as TwizyView, app as TwizyPowerBoxApp) {
        BehaviorDelegate.initialize();
        _view = view;
        _app = app;
    }

    function onNextPage() as Boolean {
        _view.nextPage(1);
        return true;
    }

    function onPreviousPage() as Boolean {
        _view.nextPage(-1);
        return true;
    }

    // START/tap: search for the PowerBox again.
    function onSelect() as Boolean {
        _app.reconnect();
        WatchUi.requestUpdate();
        return true;
    }
}
