# AGENTS.local.md — 프로젝트별 확장 규칙
> 위치: /Users/lee/Documents/Apps/PickBeon/AGENTS.local.md

## 1. 프로젝트 정보
- **프로젝트명**: PickBeon (픽번)
- **플랫폼**: macos
- **기술 스택**: SwiftUI + AppKit + ScreenCaptureKit + Vision + TranslationSession(macOS 15+) + SwiftData
- **선정 이유**: screenTranslate 정답 스택, 온디바이스·오프라인·API키 없음
- **design_profile**: custom — 확정 (2026-09-22 전환. 토큰은 docs/DESIGN.md, 코드는 Design/Theme.swift)
- **작업 모드 기본값**: 정식 (사용자 부재 시 권장 방향으로 진행)

## 2. 번들ID / 앱 ID
- bundleIdentifier: `com.borasarang.PickBeon` (변경 시 파괴적 변경 가드 적용)

## 3. 성능 예산 Override
- 없음. budgets.json 기본값 사용 (Cold Start ≤1.5s, 메모리 ≤300MB, 60fps)

## 4. 프로젝트 특화 예외 규칙
- 최소 **macOS 26+** (2026-09-27 상향). `TranslationSession` 독립 생성 API
  (`init(installedSource:target:)`) 가 macOS 26.0+ 전용이라, 그 이전에서는 SwiftUI
  `View.translationTask` 안에서만 세션을 얻을 수 있어 차별화 축(온디바이스 번역)이 성립하지 않는다.
  SwiftPM `Platform` 열거형이 `.v25` 까지만 제공하므로 `Package.swift` 는 `.macOS("26.0")` 문자열 초기자를 쓴다.
- 번역 폴백 없음 (min 26 이므로 게이트 자체가 불필요)
- 번역 엔진 MVP는 Apple Translation만. BYOK 자리만 예약, P1 이후 재검토
- 클립보드 저장 기본 20개, 옵션 20/50/100/200/제한없음. 텍스트·이미지·암호화 토글
- 캡쳐 엔진 ScreenCaptureKit 필수. CGWindowListCreateImage 금지
- 소스 수정 후에는 `./build_and_run.sh debug macos`로 빌드 + 앱 재실행 필수 (`--no-open` 금지)

## 5. 디자인 토큰 (custom)
- docs/DESIGN.md에 토큰(색/라운드/간격/타이포/모션) 정의, 코드는 Design/Theme.swift 단일 소스
- 시스템 UI(설정·권한·DebugPanel)는 native 규칙 준수
- 콘셉트 기반: PickBeon-Ui-Concept-v2.html (다크 톤 + 보라 액센트 #7C7CF4 + 히어로 그라데이션)
