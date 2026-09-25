#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="Roast"
APP_BUNDLE="$SCRIPT_DIR/$APP_NAME.app"
BUNDLE_ID="com.toby.roast"

echo "Building $APP_NAME..."
cd "$SCRIPT_DIR"
swift build -c release --product Roast

echo "Assembling app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

EXECUTABLE=$(find .build -path "*/release/Roast" -type f ! -path "*.dSYM*" | head -1)
if [ -z "$EXECUTABLE" ]; then
    echo "Error: Roast executable not found in .build/release/" >&2
    exit 1
fi

cp "$EXECUTABLE" "$APP_BUNDLE/Contents/MacOS/Roast"
cp Info.plist "$APP_BUNDLE/Contents/Info.plist"
cp AppIcon.icns "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

echo "Signing ad-hoc..."
codesign --force --sign - --identifier "$BUNDLE_ID" "$APP_BUNDLE"
codesign --verify --deep --strict "$APP_BUNDLE"

echo "Done: $APP_BUNDLE"

if [ "${1:-}" = "--install" ]; then
    echo "Installing to /Applications..."
    mkdir -p "/Applications/$APP_NAME.app"
    rsync -a --delete "$APP_BUNDLE/" "/Applications/$APP_NAME.app/"
    echo "Installed to /Applications/$APP_NAME.app"
fi
