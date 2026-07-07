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
BUILD_DIR="$ROOT_DIR/.build/universal"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
SDK_PATH="$(xcrun --show-sdk-path --sdk macosx)"
ARCHS="${ARCHS:-arm64 x86_64}"

rm -rf "$APP_DIR"
rm -rf "$BUILD_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

SOURCE_FILES=()
while IFS= read -r source_file; do
  SOURCE_FILES+=("$source_file")
done < <(find "$ROOT_DIR/DevDeck" -name '*.swift' | sort)

mkdir -p "$BUILD_DIR"

BUILT_BINARIES=()
for arch in $ARCHS; do
  target="${arch}-apple-macosx14.0"
  binary_path="$BUILD_DIR/$APP_NAME-$arch"

  xcrun swiftc \
    -sdk "$SDK_PATH" \
    -target "$target" \
    -parse-as-library \
    "${SOURCE_FILES[@]}" \
    -o "$binary_path"

  BUILT_BINARIES+=("$binary_path")
done

if ((${#BUILT_BINARIES[@]} == 1)); then
  cp "${BUILT_BINARIES[0]}" "$MACOS_DIR/$APP_NAME"
else
  lipo -create "${BUILT_BINARIES[@]}" -output "$MACOS_DIR/$APP_NAME"
fi

chmod +x "$MACOS_DIR/$APP_NAME"

cp "$PLIST_PATH" "$CONTENTS_DIR/Info.plist"
cp "$ROOT_DIR/DevDeck/App/Credits.rtf" "$RESOURCES_DIR/Credits.rtf"
cp "$ROOT_DIR/DevDeck/App/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"

codesign --force --deep --sign - "$APP_DIR"

echo "Built $APP_DIR"
