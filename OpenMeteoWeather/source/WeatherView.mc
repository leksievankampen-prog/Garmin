import Toybox.Communications;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

// Three pages: current conditions, the next hours and the next days.
// UP/DOWN (or swipe) switches pages, START refreshes.
class WeatherView extends WatchUi.View {
    const PAGES = 3;

    private var _model;
    private var _page = 0;

    function initialize(model) {
        View.initialize();
        _model = model;
    }

    function turnPage(step as Number) as Void {
        _page = (_page + step + PAGES) % PAGES;
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        var d = _model.data;
        if (d == null) {
            drawMessage(dc);
            return;
        }

        if (_page == 0) {
            drawCurrent(dc, d);
        } else if (_page == 1) {
            drawHourly(dc, d);
        } else {
            drawDaily(dc, d);
        }
        drawStatus(dc, d);
        drawPageDots(dc);
    }

    // Shown when there is no cached forecast yet.
    private function drawMessage(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var state = _model.state;
        var line1;
        var line2 = null;
        if (state == STATE_ERROR) {
            line1 = errorText(_model.errorCode);
            line2 = str(Rez.Strings.PressStart);
        } else if (state == STATE_LOADING) {
            line1 = str(Rez.Strings.Loading);
        } else {
            line1 = str(Rez.Strings.SearchingGps);
        }

        WeatherIcons.draw(dc, 2, 1, w / 2, h * 0.32, w * 0.1);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 0.55, Graphics.FONT_SMALL, line1, center());
        if (line2 != null) {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 0.68, Graphics.FONT_XTINY, line2, center());
        }
    }

    private function drawCurrent(dc as Graphics.Dc, d as Dictionary) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cur = d["cur"];

        WeatherIcons.draw(dc, cur["code"], cur["day"], w * 0.3, h * 0.35, w * 0.12);

        // Big temperature with a smaller degree sign (number fonts lack "°").
        var bigFont = Graphics.FONT_NUMBER_MEDIUM;
        var t = fmt(cur["temp"]);
        var tx = w * 0.64;
        var ty = h * 0.35;
        var tw = dc.getTextWidthInPixels(t, bigFont);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(tx, ty, bigFont, t, center());
        dc.drawText(tx + tw / 2 + 1, ty - dc.getFontHeight(bigFont) * 0.25, Graphics.FONT_SMALL, "°",
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        dc.drawText(w / 2, h * 0.555, Graphics.FONT_SMALL, WeatherCodes.describe(cur["code"]), center());

        // Feels like / wind / humidity.
        var labelY = h * 0.67;
        var valueY = h * 0.755;
        var cols = [w * 0.24, w * 0.5, w * 0.76];
        var labels = [str(Rez.Strings.FeelsLike), str(Rez.Strings.Wind), str(Rez.Strings.Humidity)];
        var values = [
            fmt(cur["feels"]) + "°",
            fmt(cur["wind"]) + " " + d["wu"],
            fmt(cur["hum"]) + "%"
        ];
        for (var i = 0; i < 3; i++) {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cols[i], labelY, Graphics.FONT_XTINY, labels[i], center());
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cols[i], valueY, Graphics.FONT_TINY, values[i], center());
        }
        if (cur["dir"] != null) {
            var lw = dc.getTextWidthInPixels(labels[1], Graphics.FONT_XTINY);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            WeatherIcons.windArrow(dc, cols[1] + lw / 2 + 9, labelY, 6, cur["dir"]);
        }

        // Today's high / low.
        var days = d["days"] as Array;
        if (days.size() > 0) {
            var today = days[0];
            drawHighLow(dc, w / 2, h * 0.86, today["max"], today["min"], Graphics.FONT_TINY, true);
        }
    }

    private function drawHourly(dc as Graphics.Dc, d as Dictionary) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        drawTitle(dc, str(Rez.Strings.Hourly));

        var hours = d["hours"] as Array;
        var rowH = h * 0.1;
        var y0 = h * 0.27;
        for (var i = 0; i < hours.size(); i++) {
            var hr = hours[i];
            var y = y0 + i * rowH;
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w * 0.14, y, Graphics.FONT_TINY, hr["t"], left());
            WeatherIcons.draw(dc, hr["code"], hr["day"], w * 0.45, y, rowH * 0.42);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w * 0.68, y, Graphics.FONT_TINY, fmt(hr["temp"]) + "°", right());
            drawPop(dc, w * 0.86, y, hr["pop"]);
        }
    }

    private function drawDaily(dc as Graphics.Dc, d as Dictionary) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        drawTitle(dc, str(Rez.Strings.Daily));

        var days = d["days"] as Array;
        var rowH = h * 0.12;
        var y0 = h * 0.28;
        for (var i = 0; i < days.size(); i++) {
            var day = days[i];
            var y = y0 + i * rowH;
            var name = (i == 0) ? str(Rez.Strings.Today) : weekday(day["date"]);
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w * 0.11, y, Graphics.FONT_TINY, name, left());
            WeatherIcons.draw(dc, day["code"], 1, w * 0.44, y, rowH * 0.38);
            drawHighLow(dc, w * 0.64, y, day["max"], day["min"], Graphics.FONT_TINY, false);
            drawPop(dc, w * 0.9, y, day["pop"]);
        }
    }

    private function drawTitle(dc as Graphics.Dc, title as String) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(dc.getWidth() / 2, dc.getHeight() * 0.15, Graphics.FONT_SMALL, title, center());
    }

    // "18° / 9°" with the high in orange and the low in blue.
    private function drawHighLow(dc as Graphics.Dc, cx, y, hi, lo, font, withSpaces as Boolean) as Void {
        var sep = withSpaces ? " / " : "/";
        var hiText = fmt(hi) + "°";
        var loText = fmt(lo) + "°";
        var total = dc.getTextWidthInPixels(hiText + sep + loText, font);
        var x = cx - total / 2;
        dc.setColor(Graphics.COLOR_ORANGE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, font, hiText, left());
        x += dc.getTextWidthInPixels(hiText, font);
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, font, sep, left());
        x += dc.getTextWidthInPixels(sep, font);
        dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, font, loText, left());
    }

    // Chance of precipitation, right aligned.
    private function drawPop(dc as Graphics.Dc, x, y, pop) as Void {
        dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, Graphics.FONT_XTINY, fmt(pop) + "%", right());
    }

    // "Updated 14:32", or the current activity / problem.
    private function drawStatus(dc as Graphics.Dc, d as Dictionary) as Void {
        var state = _model.state;
        var text;
        var color = Graphics.COLOR_LT_GRAY;
        if (state == STATE_LOADING) {
            text = str(Rez.Strings.Updating);
        } else if (state == STATE_ERROR) {
            text = str(Rez.Strings.Offline) + " " + clock(d["at"]);
            color = Graphics.COLOR_RED;
        } else {
            text = str(Rez.Strings.Updated) + " " + clock(d["at"]);
        }
        var y = (_page == 0) ? dc.getHeight() * 0.1 : dc.getHeight() * 0.93;
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(dc.getWidth() / 2, y, Graphics.FONT_XTINY, text, center());
    }

    private function drawPageDots(dc as Graphics.Dc) as Void {
        var x = dc.getWidth() - 9;
        var cy = dc.getHeight() / 2;
        for (var i = 0; i < PAGES; i++) {
            var y = cy + (i - 1) * 12;
            if (i == _page) {
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(x, y, 3);
            } else {
                dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
                dc.drawCircle(x, y, 3);
            }
        }
    }

    private function errorText(code as Number) as String {
        if (code == Communications.BLE_CONNECTION_UNAVAILABLE) {
            return str(Rez.Strings.ErrNoPhone);
        } else if (code == Communications.NETWORK_REQUEST_TIMED_OUT) {
            return str(Rez.Strings.ErrTimeout);
        }
        return str(Rez.Strings.ErrGeneric) + " " + code;
    }

    // Rounded value without decimals, "--" when missing.
    private function fmt(v) as String {
        if (v == null) {
            return "--";
        }
        return Math.round(v.toFloat()).toNumber().toString();
    }

    // "2026-09-28" -> localized short weekday.
    private function weekday(date) as String {
        if (!(date instanceof String) || date.length() < 10) {
            return "";
        }
        var m = Gregorian.moment({
            :year => date.substring(0, 4).toNumber(),
            :month => date.substring(5, 7).toNumber(),
            :day => date.substring(8, 10).toNumber(),
            :hour => 12
        });
        return Gregorian.utcInfo(m, Time.FORMAT_MEDIUM).day_of_week as String;
    }

    private function clock(epoch) as String {
        if (epoch == null) {
            return "";
        }
        var info = Gregorian.info(new Time.Moment(epoch), Time.FORMAT_SHORT);
        return info.hour.format("%02d") + ":" + info.min.format("%02d");
    }

    private function str(id) as String {
        return WatchUi.loadResource(id) as String;
    }

    private function center() as Number {
        return Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
    }

    private function left() as Number {
        return Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER;
    }

    private function right() as Number {
        return Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER;
    }
}
