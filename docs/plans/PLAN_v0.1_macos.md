# PLAN_v0.1_macos.md
> 생성일: 2026-09-20 | 플랫폼: macos | 최소버전: macOS 26+ (당시 15+, 2026-09-27 상향)

## 1. 목표
화면에서 텍스트를 Pick해서 번역 — 영역 캡쳐 OCR→번역 + 텍스트 선택 번역 + 클립보드 히스토리.

## 2. 범위
- 플랫폼: macos 단일
- 기술 스택: SwiftUI 기본 + AppKit 허용 + ScreenCaptureKit + Vision(VNRecognizeTextRequest) + TranslationSession + SwiftData + AX SelectedText. 선정 이유: 온디바이스·오프라인·API키 없음
- design_profile: native (macos-app-design + apple-design + ios-the-final-5-percent)
- 구조: PickBeon/{Capture,OCR,Translation,History,Settings,Common}

## 3. 문서 위치
- PLAN: 본 문서
- TODO: docs/TODO.md T-01~T-07
- DESIGN: docs/DESIGN.md
- API: 없음 (Apple만, BYOK 자리 예약)

## 4. 성능 예산
- budgets.json 참조. Cold Start ≤1.5s, 메모리 ≤300MB, 60fps
- smoke ≤10s, unit ≤60s

## 5. 에러 코드
- E-MAC-CAPTURE-0001~, E-MAC-OCR-0001~, E-MAC-TRANS-0001~, E-MAC-STORE-0001~, E-MAC-PERM-0001~
- 사용자 메시지 error_message_ko.json 분리

## 6. 빌드 & 검증 계획
- xcodebuild → ~/Applications/PickBeon.app
- ./build_and_run.sh debug macos (생성 예정, xcodebuild 래핑)
- DebugPanel Cmd+Shift+D 플로팅, ERROR 0, PERF/CACHE 확인
- 단축키: Cmd+Shift+X 캡쳐, Cmd+Option+Z 선택번역, Cmd+Shift+C 히스토리

## 7. 예외 규칙
- 없음. [HARD]는 사용자 승인 필요
