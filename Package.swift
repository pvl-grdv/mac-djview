// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "MacDjView",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    dependencies: [
        .package(url: "https://github.com/mtgto/Unrar.swift.git", exact: "0.5.4")
    ],
    targets: [
        .executableTarget(
            name: "MacDjView",
            dependencies: [
                .product(name: "Unrar", package: "Unrar.swift")
            ],
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
