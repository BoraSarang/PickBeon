# CHANGELOG
## v0.7.1-macos 중간 점검 P0 수정 (2026-09-27)
> 중간 감사에서 발견된 "동작하지 않는" 경로 일괄 수정. 기능 추가가 아니라 신뢰성 복구.

- [macos] **번역**: macOS 15~25에서 원문을 "번역"으로 반환하던 no-op 제거 → `E-MAC-TRANS-0002` 명시 실패.
  SDK 감사 결과 `TranslationSession` 생성(`installedSource:target:`)은 macOS 26.0+ 전용이며,
  macOS 15 에서는 SwiftUI `View.translationTask`(15.0+) 안에서만 세션을 얻을 수 있다.
  게이트는 유지하되 조용한 성공을 금지. `isStandaloneSessionSupported` 노출으로 UI 게이팅 가능.
- [macos] **클립보드**: `writeObjects` 와 `setData/setString` 혼용으로 데이터가 소실되던 결함 2곳 수정
  (에디터 복사 시 번역문 증발, GIF 복사 시 GIF 바이트 증발). `PasteboardService` 신설로 22곳 통합.
  복사 결과 토스트("복사됨 · 주석 포함") 추가.
- [macos] **블러/모자이크**: AppKit 하단원점 rect 를 CGImage(top-left)에 그대로 넣던 오류로
  **세로 대칭 영역을 가리던** 결함 수정. `Redactor` 로 좌표계 통합, preview = 실제 결과 보장.
  blur 가장자리 검은 테두리 제거(pad 샘플), drag 중에는 영역만 표시.
- [macos] **설정**: ScrollView 미적용으로 하단 항목이 잘려 접근 불가하던 문제 수정
  (캡쳐 탭 2개, 단축키 탭 4~5개). 창 430 → 520pt.
- [macos] **메뉴 팝오버**: 240pt 안에 7개 항목이 들어가지 않아 4개가 폴드 아래에 있던 문제 수정
  (463pt + 행 압축). `영역 Pick` 을 실제 primary 스타일로 분리.
- [macos] **GIF**: 녹화 중 Esc 가 오버레이만 닫고 녹화를 계속하던 결함 수정, 그리고
  오버레이가 마우스를 전부 삼켜 다른 앱을 조작할 수 없던 문제 수정(녹화 중 클릭 통과).
- [macos] **업데이트**: 비공개 저장소라 항상 404 였던 문제. 원인 명확화 + 저장소 지정 UI 추가.
- [macos] `설정 초기화`에 확인 다이얼로그 추가(파괴적 변경 가드).
- [macos] 메뉴 설정 탭의 "번역 오버레이" 토글이 실제로는 OCR 박스를 조작하던 라벨 오류 수정.
- [macos] 아무 동작도 하지 않는 비활성 "암호화" 토글을 상태 배지로 교체.
- [macos] 히스토리 창을 `close()` 로 종료(재오픈 시 상태 초기화), `orderOut` 누수 해결.
- [macos] 말투 변환 "습니다"→"어"(있습니다 → "있이어") 규칙 오류 수정.
- [macos] 컴파일 경고 2건 제거, `error_message_ko.json` 누락 코드 보강, RACE 제거(ToneShaper 분리).
- [docs] RESEARCH 격차 재평가(2026-09-27 CleanShot X·TextSniper 공식 확인), TODO ↔ bd 정합화.

