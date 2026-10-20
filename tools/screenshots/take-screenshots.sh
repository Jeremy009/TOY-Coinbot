#!/usr/bin/env bash
# Regenerates the README screenshots in docs/screenshots/.
#
# Builds the app for the iOS Simulator and launches it in demo mode (see
# Coinbot/Utilities/DemoMode.swift), so every screen shows fictional data and
# no Bitvavo account is needed. Run it from anywhere; requires Xcode.
#
#   tools/screenshots/take-screenshots.sh ["iPhone 17 Pro"]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="$ROOT/docs/screenshots"
DEVICE_NAME="${1:-iPhone 17 Pro}"
BUNDLE_ID="com.takeitup.coinbot010"
BUILD_DIR="$(mktemp -d)"
trap 'rm -rf "$BUILD_DIR"' EXIT

DEVICE_ID="$(xcrun simctl list devices available -j | python3 -c "
import json, sys
devices = json.load(sys.stdin)['devices']
matches = [d['udid'] for runtime in sorted(devices, reverse=True) for d in devices[runtime] if d['name'] == '$DEVICE_NAME']
print(matches[0] if matches else '')
")"
[ -n "$DEVICE_ID" ] || { echo "No simulator named '$DEVICE_NAME'"; exit 1; }

echo "Building for $DEVICE_NAME ($DEVICE_ID)..."
xcodebuild -project "$ROOT/Coinbot.xcodeproj" -scheme Coinbot \
  -destination "id=$DEVICE_ID" -derivedDataPath "$BUILD_DIR" \
  CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= build -quiet 2>&1 | grep -E "error:" || true
APP="$BUILD_DIR/Build/Products/Debug-iphonesimulator/Coinbot.app"

xcrun simctl boot "$DEVICE_ID" 2>/dev/null || true
xcrun simctl bootstatus "$DEVICE_ID" >/dev/null
xcrun simctl ui "$DEVICE_ID" appearance light
xcrun simctl status_bar "$DEVICE_ID" override --time 9:41 --batteryState charged \
  --batteryLevel 100 --cellularBars 4 --wifiBars 3
xcrun simctl uninstall "$DEVICE_ID" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl install "$DEVICE_ID" "$APP"

mkdir -p "$OUT"
shoot() {  # shoot <file> <launch arguments...>
  local file="$1"; shift
  xcrun simctl terminate "$DEVICE_ID" "$BUNDLE_ID" 2>/dev/null || true
  xcrun simctl launch "$DEVICE_ID" "$BUNDLE_ID" -demo "$@" >/dev/null
  sleep 4
  xcrun simctl io "$DEVICE_ID" screenshot --type=png "$OUT/$file" >/dev/null 2>&1
  echo "  $file"
}

shoot 01-lock-screen.png -demoLocked
shoot 02-assets.png -demoTab assets
shoot 03-orders.png -demoTab orders
shoot 04-settings.png -demoTab settings
shoot 05-bots.png -demoTab bots

xcrun simctl terminate "$DEVICE_ID" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl status_bar "$DEVICE_ID" clear
echo "Screenshots written to $OUT"
