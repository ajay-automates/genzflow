#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="GenZFlow"
APP_DIR="$HOME/Applications/${APP_NAME}.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

cd "$ROOT_DIR"

swift build
BUILD_DIR="$(swift build --show-bin-path)"

mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

rm -f "$MACOS_DIR/$APP_NAME"
cp "$BUILD_DIR/$APP_NAME" "$MACOS_DIR/$APP_NAME"
cp "$ROOT_DIR/GenZFlow/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$ROOT_DIR/GenZFlow/Resources/GenZFlow.entitlements" "$RESOURCES_DIR/GenZFlow.entitlements"

chmod +x "$MACOS_DIR/$APP_NAME"
codesign --force --deep --sign - "$APP_DIR"

open "$APP_DIR"
