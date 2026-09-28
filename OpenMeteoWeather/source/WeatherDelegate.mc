import Toybox.Lang;
import Toybox.WatchUi;

class WeatherDelegate extends WatchUi.BehaviorDelegate {
    private var _view;
    private var _model;

    function initialize(view, model) {
        BehaviorDelegate.initialize();
        _view = view;
        _model = model;
    }

    function onNextPage() as Boolean {
        _view.turnPage(1);
        return true;
    }

    function onPreviousPage() as Boolean {
        _view.turnPage(-1);
        return true;
    }

    // START button (or tap): reload the forecast.
    function onSelect() as Boolean {
        if (_model.state != STATE_LOADING) {
            _model.refresh();
        }
        return true;
    }
}
