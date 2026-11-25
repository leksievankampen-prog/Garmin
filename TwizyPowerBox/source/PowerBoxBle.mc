import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;
using Toybox.BluetoothLowEnergy as Ble;

// Talks to the Twizy PowerBox BT over the Nordic UART Service.
//
// Flow: register GATT profile -> scan -> pair with the box -> enable
// notifications on the TX characteristic -> receive JSON telemetry.
//
// The box only sends. Its firmware ignores writes to RX (CAN runs in
// listen-only mode), so this client never writes commands.
class PowerBoxBle extends Ble.BleDelegate {
    hidden var _model as TwizyModel;
    hidden var _protocol as PowerBoxProtocol;
    hidden var _targetName as String;

    hidden var _serviceUuid as Ble.Uuid;
    hidden var _txUuid as Ble.Uuid;   // box -> watch (notify)
    hidden var _rxUuid as Ble.Uuid;   // watch -> box (write, unused)

    hidden var _device as Ble.Device? = null;
    hidden var _profileReady as Boolean = false;

    function initialize(model as TwizyModel, protocol as PowerBoxProtocol, targetName as String) {
        BleDelegate.initialize();
        _model = model;
        _protocol = protocol;
        _targetName = targetName;
        _serviceUuid = Ble.stringToUuid("6E400001-B5A3-F393-E0A9-E50E24DCCA9E");
        _rxUuid      = Ble.stringToUuid("6E400002-B5A3-F393-E0A9-E50E24DCCA9E");
        _txUuid      = Ble.stringToUuid("6E400003-B5A3-F393-E0A9-E50E24DCCA9E");
    }

    function start() as Void {
        Ble.setDelegate(self);
        _model.setLink(LINK_REGISTERING, "");
        try {
            Ble.registerProfile({
                :uuid => _serviceUuid,
                :characteristics => [
                    { :uuid => _txUuid, :descriptors => [Ble.cccdUuid()] },
                    { :uuid => _rxUuid }
                ]
            });
        } catch (e) {
            fail("Profiel: " + errText(e));
        }
    }

    function stop() as Void {
        try {
            Ble.setScanState(Ble.SCAN_STATE_OFF);
        } catch (e) {
        }
        releaseDevice();
    }

    // Manual retry (START button): drop the pairing and scan again.
    function restart() as Void {
        releaseDevice();
        _protocol.reset();
        if (_profileReady) {
            startScan();
        } else {
            start();
        }
    }

    hidden function releaseDevice() as Void {
        var device = _device;
        if (device != null) {
            try {
                Ble.unpairDevice(device);
            } catch (e) {
            }
            _device = null;
        }
    }

    hidden function startScan() as Void {
        _model.setLink(LINK_SCANNING, _targetName);
        try {
            Ble.setScanState(Ble.SCAN_STATE_SCANNING);
        } catch (e) {
            fail("Scan: " + errText(e));
        }
    }

    hidden function errText(e as Exception) as String {
        var msg = e.getErrorMessage();
        return (msg == null) ? "onbekend" : msg;
    }

    hidden function fail(message as String) as Void {
        System.println("PowerBox: " + message);
        _model.setLink(LINK_ERROR, message);
        WatchUi.requestUpdate();
    }

    // ---- BleDelegate callbacks ----

    function onProfileRegister(uuid as Ble.Uuid, status as Ble.Status) as Void {
        if (status == Ble.STATUS_SUCCESS) {
            _profileReady = true;
            startScan();
        } else {
            fail("Profiel status " + status.toString());
        }
        WatchUi.requestUpdate();
    }

    function onScanResults(scanResults as Ble.Iterator) as Void {
        if (_device != null) {
            return;
        }
        for (var r = scanResults.next() as Ble.ScanResult?; r != null; r = scanResults.next() as Ble.ScanResult?) {
            if (!isPowerBox(r)) {
                continue;
            }
            Ble.setScanState(Ble.SCAN_STATE_OFF);
            _model.deviceName = r.getDeviceName();
            _model.rssi = r.getRssi();
            _model.setLink(LINK_CONNECTING, "");
            try {
                _device = Ble.pairDevice(r);
            } catch (e) {
                fail("Koppelen: " + errText(e));
                startScan();
            }
            WatchUi.requestUpdate();
            return;
        }
    }

    hidden function isPowerBox(r as Ble.ScanResult) as Boolean {
        var name = r.getDeviceName();
        if (name != null) {
            return name.equals(_targetName);
        }
        // No name in the advertisement: fall back to the advertised service.
        var uuids = r.getServiceUuids();
        for (var u = uuids.next(); u != null; u = uuids.next()) {
            if (_serviceUuid.equals(u)) {
                return true;
            }
        }
        return false;
    }

    function onConnectedStateChanged(device as Ble.Device, state as Ble.ConnectionState) as Void {
        if (state == Ble.CONNECTION_STATE_CONNECTED) {
            _device = device;
            _protocol.reset();
            enableNotifications(device);
        } else {
            // The device stays paired, so the system reconnects by itself
            // when the box is back in range. START forces a fresh scan.
            _model.setLink(LINK_DISCONNECTED, "START = opnieuw zoeken");
        }
        WatchUi.requestUpdate();
    }

    hidden function enableNotifications(device as Ble.Device) as Void {
        var service = device.getService(_serviceUuid);
        if (service == null) {
            fail("UART-service niet gevonden");
            return;
        }
        var tx = service.getCharacteristic(_txUuid);
        if (tx == null) {
            fail("TX niet gevonden");
            return;
        }
        var cccd = tx.getDescriptor(Ble.cccdUuid());
        if (cccd == null) {
            fail("CCCD niet gevonden");
            return;
        }
        _model.setLink(LINK_SUBSCRIBING, "");
        try {
            cccd.requestWrite([0x01, 0x00]b);
        } catch (e) {
            fail("Notify: " + errText(e));
        }
    }

    function onDescriptorWrite(descriptor as Ble.Descriptor, status as Ble.Status) as Void {
        if (status == Ble.STATUS_SUCCESS) {
            _model.setLink(LINK_STREAMING, "");
        } else {
            fail("Notify status " + status.toString());
        }
        WatchUi.requestUpdate();
    }

    function onCharacteristicChanged(characteristic as Ble.Characteristic, value as ByteArray) as Void {
        if (!_txUuid.equals(characteristic.getUuid())) {
            return;
        }
        var frames = _protocol.feed(value);
        if (frames.size() == 0) {
            return;
        }
        // At 5 Hz only the newest frame matters.
        _model.applyFrame(frames[frames.size() - 1]);
        if (_model.link != LINK_STREAMING) {
            _model.setLink(LINK_STREAMING, "");
        }
        WatchUi.requestUpdate();
    }
}
