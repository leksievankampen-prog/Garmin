import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class TwizyPowerBoxApp extends Application.AppBase {
    hidden var _model as TwizyModel;
    hidden var _protocol as PowerBoxProtocol;
    hidden var _ble as PowerBoxBle? = null;
    hidden var _demo as DemoSource? = null;

    function initialize() {
        AppBase.initialize();
        _model = new TwizyModel();
        _protocol = new PowerBoxProtocol();
    }

    function onStart(state as Dictionary?) as Void {
        if (readBool("demoMode", false)) {
            var demo = new DemoSource(_model, _protocol);
            demo.start();
            _demo = demo;
        } else {
            var ble = new PowerBoxBle(_model, _protocol, readString("deviceName", "TwizyPB"));
            ble.start();
            _ble = ble;
        }
    }

    function onStop(state as Dictionary?) as Void {
        var ble = _ble;
        if (ble != null) {
            ble.stop();
        }
        var demo = _demo;
        if (demo != null) {
            demo.stop();
        }
    }

    function getInitialView() {
        var view = new TwizyView(_model, _protocol);
        return [view, new TwizyDelegate(view, self)];
    }

    function reconnect() as Void {
        var ble = _ble;
        if (ble != null) {
            ble.restart();
        }
    }

    hidden function readBool(key as String, fallback as Boolean) as Boolean {
        try {
            var v = Application.Properties.getValue(key);
            return (v instanceof Boolean) ? v : fallback;
        } catch (e) {
            return fallback;
        }
    }

    hidden function readString(key as String, fallback as String) as String {
        try {
            var v = Application.Properties.getValue(key);
            return (v instanceof String && v.length() > 0) ? v : fallback;
        } catch (e) {
            return fallback;
        }
    }
}
