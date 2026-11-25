// swift-tools-version: 5.9

// WARNING:
// This is a Swift Playgrounds / Xcode app package. Open the
// TwizyPowerBox.swiftpm folder in Xcode (Mac) or Swift Playgrounds (iPad).

import PackageDescription
import AppleProductTypes

let package = Package(
    name: "TwizyPowerBox",
    platforms: [
        .iOS("17.0")
    ],
    products: [
        .iOSApplication(
            name: "Twizy PowerBox",
            targets: ["AppModule"],
            bundleIdentifier: "com.example.twizypowerbox",
            teamIdentifier: "",
            displayVersion: "1.0",
            bundleVersion: "1",
            appIcon: .placeholder(icon: .car),
            accentColor: .presetColor(.yellow),
            supportedDeviceFamilies: [
                .pad,
                .phone
            ],
            supportedInterfaceOrientations: [
                .portrait,
                .landscapeRight,
                .landscapeLeft,
                .portraitUpsideDown(.when(deviceFamilies: [.pad]))
            ],
            capabilities: [
                .bluetoothAlways(purposeString: "Bluetooth is nodig om verbinding te maken met de PowerBox in je Twizy.")
            ]
        )
    ],
    targets: [
        .executableTarget(
            name: "AppModule",
            path: "."
        )
    ]
)
