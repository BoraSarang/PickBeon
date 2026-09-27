# RESEARCH_capture_apps.md — 캡쳐/GIF/OCR 앱 벤치마크
> 생성일: 2026-09-24 | 갱신: 2026-09-27 (중간 점검, 공식 사이트 직접 확인)
> 용도: 기능 후보 검토용 조사 자료 (bd 이슈 아님)
> 2026-09-27 갱신: CleanShot X(cleanshot.com/features)·TextSniper(textsniper.app) 공식 페이지를
> 직접 확인해 격차를 재산정했다. §6 참조.

## 1. 앱별 기능 비교표

| 기능 | Gifox | GifJot | CleanShot X | ShotZen* | Gifable | TextSniper | Shottr | Snapzy | PickBeon |
|---|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| 영역/윈도우 캡쳐 | ✅ | ✅ | ✅ | ✅ | ✅ | – | ✅ | ✅ | ✅ |
| Same area 반복 | ✅ | ✅ | ✅ | – | – | – | – | ✅ | ✅ |
| OCR 텍스트 추출 | – | – | ✅ | – | – | ✅ | ✅ | ✅ | ✅ |
| OCR→바로 복사 단일 플로우 | – | – | ✅ | – | – | ✅ | ✅ | ✅ | ⚠️ 중간 UI 필요 |
| 번역(온디바이스) | – | – | – | – | – | – | – | – | ⚠️ macOS 26+ 전용 |
| GIF 녹화 | ✅ | ✅ | ✅ | – | ✅ | – | – | ✅ | ✅ |
| MP4/영상 녹화 | ✅ | – | ✅ | – | – | – | – | ✅ | ❌ |
| 오디오(마이크/시스템) | ✅ | – | ✅ | – | – | – | – | ✅ | ❌ |
| 클릭/키 입력 시각화 | – | – | ✅ | – | – | – | – | ✅ | ❌ |
| 녹화 품질·해상도 제어 | ✅ | – | ✅ | – | – | – | – | ✅ | ❌ 해상도 800px 고정 |
| 스크롤 캡쳐 | – | ✅ | ✅ | – | – | – | ✅ | ✅ | ❌ |
| 주석(펜/화살표/텍스트) | ✅편집 | ✅Jot | ✅ | ? | – | – | ✅ | ✅ | ✅ |
| 블러/모자이크 | – | – | ✅ 보안옵션 | – | – | – | ✅ | ✅ | ✅ 위치오류 수정됨 |
| 주석 재편집(프로젝트 파일) | ✅ | – | ✅ | – | – | – | ✅ | ✅ | ❌ 픽셀 평탄화 |
| 에디터 줌/팬 | ✅ | – | ✅ | – | – | – | ✅ | ✅ | ❌ |
| 배경 beautify | – | – | ✅ | – | – | – | ✅ | ✅ | ❌ |
| 핀(항시 위) | – | – | ✅ Lock Mode | – | – | – | ✅ | – | ✅ |
| Quick Access 오버레이 | – | ✅ | ✅ 자동닫기 설정 | – | – | – | – | ✅ | ✅ 3초 고정 |
| 클립보드 히스토리 | – | – | ✅ 1개월 | – | – | – | – | ✅ | ✅ |
| QR/바코드 | – | – | ✅ | – | – | ✅ | – | – | ❌ |
| TTS 읽어주기 | – | – | – | – | – | ✅ | – | – | ❌ |
| 클라우드 업로드 | ✅ | ❌ | ✅ | – | – | – | ✅ | ✅ BYOS | ❌ 프라이버시 콘셉트 |
| URL 스킴/API | – | – | ✅ | – | – | – | – | ✅ | ❌ |
| 단축키 커스텀 | – | – | ✅ | – | – | ✅ | – | – | ❌ |

