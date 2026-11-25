import Toybox.Lang;
import Toybox.Math;
import Toybox.Timer;
import Toybox.WatchUi;

// Fake PowerBox for testing without a car (and in the simulator, which has
// no BLE without an nRF dongle). It builds the same JSON the real box sends
// and feeds it through the real protocol parser in 20-byte chunks, the
// default BLE payload size, so fragment reassembly is exercised too.
class DemoSource {
    hidden var _model as TwizyModel;
    hidden var _protocol as PowerBoxProtocol;
    hidden var _timer as Timer.Timer?;
    hidden var _t as Float = 0.0;
    hidden var _soc as Float = 82.0;
    hidden var _frames as Number = 0;

    function initialize(model as TwizyModel, protocol as PowerBoxProtocol) {
        _model = model;
        _protocol = protocol;
    }

    function start() as Void {
        _model.setLink(LINK_DEMO, "Gesimuleerde data");
        _model.deviceName = "Demo";
        var timer = new Timer.Timer();
        timer.start(method(:onTick), 200, true);
        _timer = timer;
    }

    function stop() as Void {
        var timer = _timer;
        if (timer != null) {
            timer.stop();
            _timer = null;
        }
    }

    function onTick() as Void {
        _t += 0.2;
        _frames += 37;

        // Accelerate, cruise, brake (regen), stand still: a 30 s loop.
        var phase = (_t.toNumber() % 30);
        var speed;
        var current;
        if (phase < 8) {
            speed = phase * 9.5;
            current = 95.0 - phase * 4;
        } else if (phase < 18) {
            speed = 76.0 + 3 * Math.sin(_t);
            current = 38.0 + 6 * Math.sin(_t * 1.7);
        } else if (phase < 24) {
            speed = 76.0 - (phase - 18) * 12.6;
            current = -22.0;
        } else {
            speed = 0.0;
            current = 0.8;
        }
        if (speed < 0) {
            speed = 0.0;
        }
        _soc -= current.toFloat() * 0.00004;
        var voltage = 56.5 - current * 0.04;
        var power = voltage * current;

        var json = "{\"v\":" + voltage.format("%.2f") +
            ",\"i\":" + current.format("%.2f") +
            ",\"p\":" + power.format("%.1f") +
            ",\"soc\":" + _soc.format("%.2f") +
            ",\"spd\":" + speed.format("%.1f") +
            ",\"tmp\":" + (34 + phase / 3).format("%d") +
            ",\"valid\":true,\"frames\":" + _frames.toString() +
            ",\"can_age_ms\":3}";

        var bytes = PowerBoxProtocol.textToBytes(json);
        for (var i = 0; i < bytes.size(); i += 20) {
            var end = (i + 20 < bytes.size()) ? i + 20 : bytes.size();
            var frames = _protocol.feed(bytes.slice(i, end));
            if (frames.size() > 0) {
                _model.applyFrame(frames[frames.size() - 1]);
            }
        }
        WatchUi.requestUpdate();
    }
}
