#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

APP_NAME="DevDeck"
PLIST_PATH="$ROOT_DIR/DevDeck/App/Info.plist"

if [[ $# -gt 0 ]]; then
  case "$1" in
    menu-bar|--menu-bar|window|--window|window-only|--window-only)
      echo "DevDeck is now a single app; building .build/DevDeck.app" >&2
      ;;
    *)
      echo "Usage: Scripts/build-app.sh" >&2
      exit 2
      ;;
  esac
fi

APP_DIR="$ROOT_DIR/.build/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

ARCH="$(uname -m)"
TARGET="${ARCH}-apple-macosx14.0"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

SWIFTC_ARGS=(
  -target "$TARGET"
  -parse-as-library
)

while IFS= read -r source_file; do
  SWIFTC_ARGS+=("$source_file")
done < <(find "$ROOT_DIR/DevDeck" -name '*.swift' | sort)

SWIFTC_ARGS+=(-o "$MACOS_DIR/$APP_NAME")

swiftc "${SWIFTC_ARGS[@]}"

cp "$PLIST_PATH" "$CONTENTS_DIR/Info.plist"
cp "$ROOT_DIR/DevDeck/App/Credits.rtf" "$RESOURCES_DIR/Credits.rtf"
cp "$ROOT_DIR/DevDeck/App/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"

echo "Built $APP_DIR"
