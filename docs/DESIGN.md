# DESIGN.md — PickBeon (custom)
> design_profile: custom (2026-09-22). 코드 단일 소스: `PickBeon/Design/Theme.swift`. 콘셉트: PickBeon-Ui-Concept-v2.html

## 1. 색 토큰
| 토큰 | 다크 | 라이트 | 용도 |
|---|---|---|---|
| accent | `#7C7CF4` | `#5B5BF0` | 강조, 선택, primary 버튼 |
| hero1→hero2 | `#5B5BF0→#8B5CF6` | 동일 | 히어로 그라데이션 (메뉴/온보딩) |
| bg | `#141416` | `#F2F2F7` | 패널 바깥 배경 |
| surface | `#232327` | `#FFFFFF` | 패널/카드 본체 |
| surface2 | `#2C2C31` | `#F5F5F7` | 보조 표면 |
| row | `#303035` | `#EBEBF0` | 리스트 행/입력칸 |
| textPrimary | `#F5F5F7` | `#1C1C1E` | 본문 |
| textSecondary | `#9A9AA2` | `#6E6E73` | 보조 텍스트 |
| line | `white 8%` | `black 8%` | 1px 구분선 |
| ok / danger | `#30D158` / `#FF453A` | 동일 | 성공/오류 |
| transPanel | `#1A1C26` | `#EEEEF8` | 번역 결과 박스 (accent 보더 35%) |

## 2. 라운드 / 간격
- radius: chip 6~8, card 10~12, panel 16, pill 999
- spacing 스케일: 4 / 8 / 10 / 12 / 14 / 16 / 20
- 패널 그림자: `0 24px 70px black 60%` (浮动 팝업), 카드는 보더 1px line

## 3. 타이포
- family: SF Pro Text / Apple SD Gothic Neo (system)
- 스�CALE: caption 11~12, body 12.5~13.5, title 14~16, hero 14 bold
- 키캡: monospaced 11, 배경 black 45%, radius 6

## 4. 모션
- 등장: scale 0.96→1 + opacity, spring(response 0.28, damping 0.85)
- 호버: 배경 `white/black 8%` 페이드 0.12s
- `prefers-reduced-motion` 시 전환 생략
- 결과카드: 3초 자동 숨김 (호버 시 연장, 핀 상태면 유지)

## 5. 화면별 레이아웃
### 오버레이
- 전체 딤 48% + 선택영역 컷아웃, 치수 pill, 코너 핸들 9pt(프리즈 후에도 리사이즈), 커서 loupe(전체화면 1회 캡쳐 기반 확대), 액상 글래스 툴바 5개(복사/저장/핀/OCR/번역)
- Option+드래그 = 즉시 번역. Esc 취소, R 마지막영역, Enter 번역
### 결과카드 (시그니처, 330px)
- 상단: 상태 원 + 타이틀 + 서브(⌘V) + 닫기
- 본문: 원문 1줄(secondary) + 번역 전체
- 썸네일: 드래그=이미지 클립보드. 하단 액션: 번역보기/다시/핀
### 에디터 (980×620)
- 상단 툴바 SF Symbols, 좌 이미지+박스+오버레이+주석, 우 톤토글+OCR/번역 탭
### 히스토리 팝업
- 커서 근처 nonactivating NSPanel, 검색 autofocus, 핀 상단고정, Cmd+1~5 붙여넣기, hover 삭제
### 메뉴 팝업
- 히어로1 + 행2 + 최신1(썸네일) + 푸터. 호버/프레스 피드백
### 설정·권한·DebugPanel
- 시스템 UI native 규칙 준수 (내부 카드는 custom 토큰 허용)
