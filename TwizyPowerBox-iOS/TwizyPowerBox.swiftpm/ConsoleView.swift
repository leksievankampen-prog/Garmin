import SwiftUI

struct ConsoleView: View {
    @EnvironmentObject var ble: BLEManager

    @State private var input = ""
    @State private var hexMode = false
    @State private var ending: LineEnding = .crlf
    @State private var showHex = false
    @State private var editingCommands = false
    @State private var confirmedRisk = false
    @State private var askRisk = false
    @State private var pending: (() -> Void)?

    @AppStorage("quickCommands") private var storedCommands: Data = Data()

    private var quickCommands: [QuickCommand] {
        (try? JSONDecoder().decode([QuickCommand].self, from: storedCommands)) ?? []
    }

    var body: some View {
        VStack(spacing: 0) {
            logList
            Divider()
            if !quickCommands.isEmpty {
                quickBar
            }
            composer
        }
        .navigationTitle("Console")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $editingCommands) {
            QuickCommandEditor(storedCommands: $storedCommands)
        }
        .alert("Commando naar de auto sturen?", isPresented: $askRisk) {
            Button("Annuleren", role: .cancel) { pending = nil }
            Button("Versturen") {
                confirmedRisk = true
                pending?()
                pending = nil
            }
        } message: {
            Text("Onbekende commando's kunnen instellingen van de PowerBox wijzigen. Test alleen met de auto stilstaand, handrem erop.")
        }
    }

    private var logList: some View {
        ScrollViewReader { proxy in
            List(ble.log) { entry in
                LogRow(entry: entry, showHex: showHex)
                    .id(entry.id)
                    .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
            }
            .listStyle(.plain)
            .font(.caption.monospaced())
            .onChange(of: ble.log.count) { _ in
                if let last = ble.log.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .principal) {
                    Picker("Weergave", selection: $showHex) {
                        Text("Tekst").tag(false)
                        Text("Hex").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 140)
                }
            }
        }
    }

    private var quickBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(quickCommands) { command in
                    Button(command.title) {
                        guarded { ble.send(command) }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    private var composer: some View {
        VStack(spacing: 8) {
            HStack {
                Picker("Naar", selection: $ble.writeTarget) {
                    ForEach(ble.writableCharacteristics) { c in
                        Text(c.uuid).tag(Optional(c.uuid))
                    }
                }
                .font(.caption)
                Spacer()
                Toggle("Hex", isOn: $hexMode)
                    .toggleStyle(.button)
                if !hexMode {
                    Picker("Einde", selection: $ending) {
                        ForEach(LineEnding.allCases) { Text($0.rawValue).tag($0) }
                    }
                }
            }
            HStack {
                TextField(hexMode ? "bijv. A0 01 FF" : "commando", text: $input)
                    .textFieldStyle(.roundedBorder)
                    .font(.body.monospaced())
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit(sendInput)
                Button(action: sendInput) {
                    Image(systemName: "paperplane.fill")
                }
                .disabled(input.isEmpty || ble.writeTarget == nil)
                Menu {
                    Button("Snelknoppen bewerken") { editingCommands = true }
                    Button("Log wissen", role: .destructive) { ble.clearLog() }
                    Button("Dashboard wissen", role: .destructive) { ble.clearFields() }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .padding()
    }

    private func sendInput() {
        let text = input
        let hex = hexMode
        let end = ending
        guarded {
            let ok = hex ? ble.send(hex: text) : ble.send(text: text, ending: end)
            if ok { input = "" }
        }
    }

    /// Asks once per session before anything is written to the box.
    private func guarded(_ action: @escaping () -> Void) {
        if confirmedRisk {
            action()
        } else {
            pending = action
            askRisk = true
        }
    }
}

private struct LogRow: View {
    let entry: LogEntry
    let showHex: Bool

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Text(Self.formatter.string(from: entry.time))
                .foregroundStyle(.tertiary)
            Text(arrow)
                .foregroundStyle(color)
            Text(entry.direction == .info || !showHex ? entry.text : entry.hex)
                .foregroundStyle(entry.direction == .info ? .secondary : .primary)
                .textSelection(.enabled)
        }
    }

    private var arrow: String {
        switch entry.direction {
        case .incoming: return "←"
        case .outgoing: return "→"
        case .info: return "·"
        }
    }

    private var color: Color {
        switch entry.direction {
        case .incoming: return .green
        case .outgoing: return .yellow
        case .info: return .secondary
        }
    }
}

struct QuickCommandEditor: View {
    @Binding var storedCommands: Data
    @Environment(\.dismiss) private var dismiss
    @State private var commands: [QuickCommand] = []

    var body: some View {
        NavigationStack {
            List {
                ForEach($commands) { $command in
                    VStack(alignment: .leading) {
                        TextField("Naam (bijv. Stand 2)", text: $command.title)
                            .font(.headline)
                        TextField(command.isHex ? "Hex-bytes" : "Commando", text: $command.payload)
                            .font(.body.monospaced())
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        HStack {
                            Toggle("Hex", isOn: $command.isHex)
                                .toggleStyle(.button)
                            if !command.isHex {
                                Picker("Einde", selection: $command.ending) {
                                    ForEach(LineEnding.allCases) { Text($0.rawValue).tag($0) }
                                }
                            }
                        }
                    }
                }
                .onDelete { commands.remove(atOffsets: $0) }
                .onMove { commands.move(fromOffsets: $0, toOffset: $1) }

                Button {
                    commands.append(QuickCommand(title: "Nieuw", payload: ""))
                } label: {
                    Label("Snelknop toevoegen", systemImage: "plus")
                }
            }
            .navigationTitle("Snelknoppen")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuleren") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Bewaar") {
                        let cleaned = commands.filter { !$0.title.isEmpty && !$0.payload.isEmpty }
                        storedCommands = (try? JSONEncoder().encode(cleaned)) ?? Data()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
            }
            .onAppear {
                commands = (try? JSONDecoder().decode([QuickCommand].self, from: storedCommands)) ?? []
            }
        }
    }
}
