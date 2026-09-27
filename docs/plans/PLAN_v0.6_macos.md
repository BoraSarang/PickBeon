# PLAN_v0.6_macos.md — A1 GIF 녹화 MVP + v0.7 백로그
> 생성일: 2026-09-24 | 기반: 사용자 확정 (⌥⌘G, GIF만, 설정 fps/최대시간)
> 이슈: pickbeon-pf4 | 리서치: docs/RESEARCH_capture_apps.md | 이전: v0.5.1
> v0.7 백로그(2026-09-24 구현): A2 텍스트 바로 복사(⌥⌘C) · B3 창 캡쳐(⌥⌘W) · B2 블러/모자이크 · C1 GIF 프레임 번역 — 빌드 ERROR 0, 사용자 일괄 검증 대기
> 핫키 signature: 1=⌘⇧X, 2=⌘⌥Z, 3=⌥⌘G(keyCode 5·G 수정), 4=⌥⌘C, 5=⌥⌘W

## 0. 합의 사항
- 단축키 **⌥⌘G** (Option+Command+G)
- 산출물은 **GIF만** (MP4/트림/오디스 없음)
- 설정: **fps**(기본 10), **최대 시간**(10초/30초/무제한, 기본 10초), 종료 시 자동 복사
- 흐름: ⌥⌘G → 영역 드래그 → 미리보기+'녹화' 버튼 → HUD(경과시간) 중지/자동중지 → GIF 클립보드+저장+결과카드(첫 프레임)
- 로드맵: A1 → A2 → B3+B2 → C1 (본 계획은 A1만)

## 1. 범위
### T-01 설정 (AppSettings)
- `gifFps` (기본 10), `gifMaxSeconds` (10|30|0=무제한, 기본 10), `gifAutoCopy` (기본 true)
- SettingsView 캡쳐 탭: fps/최대시간/자동복사 카드, 단축키 탭 ⌥⌘G 표기

### T-02 단축키 (GlobalHotKeyService)
- signature 3, keyCode 3 (G), modifiers 2304 (cmd+opt) → `onGifCapture`
- 녹화 중 재누름 = 중지 토글

### T-03 GifRecorder (신규 Capture/GifRecorder.swift)
- SCStream(디스플레이 전체) → VTCreateCGImageFromCVPixelBuffer → 영역 크롭 → 최대변 800px 다운스케일
- fps 스로틀, ImageIO CGImageDestination 증분 GIF 인코딩 (loop 0, delay 1/fps)
- 최대시간 자동 중지, 안전 프레임 상한 10000
- HUD NSPanel: ● REC 초 + 중지 버튼, Esc 중지

### T-04 AppCoordinator 라우팅
- `startGifCapture()` / `didSelectArea` gifMode → 프리즈+녹화 툴바 / `confirmGifRecord` → `startGifRecording` / `stopGifRecording`
- 완료: (autoCopy 시) GIF 데이터+파일URL 클립보드, `~/Desktop/PickBeon/Pick ….gif` 저장, 결과카드 메시지
- 에러: E-MAC-GIF-0001/0002/0003 결과카드

### T-05 메뉴·문서
- MenuPopupView Pick 탭: GIF 녹화 행 (⌥⌘G)
- error_message_ko.json GIF 코드 3건, CHANGELOG/TODO/DESIGN 힌트바 갱신

## 2. 비범위
- MP4, 트림 편집, 음성, 커서 클릭 강조, GIF 편집기, 히스토리 GIF 항목 타입

## 3. DoD
- `./build_and_run.sh debug macos` ERROR 0 + 앱 재실행
- ⌥⌘G → 드래그 → HUD → 중지 → ⌘V GIF 붙여넣기 + Desktop 저장
- 최대시간 10초 자동중지, 설정 변경 반영, 녹화 중 재단축키로 중지
- CHANGELOG + TODO + session 로그 + bd close (pickbeon-pf4)
