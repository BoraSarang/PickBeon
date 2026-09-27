# RESEARCH_capture_apps.md — 캡쳐/GIF/OCR 앱 벤치마크
> 생성일: 2026-09-24 | 용도: 기능 후보 검토용 조사 자료 (bd 이슈 아님)
> 참고: A1 GIF 녹화 진행 후 추 재참조 대상

## 1. 앱별 기능 비교표

| 기능 | Gifox | GifJot | CleanShot X | ShotZen* | Gifable | TextSniper | Shottr | Snapzy | PickBeon(2026-09-24) |
|---|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| 영역/윈도우 캡쳐 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Same area 반복 | ✅ | ✅ | ✅ | – | – | – | – | ✅ | ✅ |
| OCR 텍스트 추출 | – | – | ✅ | – | – | ✅ | ✅ | ✅ | ✅ |
| OCR→바로 복사 단일 플로우 | – | – | ✅ | – | – | ✅ | ✅ | ✅ | ⚠️ 부분 |
| 번역(온디바이스) | – | – | – | – | – | – | – | – | ✅ 차별화 |
| GIF 녹화 | ✅ | ✅ | ✅ | – | ✅ | – | – | ✅ | (A1 진행 중) |
| MP4/영상 녹화 | ✅ | – | ✅ | – | – | – | – | ✅ | ❌ |
| 스크롤 캡쳐 | – | ✅ | ✅ | – | – | – | ✅ | ✅ | ❌ |
| 주석(펜/화살표/텍스트) | ✅편집 | ✅Jot | ✅ | ? | – | – | ✅ | ✅ | ✅ |
| 블러/모자이크·감열 | – | – | ✅ | – | – | – | ✅ | ✅ | ❌ |
| 배경 beautify | – | – | ✅ | – | – | – | ✅ | ✅ | ❌ |
| 핀(항상 위) | – | – | ✅ | – | – | – | ✅ | – | ✅ 히스토리핀 |
| Quick Access 오버레이 | – | ✅ | ✅ | – | – | – | – | ✅ | ✅ 결과카드 |
| 클립보드 히스토리 | – | – | – | – | – | – | – | ✅ | ✅ |
| QR/바코드 | – | – | ✅ | – | – | ✅ | – | – | ❌ |
| TTS 읽어주기 | – | – | – | – | – | ✅ | – | – | ❌ |
| 클라우드 업로드 | ✅ | ❌ | ✅ | – | – | – | ✅ | ✅ BYOS | ❌ |
| 윈도우 캡쳐 전용 모드 | ✅ | – | ✅ | – | – | – | – | ✅ | ❌ |

\* ShotZen: 검색 결과 희박 — 유사 스크린샷 앱군으로 분류. Gifable(gifableapp.com)은 GIF 녹화 전용 초경량 앱.

## 2. 앱별 핵심 특징

### Gifox (gifox.app)
- 영역/윈도우 선택, Aspect lock(영역 기억), Space 시작 / ⌘Esc 중지
- 라이브러리 팝오버, 편집(Cut/Trim/Crop/Duplicate), 압축 설정(색·디더링·리사이즈)
- Dropbox/Google Drive/Imgur 공유, GIF·MOV·MP4 내보내기
- 무료 10초 제한+워터마크, Pro $14.99

### GifJot (gifjot.com) — A1 MVP 레퍼런스
- ⌥⌘G GIF / ⌥⌘S PNG, Same area, 캡처 후 Jot(주석)·다시·Finder
- 로컬 전용, 계정·업로드·워터마크 없음, macOS 14+, free beta
- 3스텝: Choose → Capture → Paste/Jot

### CleanShot X (cleanshot.com)
- 영역/창/전체/스크롤 캡쳐, 타이머, 프리즈, 크로스헤어/매그니파이어
- 녹화: MP4/GIF, 시스템+마이크, 클릭/키 강조, 웹캠 버블, 스마트 줌
- 주석 풀세트, 블러/픽셀 감열, 배경 beautify(20종), 핀, OCR, QR, 클립보드 히스토리(1개월)
- CleanShot Cloud 업로드, 편집가능 .cleanshot 파일

