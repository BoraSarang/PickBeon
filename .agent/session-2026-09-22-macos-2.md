# 세션 2026-09-22 · macos (M4/M5 수리 + 정리)

1. **원인**: NSPanel 기본 hidesOnDeactivate=true → 단축키 카드 미표시/팝오버 닫힘 시 소실. false 처리(카드·기록·핀).
2. **UX**: ⌘⌥Z 카드를 드래그 직후 마우스 근처 배치(placeCard), 캡쳐는 우상단.
3. **AX**: Safari 대비 readSelectedTextWithFallback(시뮬 Cmd+C + 클립보드 복원).
4. **에디터**: 우측 패널 세로 분배 — 번역 ScrollView 확장, 하단 고정 액션(다시번역/복사/기록/글자수).
5. **오버레이**: 드래그 loupe 2.5x 제거 (사용자 “확대 느낌” A선택).
6. **검증**: ./build_and_run.sh debug macos — ERROR 0, 설치 완료. M4/M5 육안 통과 → pickbeon-qir close.
7. **잔여**: pickbeon-17m(main 병합), pickbeon-6yo(M1 검증), P2 3건·P3 1건.
8. **커밋**: feat/macos-m3 브랜치에 M4/M5+수리 전체 커밋 후 main 병합 예정.
