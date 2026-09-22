# CHANGELOG
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