## v0.7.0-macos A2/B3/B2/C1 백로그 (2026-09-24)
- [macos] A2 텍스트 바로 복사 ⌥⌘C: 영역 드래그 → OCR → 클립보드 즉시 (TextSniper류, 번역 스킵, 결과카드)
- [macos] B3 윈도우 캡쳐 ⌥⌘W: 창 hover 하이라이트 + 클릭 → SCContentFilter 독립 창 캡쳐 → 프리즈 툴바
- [macos] B2 블러/모자이크 주석: 툴바 도구 2종, 미리보기(재질/격자), 복사·핀 시 CoreImage CIGaussianBlur/CIPixellate 합성
- [macos] C1 GIF 프레임 번역: 종료 후 첫 프레임 OCR→번역, 결과카드 승격 + 히스토리 (설정 토글, 기본 on)
- [macos] GIF 핫키 keyCode 3(F)→5(G) 수정 — 의도한 ⌥⌘G 실제 등록
- [macos] 메뉴 Pick 탭: 텍스트 바로 복사·창 캡쳐 행, 설정 단축키/GIF 탭 표기 갱신, 빌드 ERROR 0
## v0.6.2-macos A1 GIF 녹화 UX (2026-09-24)
- [macos] 영역 선택 후 자동 녹화 제거 → 미리보기 프리즈 + '녹화' 툴바 버튼으로 시작 (Esc 취소)
- [macos] 녹화 중 경과 시간: HUD 초 표시 + 오버레이 REC pill에 `● REC 3.2s WxH` 동시 표시
- [macos] 종료 시 GIF 첫 프레임을 `latestImage`로 설정 — 결과카드 썸네일·에디터 이미지 노출
- [macos] NSLock async 분리(snapshotCounts), QuartzCore import, CGImage? unwrap — 빌드 ERROR 0
## v0.6.1-macos A1 GIF UI 수정 (2026-09-24)
- [macos] 녹화 전후 선택 영역 유지: mouseUp 시 오버레이 닫지 않고 REC 테두리(빨강 2pt)+코너+● REC pill 유지, 종료 시 일괄 닫힘
- [macos] HUD 잘림 수정: 패널 260×52 고정 + 선택 영역 바로 위 배치, fittingSize 왜곡 제거
- [macos] SCStream에서 앱 윈도우(오버레이/HUD/카드) 제외 — GIF에 UI 미포함
- [macos] 프레임 스로틀 PTS → wall-clock, queueDepth 8, frames 카운트 lock 직렬화 (이전 3프레임/9.7s 개선)
## v0.6.0-macos A1 GIF 녹화 MVP (2026-09-24)
- [macos] 단축키 ⌥⌘G 영역 GIF 녹화 (GifRecorder: SCStream → 영역 크롭 → ImageIO 증분 GIF, 최대변 800px, 프레임 상한 10000)
- [macos] 흐름: 영역 드래그 → mouseUp 즉시 녹화(툴바 생략) → HUD(●REC+중지, Esc) → 클립보드 복사 + `~/Desktop/PickBeon/Pick ….gif` + 결과카드
- [macos] 설정: GIF fps(기본 10), 최대시간(10/30/무제한, 기본 10초), 후 클립보드 복사 토글 + 단축키 탭 ⌥⌘G 표기
- [macos] 메뉴 Pick 탭 GIF 녹화 행, 오버레이 GIF 힌트(드래그→GIF 녹화 시작), 에러 E-MAC-GIF-0001/0002/0003
- [macos] 리서치 docs/RESEARCH_capture_apps.md + 계획 docs/plans/PLAN_v0.6_macos.md, 빌드 ERROR 0 (육안 E2E는 사용자 확인 후 close pickbeon-pf4)
## v0.5.1-macos UI/UX 재정리 + Blue 팔레트 (2026-09-22)
- [macos] P5 메뉴 팝오버 A안: 기록 탭 제거(전체검색 전담), [Pick|설정] 2탭, 340×240 + contentSize 360×260, ScrollView overflow 차단, 최신 번역 1줄+복사/에디터
- [macos] P6 전체검색: 행 탭=미리보기 pin(두 번째 탭=붙여넣기), Esc pin 해제, 힌트 갱신
- [macos] P7 Blue 팔레트: accent #2563EB/#60A5FA, hero blue 그라데이션, transPanel blue tint, FooterButton hover → rowHover(라이트모드 대비)
- [macos] 빌드: ERROR 0 (P5~P7). 육안 검증·후속 UI 개선은 사용자 써보기 이후
## v0.5.0-macos GifJot 차별화 리디자인 P1~P4 (2026-09-22)
- [macos] P1 메뉴 팝오버 → Pick Hub: 히어로 제거, [Pick|기록|설정] 탭, accent primary 영역 Pick, 최신 번역 스티커, 글래스 ultraThinMaterial + glassStroke, 업데이트 푸터
- [macos] P2 결과카드 → 헤더 없는 번역 스티커: 좌측 accent 바 + 원문/번역 패널 + 썸네일 드래그 + 번역보기/다시/핀
- [macos] P3 캡쳐 툴바: 번역 primary(accent) 좌측 재배치 + Same area pill(치수) + 힌트바 ⏎번역/⌥즉시/R/Esc, toolbar 420pt
- [macos] P4 전체 검색 팔레트: 필터(전체/번역/클립보드) + 하단 ⌘1 복사·⌥↵ 붙여넣기 힌트 + 건수
- [macos] P0 토큰: glassStroke / rTab / kbdFill 추가, docs/DESIGN.md 화면별 레이아웃 갱신
- [macos] NSPopover open 시 material = popover 적용 (applyPopoverMaterial)
## v0.4.1-macos 업데이트 확인 + 히스토리 호버 미리보기 (2026-09-22)
- [macos] GitHub Releases 업데이트 확인 (가이드 채택): ReleaseChecker + UpdateCenter(주기/마지막확인 UserDefaults), 설정「업데이트」탭, 팝오버 하단 버전/주황 업데이트 배너, 전용 시트(릴리스 노트 inline 렌더 + 릴리스 페이지 열기)
- [macos] `.github/workflows/release.yml`: v*.*.* 태그 → 빌드·ad-hoc·ZIP·Release 발행, 태그↔Info.plist 버전 검증
- [macos] Info.plist 버전 0.1.0 → 0.4.1 (CHANGELOG 정합)
- [macos] 히스토리 호버 미리보기: 전체 검색 팔레트 우측 고정 패널(610px), 팝오버 기록 목록 행 호버 시 우측 피크 — HistoryRecordPreview 공용
## v0.4.1-macos M4/M5 육안 피드백 수리 (2026-09-22)
- [macos] 단축키 카드 미표시/팝오버 닫힘 시 소실: NSPanel hidesOnDeactivate=false (결과카드·기록·핀)
- [macos] ⌘⌥Z 선택번역 카드 → 드래그 직후 마우스 근처 배치 (화면 클램프), 캡쳐 카드는 우상단 유지
- [macos] 선택번역 Safari 폴백: AX 실패 시 시뮬 Cmd+C → 클립보드 읽기 → 원본 복원 (AXSelectionReader async)
- [macos] 에디터 우측 패널 세로 분배: 번역문 확장(ScrollView) + 하단 고정(다시번역/복사/기록/글자수)
- [macos] 오버레이 드래그 loupe(2.5x 돋보기) 제거 — 확대 느낌 해소
- [macos] 빌드: ERROR 0, ~/Applications 설치, M4/M5 육안 검증 통과 (pickbeon-qir close)
## v0.4.0-macos M4+M5 custom 디자인 시스템 + 시그니처 UX (2026-09-22)
- [macos] design_profile native → custom: Design/Theme.swift 토큰 단일 소스 + 공용 컴포넌트(SurfaceCard/KeyCap/HeroButton/PressableRow/FooterButton/IconToolButton/TransPanel), docs/DESIGN.md 토큰 표 정의
- [macos] 결과카드 460px 헤비 → 330px 컴팩트 시그니처: 원문1줄+번역+썸네일 드래그(Transferable PNG)+번역보기/다시/핀, 번역·메시지 3초 자동숨김(호버 연장, 에러 제외, 핀 상주), Esc 닫기
- [macos] 히스토리 영속화 버그 수정: 시작 시 DB 로드(E-MAC-STORE-0001), limit 초과분 SwiftData 행 삭제, 핀/삭제 동작화, 동일 내용 선두 중복 스킵
- [macos] 히스토리 Raycast식 패널: 커서 근처 nonactivating KeyableResultPanel, 검색 autofocus, Cmd+1~5/Enter/Esc/방향키 local monitor, hover 삭제, 핀 contextMenu, 썸네일/플래그 아이콘
- [macos] 오버레이: 커서 loupe(디스플레이 1회 캡쳐 기반 2.5x), Option+드래그 즉시 번역, 프리즈 후 코너 핸들 리사이즈(로컬 crop 재freeze, 재캡쳐 없음)
- [macos] 설정: 가짜 토글 제거 → afterCapture 실제 라우팅(card/editor/clipboard), 검색 필터 동작, encryptStore 비활성(미지원 표시), 단축키 표기 갱신
- [macos] 단축키 ⌥⌃P/⌥⌃Z → ⌘⇧X/⌘⌥Z (PLAN_v0.1 부합), 메뉴·설정 표기 통일
- [macos] 전 화면 스킨: 메뉴/온보딩/에디터/설정 SF Symbols + 호버/프레스 피드백 + Theme 경유
- [macos] WindowDropper weak-delegate 즉시 해제 버그 수정 (WindowDropper.attach + assoc retain) — 창 닫힘 콜백 실제 동작
- [macos] 빌드: ERROR 0, 경고 0건, ~/Applications 설치
## v0.3.0-macos M3 에디터 완성 (2026-09-22)
- [macos] 에디터 640×420 → 980×620 (리사이즈, 최소 800×520)
- [macos] 📌 핀 연결 (주석 합성 포함), 존댓말/캐주얼 토글 (변경 시 재번역)
- [macos] 번역오버레이 ON/OFF: 박스 영역에 번역문 표시 (줄분할 매핑)
- [macos] 주석도구: 펜/화살표/박스/텍스트 + 실행취소/전체지우기, 복사·핀에 합성 포함
- [macos] 박스 호버툴팁, error_message_ko.json 누락 3건 추가
## v0.2.0-macos M2 (2026-09-22)
- [macos] P1-1 captureAndRoute 중복 switch 제거 → 캡쳐 후 applyAction 단일 경로 호출
- [macos] P1-2 runPipeline 데드코드 삭제 (호출자 없음 확인)
- [macos] P1-3 자기복사 중복 방지: ClipboardStore.add에서 changeCount 동기화
- [macos] P1-4 pinPanel 단일 → pinPanels 배열, 닫힌 패널 자동 제거
- [macos] 로컬 git+bd 초기화 (베이스 커밋, M2 이슈 4건)
## v0.2.0-macos M1 (2026-09-20)
- [macos] 결과카드 합의 레이아웃: 좌이미지/우OCR/하번역전체 + 자동높이 + 타이틀 PickBeon
- [macos] 번역 bulk 유지 (단독검증: 6줄 전체 반환) + 표시부 lineLimit 제거
- [macos] 에디터 박스 aspect-fit 레터박스 매핑 수정
- [macos] 선택번역 카드모드/FileLog/빈선택 안내, R 이중실행 제거, 캡쳐실패 카드
- [macos] 오버레이 AppKit 재구현: NSView 마우스 트래킹+직접 그리기, 컷아웃+치수+핸들, 플로팅 툴바
- [macos] 캡쳐 디스플레이 매칭(displayID)+픽셀 sourceRect, Same area 반복 지원
- [macos] 확정 스텝: 고정후툴바→액션에서만 1회캡쳐, Enter=번역, R/Esc 직접처리, 실패시 에러카드
- [macos] Carbon 전역단축키 ⌥⌃P/⌥⌃Z, 저장 ~/Desktop/PickBeon + Pick 날짜.png
- [macos] 한글 표시명: "픽번 - Pick 해서 번역" (ko.lproj, LSHasLocalizedDisplayName)
- [macos] 개발자 서명 적용 (Team 6GPJQ7BQC9, 권한 재빌드 유지)
- [macos] 온보딩: 1.5초 자동 확인 + 앱 복귀 시 재확인 + 닫기 버튼
- [macos] 메뉴 NSStatusItem+NSPopover 전환, 메뉴바 전용, 권한 온보딩, 오버레이/결과카드/Jot에디터/사이드바 설정
