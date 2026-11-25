import CoreBluetooth
import SwiftUI

struct ScanView: View {
    @EnvironmentObject var ble: BLEManager

    var body: some View {
        List {
            if let problem = bluetoothProblem {
                Section {
                    Label(problem, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
            }

            Section {
                ForEach(ble.visibleDevices) { device in
                    Button {
                        ble.connect(device)
                    } label: {
                        DeviceRow(device: device)
                    }
                }
                if ble.visibleDevices.isEmpty && ble.isScanning {
                    HStack {
                        ProgressView()
                        Text("Zoeken... zet de auto aan")
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Bluetooth-apparaten in de buurt")
            } footer: {
                Text("Waarschijnlijke PowerBox-kandidaten staan bovenaan met een bliksem. Weet je niet welke het is? Zet de auto uit en weer aan en kijk welk apparaat verschijnt.")
            }

            Section {
                Toggle("Ook naamloze apparaten tonen", isOn: $ble.showAllDevices)
            }
        }
        .navigationTitle("PowerBox zoeken")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if ble.isScanning {
                    Button("Stop") { ble.stopScan() }
                } else {
                    Button("Scan") { ble.startScan() }
                }
            }
        }
        .onAppear {
            if !ble.isScanning { ble.startScan() }
        }
    }

    private var bluetoothProblem: String? {
        switch ble.bluetoothState {
        case .poweredOff: return "Bluetooth staat uit."
        case .unauthorized: return "Geen toestemming voor Bluetooth. Zet het aan in Instellingen > Privacy > Bluetooth."
        case .unsupported: return "Dit apparaat ondersteunt geen Bluetooth LE (de simulator ook niet)."
        default: return nil
        }
    }
}

private struct DeviceRow: View {
    let device: DiscoveredDevice

    var body: some View {
        HStack {
            Image(systemName: device.isLikelyPowerBox ? "bolt.car.fill" : "dot.radiowaves.left.and.right")
                .foregroundStyle(device.isLikelyPowerBox ? .yellow : .secondary)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                if !device.serviceUUIDs.isEmpty {
                    Text(device.serviceUUIDs.map(\.uuidString).joined(separator: ", "))
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            Text("\(device.rssi) dBm")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }
}
