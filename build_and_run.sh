#!/bin/zsh
# build_and_run.sh debug macos [--no-open] — 빌드→번들→서명→실행
set -e
set -o pipefail
MODE=${1:-debug}
PLATFORM=${2:-macos}
if [[ "$PLATFORM" != "macos" ]]; then echo "지원 플랫폼: macos"; exit 1; fi
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"
echo "[INFO] [FEATURE] PickBeon 빌드 시작 ($MODE/$PLATFORM)"
if [[ -f .env ]]; then echo "[CACHE] .env 존재"; fi
pkill -f "PickBeon.app" 2>/dev/null || true
if [[ "$MODE" == "debug" ]]; then swift build -c debug 2>&1 | tail -n 30; else swift build -c release 2>&1 | tail -n 30; fi
BIN="$ROOT/.build/debug/PickBeon"
BDIR="$ROOT/.build/debug"
if [[ "$MODE" != "debug" ]]; then BIN="$ROOT/.build/release/PickBeon"; BDIR="$ROOT/.build/release"; fi
if [[ ! -f "$BIN" ]]; then echo "[ERROR] E-MAC-CAPTURE-0001 빌드 산출물 없음"; exit 1; fi
echo "[PERF] 빌드 성공: $BIN"
APP="$BDIR/PickBeon.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/PickBeon"
cp "$ROOT/Packaging/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/Packaging/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
cp -R "$ROOT/Packaging/ko.lproj" "$ROOT/Packaging/en.lproj" "$APP/Contents/Resources/"
cp "$ROOT/Packaging/Icons/MenuBar/menubar-18.png" "$APP/Contents/Resources/menubar-18.png"
cp "$ROOT/Packaging/Icons/MenuBar/menubar-18@2x.png" "$APP/Contents/Resources/menubar-18@2x.png"
echo "APPL????" > "$APP/Contents/PkgInfo"
/usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$APP/Contents/Info.plist" 2>/dev/null || /usr/libexec/PlistBuddy -c "Set :CFBundleIconFile AppIcon" "$APP/Contents/Info.plist"
CODESIGN_ID="${PICKBEON_SIGN_ID:-Apple Development: leeborasarang@gmail.com (HLQNBZHQQN)}"
if ! codesign --force --deep --sign "$CODESIGN_ID" "$APP" >/dev/null 2>&1; then
  echo "[WARN] 개발자 서명 실패, 임시 서명으로 대체 (권한이 재빌드마다 초기화될 수 있음)"
  codesign --force --deep --sign - "$APP" >/dev/null 2>&1
else
  echo "[INFO] [FEATURE] 개발자 서명 OK (Team 포함, 권한 유지)"
fi
echo "[CACHE] 번들 생성: $APP"
INSTALLED="$HOME/Applications/PickBeon.app"
rm -rf "$INSTALLED"
cp -R "$APP" "$INSTALLED"
echo "[INFO] [FEATURE] 설치됨: $INSTALLED"
mdls -name kMDItemDisplayName "$INSTALLED" 2>/dev/null || true
if [[ "$3" != "--no-open" ]]; then
  open "$INSTALLED"
  echo "[INFO] [FEATURE] PickBeon 실행 요청 ($INSTALLED)"
fi
echo "ERROR 0"
