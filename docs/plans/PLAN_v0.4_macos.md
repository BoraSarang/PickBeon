# PLAN_v0.4_macos.md — custom 디자인 시스템 + 시그니처 UX
> 생성일: 2026-09-22 | 기반: 사용자 확정 (custom 전환, 컴팩트 시그니처, 히스토리 버그 포함, 오버레이 고도화)
> 이슈: pickbeon-qir | 이전: PLAN_v0.3 (M3 완료)

## 0. 합의 사항
- design_profile **native → custom** (AGENTS.local.md 갱신, 토큰은 docs/DESIGN.md + Design/Theme.swift)
- 결과카드 **330px 컴팩트 시그니처**로 교체 (3초 자동숨김/썸네일 드래그/핀)
- 히스토리 **영속화 버그 수정 포함** (DB 로드 없음 + limit 미삭제)
- 나머지 권장안 전부: loupe, Option+드래그 번역, 프리즈 후 리사이즈 핸들, Raycast식 히스토리, 설정 가짜 토글 정리, 단축키 ⌘⇧X/⌘⌥Z 통일

## 1. 범위 (M4+M5 통합)
### M4 디자인 시스템 + 스킨
- T-01 `Design/Theme.swift`: 색(다크/라이트 dynamic)·라운드·간격·타이포·모션 토큰 + 공용 컴포넌트(SurfaceCard/KeyCap/HeroGradient/PressableRow)
- T-02 메뉴/온보딩/에디터/설정/오버레이 툴바 스킨 — 하드코딩 색 0건, SF Symbols, 호버·프레스 피드백

### M5 시그니처 + 히스토리 + 오버레이
- T-03 결과카드 330px: 원문1줄+번역+썸네일 드래그(=이미지 클립보드)+번역보기/다시/핀. 번역·메시지 3초 자동숨김(호버 연장), 에러는 유지, 핀은 상주
- T-04 ClipboardStore 영속화: 시작 시 DB 로드, limit 초과분 SwiftData 행 삭제, pinned 유지
- T-05 히스토리 Raycast 패널: 커서 근처 nonactivating, 검색 autofocus, 핀 고정, Cmd+1~5, hover 삭제, 썸네일
- T-06 오버레이: loupe(전체화면 1회 캡쳐 기반), Option+드래그 즉시 번역, 프리즈 후 코너 핸들 리사이즈(로컬 crop 재freeze)
- T-07 설정: 가짜 토글 → afterCapture 실제 Picker, encryptStore 비활성(미지원 표시), 검색 필터 동작
- T-08 단축키 ⌥⌃P/⌥⌃Z → ⌘⇧X/⌘⌥Z (PLAN_v0.1 부합), 메뉴·설정 표기 통일

## 2. 비범위 (P2 유지)
- 단축키 커스텀, Dark/Tinted 아이콘, E2E, BYOK, AES-256 암호화 구현, 런타임 UI 언어 전환(설정 저장+재시작 안내까지만)

## 3. DoD
- `./build_and_run.sh debug macos --no-open` ERROR 0, 신규 경고 없음
- 디자인 하드코딩 리터럴 신규 0건 (Theme 경유), DESIGN.md 토큰과 일치
- 히스토리 재실행 시 데이터 유지 + limit 시 DB 삭제 확인
- 결과카드 3초 숨김/썸네일 드래그/핀 동작, loupe·핸들·Option번역 동작
- CHANGELOG + TODO + session 로그 갱신
