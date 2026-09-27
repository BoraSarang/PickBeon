# Session 2026-09-28 (macos) — 중간 감사 Phase 0/1 + 에디터 UX

> 규칙 형식 8줄 요약 + 이어가기(handoff) 섹션.
> 다음 세션은 `docs/TODO.md` 와 이 문서를 먼저 읽을 것.

## 8줄 요약 (rules/workflow.md §2)

1. **무엇을**: 중간 감사 P0 8건 수정 + 최소 macOS 26 상향 + 단축키 사용자 지정 + OCR 정지 수정 + [HARD] 로그 마스킹 + 에디터 줌/팬·주석 개별 편집·Redo
2. **플랫폼**: macOS 26+ / SwiftUI+AppKit / ScreenCaptureKit+Vision+Translation / 브랜치 `fix/macos-p0-audit` (main 대비 16커밋, **미병합·미push**)
3. **빌드**: `./build_and_run.sh debug macos` ERROR 0 · **경고 0** · 앱 재실행(PID 확인) · `swift build`로 별도 scratch 경로도 교차 검증
4. **PERF/CACHE**: `[PERF] 빌드 성공` · `[CACHE] 번들 생성/설치` · 핫키 등록 로그로 조합 정합 확인. 성능 예산(1.5s/300MB) **아직 미측정** — DebugPanel 스텁이라 실측 불가
5. **남은 TODO**: bd 17건 (P1: `AppCoordinator` 분리·에러코드 실제 사용·가짜 기능·히스토리 UX·결과카드 소멸정책·말투 전환 / P2: 테스트 타깃·GIF 해상도·멀티디스플레이)
6. **전달 로그**: `AppLog` 신설 — 메모리 링버퍼 400줄 + 디스크 0.5초 배치 flush + 2MB 로테이션, 경로 `~/Library/Application Support/PickBeon/debug.log`
7. **문서 갱신**: `docs/TODO.md`(전면 재작성) · `docs/CHANGELOG.md`(v0.7.2) · `docs/RESEARCH_capture_apps.md`(§6 격차 재평가) · `AGENTS.local.md`(min 26) · `error_message_ko.json`
8. **큐 상태 / E2E**: bd 23건 중 5건 close(087·dt7·6pm·mkq·zpy) 17건 open, 1건 in_progress(pf4) · E2E **없음**(테스트 타깃 0개, pickbeon-gjr)

---

## Handoff — 다음 세션 시작 지점

### 먼저 읽을 것
1. `docs/TODO.md` — 특히 **"사용자 육안 검증 대기"** 목록과 **"자주 틀리는 지점"**
2. `bd prime` → `pickbeon-audit-handoff` 메모리 자동 주입
3. `git log --oneline main..HEAD` — 16커밋 요약

### 브랜치 상태
- 작업 브랜치: `fix/macos-p0-audit`
- **main 에는 v0.6~v0.7 작업분이 스냅샷 커밋으로만 반영** (`8d9ff76`)
- **push 하지 않음** ([HARD] main 직접 push 금지, conservative 프로필)
- 병합 여부는 사용자 판단 필요

### 사용자 결정으로 확정된 것
| 결정 | 결과 |
|---|---|
| 최소 macOS 버전 | **26** (`Package.swift` `.macOS("26.0")`, Info.plist `LSMinimumSystemVersion 26.0`) |
| GitHub 저장소 | **public 전환 완료** — 업데이트 확인 동작 가능(단 릴리스 0건이라 "게시된 릴리스 없음"이 정상 표시) |
| ⌥⌘C 충돌 | 제거 → `⌘⇧C` |
| 블러/모자이크 용도 | **앱 내부 표시 전용** (외부 공유 아님) → 외부 공유 경고 불필요 |

### ⚠️ 사용자가 아직 확인 안 한 것 (다음 세션 첫 질문)
1. **OCR 1회** → 로그 `OCR 완료 N줄 Mms` 확인. ms가 수십 초면 Vision 병목
2. **에디터 복사(주석 있음)** → 클립보드에 텍스트+이미지 **동시** (P0-2 재현 확인)
3. **⌥⌘G → ⌘V** → GIF 데이터 붙여넣기 (P0-2 재현 확인)
4. **블러/모자이크 위치** → 드래그 영역과 정확히 일치하는지 (P0-3 재현 확인)
5. **단축키 변경** → 실제 동작 + 등록 실패 표시
6. **에디터 줌/팬/Undo/Redo/주석 개별 삭제**

### 이 세션에서 발견해서 고친 "원인이 코드에 숨어 있던" 버그
- `⌥⌘W` 는 **원래부터 W 가 아니었다** (keyCode 13 = E). 표기만 W.
- keyCode 매핑을 알파벳 인덱스로 하면 **전부 어긋난다** (7=X 인데 7 로 표시).
- OCR `withCheckedThrowingContinuation` 본문은 **호출 스레드(=메인)에서 동기 실행** → 54초 완전 정지.
- `Redactor` 가 AppKit 하단원점 rect 를 CGImage(top-left)에 넣어 **세로 대칭 영역**을 가림.
- `NSPasteboard.writeObjects` 가 클립보드를 비워 먼저 넣은 데이터가 증발(2곳).
- 설정을 430pt 창에 ScrollView 없이 넣어 하단 항목 **접근 불가**.
- 툴바 가로 계산의 하드코딩 너비(420)가 실제(~320)와 달라 **중앙이 52pt 밀림**.
- 메뉴 팝오버 240pt에 7행이 들어가지 않아 **4개 액션이 폴드 아래**.

### DoD 체크 (rules/workflow.md §5, [정식])
- [x] 플랫폼 명시 / 문서 우선 / 한국어 / error_code / CHANGELOG / TODO / session 로그
- [x] build_and_run 성공 · ERROR 0 · **경고 0**
- [x] error_message_ko.json 갱신
- [ ] **smoke+unit 통과 — 테스트 타깃이 없어 해당 없음** (pickbeon-gjr)
- [ ] DebugPanel 로그 첨부 — 사용자가 직접 열람 필요(우클릭 or `showDebug`)
- [ ] E2E — 없음 (pickbeon-bwm, P2)
