#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "Building app bundle..."
"$ROOT/scripts/run-mac.sh" --build-only >/dev/null

APP="$ROOT/.build/Network Speed Test.app"
OUT_DIR="$ROOT/docs/screenshots"

mkdir -p "$OUT_DIR"

echo "Exporting screenshots..."
SCREENSHOT_EXPORT=1 SCREENSHOT_DIR="$OUT_DIR" "$APP/Contents/MacOS/NetworkTestApp"

echo "Saved screenshots to $OUT_DIR"
