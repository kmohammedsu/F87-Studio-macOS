// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "F87Studio",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "F87Studio", targets: ["F87Studio"])
    ],
    targets: [
        .target(
            name: "CHID",
            path: "Sources/CHID",
            publicHeadersPath: "include",
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("CoreFoundation")
            ]
        ),
        .executableTarget(
            name: "F87Studio",
            dependencies: ["CHID"],
            path: "Sources/F87Studio"
        ),
        .testTarget(
            name: "F87StudioTests",
            dependencies: ["F87Studio"],
            path: "Tests/F87StudioTests"
        )
    ],
    swiftLanguageModes: [.v5]
)
