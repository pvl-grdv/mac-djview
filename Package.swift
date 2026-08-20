// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "MacDjView",
    platforms: [.macOS("26.0")],
    targets: [
        .executableTarget(
            name: "MacDjView",
            path: "Sources/MacDjView",
            exclude: [
                "Assets.xcassets",
                "PrivacyInfo.xcprivacy"
            ],
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-dead_strip"])
            ]
        ),
        .testTarget(
            name: "MacDjViewTests",
            dependencies: ["MacDjView"],
            path: "Tests/MacDjViewTests"
        )
    ]
)
