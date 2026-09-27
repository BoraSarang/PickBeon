# TODO — PickBeon v0.7.2

> 마지막 갱신: 2026-09-28 (중간 점검 P0 수정 + Phase1/3 착수)
> 규칙: 코드 커밋 = 완료. bd 이슈 상태와 반드시 일치시킬 것.
> 진행 브랜치: `fix/macos-p0-audit` (main 대비 16커밋, 미병합)

## ✅ 완료 — 중간 감사 (2026-09-27~28)
- [x] P0-1 번역 macOS 15~25 조용한 no-op 제거 → 이후 최소 macOS 26 으로 상향
- [x] P0-2 클립보드 `writeObjects` 혼용 데이터 소실 2곳 + `PasteboardService` 신설(22곳 통합)
- [x] P0-3 블러/모자이크 세로 대칭 오류 + `Redactor` 로 preview=결과 보장
- [x] P0-4 설정 탭 내용 잘림 (ScrollView + 520pt)
- [x] P0-5 메뉴 팝오버 폴드 아래 4개 액션 (463pt + primary 강조)
- [x] P0-6 GIF 녹화 중 Esc 중지 무효 + 마우스 완전 봉쇄
- [x] P0-8 비공개 저장소 → public 전환, 404 원인 구분 가능하게
- [x] [HARD] 로그 마스킹 위반(사용자 원문 평문 기록 4곳) → `AppLog.sensitive()`
- [x] [HARD] 로그 무한 증가 + 메인스레드 동기 I/O → 링버퍼/로테이션/백그라운드 flush
- [x] DebugPanel 스텁("ERROR 0" 하드코딩) → 실제 로그 실시간 표시
- [x] OCR 이 메인 스레드 54초 정지 → 전용 큐 + 12초 타임아웃 + 진행 표시
- [x] 오버레이 툴바 배치 2건 (중앙 ~52pt 밀림 / 하단 닿으면 영역 안쪽)
- [x] 전역 단축키 5종 전부 사용자 지정 + `⌥⌘C` 충돌 제거
- [x] `⌥⌘W` 는 표기만 W, 실제로는 `⌥⌘E`(keyCode 13)였음 → `⌘⇧W`(keyCode 12)
- [x] 에디터 줌/팬 + 주석 개별 선택·삭제 + Undo/Redo
- [x] "설정 초기화" 확인 없이 파괴 → 확인 다이얼로그
- [x] 컴파일 경고 0건

## 🔲 사용자 육안 검증 대기 (코드 반영 완료, 확인 전)
- [ ] OCR 1회 실행 → 로그의 `OCR 완료 N줄 Mms` 확인 (첫 호출 모델 로딩으로 느릴 수 있음)
- [ ] 에디터 복사(주석 있음) → 클립보드에 **텍스트+이미지 동시**
- [ ] ⌥⌘G 녹화 → ⌘V → **GIF 데이터** 붙여넣기
- [ ] 에디터 블러/모자이크 → 드래그 영역 **정확히** 가려짐
- [ ] 단축키 변경 후 실제 동작 + Carbon 등록 실패 표시
- [ ] 에디터 줌/팬/Undo/Redo/주석 개별 삭제
- [ ] A1 GIF / A2 텍스트복사 / B3 창캡쳐 / B2 블러 / C1 GIF번역 (pickbeon-pf4/76r/2xc/n3z/2sp)
- [ ] M1 캡쳐→번역→⌘V (pickbeon-6yo)

## 📋 남은 작업 (bd 17건)
### P1 — 신뢰성/구조
- [ ] pickbeon-aoa `AppCoordinator` 분리 (1167줄 God Object)
- [ ] pickbeon-c6k `error_message_ko.json` 실제 사용 + 에러카드 13중복 통합
- [ ] pickbeon-bus UI 언어·암호화 등 가짜 기능 정리
- [ ] pickbeon-n4z 히스토리 UX (1클릭=복사, 삭제 확인, orderOut 정리)
- [ ] pickbeon-0y0 결과카드 소멸 정책 + 원문 전체 표시
- [ ] pickbeon-bag 말투 전환을 프롬프트/BYOK 기반으로 교체

### P2 — 품질
- [ ] pickbeon-gjr 테스트 타깃 신설 + smoke 시나리오 자동화
- [ ] pickbeon-4xv GIF 해상도 800px 고정 재검토
- [ ] pickbeon-9y6 멀티디스플레이 좌표계 검증

## 🎯 다음 세션 권장 순서
1. 사용자 육안 검증 결과 반영 (위 "대기" 항목)
2. `pickbeon-0y0` 결과카드 — 앱의 유일한 산출물이 3초 뒤 사라지고 복구 수단이 없음
3. `pickbeon-aoa` AppCoordinator 분리
4. `pickbeon-c6k` 에러코드 실제 사용

## 참고 — 자주 틀리는 지점
- **Carbon keyCode 는 알파벳 순서가 아니라 QWERTY 물리 위치**: 0=A 4=H 5=G 6=Z **7=X** 8=C 12=**W** **13=E**
  표기 테이블은 `HotKeyBinding.keyNameTable` 단일 소스. 역매핑은 "정확히 한 글자 대문자"만 사용
  (F11/esc/home/pageup 이 알파벳으로 오염됨).
- **CGImage 와 AppKit 의 y 원점**이 다름. `Redactor` 는 정규화 top-left 한 벌만 받아 변환.
- `NSPasteboard` 는 `writeObjects` 와 `setData/setString` **혼용 금지** — `PasteboardService` 만 사용.
- SwiftUI `.commands` 는 Scene modifier. `NSWindow+NSHostingController` 창에서는 동작하지 않음 → 로컬 NSEvent 모니터.
- SwiftPM `Platform` 열거형은 `.v25` 까지만. macOS 26 은 `.macOS("26.0")` 문자열 초기자.
