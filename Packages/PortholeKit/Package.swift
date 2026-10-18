// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PortholeKit",
    platforms: [.macOS("26.0"), .iOS("26.0")],
    products: [
        .library(name: "PortholeProtocol", targets: ["PortholeProtocol"]),
        .library(name: "PortholeSession", targets: ["PortholeSession"]),
        // Test-only Mac stand-in for Protocol/dart/test/interop_test.dart.
        .executable(name: "porthole-interop-host", targets: ["PortholeInteropHost"]),
    ],
    dependencies: [
        .package(url: "https://github.com/stasel/WebRTC.git", exact: "155.0.0"),
        // Wire format v3. Generated code in Sources/PortholeProtocol/Generated must come from this same version.
        .package(url: "https://github.com/apple/swift-protobuf.git", exact: "1.38.1"),
        .package(url: "https://github.com/x-sheep/swift-property-based.git", exact: "2.0.1"),
    ],
    targets: [
        .target(
            name: "PortholeProtocol",
            dependencies: [.product(name: "SwiftProtobuf", package: "swift-protobuf")],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .target(
            name: "PortholeSession",
            dependencies: [
                "PortholeProtocol",
                .product(name: "WebRTC", package: "WebRTC"),
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "PortholeInteropHost",
            dependencies: ["PortholeProtocol", "PortholeSession"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "PortholeKitTests",
            dependencies: [
                "PortholeProtocol",
                "PortholeSession",
                .product(name: "PropertyBased", package: "swift-property-based"),
                .product(name: "SwiftProtobuf", package: "swift-protobuf"),
            ]
        ),
    ]
)
