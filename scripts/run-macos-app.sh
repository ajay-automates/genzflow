#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="GenZFlow"
APP_DIR="/Applications/${APP_NAME}.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
LOCAL_CONFIG_FILE="$ROOT_DIR/GenZFlow/Config.swift"
APP_SUPPORT_DIR="$HOME/Library/Application Support/${APP_NAME}"
APP_SUPPORT_CONFIG="$APP_SUPPORT_DIR/LocalConfig.plist"

cd "$ROOT_DIR"

swift build
BUILD_DIR="$(swift build --show-bin-path)"

if [[ -z "${OPENAI_API_KEY:-}" && -f "$LOCAL_CONFIG_FILE" ]]; then
  OPENAI_API_KEY="$(awk -F'\"' '/openAIAPIKey/ { print $2; exit }' "$LOCAL_CONFIG_FILE")"
fi

mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
mkdir -p "$APP_SUPPORT_DIR"

rm -f "$MACOS_DIR/$APP_NAME"
cp "$BUILD_DIR/$APP_NAME" "$MACOS_DIR/$APP_NAME"
cp "$ROOT_DIR/GenZFlow/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$ROOT_DIR/GenZFlow/Resources/GenZFlow.entitlements" "$RESOURCES_DIR/GenZFlow.entitlements"

chmod +x "$MACOS_DIR/$APP_NAME"
codesign --force --deep --sign - "$APP_DIR"

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

if [[ -n "${OPENAI_API_KEY:-}" ]]; then
  cat >"$APP_SUPPORT_CONFIG" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>OPENAI_API_KEY</key>
    <string>$OPENAI_API_KEY</string>
</dict>
</plist>
EOF
else
  echo "Warning: OPENAI_API_KEY is not set. Translation will fail until you provide one."
fi

open "$APP_DIR"
echo "Installed GenZFlow to $APP_DIR"
echo "App support config: $APP_SUPPORT_CONFIG"
