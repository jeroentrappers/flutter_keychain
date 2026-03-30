// swift-tools-version: 5.9
// Flutter Swift Package Manager support.
// See: https://docs.flutter.dev/packages-and-plugins/swift-package-manager/for-plugin-authors

import PackageDescription

let package = Package(
    name: "flutter_keychain",
    platforms: [
        .iOS(.v12),
    ],
    products: [
        .library(
            name: "flutter-keychain",
            targets: ["flutter_keychain"]
        ),
    ],
    targets: [
        .target(
            name: "flutter_keychain",
            dependencies: [],
            path: "Sources/flutter_keychain",
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("include"),
            ]
        ),
    ]
)
