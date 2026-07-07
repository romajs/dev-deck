#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="DevDeck"
APP_DIR="$ROOT_DIR/.build/$APP_NAME.app"
DIST_DIR="$ROOT_DIR/dist"
RELEASE_NAME="${1:-}"

if [[ -z "$RELEASE_NAME" ]]; then
  RELEASE_NAME="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT_DIR/DevDeck/App/Info.plist")"
fi

"$ROOT_DIR/Scripts/build-app.sh"

lipo "$APP_DIR/Contents/MacOS/$APP_NAME" -verify_arch arm64 x86_64
codesign --verify --deep --strict --verbose=2 "$APP_DIR"

rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

ZIP_PATH="$DIST_DIR/$APP_NAME-$RELEASE_NAME.zip"
CHECKSUM_PATH="$ZIP_PATH.sha256"

ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$ZIP_PATH"
checksum="$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')"
printf "%s  %s\n" "$checksum" "$(basename "$ZIP_PATH")" > "$CHECKSUM_PATH"

echo "Packaged $ZIP_PATH"
echo "Checksum $CHECKSUM_PATH"
