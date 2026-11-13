# LocalShot

Native macOS menu bar app. Swift 6, AppKit, SwiftUI, Carbon and ServiceManagement;
no third-party packages, web server, accounts or network calls. macOS 13+.

- `swift test`: shortcut validation and capture outcome regression tests.
- `swift build -c release`: compile and typecheck.
- `swift-format lint --strict --recursive Sources Tests Package.swift`: lint.
- `./scripts/build.sh`: build `dist/LocalShot.app` with the persistent local signing identity.
- `./scripts/check-signing.sh`: check update identity stability and rejection of another signer.
- `./scripts/install.sh`: install in `~/Applications`, keeping the previous version.

Capture uses `/usr/sbin/screencapture -i -s -c -x`; keep selection native, preserve
the clipboard on cancellation, and never save screenshots or send them anywhere.
Use Carbon registered hotkeys instead of global keyboard monitoring. Settings are
local UserDefaults. Autostart uses SMAppService.mainApp. Do not change other apps'
shortcuts or macOS screenshot preferences. Keep UI text in English.

Test actual selection, clipboard image, Escape, global hotkey and settings in the
installed app. Do not equate a build or process launch with verified capture.
Run `open -n -g ~/Applications/LocalShot.app --args --diagnose-capture` to test the
installed app's own screen permission. Read `~/Library/Logs/LocalShot/capture-check.json`.
This explicit diagnostic captures one pixel into a private temporary directory,
removes it, and leaves the clipboard unchanged. Never test TCC from a shell-launched
binary: macOS can attribute that access to the terminal instead of LocalShot.
Do not fall back to ad-hoc signing: it changes the designated requirement and
breaks existing TCC consent after every update. Do not edit the TCC database.