### Gifable (gifableapp.com)
- macOS 전용 GIF 녹화 초경량 앱. 데모/소셜/블로그用途

### TextSniper (textsniper.app)
- ⌘⇧2 → 영역 드래그 → OCR → 클립보드 즉시 (번역 없음)
- QR/바코드, TTS 낭독, 커스텀 단축키, 온디바이스 Vision
- $6.99~ 일회성

### Shottr (shottr.cc)
- 초고속 스크린샷, 스크롤 캡쳐, OCR(Cmd+O 영역 텍스트 복사)
- 주석+측정도구(자), 업로드 링크, 핀, 매그니파이어, WCAG 대비 표시
- 무료+일부 유료

### Snapzy (github.com/duongductrong/Snapzy) — 오픈소스 CleanShot 대안
- SwiftUI+AppKit+SCK+Vision+Sparkle, BSD-3
- 영역/스크롤/녹화(MP4/GIF)+오디오, OCR, 주석+블러, 배경, Quick Access
- BYOS 클라우드(S3/R2), 히스토리, URL 스킴, 다국어 10개

## 3. 후보 기능 (A~D군)

### A군 — 사용자 제안
| ID | 기능 | 근거 | 난이도 | 상태 |
|---|---|---|---|---|
| A1 | GIF 녹화 (영역 → GIF → 복사/저장) | Gifox/GifJot/Gifable/Snapzy | 🔴 높음 | ✅ 구현·빌드 완료, 사용자 E2E 대기 (pickbeon-pf4) |
| A2 | 드래그 → 텍스트 바로 복사 (번역 스킵) | TextSniper, Shottr Cmd+O | 🟢 낮음 | 백로그 |

### B군 — 파이프라인 확장
| ID | 기능 | 근거 | 난이도 |
|---|---|---|---|
| B1 | 스크롤 캡쳐 | CleanShot/Shottr/Snapzy/GifJot | 🔴 |
| B2 | 블러/모자이크 감열 | CleanShot/Shottr/Snapzy | 🟡 |
| B3 | 윈도우 캡쳐 모드 | Gifox/CleanShot/Snapzy | 🟡 |
| B4 | 배경 beautify | CleanShot/Snapzy/Shottr | 🟡 |
| B5 | Quick Access 동작 매트릭스 | CleanShot/Snapzy | 🟢 |

### C군 — 차별화 조합
| ID | 기능 | 아이디어 |
|---|---|---|
| C1 | GIF 프레임 번역 | 녹화 GIF 주요 프레임 OCR → 번역 오버레이 |
| C2 | 번역 합성 주석 | 주석 텍스트 자동 번역 입력 |
| C3 | TTS 낭독 | 번역문 읽어주기 |
| C4 | QR 스캔 → 번역/열기 | Vision barcodes 추가 |

### D군 — 범위 밖/보류
- 클라우드 업로드(S3/R2) — 프라이버시 콘셉트와 충돌
- 웹캠·시스템음성 녹화 — 범위 과잉
- 독립 편집기 전체 재현 — 에디터 보유

## 4. 확정 로드맵 (2026-09-24)
1. **A1** GIF 녹화 MVP (GIF만, ⌥⌘G, 설정 fps/최대시간) ← 구현 완료, E2E 대기
2. **A2** 드래그→텍스트 복사
3. **B3+B2** 윈도우 캡쳐 + 블러/모자이크
4. **C1** GIF 프레임 번역

## 5. 출처
- https://gifox.app/ / docs/recording
- https://gifjot.com/
- https://cleanshot.com/features
- https://textsniper.app
- https://shottr.cc
- https://snapzy.app / https://github.com/duongductrong/Snapzy
- https://www.gifableapp.com/
