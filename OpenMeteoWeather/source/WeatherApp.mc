import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

// Entry point. Annotated for the glance scope so the glance view can be
// created without loading the full app.
(:glance)
class WeatherApp extends Application.AppBase {
    private var _model = null;

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state) {
    }

    function onStop(state) {
        if (_model != null) {
            _model.stop();
        }
    }

    function getInitialView() {
        _model = new WeatherModel();
        var view = new WeatherView(_model);
        _model.start();
        return [view, new WeatherDelegate(view, _model)];
    }

    function getGlanceView() {
        return [new WeatherGlanceView()];
    }

    function onSettingsChanged() {
        if (_model != null) {
            _model.refresh();
        }
        WatchUi.requestUpdate();
    }
}
