# TODO — PickBeon v0.8

> 마지막 갱신: 2026-09-27 (중간 점검 P0 수정 후)
> 규칙: 코드 커밋 = 완료. bd 이슈 상태와 반드시 일치시킬 것.

## 진행 중 (코드 반영, 사용자 검증 대기)
- [ ] A1 GIF 녹화 ⌥⌘G (pickbeon-pf4, in_progress)
- [ ] A2 드래그→텍스트 바로 복사 ⌥⌘C (pickbeon-76r)
- [ ] B3 윈도우 캡쳐 ⌥⌘W (pickbeon-2xc)
- [ ] B2 블러/모자이크 주석 (pickbeon-n3z)
- [ ] C1 GIF 프레임 번역 (pickbeon-2sp)
- [ ] M1 사용자 검증: 캡쳐→번역→⌘V, 박스 정렬 (pickbeon-6yo)

## P0 감사 반영 (2026-09-27, fix/macos-p0-audit)
- [x] 번역이 macOS 15~25에서 조용히 원문을 반환하던 no-op 제거 → E-MAC-TRANS-0002
- [x] 클립보드 writeObjects 혼용 데이터 소실 2곳 수정 + PasteboardService 신설
- [x] 블러/모자이크 세로 대칭 영역 오류 + preview=결과 보장 (Redactor)
- [x] 설정 탭 내용 잘림 (ScrollView + 520pt)
- [x] 메뉴 팝오버 폴드 아래 4개 액션 (463pt + primary 강조)
- [x] GIF 녹화 중 Esc 중지 무효 + 마우스 완전 봉쇄
- [x] 비공개 저장소로 업데이트 확인 영구 실패
- [x] "설정 초기화" 확인 없이 전 설정 파괴
- [x] 컴파일 경고 2건 제거

## P1 (감사로 신규 등록)
- [ ] pickbeon-aoa AppCoordinator 분리 (1167줄 God Object)
- [ ] pickbeon-c6k error_message_ko.json 실제 사용 + 에러카드 13중복 통합
- [ ] pickbeon-6pm DebugPanel 스텁 제거 + FileLog 비동기·마스킹
- [ ] pickbeon-bus UI 언어·암호화 등 가짜 기능 정리
- [ ] pickbeon-n4z 히스토리 UX (1클릭 복사, 삭제 확인, orderOut 정리)
- [ ] pickbeon-0y0 결과카드 소멸 정책 + 원문 전체 표시
- [ ] pickbeon-zpy 에디터 줌/팬 + 주석 개별 편집 + Redo
- [ ] pickbeon-tnq 말투 전환을 프롬프트/BYOK 기반으로 교체
- [ ] pickbeon-mkq FileLog 무한增长·평문 로그 마스킹 ([HARD] 로그 마스킹)
- [ ] pickbeon-gjr 테스트 타깃 신설 + smoke 시나리오 자동화
- [ ] pickbeon-4xv GIF 해상도(800px 고정) 재검토
- [ ] pickbeon-9y6 멀티디스플레이 좌표계 검증
- [ ] pickbeon-dt7 macOS 최소 버전 결정 (15 유지 vs 26 상향)

## P2 보류
- [ ] pickbeon-087 단축키 커스텀
- [ ] pickbeon-e2n Dark/Tinted 아이콘
- [ ] pickbeon-bwm E2E
- [ ] pickbeon-w3f BYOK (외부 번역키)

## 미해결 사용자 결정 필요
- macOS 최소 버전: 15 로 두면 번역 기능이 macOS 26 미만 전 구간에서 비활성 (pickbeon-dt7)
- GitHub 저장소 public 전환 여부 (비공개라 업데이트 확인 불가)
