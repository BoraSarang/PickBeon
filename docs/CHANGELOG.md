# CHANGELOG
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
