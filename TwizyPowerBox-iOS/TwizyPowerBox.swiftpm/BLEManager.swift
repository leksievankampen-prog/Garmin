import CoreBluetooth
import Foundation

/// Everything Bluetooth: scanning, connecting, discovering every service,
/// subscribing to every notify characteristic, writing commands and logging
/// all traffic. Built to work with a box whose protocol is not documented.
final class BLEManager: NSObject, ObservableObject {
    enum Link: Equatable {
        case idle
        case connecting(String)
        case connected(String)
        case disconnected(String)
    }

    // Bluetooth / scan
    @Published private(set) var bluetoothState: CBManagerState = .unknown
    @Published private(set) var isScanning = false
    @Published private(set) var devices: [DiscoveredDevice] = []
    @Published var showAllDevices = false

    // Connection
    @Published private(set) var link: Link = .idle
    @Published private(set) var characteristics: [CharacteristicInfo] = []
    @Published var writeTarget: String?
    @Published var autoReconnect = true

    // Data
    @Published private(set) var log: [LogEntry] = []
    @Published private(set) var fields: [String: TelemetryField] = [:]
    @Published private(set) var fieldOrder: [String] = []
    @Published private(set) var lastMessage: String = ""
    @Published private(set) var lastDataAt: Date?
    @Published private(set) var messageCount = 0

    private var central: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var userDisconnected = false
    private var assemblers: [String: StreamAssembler] = [:]
    private var flushWork: [String: DispatchWorkItem] = [:]

