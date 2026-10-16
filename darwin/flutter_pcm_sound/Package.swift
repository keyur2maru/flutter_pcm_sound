// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "flutter_pcm_sound",
    platforms: [
        .iOS("13.0"),
        .macOS("10.15")
    ],
    products: [
        .library(name: "flutter-pcm-sound", targets: ["flutter_pcm_sound"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "flutter_pcm_sound",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ],
            cSettings: [
                .headerSearchPath("include/flutter_pcm_sound")
            ],
            linkerSettings: [
                .linkedFramework("CoreAudio")
            ]
        )
    ]
)
