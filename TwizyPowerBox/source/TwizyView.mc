import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Three pages, switched with UP/DOWN (or swipe):
//   0 = dashboard  (speed, SOC ring, power)
//   1 = details    (voltage, current, power, temperature, SOC)
//   2 = diagnose   (BLE state, frame counters, last raw message)
const TWIZY_PAGE_COUNT = 3;

class TwizyView extends WatchUi.View {
    hidden var _model as TwizyModel;
    hidden var _protocol as PowerBoxProtocol;
    var page as Number = 0;

    function initialize(model as TwizyModel, protocol as PowerBoxProtocol) {
        View.initialize();
        _model = model;
        _protocol = protocol;
    }

    function nextPage(step as Number) as Void {
        page = (page + step + TWIZY_PAGE_COUNT) % TWIZY_PAGE_COUNT;
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        if (page == 0) {
            drawDashboard(dc);
        } else if (page == 1) {
            drawDetails(dc);
        } else {
            drawDiagnostics(dc);
        }
    }

    // ---------------------------------------------------------------- pages

    hidden function drawDashboard(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var cy = h / 2;
        var stale = _model.isStale();

        // SOC ring: 270 degrees, open at the bottom.
        var radius = (w < h ? w : h) / 2 - 6;
        dc.setPenWidth(8);
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawArc(cx, cy, radius, Graphics.ARC_CLOCKWISE, 225, 315);
        var soc = _model.soc;
        if (!stale && soc != null) {
            var frac = clamp(soc / 100.0, 0.0, 1.0);
            if (frac > 0.005) {
                dc.setColor(socColor(soc), Graphics.COLOR_TRANSPARENT);
                var endDeg = normDeg(225 - (270 * frac).toNumber());
                dc.drawArc(cx, cy, radius, Graphics.ARC_CLOCKWISE, 225, endDeg);
            }
        }
        dc.setPenWidth(1);

        // SOC text at the top.
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.14, Graphics.FONT_SMALL,
            fmt(stale ? null : soc, "%.0f") + "%", Graphics.TEXT_JUSTIFY_CENTER);

        // Speed in the middle.
        dc.drawText(cx, cy, Graphics.FONT_NUMBER_THAI_HOT,
            fmt(stale ? null : _model.speed, "%.0f"),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.63, Graphics.FONT_XTINY, "km/h", Graphics.TEXT_JUSTIFY_CENTER);

        // Power at the bottom: red = consuming, green = regen/charging.
        var p = stale ? null : _model.power;
        var powerText = "-- kW";
        if (p != null) {
            dc.setColor(p < 0 ? Graphics.COLOR_GREEN : Graphics.COLOR_ORANGE, Graphics.COLOR_TRANSPARENT);
            powerText = (p / 1000.0).format("%.1f") + " kW";
        } else {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        }
        dc.drawText(cx, h * 0.72, Graphics.FONT_MEDIUM, powerText, Graphics.TEXT_JUSTIFY_CENTER);

        drawStatusLine(dc, stale);
    }

    hidden function drawDetails(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var stale = _model.isStale();
        var p = stale ? null : _model.power;

        var labels = ["Spanning", "Stroom", "Vermogen", "Motor", "Accu"];
        var values = [
            fmt(stale ? null : _model.voltage, "%.1f") + " V",
            fmt(stale ? null : _model.current, "%.1f") + " A",
            fmt(p == null ? null : p / 1000.0, "%.2f") + " kW",
            fmt(stale ? null : _model.motorTemp, "%.0f") + " C",
            fmt(stale ? null : _model.soc, "%.1f") + " %"
        ];

        var top = h * 0.18;
        var row = (h * 0.64) / labels.size();
        for (var k = 0; k < labels.size(); k++) {
            var y = top + row * k;
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w * 0.47, y, Graphics.FONT_SMALL, labels[k], Graphics.TEXT_JUSTIFY_RIGHT);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w * 0.53, y, Graphics.FONT_SMALL, values[k], Graphics.TEXT_JUSTIFY_LEFT);
        }
        if (!stale && !_model.bmsValid) {
            dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 0.08, Graphics.FONT_XTINY, "BMS-data onzeker", Graphics.TEXT_JUSTIFY_CENTER);
        }
        drawStatusLine(dc, stale);
    }

    hidden function drawDiagnostics(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var font = Graphics.FONT_XTINY;
        var lineH = dc.getFontHeight(font);
        var y = h * 0.12;

        var lines = [
            "Status: " + _model.linkText(),
            _model.linkDetail,
            "Apparaat: " + (_model.deviceName == null ? "-" : _model.deviceName.toString()),
            "RSSI: " + (_model.rssi == null ? "-" : _model.rssi.toString() + " dBm"),
            "Berichten ok/fout: " + _protocol.framesOk.toString() + "/" + _protocol.framesBad.toString(),
            "CAN-frames: " + (_model.canFrames == null ? "-" : _model.canFrames.toString()),
            "CAN-leeftijd: " + (_model.canAgeMs == null ? "-" : _model.canAgeMs.toString() + " ms")
        ];
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        for (var k = 0; k < lines.size(); k++) {
            if (lines[k].length() > 0) {
                dc.drawText(w / 2, y, font, lines[k], Graphics.TEXT_JUSTIFY_CENTER);
                y += lineH;
            }
        }

        // Last raw message, wrapped. Handy to see what an unknown box sends.
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        var raw = _protocol.lastRawText;
        var perLine = 26;
        for (var i = 0; i < raw.length() && y < h * 0.9; i += perLine) {
            var end = (i + perLine < raw.length()) ? i + perLine : raw.length();
            dc.drawText(w / 2, y, font, raw.substring(i, end), Graphics.TEXT_JUSTIFY_CENTER);
            y += lineH;
        }
    }

    // ---------------------------------------------------------------- helpers

    hidden function drawStatusLine(dc as Dc, stale as Boolean) as Void {
        var link = _model.link;
        if (link == LINK_STREAMING && !stale) {
            return;
        }
        var text = _model.linkText();
        if (link == LINK_STREAMING && stale) {
            text = "Geen data van auto";
        }
        dc.setColor(link == LINK_ERROR ? Graphics.COLOR_RED : Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
        dc.drawText(dc.getWidth() / 2, dc.getHeight() * 0.86, Graphics.FONT_XTINY, text, Graphics.TEXT_JUSTIFY_CENTER);
    }

    static function fmt(value, pattern as String) as String {
        if (value == null) {
            return "--";
        }
        return value.format(pattern);
    }

    static function socColor(soc as Float) as Number {
        if (soc > 50) {
            return Graphics.COLOR_GREEN;
        }
        if (soc > 20) {
            return Graphics.COLOR_YELLOW;
        }
        return Graphics.COLOR_RED;
    }

    static function clamp(v, lo, hi) {
        return v < lo ? lo : (v > hi ? hi : v);
    }

    static function normDeg(d as Number) as Number {
        return ((d % 360) + 360) % 360;
    }
}
