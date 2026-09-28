import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;

// Vector weather icons, so they scale to any size and need no bitmaps.
// (cx, cy) is the icon center, r is roughly half the icon size.
// Assumes a black background (moon crescent is cut out with black).
(:glance)
module WeatherIcons {
    // Icon groups for the WMO weather codes.
    enum Kind {
        KIND_CLEAR,
        KIND_PARTLY,
        KIND_CLOUDY,
        KIND_FOG,
        KIND_DRIZZLE,
        KIND_RAIN,
        KIND_SNOW,
        KIND_STORM
    }

    function kind(code) as Number {
        if (code == null) {
            return KIND_CLOUDY;
        }
        code = code.toNumber();
        if (code == 0) {
            return KIND_CLEAR;
        } else if (code <= 2) {
            return KIND_PARTLY;
        } else if (code == 3) {
            return KIND_CLOUDY;
        } else if (code == 45 || code == 48) {
            return KIND_FOG;
        } else if (code >= 51 && code <= 57) {
            return KIND_DRIZZLE;
        } else if ((code >= 61 && code <= 67) || (code >= 80 && code <= 82)) {
            return KIND_RAIN;
        } else if ((code >= 71 && code <= 77) || code == 85 || code == 86) {
            return KIND_SNOW;
        } else if (code >= 95) {
            return KIND_STORM;
        }
        return KIND_CLOUDY;
    }

    function draw(dc as Graphics.Dc, code, isDay, cx, cy, r) as Void {
        var night = (isDay != null && isDay.toNumber() == 0);
        var k = kind(code);
        if (dc has :setAntiAlias) {
            dc.setAntiAlias(true);
        }

        if (k == KIND_CLEAR) {
            if (night) {
                moon(dc, cx, cy, r);
            } else {
                sun(dc, cx, cy, r);
            }
        } else if (k == KIND_PARTLY) {
            if (night) {
                moon(dc, cx - r * 0.3, cy - r * 0.3, r * 0.7);
            } else {
                sun(dc, cx - r * 0.3, cy - r * 0.3, r * 0.7);
            }
            cloud(dc, cx + r * 0.15, cy + r * 0.15, r * 0.85, Graphics.COLOR_LT_GRAY);
        } else if (k == KIND_CLOUDY) {
            cloud(dc, cx, cy, r, Graphics.COLOR_LT_GRAY);
        } else if (k == KIND_FOG) {
            fog(dc, cx, cy, r);
        } else if (k == KIND_DRIZZLE || k == KIND_RAIN) {
            cloud(dc, cx, cy - r * 0.25, r, Graphics.COLOR_LT_GRAY);
            rain(dc, cx, cy, r, k == KIND_RAIN);
        } else if (k == KIND_SNOW) {
            cloud(dc, cx, cy - r * 0.25, r, Graphics.COLOR_LT_GRAY);
            snow(dc, cx, cy, r);
        } else {
            cloud(dc, cx, cy - r * 0.25, r, Graphics.COLOR_DK_GRAY);
            bolt(dc, cx, cy, r);
        }
    }

    function sun(dc as Graphics.Dc, cx, cy, r) as Void {
        dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(max1(r / 7));
        for (var i = 0; i < 8; i++) {
            var a = i * Math.PI / 4;
            var c = Math.cos(a);
            var s = Math.sin(a);
            dc.drawLine(cx + c * r * 0.7, cy + s * r * 0.7, cx + c * r * 0.98, cy + s * r * 0.98);
        }
        dc.fillCircle(cx, cy, r * 0.5);
        dc.setPenWidth(1);
    }

    function moon(dc as Graphics.Dc, cx, cy, r) as Void {
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, r * 0.65);
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx + r * 0.35, cy - r * 0.25, r * 0.55);
    }

    function cloud(dc as Graphics.Dc, cx, cy, r, color) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx - r * 0.45, cy + r * 0.12, r * 0.33);
        dc.fillCircle(cx - r * 0.05, cy - r * 0.12, r * 0.45);
        dc.fillCircle(cx + r * 0.45, cy + r * 0.1, r * 0.35);
        dc.fillRectangle(cx - r * 0.45, cy + r * 0.1, r * 0.9, r * 0.35);
    }

    function fog(dc as Graphics.Dc, cx, cy, r) as Void {
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(max1(r / 6));
        for (var i = 0; i < 4; i++) {
            var y = cy - r * 0.5 + i * r * 0.33;
            var off = (i % 2 == 0) ? 0 : r * 0.2;
            dc.drawLine(cx - r * 0.8 + off, y, cx + r * 0.8 - (r * 0.2 - off), y);
        }
        dc.setPenWidth(1);
    }

    function rain(dc as Graphics.Dc, cx, cy, r, heavy as Boolean) as Void {
        dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(max1(r / 8));
        var len = heavy ? r * 0.45 : r * 0.2;
        for (var i = -1; i <= 1; i++) {
            var x = cx + i * r * 0.4;
            var y = cy + r * 0.35;
            dc.drawLine(x, y, x - len * 0.4, y + len);
        }
        dc.setPenWidth(1);
    }

    function snow(dc as Graphics.Dc, cx, cy, r) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        var d = max1(r / 9);
        for (var i = -1; i <= 1; i++) {
            dc.fillCircle(cx + i * r * 0.4, cy + r * 0.45, d);
            dc.fillCircle(cx + i * r * 0.4 - r * 0.2, cy + r * 0.8, d);
        }
    }

    function bolt(dc as Graphics.Dc, cx, cy, r) as Void {
        dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([
            [cx + r * 0.1, cy + r * 0.1],
            [cx - r * 0.25, cy + r * 0.6],
            [cx, cy + r * 0.6],
            [cx - r * 0.15, cy + r],
            [cx + r * 0.3, cy + r * 0.45],
            [cx + r * 0.05, cy + r * 0.45],
            [cx + r * 0.2, cy + r * 0.1]
        ]);
    }

    // Arrow pointing where the wind blows to (Open-Meteo gives where it comes from).
    function windArrow(dc as Graphics.Dc, cx, cy, r, fromDeg) as Void {
        var a = Math.toRadians(fromDeg.toFloat() + 180);
        var c = Math.cos(a);
        var s = Math.sin(a);
        var shape = [[0, -r], [r * 0.65, r * 0.8], [0, r * 0.4], [-r * 0.65, r * 0.8]];
        var pts = [];
        for (var i = 0; i < shape.size(); i++) {
            var x = shape[i][0];
            var y = shape[i][1];
            pts.add([cx + x * c - y * s, cy + x * s + y * c]);
        }
        dc.fillPolygon(pts);
    }

    function max1(v) as Number {
        var n = v.toNumber();
        return n < 1 ? 1 : n;
    }
}