\* ShotZen: 검색 결과 희박 — 유사 스크린샷 앱군으로 분류. Gifable(gifableapp.com)은 GIF 녹화 전용 초경량 앱.
PickBeon 열은 2026-09-27 P0 수정 반영 상태.

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

### CleanShot X (cleanshot.com/features — 2026-09-27 직접 확인)
- 캡쳐: 영역/창/전체/**스크롤(가로·세로)**/타이머, 크로스헤어, 매그니파이어, **프리즈**, 창 배경·투명·그림자
- **All-In-One 모드**: 단축키 하나로 전 모드, 크기 고정, **종횡비 잠금**, **마지막 선택 기억**
- 녹화: MP4(H.264)/GIF, **마이크 + 시스템 오디오**, **FPS·품질·해상도 제어**, DND 자동, 커서 표시,
  **메뉴바에 녹화 시간**, **데스크톱 클러터 숨김**, **클릭 캡처**(색·크기·스타일·애니메이션),
  **키 입력 캡처**(위치·크기·스타일), **카메라**
- 비디오 에디터: 스마트 줌, 커서 흔들림 정리, 모션 블러, 플랫폼별 프리셋
- 주석 15종: Crop(종횡비·스냅), **Pixelate(무작위화 적용)**, Arrow(곡선 포함 4종),
  **Blur(secure / smooth 옵션)**, Spotlight, Counter, Pencil(자동 스무딩),
  **Highlighter(글자 크기 자동 감지)**, 채워진 사각형, 사각형, 선, 타원, 텍스트(스타일 7종)
- **화면에서 색 추출하는 컬러 피커**, 이미지 합치기
- **CleanShot 프로젝트 파일** — 주석을 편집 가능한 상태로 저장(재편집 가능)
- Quick Access Overlay: 복사/저장/드래그&드롭, **닫힌 오버레이 복원**, 위치·크기 조절,
  **자동 닫힘 설정 가능**, **멀티디스플레이**, 스와이프 제스처
- Floating Screenshots: 핀, 항상 위, 크기·불투명도, 방향키로 위치 조정, **Lock Mode(하단 앱 조작)**
- OCR: 텍스트 복사, **QR**, 30+ 언어, 온디바이스
- 클라우드: 링크 공유, 4K, 트랜스크립션, 댓글, 접근 제어, 비밀번호 링크, SSO/SCIM, ISO 27001
- **URL 스킴 API**, 캡쳐 히스토리 1개월(타입별 필터)

### TextSniper (textsniper.app — 2026-09-27 직접 확인)
- ⌘⇧2 → 영역 드래그 → OCR → 클립보드 즉시. **중간 UI 없음** (오버레이·툴바 없이 3스텝 완료)
- QR/바코드 리더, **TTS 낭독**, **단축키 커스텀**, 메뉴바 전용(독 비표시)
- $7.99(1Mac) / $9.99(3Macs) / $11.99(App Store 무제한), 7일 환불
- Ventura 이상 11개 언어(한·일·중 포함)

### Gifable (gifableapp.com)
- macOS 전용 GIF 녹화 초경량 앱. 데모/소셜/블로그 用途

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
- https://cleanshot.com/features (2026-09-27 확인)
- https://textsniper.app (2026-09-27 확인)
- https://gifox.app/ / docs/recording
- https://gifjot.com/
- https://shottr.cc
- https://snapzy.app / https://github.com/duongductrong/Snapzy
- https://www.gifableapp.com/

## 6. 격차 재평가 (2026-09-27, P0 수정 후)

