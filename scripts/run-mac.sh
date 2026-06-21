#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

swift build
BINARY="$ROOT/.build/debug/NetworkTestApp"
if [[ ! -f "$BINARY" ]]; then
  BINARY="$ROOT/.build/arm64-apple-macosx/debug/NetworkTestApp"
fi

RESOURCE_BUNDLE="$ROOT/.build/debug/NetworkTest_NetworkTestApp.bundle"
if [[ ! -d "$RESOURCE_BUNDLE" ]]; then
  RESOURCE_BUNDLE="$ROOT/.build/arm64-apple-macosx/debug/NetworkTest_NetworkTestApp.bundle"
fi

APP="$ROOT/.build/Network Speed Test.app"
ICON_SOURCE="$ROOT/Sources/NetworkTestApp/Resources/AppIcon.png"
ROUNDED_ICON="$ROOT/.build/AppIcon-rounded.png"
ICONSET="$ROOT/.build/NetworkTestApp.iconset"
ICNS="$APP/Contents/Resources/AppIcon.icns"

rm -rf "$APP" "$ICONSET"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$ICONSET"

cp "$BINARY" "$APP/Contents/MacOS/NetworkTestApp"
chmod +x "$APP/Contents/MacOS/NetworkTestApp"

if [[ -d "$RESOURCE_BUNDLE" ]]; then
  cp -R "$RESOURCE_BUNDLE" "$APP/NetworkTest_NetworkTestApp.bundle"
fi

python3 - "$ICON_SOURCE" "$ROUNDED_ICON" <<'PY'
import sys
from PIL import Image, ImageDraw

source, output = sys.argv[1], sys.argv[2]
image = Image.open(source).convert("RGBA")
side = min(image.size)
left = (image.width - side) // 2
top = (image.height - side) // 2
image = image.crop((left, top, left + side, top + side)).resize((1024, 1024), Image.LANCZOS)

mask = Image.new("L", (1024, 1024), 0)
draw = ImageDraw.Draw(mask)
draw.rounded_rectangle((0, 0, 1024, 1024), radius=220, fill=255)
image.putalpha(mask)
image.save(output)
PY

sips -z 16 16 "$ROUNDED_ICON" --out "$ICONSET/icon_16x16.png" >/dev/null
sips -z 32 32 "$ROUNDED_ICON" --out "$ICONSET/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$ROUNDED_ICON" --out "$ICONSET/icon_32x32.png" >/dev/null
sips -z 64 64 "$ROUNDED_ICON" --out "$ICONSET/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$ROUNDED_ICON" --out "$ICONSET/icon_128x128.png" >/dev/null
sips -z 256 256 "$ROUNDED_ICON" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$ROUNDED_ICON" --out "$ICONSET/icon_256x256.png" >/dev/null
sips -z 512 512 "$ROUNDED_ICON" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$ROUNDED_ICON" --out "$ICONSET/icon_512x512.png" >/dev/null
sips -z 1024 1024 "$ROUNDED_ICON" --out "$ICONSET/icon_512x512@2x.png" >/dev/null
iconutil -c icns "$ICONSET" -o "$ICNS"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>NetworkTestApp</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleIdentifier</key>
  <string>io.github.network-speed-test.app</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>Network Speed Test</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>2</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

pkill -x NetworkTestApp 2>/dev/null || true
if [[ "${1:-}" == "--build-only" ]]; then
  exit 0
fi
open "$APP"
