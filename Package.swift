// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Dittado",
    platforms: [.macOS(.v14)],
    targets: [
        // whisper.cpp pré-compilado (baixado por scripts/baixar-dependencias.sh)
        .binaryTarget(name: "whisper", path: "Vendor/build-apple/whisper.xcframework"),
        // llama.cpp pré-compilado (baixado por scripts/baixar-dependencias.sh)
        .binaryTarget(name: "llama", path: "Vendor/build-apple/llama.xcframework"),
        .target(name: "DittadoCore"),
        .target(name: "DittadoWhisper", dependencies: ["whisper", "DittadoCore"]),
        .target(name: "DittadoLLM", dependencies: ["llama", "DittadoCore"]),
        .executableTarget(
            name: "Dittado",
            dependencies: ["DittadoCore", "DittadoWhisper", "DittadoLLM"],
            linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]
        ),
        .executableTarget(name: "DittadoTeste", dependencies: ["DittadoCore", "DittadoWhisper", "DittadoLLM"]),
    ],
    swiftLanguageModes: [.v5]
)