    private static let maxLog = 3000
    private static let lastDeviceKey = "lastDeviceUUID"
    /// After this much silence, a chunk without a terminator counts as a message.
    private static let quietFlush: TimeInterval = 0.15

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: nil,
                                   options: [CBCentralManagerOptionShowPowerAlertKey: true])
    }

    // MARK: - Scanning

    var visibleDevices: [DiscoveredDevice] {
        devices
            .filter { showAllDevices || $0.isLikelyPowerBox || !$0.name.hasPrefix("(") }
            .sorted { a, b in
                if a.isLikelyPowerBox != b.isLikelyPowerBox { return a.isLikelyPowerBox }
                return a.rssi > b.rssi
            }
    }

    func startScan() {
        guard bluetoothState == .poweredOn else { return }
        devices.removeAll()
        central.scanForPeripherals(withServices: nil,
                                   options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
        isScanning = true
    }

    func stopScan() {
        central.stopScan()
        isScanning = false
    }

    // MARK: - Connecting

    func connect(_ device: DiscoveredDevice) {
        stopScan()
        UserDefaults.standard.set(device.id.uuidString, forKey: Self.lastDeviceKey)
        connect(peripheral: device.peripheral, name: device.name)
    }

    private func connect(peripheral: CBPeripheral, name: String) {
        userDisconnected = false
        self.peripheral = peripheral
        peripheral.delegate = self
        characteristics.removeAll()
        assemblers.removeAll()
        link = .connecting(name)
        addInfo("Verbinden met \(name) (\(peripheral.identifier.uuidString))")
        // No timeout on purpose: iOS keeps waiting until the box is in range.
        central.connect(peripheral, options: nil)
    }

    func disconnect() {
        userDisconnected = true
        if let peripheral {
            central.cancelPeripheralConnection(peripheral)
        }
        peripheral = nil
        characteristics.removeAll()
        link = .idle
    }

    func forgetDevice() {
        disconnect()
        UserDefaults.standard.removeObject(forKey: Self.lastDeviceKey)
    }

    var hasRememberedDevice: Bool {
        UserDefaults.standard.string(forKey: Self.lastDeviceKey) != nil
    }

    private func reconnectToRememberedDevice() {
        guard let raw = UserDefaults.standard.string(forKey: Self.lastDeviceKey),
              let uuid = UUID(uuidString: raw),
              let known = central.retrievePeripherals(withIdentifiers: [uuid]).first else {
            return
        }
        connect(peripheral: known, name: known.name ?? "PowerBox")
    }

    // MARK: - Sending

    var writableCharacteristics: [CharacteristicInfo] {
        characteristics.filter(\.canWrite)
    }

    @discardableResult
    func send(text: String, ending: LineEnding) -> Bool {
        guard let data = (text + ending.bytes).data(using: .utf8) else { return false }
        return send(data: data)
    }

    @discardableResult
    func send(hex: String) -> Bool {
        guard let data = HexParser.data(from: hex) else {
            addInfo("Ongeldige hex: \(hex)")
            return false
        }
        return send(data: data)
    }

    func send(_ command: QuickCommand) {
        if command.isHex {
            send(hex: command.payload)
        } else {
            send(text: command.payload, ending: command.ending)
        }
    }

    @discardableResult
    func send(data: Data) -> Bool {
        guard let peripheral, peripheral.state == .connected,
              let target = writeTarget,
              let characteristic = findCharacteristic(target) else {
            addInfo("Niet verzonden: geen verbinding of geen schrijf-characteristic")
            return false
        }
        let type: CBCharacteristicWriteType =
            characteristic.properties.contains(.write) ? .withResponse : .withoutResponse
        let chunkSize = max(20, peripheral.maximumWriteValueLength(for: type))
        var offset = 0
        while offset < data.count {
            let end = min(offset + chunkSize, data.count)
            peripheral.writeValue(data.subdata(in: offset..<end), for: characteristic, type: type)
            offset = end
        }
        append(LogEntry(time: Date(), direction: .outgoing, characteristic: target, data: data, note: nil))
        return true
    }

    private func findCharacteristic(_ uuid: String) -> CBCharacteristic? {
        peripheral?.services?
            .flatMap { $0.characteristics ?? [] }
            .first { $0.uuid.uuidString == uuid }
    }

    // MARK: - Log

    func clearLog() {
        log.removeAll()
        messageCount = 0
    }

    func clearFields() {
        fields.removeAll()
        fieldOrder.removeAll()
    }

    private func addInfo(_ text: String) {
        append(LogEntry(time: Date(), direction: .info, characteristic: "", data: Data(), note: text))
    }

    private func append(_ entry: LogEntry) {
        log.append(entry)
        if log.count > Self.maxLog {
            log.removeFirst(log.count - Self.maxLog)
        }
    }

    /// Plain-text log to share (mail, WhatsApp, Notes...).
    func exportText() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        var out = "Twizy PowerBox log, \(Date())\n"
        if let peripheral {
            out += "Apparaat: \(peripheral.name ?? "?") \(peripheral.identifier.uuidString)\n"
        }
        out += "\nCharacteristics:\n"
        for c in characteristics {
            out += "  service \(c.serviceUUID)  char \(c.uuid)  [\(c.propertyText)]"
            if let v = c.lastValue {
                out += "  laatste: \(LogEntry.printable(v))"
            }
            out += "\n"
        }
        out += "\nVerkeer (tijd, richting, characteristic, hex | tekst):\n"
        for e in log {
            let time = formatter.string(from: e.time)
            if e.direction == .info {
                out += "\(time) --- \(e.text)\n"
            } else {
                out += "\(time) \(e.direction.rawValue) \(e.characteristic)  \(e.hex)  |  \(e.text)\n"
            }
        }
        return out
    }

    // MARK: - Incoming data

    private func handleIncoming(_ data: Data, from uuid: String) {
        lastDataAt = Date()
        append(LogEntry(time: Date(), direction: .incoming, characteristic: uuid, data: data, note: nil))
        if let index = characteristics.firstIndex(where: { $0.uuid == uuid }) {
            characteristics[index].lastValue = data
        }

        let text = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
        var assembler = assemblers[uuid] ?? StreamAssembler()
        let messages = assembler.feed(text)
        assemblers[uuid] = assembler
        messages.forEach(handleMessage)

        // Unterminated text: treat it as complete after a short silence.
        flushWork[uuid]?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, var a = self.assemblers[uuid] else { return }
            if let rest = a.flush() {
                self.assemblers[uuid] = a
                self.handleMessage(rest)
            }
        }
        flushWork[uuid] = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.quietFlush, execute: work)
    }

    private func handleMessage(_ message: String) {
        lastMessage = message
        messageCount += 1
        for field in TelemetryParser.parse(message) {
            if fields[field.key] == nil {
                fieldOrder.append(field.key)
            }
            fields[field.key] = field
        }
    }
}

