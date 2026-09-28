import Toybox.Application;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.Position;
import Toybox.Time;
import Toybox.WatchUi;

enum WeatherState {
    STATE_IDLE,
    STATE_WAITING_GPS,
    STATE_LOADING,
    STATE_OK,
    STATE_ERROR
}

// Gets a location fix and loads the forecast from Open-Meteo.
// The parsed forecast is cached in Storage so the app shows the last
// known weather immediately, even without a phone connection.
class WeatherModel {
    const URL = "https://api.open-meteo.com/v1/forecast";
    const HOURS = 6;
    const DAYS = 5;

    var state = STATE_IDLE;
    var errorCode = 0;
    var data = null;

    private var _lat = null;
    private var _lon = null;

    function initialize() {
        data = Application.Storage.getValue("weather");
    }

    function start() as Void {
        var loc = null;
        var info = Position.getInfo();
        var pos = info.position;
        var fresh = false;
        if (pos != null && info.accuracy != Position.QUALITY_NOT_AVAILABLE) {
            var deg = pos.toDegrees();
            if (isValid(deg[0], deg[1])) {
                loc = deg;
                fresh = info.accuracy >= Position.QUALITY_POOR;
            }
        }
        if (loc == null) {
            loc = Application.Storage.getValue("location") as Array?;
        }

        if (loc != null) {
            fetch(loc[0].toFloat(), loc[1].toFloat());
        } else {
            state = STATE_WAITING_GPS;
        }

        // Without a current fix, ask the GPS for one and refetch when we moved.
        if (!fresh) {
            Position.enableLocationEvents(Position.LOCATION_ONE_SHOT, method(:onPosition));
        }
    }

    function stop() as Void {
        Position.enableLocationEvents(Position.LOCATION_DISABLE, method(:onPosition));
    }

    function refresh() as Void {
        if (_lat != null) {
            fetch(_lat, _lon);
        } else {
            start();
        }
    }

    function onPosition(info as Position.Info) as Void {
        var pos = info.position;
        if (pos == null) {
            return;
        }
        var deg = pos.toDegrees();
        var lat = deg[0].toFloat();
        var lon = deg[1].toFloat();
        if (!isValid(lat, lon)) {
            return;
        }
        Application.Storage.setValue("location", [lat, lon]);

        // Only refetch when the location changed noticeably (~5 km).
        if (_lat == null || (lat - _lat).abs() > 0.05 || (lon - _lon).abs() > 0.05) {
            fetch(lat, lon);
        }
    }

    private function isValid(lat, lon) as Boolean {
        if (lat == null || lon == null) {
            return false;
        }
        // Devices report 0,0 or 180,180 when there is no real fix.
        if (lat.abs() < 0.0001 && lon.abs() < 0.0001) {
            return false;
        }
        return lat.abs() <= 90 && lon.abs() <= 180;
    }

    private function fetch(lat as Float, lon as Float) as Void {
        _lat = lat;
        _lon = lon;
        state = STATE_LOADING;
        WatchUi.requestUpdate();

        var tempUnit = Application.Properties.getValue("tempUnit");
        var windUnit = Application.Properties.getValue("windUnit");
        var windUnits = ["kmh", "ms", "mph", "kn"];
        if (!(windUnit instanceof Number) || windUnit < 0 || windUnit >= windUnits.size()) {
            windUnit = 0;
        }

        var params = {
            "latitude" => lat.format("%.3f"),
            "longitude" => lon.format("%.3f"),
            "current" => "temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,wind_speed_10m,wind_direction_10m,is_day",
            "hourly" => "temperature_2m,precipitation_probability,weather_code,is_day",
            "daily" => "weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max",
            "timezone" => "auto",
            "forecast_days" => DAYS.toString(),
            "forecast_hours" => (HOURS + 1).toString(),
            "temperature_unit" => tempUnit == 1 ? "fahrenheit" : "celsius",
            "wind_speed_unit" => windUnits[windUnit]
        };
        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_GET,
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };
        Communications.makeWebRequest(URL, params, options, method(:onResponse));
    }

    function onResponse(code as Number, body) as Void {
        var parsed = null;
        if (code == 200 && body instanceof Dictionary) {
            parsed = parse(body);
        }

        if (parsed != null) {
            data = parsed;
            state = STATE_OK;
            Application.Storage.setValue("weather", parsed);
            saveGlance(parsed);
        } else {
            state = STATE_ERROR;
            errorCode = (code == 200) ? -1 : code;
        }
        WatchUi.requestUpdate();
    }

    // Reduces the Open-Meteo response to the small structure the views need.
    private function parse(body as Dictionary) as Dictionary? {
        var cur = body["current"];
        var hr = body["hourly"];
        var dy = body["daily"];
        var units = body["current_units"];
        if (!(cur instanceof Dictionary) || !(hr instanceof Dictionary) || !(dy instanceof Dictionary)) {
            return null;
        }

        var hours = [];
        var hTime = hr["time"];
        if (hTime instanceof Array) {
            // Index 0 is the current hour, so start with the next one.
            for (var i = 1; i < hTime.size() && hours.size() < HOURS; i++) {
                hours.add({
                    "t" => (hTime[i] as String).substring(11, 16),
                    "temp" => at(hr["temperature_2m"], i),
                    "pop" => at(hr["precipitation_probability"], i),
                    "code" => at(hr["weather_code"], i),
                    "day" => at(hr["is_day"], i)
                });
            }
        }

        var days = [];
        var dTime = dy["time"];
        if (dTime instanceof Array) {
            for (var i = 0; i < dTime.size() && days.size() < DAYS; i++) {
                days.add({
                    "date" => dTime[i],
                    "max" => at(dy["temperature_2m_max"], i),
                    "min" => at(dy["temperature_2m_min"], i),
                    "code" => at(dy["weather_code"], i),
                    "pop" => at(dy["precipitation_probability_max"], i)
                });
            }
        }

        var wu = "";
        if (units instanceof Dictionary) {
            if (units["wind_speed_10m"] != null) {
                wu = units["wind_speed_10m"];
            }
        }

        return {
            "cur" => {
                "temp" => cur["temperature_2m"],
                "feels" => cur["apparent_temperature"],
                "hum" => cur["relative_humidity_2m"],
                "code" => cur["weather_code"],
                "wind" => cur["wind_speed_10m"],
                "dir" => cur["wind_direction_10m"],
                "day" => cur["is_day"]
            },
            "hours" => hours,
            "days" => days,
            "wu" => wu,
            "at" => Time.now().value()
        };
    }

    private function at(arr, i as Number) {
        if (arr instanceof Array && i < arr.size()) {
            return arr[i];
        }
        return null;
    }

    // The glance runs with little memory, so it gets its own tiny summary
    // with the description already translated.
    private function saveGlance(d as Dictionary) as Void {
        var cur = d["cur"];
        var days = d["days"] as Array;
        var today = days.size() > 0 ? days[0] : {};
        Application.Storage.setValue("glance", {
            "temp" => cur["temp"],
            "code" => cur["code"],
            "day" => cur["day"],
            "max" => today["max"],
            "min" => today["min"],
            "desc" => WeatherCodes.describe(cur["code"])
        });
    }
}
