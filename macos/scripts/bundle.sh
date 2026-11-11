#!/bin/zsh
# 릴리스 빌드를 Linkie.app 으로 묶는다. 사용: scripts/bundle.sh  (배포용: UNIVERSAL=1 scripts/bundle.sh)
set -euo pipefail

cd "$(dirname "$0")/.."

# UNIVERSAL=1 이면 인텔·애플 실리콘 겸용으로 빌드한다(배포용).
ARCH_FLAGS=()
if [[ "${UNIVERSAL:-0}" == "1" ]]; then
  ARCH_FLAGS=(--arch arm64 --arch x86_64)
fi
swift build -c release "${ARCH_FLAGS[@]}"

APP="Linkie.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$(swift build -c release "${ARCH_FLAGS[@]}" --show-bin-path)/Linkie" "$APP/Contents/MacOS/Linkie"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Linkie</string>
    <key>CFBundleDisplayName</key><string>Linkie</string>
    <key>CFBundleIdentifier</key><string>local.linkie.menubar</string>
    <key>CFBundleExecutable</key><string>Linkie</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <!-- 메뉴바 전용: Dock 아이콘 없음 -->
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP" >/dev/null
echo "완성: $(pwd)/$APP"
