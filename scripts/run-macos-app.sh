#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="GenZFlow"
APP_DIR="$HOME/Applications/${APP_NAME}.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
LOCAL_CONFIG_FILE="$ROOT_DIR/GenZFlow/Config.swift"
LOG_FILE="$ROOT_DIR/.build/${APP_NAME}.log"

cd "$ROOT_DIR"

swift build
BUILD_DIR="$(swift build --show-bin-path)"

if [[ -z "${OPENAI_API_KEY:-}" && -f "$LOCAL_CONFIG_FILE" ]]; then
  OPENAI_API_KEY="$(sed -n 's/.*openAIAPIKey = \"\\(.*\\)\"/\\1/p' "$LOCAL_CONFIG_FILE" | head -n 1)"
fi

mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

rm -f "$MACOS_DIR/$APP_NAME"
cp "$BUILD_DIR/$APP_NAME" "$MACOS_DIR/$APP_NAME"
cp "$ROOT_DIR/GenZFlow/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$ROOT_DIR/GenZFlow/Resources/GenZFlow.entitlements" "$RESOURCES_DIR/GenZFlow.entitlements"

chmod +x "$MACOS_DIR/$APP_NAME"
codesign --force --deep --sign - "$APP_DIR"

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

if [[ -n "${OPENAI_API_KEY:-}" ]]; then
  env OPENAI_API_KEY="$OPENAI_API_KEY" "$MACOS_DIR/$APP_NAME" >>"$LOG_FILE" 2>&1 &
else
  echo "Warning: OPENAI_API_KEY is not set. Translation will fail until you provide one."
  "$MACOS_DIR/$APP_NAME" >>"$LOG_FILE" 2>&1 &
fi
