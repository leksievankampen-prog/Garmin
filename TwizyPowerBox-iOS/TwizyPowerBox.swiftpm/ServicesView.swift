import SwiftUI

/// Every service and characteristic the box exposes. This is the map we
/// need to figure out its protocol.
struct ServicesView: View {
    @EnvironmentObject var ble: BLEManager

    private var grouped: [(String, [CharacteristicInfo])] {
        Dictionary(grouping: ble.characteristics, by: \.serviceUUID)
            .map { ($0.key, $0.value) }
            .sorted { $0.0 < $1.0 }
    }

    var body: some View {
        List {
            if ble.characteristics.isEmpty {
                Text("Nog geen services gevonden.")
                    .foregroundStyle(.secondary)
            }
            ForEach(grouped, id: \.0) { service, chars in
                Section("Service \(service)") {
                    ForEach(chars) { c in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(c.uuid).font(.callout.monospaced())
                                Spacer()
                                if c.isNotifying {
                                    Image(systemName: "ear").foregroundStyle(.green)
                                }
                                if c.uuid == ble.writeTarget {
                                    Image(systemName: "paperplane").foregroundStyle(.yellow)
                                }
                            }
                            Text(c.propertyText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let value = c.lastValue {
                                Text(LogEntry.printable(value))
                                    .font(.caption.monospaced())
                                    .lineLimit(3)
                                    .textSelection(.enabled)
                            }
                        }
                    }
                }
            }
            Section {
                Toggle("Automatisch opnieuw verbinden", isOn: $ble.autoReconnect)
            } footer: {
                Text("Oor = app luistert mee. Papiervliegtuig = hier gaan commando's naartoe (te wijzigen in de Console). Deel de log met de knop rechtsboven.")
            }
        }
        .navigationTitle("Services")
        .navigationBarTitleDisplayMode(.inline)
    }
}
