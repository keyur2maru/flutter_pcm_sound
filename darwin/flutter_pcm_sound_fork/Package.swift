// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "flutter_pcm_sound_fork",
    platforms: [
        .iOS("13.0"),
        .macOS("10.15")
    ],
    products: [
        .library(name: "flutter-pcm-sound-fork", targets: ["flutter_pcm_sound_fork"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "flutter_pcm_sound_fork",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ],
            cSettings: [
                .headerSearchPath("include/flutter_pcm_sound_fork")
            ],
            linkerSettings: [
                .linkedFramework("CoreAudio")
            ]
        )
    ]
)
