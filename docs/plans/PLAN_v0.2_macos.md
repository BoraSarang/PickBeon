# PLAN_v0.2_macos.md — 통합 재계획
> 생성일: 2026-09-20 | 기반: v0.1 구현 전체 리뷰 + API 단독 검증

## 1. 검증済 사실 (추측 아님)
- Translation bulk 전체 반환 확인 (6줄→전체, 6.6s, 단독 테스트). 짤림은 표시부 문제 → **bulk 유지**, 줄 단위案 폐기
- en↔ko installed 확인. 세션 메인 실행 검증됨
- 캡쳐 SCScreenshotManager + 실측 스케일 동작 (debug.log 캡쳐 완료)
- LS ko 이름 "픽번 - Pick 해서 번역", 개발자 서명 Team 유지, ~/Applications 설치

## 2. 확정 스텝 (불변)
`⌥⌃P` → 딤+힌트(중앙) → 드래그(치수만) → mouseUp 즉시캡쳐 → 정지이미지+툴바 → 액션은 저장 이미지로 1회.
Enter=번역, R=이력시만, Esc=취소. 실패는 카드로 (침묵 금지).

## 3. 버그 목록
### P0 (M1에서 수정)
- P0-1 결과 카드 표시부: lineLimit + 고정 330x300 → 합의 레이아웃 (좌이미지/우OCR/하번역전체, 자동높이) + 타이틀 무제→PickBeon
- P0-2 translateSelection cardMode 미설정 (stale 카드 버그) + FileLog + 빈 선택 시 메시지 카드
- P0-3 R 이중 실행 (monitor repeatLastArea + keyDown repeatFromOverlay) → 모니터는 Esc만
- P0-4 startCapture 실패 침묵 (shown==0/catch) → 에러 카드 (권한 재확인 유도)
### P1 (M2에서 수정)
- P1-1 captureAndRoute/applyAction 중복 → 캡쳐 후 applyAction 호출로 통합
- P1-2 runPipeline 데드코드 삭제
- P1-3 자기복사 중복: 우리 번역 복사 → 폴링이 다시 add → add 시 changeCount 동기화
- P1-4 pinPanel 배열 관리 (사소)
### P2 (보류)
- Dark/Tinted 아이콘, 단축키 커스텀, E2E, 주석도구, BYOK

## 4. 마일스톤 + DoD
- M1: P0 4건. 빌드 + 사용자 1회 플로우 확인 (캡쳐→번역 전체표시→⌘V)
- M2: P1 4건 + 문서. 빌드 + 회귀 확인
- 각 마일스톤 후 session 로그. [HARD] 위반만 실패.

## 5. 합의된 디자인 (결과 카드)
좌 캡쳐 이미지 / 우 OCR 원문(스크롤) / 하 번역 전체(스크롤) / 버튼 복사·에디터·다시·핀.
에러/메시지 카드 동일 프레임에 내용만 교체.