// MARK: - CBCentralManagerDelegate

extension BLEManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        bluetoothState = central.state
        if central.state == .poweredOn {
            if hasRememberedDevice && autoReconnect {
                reconnectToRememberedDevice()
            }
            if peripheral == nil {
                startScan()
            }
        } else {
            isScanning = false
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let advertisedName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let name = advertisedName ?? peripheral.name ?? "(naamloos)"
        let services = (advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID]) ?? []
        let rssi = RSSI.intValue == 127 ? -127 : RSSI.intValue

        if let index = devices.firstIndex(where: { $0.id == peripheral.identifier }) {
            // Throttle UI updates: duplicates arrive many times per second.
            guard Date().timeIntervalSince(devices[index].lastUpdate) > 1 else { return }
            devices[index].rssi = rssi
            devices[index].lastUpdate = Date()
            if advertisedName != nil { devices[index].name = name }
            if !services.isEmpty { devices[index].serviceUUIDs = services }
        } else {
            devices.append(DiscoveredDevice(id: peripheral.identifier, peripheral: peripheral,
                                            name: name, rssi: rssi, serviceUUIDs: services,
                                            lastUpdate: Date()))
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        stopScan()
        link = .connected(peripheral.name ?? "PowerBox")
        addInfo("Verbonden, services ophalen")
        peripheral.discoverServices(nil)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral,
                        error: Error?) {
        link = .disconnected("Verbinden mislukt: \(error?.localizedDescription ?? "onbekend")")
        addInfo("Verbinden mislukt: \(error?.localizedDescription ?? "onbekend")")
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral,
                        error: Error?) {
        addInfo("Verbinding verbroken \(error?.localizedDescription ?? "")")
        if userDisconnected {
            link = .idle
            self.peripheral = nil
            return
        }
        link = .disconnected("Verbinding weg, opnieuw verbinden...")
        if autoReconnect {
            central.connect(peripheral, options: nil)
        }
    }
}

// MARK: - CBPeripheralDelegate

extension BLEManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error {
            addInfo("Services fout: \(error.localizedDescription)")
            return
        }
        for service in peripheral.services ?? [] {
            addInfo("Service \(service.uuid.uuidString)")
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        if let error {
            addInfo("Characteristics fout: \(error.localizedDescription)")
            return
        }
        for c in service.characteristics ?? [] {
            let uuid = c.uuid.uuidString
            let info = CharacteristicInfo(uuid: uuid, serviceUUID: service.uuid.uuidString,
                                          properties: c.properties, isNotifying: c.isNotifying,
                                          lastValue: c.value)
            if let index = characteristics.firstIndex(where: { $0.uuid == uuid }) {
                characteristics[index] = info
            } else {
                characteristics.append(info)
            }
            addInfo("  char \(uuid) [\(info.propertyText)]")

            if c.properties.contains(.notify) || c.properties.contains(.indicate) {
                peripheral.setNotifyValue(true, for: c)
            }
            if c.properties.contains(.read) {
                peripheral.readValue(for: c) // e.g. firmware version, device info
            }
        }
        chooseWriteTarget()
    }

    private func chooseWriteTarget() {
        if let current = writeTarget, characteristics.contains(where: { $0.uuid == current && $0.canWrite }) {
            return
        }
        let writable = characteristics.filter(\.canWrite)
        for preferred in PowerBoxHints.preferredWrite {
            if let hit = writable.first(where: { $0.uuid.uppercased() == preferred }) {
                writeTarget = hit.uuid
                return
            }
        }
        writeTarget = writable.first?.uuid
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic,
                    error: Error?) {
        let uuid = characteristic.uuid.uuidString
        if let index = characteristics.firstIndex(where: { $0.uuid == uuid }) {
            characteristics[index].isNotifying = characteristic.isNotifying
        }
        if let error {
            addInfo("Notify \(uuid) fout: \(error.localizedDescription)")
        } else {
            addInfo("Luisteren op \(uuid)")
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        guard error == nil, let data = characteristic.value, !data.isEmpty else { return }
        handleIncoming(data, from: characteristic.uuid.uuidString)
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        if let error {
            addInfo("Schrijven mislukt: \(error.localizedDescription)")
        }
    }
}
