import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.WatchUi;

// Glance in the widget loop: icon, temperature, description and high / low.
// Reads the summary the app saved, so it needs no network or GPS itself.
(:glance)
class WeatherGlanceView extends WatchUi.GlanceView {
    function initialize() {
        GlanceView.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var g = Application.Storage.getValue("glance") as Dictionary?;

        if (g == null) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(0, h / 2, Graphics.FONT_TINY, WatchUi.loadResource(Rez.Strings.GlanceEmpty) as String,
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }

        var r = h * 0.32;
        WeatherIcons.draw(dc, g["code"], g["day"], r + 2, h / 2, r);

        var x = r * 2 + 10;
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, h * 0.3, Graphics.FONT_TINY, num(g["temp"]) + "° " + g["desc"],
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, h * 0.72, Graphics.FONT_XTINY, num(g["max"]) + "° / " + num(g["min"]) + "°",
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    private function num(v) as String {
        if (v == null) {
            return "--";
        }
        return Math.round(v.toFloat()).toNumber().toString();
    }
}
