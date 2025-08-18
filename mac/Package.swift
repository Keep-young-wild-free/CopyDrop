// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CopyDrop",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "CopyDrop", targets: ["CopyDrop"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-crypto.git", from: "2.0.0")
    ],
    targets: [
        .executableTarget(
            name: "CopyDrop",
            dependencies: [
                .product(name: "Crypto", package: "swift-crypto")
            ],
            swiftSettings: [
                .define("DEBUG", .when(configuration: .debug))
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("Foundation"),
                .linkedFramework("CoreBluetooth"),
                .linkedFramework("Network"),
                .linkedFramework("UserNotifications")
            ]
        )
    ]
)