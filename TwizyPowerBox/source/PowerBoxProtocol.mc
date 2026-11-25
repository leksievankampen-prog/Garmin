import Toybox.Lang;
import Toybox.Math;
import Toybox.StringUtil;

// Twizy PowerBox BT telemetry protocol.
//
// The box is a Nordic UART (NUS) peripheral that sends one flat JSON object
// per notification, about 5 times per second, without a line terminator:
//
//   {"v":57.3,"i":12.5,"p":716.25,"soc":81.5,"spd":42.1,"tmp":38,
//    "valid":true,"frames":12345,"can_age_ms":12}
//
// A full frame is ~110 bytes, which is larger than the default 20-byte BLE
// payload. The watch may therefore receive one frame split over several
// notifications, so the bytes are buffered until a complete {...} is seen.

const POWERBOX_MAX_BUFFER = 512;

class PowerBoxProtocol {
    hidden var _buf as ByteArray;

    var lastRawText as String = "";
    var framesOk as Number = 0;
    var framesBad as Number = 0;

    function initialize() {
        _buf = []b;
    }

    function reset() as Void {
        _buf = []b;
    }

    // Feed raw bytes from a notification. Returns every complete,
    // successfully parsed frame (0, 1 or more).
    function feed(chunk as ByteArray) as Array<Dictionary> {
        _buf.addAll(chunk);
        var frames = [] as Array<Dictionary>;

        while (true) {
            var start = _buf.indexOf(0x7B); // '{'
            if (start < 0) {
                _buf = []b;
                break;
            }
            if (start > 0) {
                _buf = _buf.slice(start, null);
            }

            var end = _buf.indexOf(0x7D); // '}'
            if (end < 0) {
                if (_buf.size() > POWERBOX_MAX_BUFFER) {
                    _buf = []b; // garbage, start over
                }
                break;
            }

            // If a notification got lost, a new '{' can show up before the
            // '}' that closes it. Resync on the last '{' before the '}'.
            var frameStart = 0;
            for (var k = end - 1; k > 0; k--) {
                if (_buf[k] == 0x7B) {
                    frameStart = k;
                    framesBad++;
                    break;
                }
            }

            var frameBytes = _buf.slice(frameStart, end + 1);
            _buf = _buf.slice(end + 1, null);

            var text = bytesToText(frameBytes);
            if (text == null) {
                framesBad++;
                continue;
            }
            lastRawText = text;
            var obj = new FlatJsonParser(text).parseObject();
            if (obj == null) {
                framesBad++;
            } else {
                framesOk++;
                frames.add(obj);
            }
        }
        return frames;
    }

    static function bytesToText(bytes as ByteArray) as String? {
        try {
            return StringUtil.convertEncodedString(bytes, {
                :fromRepresentation => StringUtil.REPRESENTATION_BYTE_ARRAY,
                :toRepresentation => StringUtil.REPRESENTATION_STRING_PLAIN_TEXT,
                :encoding => StringUtil.CHAR_ENCODING_UTF8
            }) as String;
        } catch (e) {
            return null;
        }
    }

    static function textToBytes(text as String) as ByteArray {
        return StringUtil.convertEncodedString(text, {
            :fromRepresentation => StringUtil.REPRESENTATION_STRING_PLAIN_TEXT,
            :toRepresentation => StringUtil.REPRESENTATION_BYTE_ARRAY,
            :encoding => StringUtil.CHAR_ENCODING_UTF8
        }) as ByteArray;
    }
}

// Minimal JSON parser for one flat object: string keys, values that are
// numbers, booleans, null or strings. Nested objects/arrays are rejected.
// Returns null for malformed input instead of throwing.
class FlatJsonParser {
    hidden var _c as Array<Char>;
    hidden var _i as Number = 0;
    hidden var _n as Number;
    hidden var _err as Boolean = false;

    function initialize(text as String) {
        _c = text.toCharArray();
        _n = _c.size();
    }

