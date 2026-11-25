import SwiftUI
import UniformTypeIdentifiers

struct DeviceView: View {
    @EnvironmentObject var ble: BLEManager

    var body: some View {
        TabView {
            NavigationStack { DashboardView().toolbar { toolbar } }
                .tabItem { Label("Dashboard", systemImage: "gauge.with.dots.needle.67percent") }
            NavigationStack { ConsoleView().toolbar { toolbar } }
                .tabItem { Label("Console", systemImage: "terminal") }
            NavigationStack { ServicesView().toolbar { toolbar } }
                .tabItem { Label("Services", systemImage: "list.bullet.rectangle") }
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Menu {
                Button("Verbreken") { ble.disconnect() }
                Button("Andere box kiezen", role: .destructive) {
                    ble.forgetDevice()
                    ble.startScan()
                }
            } label: {
                LinkBadge(link: ble.link)
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            ShareLink(item: LogExport(make: { [ble] in ble.exportText() }),
                      preview: SharePreview("PowerBox log")) {
                Image(systemName: "square.and.arrow.up")
            }
        }
    }
}

/// Builds the log text only when the user actually shares it.
struct LogExport: Transferable {
    let make: () -> String

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .plainText) { export in
            Data(export.make().utf8)
        }
        .suggestedFileName("powerbox-log.txt")
    }
}

struct LinkBadge: View {
    let link: BLEManager.Link

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 9, height: 9)
            Text(text).font(.caption).lineLimit(1)
        }
    }

    private var color: Color {
        switch link {
        case .connected: return .green
        case .connecting: return .yellow
        case .disconnected: return .red
        case .idle: return .gray
        }
    }

    private var text: String {
        switch link {
        case .connected(let name): return name
        case .connecting(let name): return "Verbinden met \(name)..."
        case .disconnected(let reason): return reason
        case .idle: return "Niet verbonden"
        }
    }
}

// MARK: - Dashboard

struct DashboardView: View {
    @EnvironmentObject var ble: BLEManager

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 12)]

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            ScrollView {
                VStack(spacing: 16) {
                    if isStale(now: context.date) {
                        staleBanner
                    }
                    if hasHeadline {
                        headline
                    }
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(ble.fieldOrder, id: \.self) { key in
                            if let field = ble.fields[key] {
                                FieldTile(field: field)
                            }
                        }
                    }
                    if ble.fieldOrder.isEmpty {
                        emptyState
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Twizy")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func isStale(now: Date) -> Bool {
        guard let last = ble.lastDataAt else { return true }
        return now.timeIntervalSince(last) > 3
    }

    private var speed: Double? { FieldCatalog.value(ble.fields, ["spd", "speed", "kmh", "vel"]) }
    private var soc: Double? { FieldCatalog.value(ble.fields, ["soc", "bat", "battery"]) }
    private var power: Double? {
        if let p = FieldCatalog.value(ble.fields, ["p", "pwr", "power", "w"]) { return p }
        if let v = FieldCatalog.value(ble.fields, ["v", "volt", "voltage"]),
           let i = FieldCatalog.value(ble.fields, ["i", "amp", "current"]) {
            return v * i
        }
        return nil
    }

    private var hasHeadline: Bool { speed != nil || soc != nil || power != nil }

    private var headline: some View {
        HStack(spacing: 20) {
            if let soc {
                Gauge(value: min(max(soc, 0), 100), in: 0...100) {
                    Text("Accu")
                } currentValueLabel: {
                    Text("\(Int(soc.rounded()))%")
                }
                .gaugeStyle(.accessoryCircular)
                .tint(soc > 50 ? .green : soc > 20 ? .yellow : .red)
                .scaleEffect(1.4)
                .frame(width: 90, height: 90)
            }
            VStack {
                Text(speed.map { "\(Int($0.rounded()))" } ?? "--")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text("km/h").foregroundStyle(.secondary)
            }
            if let power {
                VStack {
                    Text(String(format: "%.1f", power / 1000))
                        .font(.title.bold())
                        .monospacedDigit()
                        .foregroundStyle(power < 0 ? .green : .orange)
                    Text("kW").foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    private var staleBanner: some View {
        Label(ble.lastDataAt == nil ? "Nog geen data ontvangen" : "Geen nieuwe data",
              systemImage: "antenna.radiowaves.left.and.right.slash")
            .font(.subheadline)
            .foregroundStyle(.orange)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Nog geen getallen herkend")
                .font(.headline)
            Text("Het dashboard vult zich zodra de box berichten stuurt met getallen (JSON, key=waarde of komma-gescheiden). Stuurt de box alleen iets na een commando? Probeer dan iets in de Console, bijvoorbeeld de commando's die de officiële app gebruikt.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if !ble.lastMessage.isEmpty {
                Text("Laatste bericht:")
                    .font(.caption)
                    .padding(.top, 4)
                Text(ble.lastMessage)
                    .font(.caption.monospaced())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct FieldTile: View {
    let field: TelemetryField

    var body: some View {
        let info = FieldCatalog.info(for: field.key)
        VStack(alignment: .leading, spacing: 4) {
            Text(info.label)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(format(field.value))
                    .font(.title2.bold())
                    .monospacedDigit()
                if let unit = field.unit ?? info.unit {
                    Text(unit).font(.caption).foregroundStyle(.secondary)
                }
            }
            if info.label != field.key {
                Text(field.key).font(.caption2.monospaced()).foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }

    private func format(_ value: Double) -> String {
        if value == value.rounded() && abs(value) < 1e9 {
            return String(Int(value))
        }
        return String(format: abs(value) < 10 ? "%.2f" : "%.1f", value)
    }
}
