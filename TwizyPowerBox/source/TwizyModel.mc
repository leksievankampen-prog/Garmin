import Toybox.Lang;
import Toybox.System;

// Connection states shown on screen.
enum LinkState {
    LINK_IDLE,
    LINK_REGISTERING,
    LINK_SCANNING,
    LINK_CONNECTING,
    LINK_SUBSCRIBING,
    LINK_STREAMING,
    LINK_DISCONNECTED,
    LINK_ERROR,
    LINK_DEMO
}

// Data older than this is shown as stale ("--").
const TWIZY_STALE_MS = 2500;

// Latest telemetry from the PowerBox. Every value is null when unknown.
class TwizyModel {
    var voltage as Float? = null;      // V, battery pack
    var current as Float? = null;      // A, + = discharge, - = charging/regen
    var power as Float? = null;        // W
    var soc as Float? = null;          // %
    var speed as Float? = null;        // km/h
    var motorTemp as Float? = null;    // degrees C
    var bmsValid as Boolean = false;
    var canFrames as Number or Long or Null = null;
    var canAgeMs as Number or Long or Null = null;

    var lastUpdateMs as Number? = null;   // System.getTimer() of last frame

    var link as LinkState = LINK_IDLE;
    var linkDetail as String = "";
    var deviceName as String? = null;
    var rssi as Number? = null;

    function initialize() {
    }

    function applyFrame(frame as Dictionary) as Void {
        voltage = toFloat(frame.get("v"));
        current = toFloat(frame.get("i"));
        power = toFloat(frame.get("p"));
        soc = toFloat(frame.get("soc"));
        speed = toFloat(frame.get("spd"));
        motorTemp = toFloat(frame.get("tmp"));

        var valid = frame.get("valid");
        bmsValid = (valid instanceof Boolean) ? valid : false;

        var frames = frame.get("frames");
        canFrames = (frames instanceof Number || frames instanceof Long) ? frames : null;
        var age = frame.get("can_age_ms");
        canAgeMs = (age instanceof Number || age instanceof Long) ? age : null;

        if (power == null && voltage != null && current != null) {
            power = voltage * current;
        }
        lastUpdateMs = System.getTimer();
    }

    function isStale() as Boolean {
        if (lastUpdateMs == null) {
            return true;
        }
        if (System.getTimer() - lastUpdateMs > TWIZY_STALE_MS) {
            return true;
        }
        // The box is connected but the car's CAN bus went quiet (car off).
        return canAgeMs != null && canAgeMs > TWIZY_STALE_MS;
    }

    function setLink(state as LinkState, detail as String) as Void {
        link = state;
        linkDetail = detail;
    }

    function linkText() as String {
        switch (link) {
            case LINK_IDLE:         return "Start...";
            case LINK_REGISTERING:  return "BLE voorbereiden";
            case LINK_SCANNING:     return "Zoeken naar PowerBox";
            case LINK_CONNECTING:   return "Verbinden...";
            case LINK_SUBSCRIBING:  return "Data aanvragen";
            case LINK_STREAMING:    return "Verbonden";
            case LINK_DISCONNECTED: return "Verbinding weg";
            case LINK_ERROR:        return "Fout";
            case LINK_DEMO:         return "Demomodus";
        }
        return "?";
    }

    static function toFloat(value) as Float? {
        if (value instanceof Float) {
            return value;
        }
        if (value instanceof Number || value instanceof Long || value instanceof Double) {
            return value.toFloat();
        }
        return null;
    }
}
