#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE_APP="$PROJECT_ROOT/dist/LocalShot.app"
TARGET_DIRECTORY="$HOME/Applications"
TARGET_APP="$TARGET_DIRECTORY/LocalShot.app"
if [ ! -d "$SOURCE_APP" ]; then
    "$PROJECT_ROOT/scripts/build.sh"
fi
if /usr/bin/pgrep -x LocalShot >/dev/null; then
    printf 'Quit LocalShot from its menu before installing.\n' >&2
    exit 1
fi
codesign --verify --deep --strict "$SOURCE_APP"
if [ -d "$TARGET_APP" ]; then
    SOURCE_ID="$(plutil -extract CFBundleIdentifier raw -o - "$SOURCE_APP/Contents/Info.plist")"
    TARGET_ID="$(plutil -extract CFBundleIdentifier raw -o - "$TARGET_APP/Contents/Info.plist")"
    if [ "$SOURCE_ID" != "$TARGET_ID" ]; then
        printf 'The installed copy uses a different bundle identifier. Rebuild without LOCALSHOT_BUNDLE_ID before updating.\n' >&2
        exit 1
    fi
fi
mkdir -p "$TARGET_DIRECTORY"
if [ -e "$TARGET_APP" ]; then
    BACKUP_DIRECTORY="$PROJECT_ROOT/output/backups/$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$BACKUP_DIRECTORY"
    mv "$TARGET_APP" "$BACKUP_DIRECTORY/LocalShot.app"
    printf 'Previous version: %s\n' "$BACKUP_DIRECTORY/LocalShot.app"
fi
ditto "$SOURCE_APP" "$TARGET_APP"
codesign --verify --deep --strict "$TARGET_APP"
open "$TARGET_APP" --args --settings
printf 'Installed: %s\n' "$TARGET_APP"