    function parseObject() as Dictionary? {
        skipWs();
        if (!consume('{')) {
            return null;
        }
        var result = {} as Dictionary;
        skipWs();
        if (consume('}')) {
            return result;
        }
        while (true) {
            skipWs();
            var key = parseString();
            if (key == null) {
                return null;
            }
            skipWs();
            if (!consume(':')) {
                return null;
            }
            skipWs();
            var value = parseValue();
            if (_err) {
                return null;
            }
            result.put(key, value);
            skipWs();
            if (consume(',')) {
                continue;
            }
            if (consume('}')) {
                return result;
            }
            return null;
        }
        return null;
    }

    hidden function peek() as Char? {
        return (_i < _n) ? _c[_i] : null;
    }

    hidden function consume(ch as Char) as Boolean {
        if (_i < _n && _c[_i] == ch) {
            _i++;
            return true;
        }
        return false;
    }

    hidden function skipWs() as Void {
        while (_i < _n) {
            var ch = _c[_i];
            if (ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r') {
                _i++;
            } else {
                break;
            }
        }
    }

    hidden function parseString() as String? {
        if (!consume('"')) {
            return null;
        }
        var out = [] as Array<Char>;
        while (_i < _n) {
            var ch = _c[_i];
            _i++;
            if (ch == '"') {
                return StringUtil.charArrayToString(out);
            }
            if (ch == '\\') {
                if (_i >= _n) {
                    return null;
                }
                var esc = _c[_i];
                _i++;
                if (esc == 'n') {
                    out.add('\n');
                } else if (esc == 't') {
                    out.add('\t');
                } else {
                    out.add(esc); // \" \\ \/ and anything else taken literally
                }
            } else {
                out.add(ch);
            }
        }
        return null; // unterminated
    }

    hidden function parseValue() {
        var ch = peek();
        if (ch == null) {
            _err = true;
            return null;
        }
        if (ch == '"') {
            var s = parseString();
            if (s == null) {
                _err = true;
            }
            return s;
        }
        if (ch == 't') {
            return matchWord("true", true);
        }
        if (ch == 'f') {
            return matchWord("false", false);
        }
        if (ch == 'n') {
            return matchWord("null", null);
        }
        if (ch == '-' || FlatJsonParser.isDigit(ch)) {
            return parseNumber();
        }
        _err = true; // nested object/array or garbage
        return null;
    }

    hidden function matchWord(word as String, value) {
        var w = word.toCharArray();
        if (_i + w.size() > _n) {
            _err = true;
            return null;
        }
        for (var k = 0; k < w.size(); k++) {
            if (_c[_i + k] != w[k]) {
                _err = true;
                return null;
            }
        }
        _i += w.size();
        return value;
    }

    hidden function parseNumber() {
        var chars = [] as Array<Char>;
        while (_i < _n) {
            var ch = _c[_i];
            if (FlatJsonParser.isDigit(ch) || ch == '-' || ch == '+' || ch == '.' || ch == 'e' || ch == 'E') {
                chars.add(ch);
                _i++;
            } else {
                break;
            }
        }
        var s = StringUtil.charArrayToString(chars);
        var value = FlatJsonParser.numberFromString(s);
        if (value == null) {
            _err = true;
        }
        return value;
    }

    static function isDigit(ch as Char) as Boolean {
        var code = ch.toNumber();
        return code >= 48 && code <= 57;
    }

    // "42" -> 42, "4294967295" -> Long, "57.25" -> Float, "1.5e-3" -> Float.
    static function numberFromString(s as String) {
        if (s.length() == 0) {
            return null;
        }
        var e = s.find("e");
        if (e == null) {
            e = s.find("E");
        }
        var mantissa = (e == null) ? s : s.substring(0, e);
        if (mantissa == null) {
            return null;
        }
        if (e == null && mantissa.find(".") == null) {
            var n = s.toNumber();
            if (n == null) {
                n = s.toLong();
            }
            return n;
        }
        var m = mantissa.toFloat();
        if (m == null) {
            return null;
        }
        if (e != null) {
            var expStr = s.substring(e + 1, s.length());
            if (expStr == null) {
                return null;
            }
            if (expStr.find("+") == 0) {
                expStr = expStr.substring(1, expStr.length());
            }
            var ex = (expStr == null) ? null : expStr.toNumber();
            if (ex == null) {
                return null;
            }
            m = m * Math.pow(10, ex).toFloat();
        }
        return m;
    }
}
