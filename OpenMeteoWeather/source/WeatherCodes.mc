import Toybox.Lang;
import Toybox.WatchUi;

// Descriptions for the WMO weather codes used by Open-Meteo.
// https://open-meteo.com/en/docs (section "WMO Weather interpretation codes")
module WeatherCodes {
    function describe(code) as String {
        var id = Rez.Strings.WUnknown;
        if (code != null) {
            code = code.toNumber();
            if (code == 0) { id = Rez.Strings.W0; }
            else if (code == 1) { id = Rez.Strings.W1; }
            else if (code == 2) { id = Rez.Strings.W2; }
            else if (code == 3) { id = Rez.Strings.W3; }
            else if (code == 45 || code == 48) { id = Rez.Strings.W45; }
            else if (code >= 51 && code <= 55) { id = Rez.Strings.W51; }
            else if (code == 56 || code == 57) { id = Rez.Strings.W56; }
            else if (code == 61) { id = Rez.Strings.W61; }
            else if (code == 63) { id = Rez.Strings.W63; }
            else if (code == 65) { id = Rez.Strings.W65; }
            else if (code == 66 || code == 67) { id = Rez.Strings.W66; }
            else if (code == 71) { id = Rez.Strings.W71; }
            else if (code == 73) { id = Rez.Strings.W73; }
            else if (code == 75) { id = Rez.Strings.W75; }
            else if (code == 77) { id = Rez.Strings.W77; }
            else if (code == 80 || code == 81) { id = Rez.Strings.W80; }
            else if (code == 82) { id = Rez.Strings.W82; }
            else if (code == 85 || code == 86) { id = Rez.Strings.W85; }
            else if (code == 95) { id = Rez.Strings.W95; }
            else if (code == 96 || code == 99) { id = Rez.Strings.W96; }
        }
        return WatchUi.loadResource(id) as String;
    }
}
