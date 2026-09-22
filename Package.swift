// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PickBeon",
    platforms: [.macOS(.v15)],
    products: [.executable(name: "PickBeon", targets: ["PickBeon"])],
    targets: [.executableTarget(name: "PickBeon", path: "PickBeon",
                                linkerSettings: [.linkedFramework("Carbon")])]
)
