// swift-tools-version: 6.0
import PackageDescription

// 최소 macOS 26 (Tahoe). Apple TranslationSession 의 독립 생성 API
// (`init(installedSource:target:)`) 가 macOS 26.0+ 전용이라, 그 이전에서는
// SwiftUI `View.translationTask` 안에서만 세션을 얻을 수 있다.
// 앱의 차별화 축(온디바이스 번역)이 이 경계에 걸려 있으므로 26 으로 올렸다.
// [참고] SwiftPM 의 `Platform` 열거형이 .v25 까지만 제공되어 문자열 초기자를 쓴다.
let package = Package(
    name: "PickBeon",
    platforms: [.macOS("26.0")],
    products: [.executable(name: "PickBeon", targets: ["PickBeon"])],
    targets: [.executableTarget(name: "PickBeon", path: "PickBeon",
                                linkerSettings: [.linkedFramework("Carbon")])]
)
