import Toybox.Lang;
import Toybox.Test;

// Run with: monkeyc ... -t  and then  monkeydo <prg> <device> -t

(:test)
function testParsesFullFrame(logger as Test.Logger) as Boolean {
    var p = new PowerBoxProtocol();
    var frames = p.feed(PowerBoxProtocol.textToBytes(
        "{\"v\":57.25,\"i\":-12.5,\"p\":-715.6,\"soc\":81.5,\"spd\":42.1,\"tmp\":38,\"valid\":true,\"frames\":4294967295,\"can_age_ms\":12}"));
    Test.assertEqual(frames.size(), 1);
    var f = frames[0];
    Test.assert(((f.get("v") as Float) - 57.25).abs() < 0.001);
    Test.assert(((f.get("i") as Float) + 12.5).abs() < 0.001);
    Test.assertEqual(f.get("tmp"), 38);
    Test.assertEqual(f.get("valid"), true);
    Test.assert(f.get("frames") instanceof Long);
    return true;
}

(:test)
function testReassemblesFragments(logger as Test.Logger) as Boolean {
    var p = new PowerBoxProtocol();
    var bytes = PowerBoxProtocol.textToBytes("{\"soc\":50.5,\"spd\":12,\"valid\":false,\"frames\":1,\"can_age_ms\":4}");
    var total = 0;
    for (var i = 0; i < bytes.size(); i += 20) {
        var end = (i + 20 < bytes.size()) ? i + 20 : bytes.size();
        total += p.feed(bytes.slice(i, end)).size();
    }
    Test.assertEqual(total, 1);
    return true;
}

(:test)
function testResyncsAfterLostFragment(logger as Test.Logger) as Boolean {
    var p = new PowerBoxProtocol();
    // First frame lost its tail; the second one must still come through.
    var frames = p.feed(PowerBoxProtocol.textToBytes("{\"v\":57.1,\"i\":3{\"v\":56.0,\"valid\":true}"));
    Test.assertEqual(frames.size(), 1);
    Test.assert(((frames[0].get("v") as Float) - 56.0).abs() < 0.001);
    return true;
}

(:test)
function testTwoFramesInOneChunk(logger as Test.Logger) as Boolean {
    var p = new PowerBoxProtocol();
    var frames = p.feed(PowerBoxProtocol.textToBytes("{\"spd\":1}{\"spd\":2}"));
    Test.assertEqual(frames.size(), 2);
    Test.assertEqual(frames[1].get("spd"), 2);
    return true;
}

(:test)
function testRejectsGarbage(logger as Test.Logger) as Boolean {
    Test.assertEqual(new FlatJsonParser("{\"a\":}").parseObject(), null);
    Test.assertEqual(new FlatJsonParser("{\"a\":[1]}").parseObject(), null);
    Test.assertEqual(new FlatJsonParser("{\"a\" 1}").parseObject(), null);
    return true;
}

(:test)
function testExponentNumbers(logger as Test.Logger) as Boolean {
    var v = FlatJsonParser.numberFromString("1.5e-3") as Float;
    Test.assert((v - 0.0015).abs() < 0.000001);
    var w = FlatJsonParser.numberFromString("-2E+2") as Float;
    Test.assert((w + 200.0).abs() < 0.001);
    return true;
}
