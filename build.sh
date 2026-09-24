#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="Roast"
APP_BUNDLE="$SCRIPT_DIR/$APP_NAME.app"
BUNDLE_ID="com.toby.roast"
SIGN_IDENTITY="${SIGN_IDENTITY:-Roast Dev}"

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

if ! security find-identity -p codesigning | grep -q "\"$SIGN_IDENTITY\""; then
    echo "Warning: signing identity \"$SIGN_IDENTITY\" not found, signing ad-hoc (permissions reset on every rebuild)" >&2
    SIGN_IDENTITY="-"
fi

echo "Signing with $SIGN_IDENTITY..."
codesign --force --sign "$SIGN_IDENTITY" --identifier "$BUNDLE_ID" "$APP_BUNDLE"
codesign --verify --deep --strict "$APP_BUNDLE"

echo "Done: $APP_BUNDLE"

if [ "${1:-}" = "--install" ]; then
    echo "Installing to /Applications..."
    mkdir -p "/Applications/$APP_NAME.app"
    rsync -a --delete "$APP_BUNDLE/" "/Applications/$APP_NAME.app/"
    echo "Installed to /Applications/$APP_NAME.app"
fi