### 6.1 이미 따라잡은 것 (경쟁사가 하면 PickBeon 은 없는 것)
| PickBeon | 상태 |
|---|---|
| **온디바이스 번역** (무료·오프라인·API키 없음) | CleanShot·Shottr·Snapzy·TextSniper 전부 없음. 유일한 차별화 축. 단 macOS 26+ 에서만 가동 |
| GIF 녹화 + **프리즈 후 녹화 버튼** 플로우 | GifJot 과 동일. 자동 녹화가 아니라 영역 확정을 먼저 두는 판단은 경쟁사 대비 UX 우위 |
| **번역 오버레이** (캡처 이미지 위에 번역문 배치) | 어느 경쟁사도 없음. Vision 박스·줄 매핑 기반이라 검증 가능성 문제 있음(pickbeon-zpy) |
| **Blur / Pixelate** | 위치 오류만 고치면 CleanShot 대비 기능 단위로는 동급. 다만 보안 옵션(무작위화 등)은 결여 |

### 6.2 여전히 큰 격차 (우선순위 순)
| # | 격차 | 경쟁사 근거 | PickBeon 상태 | bd |
|---|---|---|---|---|
| 1 | **클릭/키 입력 시각화** | CleanShot 클릭 캡처·키 캡처, Snapzy 동일 | 없음. GIF 용도에서 사실상 필수 | 신규 필요 |
| 2 | **녹화 해상도·품질 제어** | CleanShot "FPS·품질·해상도", Gifox "색·디더링·리사이즈" | 최대변 800px 고정 하드코딩 → Retina 텍스트가 뭉개짐 | pickbeon-4xv |
| 3 | **오디오** | CleanShot 마이크+시스템, Gifox/Snapzy | 없음 | P2 (범위 과잉 판단 유지) |
| 4 | **스크롤 캡쳐** | CleanShot(가로·세로), Shottr, Snapzy, GifJot | 없음 | B1 |
| 5 | **에디터 줌/팬 + 재편집** | CleanShot `.cleanshot` 프로젝트 파일, Shottr/Gifox 줌 | 줌 없음, 주석이 픽셀로 평탄화되어 재편집 불가 | pickbeon-zpy |
| 6 | **TTS / QR** | TextSniper·CleanShot | 없음 | C3/C4 |
| 7 | **URL 스킴 (자동화)** | CleanShot URL API, Snapzy | 없음 | P2 |
| 8 | **단축키 커스텀** | TextSniper·CleanShot | 하드코딩 5종 | pickbeon-087 |

### 6.3 설계 철학 차이 (기능이 아니라 방식)
- **TextSniper = 중간 UI 0개.** ⌘⇧2 → 드래그 → 클립보드. 오버레이·툴바가 없다.
  PickBeon 은 드래그 후 프리즈 + 툴바를 거친다. ⌥+드래그(즉시 번역)가 그 대안이고,
  A2(⌥⌘C)는 TextSniper 플로우를 그대로 가져왔다. **기본 플로우는 아직 PickBeon 이 더 무겁다.**
- **CleanShot = Quick Access 의 자동 닫힘을 설정으로 노출.** PickBeon 은 3초 고정 + 복구 수단 없음.
  사용자 성향(자주 쓰는 앱 vs 한 번만 쓰는 앱) 차이가 크므로 설정형이 맞다.
- **CleanShot Floating Screenshot 의 Lock Mode = 하단 앱 조작.** 2026-09-27 P0-6 수정으로
  GIF 녹화 중 마우스 통과를 넣은 것이 같은 철학임을 확인했다.
- **CleanShot = 녹화 시간을 메뉴바에 표시.** PickBeon 은 떠 있는 HUD 패널이라
  다른 창에 가려지거나 패널을 잃을 수 있다. 메뉴바 표시가 더 견고하다.

### 6.4 결론
기능 개수만 보면 CleanShot 급으로 포지셔닝하고 있으나, **동작 검증된 경로**로는 아직
"영역 캡쳐 + OCR + (macOS 26 에서만) 번역" 에GIF 녹화를 얹은 수준이다.
차별화 축인 **번역이 최소 지원 OS 구간에서 가동되지 않는 상태**가 가장 시급한 격차다
(pickbeon-dt7). 그 다음은 GIF 품질(1·2번)과 편집기(5번)다.
