import SwiftUI

@main
struct TwizyPowerBoxApp: App {
    @StateObject private var ble = BLEManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(ble)
                .preferredColorScheme(.dark)
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var ble: BLEManager

    var body: some View {
        switch ble.link {
        case .idle:
            NavigationStack { ScanView() }
        default:
            DeviceView()
        }
    }
}
