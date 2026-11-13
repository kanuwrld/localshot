#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

# Preserve an installed copy's preferences and screen permission when updating.
# New installations use the public identifier in Resources/Info.plist.
INSTALLED_INFO="$HOME/Applications/LocalShot.app/Contents/Info.plist"
BUNDLE_IDENTIFIER="${LOCALSHOT_BUNDLE_ID:-}"
if [ -z "$BUNDLE_IDENTIFIER" ] && [ -f "$INSTALLED_INFO" ]; then
    BUNDLE_IDENTIFIER="$(plutil -extract CFBundleIdentifier raw -o - "$INSTALLED_INFO")"
fi
if [ -n "$BUNDLE_IDENTIFIER" ] && [[ ! "$BUNDLE_IDENTIFIER" =~ ^[A-Za-z0-9][A-Za-z0-9.-]+$ ]]; then
    printf 'Invalid LOCALSHOT_BUNDLE_ID or installed bundle identifier.\n' >&2
    exit 1
fi

SIGNING_IDENTITY="$("$PROJECT_ROOT/scripts/setup-signing.sh")"
swift build -c release
BIN_DIRECTORY="$(swift build -c release --show-bin-path)"
APP_BUNDLE="$PROJECT_ROOT/dist/LocalShot.app"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources" "$PROJECT_ROOT/.build/AppIcon.iconset"
cp "$BIN_DIRECTORY/LocalShot" "$APP_BUNDLE/Contents/MacOS/LocalShot"
cp Resources/Info.plist "$APP_BUNDLE/Contents/Info.plist"
if [ -n "$BUNDLE_IDENTIFIER" ]; then
    plutil -replace CFBundleIdentifier -string "$BUNDLE_IDENTIFIER" "$APP_BUNDLE/Contents/Info.plist"
fi
swift scripts/make-icon.swift "$PROJECT_ROOT/.build/AppIcon.iconset"
iconutil -c icns "$PROJECT_ROOT/.build/AppIcon.iconset" -o "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
plutil -lint "$APP_BUNDLE/Contents/Info.plist"
codesign --force --sign "$SIGNING_IDENTITY" --keychain "$HOME/Library/Keychains/login.keychain-db" --timestamp=none "$APP_BUNDLE"
codesign --verify --deep --strict "$APP_BUNDLE"
printf 'Built: %s\n' "$APP_BUNDLE"
