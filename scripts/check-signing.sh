#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_BUNDLE="$PROJECT_ROOT/dist/LocalShot.app"
SIGNING_IDENTITY="$("$PROJECT_ROOT/scripts/setup-signing.sh")"
CHECK_DIRECTORY="$(mktemp -d "$PROJECT_ROOT/.build/signing-check.XXXXXX")"
REQUIREMENT="$(codesign -dr - "$APP_BUNDLE" 2>&1 | sed -n 's/^designated => //p')"
if [ -z "$REQUIREMENT" ] || [[ "$REQUIREMENT" != *"certificate leaf"* ]]; then
    printf 'FAIL: signature does not pin a persistent signing certificate.\n' >&2
    exit 1
fi
ditto "$APP_BUNDLE" "$CHECK_DIRECTORY/Updated.app"
printf 'print("A different LocalShot executable for the signing regression check")\n' > "$CHECK_DIRECTORY/main.swift"
swiftc "$CHECK_DIRECTORY/main.swift" -o "$CHECK_DIRECTORY/Updated.app/Contents/MacOS/LocalShot"
codesign --force --sign "$SIGNING_IDENTITY" --keychain "$HOME/Library/Keychains/login.keychain-db" \
    --timestamp=none "$CHECK_DIRECTORY/Updated.app"
codesign --verify --strict -R "=$REQUIREMENT" "$CHECK_DIRECTORY/Updated.app"
printf 'PASS: a different executable signed with the same identity satisfies the original requirement.\n'
codesign --force --sign - "$CHECK_DIRECTORY/Updated.app"
if codesign --verify --strict -R "=$REQUIREMENT" "$CHECK_DIRECTORY/Updated.app" >/dev/null 2>&1; then
    printf 'FAIL: a different signer was accepted.\n' >&2
    exit 1
fi
printf 'PASS: a different signer with the same bundle ID is rejected.\n'
