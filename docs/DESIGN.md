# DESIGN.md — PickBeon (custom)
> design_profile: custom (2026-09-22). 코드 단일 소스: `PickBeon/Design/Theme.swift`. 콘셉트: PickBeon-Ui-Concept-v2.html

## 1. 색 토큰
| 토큰 | 다크 | 라이트 | 용도 |
|---|---|---|---|
| accent | `#2563EB` | `#60A5FA` | 강조, 선택, primary 버튼 (Blue) |
| hero1→hero2 | `#2563EB→#3B82F6` | `#2563EB→#60A5FA` | 히어로 그라데이션 (온보딩 전용) |
| bg | `#141416` | `#F2F2F7` | 패널 바깥 배경 |
| surface | `#232327` | `#FFFFFF` | 패널/카드 본체 |
| surface2 | `#2C2C31` | `#F5F5F7` | 보조 표면 |
| row | `#303035` | `#EBEBF0` | 리스트 행/입력칸 |
| textPrimary | `#F5F5F7` | `#1C1C1E` | 본문 |
| textSecondary | `#9A9AA2` | `#6E6E73` | 보조 텍스트 |
| line | `white 8%` | `black 8%` | 1px 구분선 |
| glassStroke | `white 12%` | `black 12%` | 글래스 패널/키캡 보더 |
| kbdFill | `primary 10%` | 동일 | 키캡 배경 |
| ok / danger | `#30D158` / `#FF453A` | 동일 | 성공/오류 |
| transPanel | `#162033` | `#EEF4FF` | 번역 결과 박스 (accent 보더 35%) |

## 2. 라운드 / 간격
- radius: chip 7, card 12, panel 16, block 10, tab 8, pill 999
- spacing 스케일: 4 / 8 / 10 / 12 / 14 / 16 / 20
- 패널 그림자: `0 24px 70px black 60%` (浮动 팝업), 카드는 보더 1px line

## 3. 타이포
- family: SF Pro Text / Apple SD Gothic Neo (system)
- scale: caption 11~12, body 12.5~13.5, title 14~16, hero 14 bold
- 키캡: monospaced 11, 배경 primary 10% + glassStroke, radius 7

## 4. 모션
- 등장: scale 0.96→1 + opacity, spring(response 0.28, damping 0.85)
- 호버: 배경 `white/black 8%` 페이드 0.12s
- `prefers-reduced-motion` 시 전환 생략
- 결과카드: 3초 자동 숨김 (호버 시 연장, 핀 상태면 유지)

## 5. 화면별 레이아웃
### 오버레이
- 전체 딤 48% + 선택영역 컷아웃, 치수 pill, 코너 핸들 9pt(프리즈 후에도 리사이즈), 크로스헤어+좌표(loupe 제거), 액상 글래스 툴바: 번역(primary accent) | 복사·저장·핀 | OCR [| Same area pill]
- 힌트바: 드래그하여 선택 · ⏎번역 · ⌥즉시 · R이전영역 · Esc취소
- Option+드래그 = 즉시 번역. Esc 취소, R 마지막영역, Enter 번역
- GIF 모드(⌥⌘G): 힌트 "드래그 → 녹화 버튼". mouseUp 시 미리보기 프리즈 + '녹화'(red)/Esc 툴바 — 버튼 클릭 시에만 SCStream 시작
### GIF 녹화 HUD
- 선택 영역 바로 위 중앙 글래스 패널 260×52 고정: ● REC(빨강) + 경과초(mono) + 프레임 + 중지 버튼(accent). border red 55%
- 오버레이 선택 영역: 빨간 테두리 2pt + 코너 + "● REC 3.2s WxH" pill (라이브 구멍 유지, 앱 윈도우는 스트림 제외)
- Esc 또는 재단축키(⌥⌘G) 중지. 최대시간 도달 시 자동 중지. 종료 시 오버레이·HUD 닫힘 → 클립보드 복사 + Desktop 저장 + 결과카드(첫 프레임 썸네일)
### 결과카드 (헤더 없는 번역 스티커, 330px)
- 좌측 3px accent/danger 바 + 번역 패널(accent 보더) + 원문1줄 + 썸네일 드래그
- 하단 액션: 번역보기/다시/핀. 3초 자동숨김(호버·핀 유지, 에러 제외)
### 에디터 (980×620)
- 상단 툴바 SF Symbols, 좌 이미지+박스+오버레이+주석, 우 톤 토글+OCR/번역 탭
### 히스토리 팝업 (전체 검색, 610×480)
- 중앙 nonactivating NSPanel, 검색 autofocus, 필터(전체/번역/클립보드), 우측 미리보기 176px
- 행 탭=미리보기 pin, 다시 탭=붙여넣기, Esc pin 해제 · ⌘1~5 붙여넣기, 하단 힌트
### 메뉴 팝오버 (Pick Hub, 340×240, ultraThinMaterial, contentSize 360×260)
- 헤더 로고 + 탭 [Pick|설정] + 본문(ScrollView) + 푸터(버전/업데이트/전체 기록/종료)
- Pick: accent primary 영역 Pick(⌘⇧X) + GIF 녹화(⌥⌘G) + 선택번역/Same area 행 + 최신 번역 1줄(복사·에디터)
- 설정: 전체설정 열기 + 빠른 토글 · 기록은 ⌘ 커맨드 팔레트 전담(이중 구조 제거)
- 히어로 그라데이션은 온보딩 전용 — 메뉴에서 금지
### 설정·권한·DebugPanel
- 시스템 UI native 규칙 준수 (내부 카드는 custom 토큰 허용)
- 캡쳐 탭 GIF: fps(4~30 기본 10), 최대시간(10/30/무제한 기본 10), 후 클립보드 복사 · 단축키 탭 ⌥⌘G
