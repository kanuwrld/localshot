# LocalShot

**Select. Copy. Paste.**

A small, native macOS menu bar app that copies a selected area straight to your
clipboard. No account, subscription, analytics, or network connection. MIT licensed.

## Use

1. Open LocalShot from `~/Applications`.
2. Press **⌃⌥S** (Control + Option + S) and drag to select an area.
3. Paste with **⌘V**.

**Esc** cancels without replacing your clipboard. A checkmark in the menu bar
confirms a successful copy. Closing Settings leaves LocalShot running in the menu
bar, without a Dock icon.

Open **Settings…** from the menu bar to change the shortcut, launch at login, or
capture sound. The interface follows your Mac's light or dark appearance.

### Your shortcut

Assign a single key or a combination with Command, Control, Option, Shift, or Fn.
Letters, numbers, punctuation, navigation keys, Esc, Return, Tab, Space, Delete,
F1–F20, and numpad / ISO / JIS keys are supported. Shortcuts follow physical key
positions across keyboard layouts.

A single key replaces its usual input while LocalShot is running. During capture,
the shortcut is temporarily released so the native selection controls still work.
Click **Cancel** to stop recording a shortcut; Esc itself can be assigned.

macOS decides whether a shortcut is available. If registration fails, the previous
shortcut is restored. Modifier-only keys, media events, Power, and Touch ID are not
supported by the Carbon hotkey API. For the Mac's top row, use function-key mode.
LocalShot never changes another app's shortcuts or the system screenshot settings.

## Build and install

Requires **macOS 13+** and a **Swift 6** toolchain with the macOS SDK
(Xcode or compatible Command Line Tools). There are no package dependencies.
Builds target the architecture of the Mac running the build.

```sh
git clone https://github.com/kanuwrld/localshot.git
cd localshot
swift test
./scripts/build.sh
./scripts/install.sh
```

The bundle is built at `dist/LocalShot.app` and installed into `~/Applications`.
Quit an existing copy before updating. The installer keeps the previous app in
`output/backups/` and rejects an update with a different bundle identifier.

On first launch, LocalShot enables launch at login. Disable it in Settings if you
prefer manual startup. Turn it off before uninstalling the app.

### Screen access

Choose **Screen access…**, then enable LocalShot under **Privacy & Security →
Screen Recording** in System Settings (the wording varies by macOS version).
Restart the app if macOS requests it. LocalShot does not need Accessibility or
Input Monitoring permission.

### Local signing

The first build creates a persistent, self-signed code signing identity in your
login Keychain. Only `codesign` is granted access to its private key. The identity
fingerprint is kept in
`~/Library/Application Support/LocalShot/Signing/identity.sha1`.
No signing key is included in this repository. No Apple Developer membership,
Apple account, or paid certificate is needed for this local build process.

Keep that identity when updating: a stable signature lets macOS recognize later
builds as the same app. If the pinned key is missing, the build fails rather than
silently replacing it. The scripts do not change trusted root certificates.

New installations use `app.localshot.LocalShot`. When updating an installed copy,
the build reuses its bundle identifier to preserve preferences and screen consent.
`LOCALSHOT_BUNDLE_ID` is an optional build override for a separate installation.

This is a **source release for local builds**, without a notarized download or an
automatic updater. Do not distribute your signing keys or local build artifacts.

## Development

```sh
swift test
swift build -c release
swift-format lint --strict --recursive Sources Tests Package.swift scripts/make-icon.swift
for script in scripts/*.sh; do bash -n "$script"; done
./scripts/build.sh
./scripts/check-signing.sh
```

The signing regression check verifies that an updated executable signed by the
same identity is accepted, and a different signer with the same bundle ID is
rejected. GitHub Actions runs tests, compilation, formatting, and script checks.

For an explicit check of the **installed app's** screen permission:

```sh
open -n -g ~/Applications/LocalShot.app --args --diagnose-capture
cat ~/Library/Logs/LocalShot/capture-check.json
```

Wait for the report's timestamp to update. `passed: true` and `captureExitCode: 0`
confirm capture. This check captures one point at the top-left of the screen into
a private temporary directory, deletes the image, and leaves the clipboard alone.
The report has no image, username, machine path, or raw command output. Launch the
app bundle as shown: running the executable from a terminal can test the terminal's
permission instead.

A successful build or diagnostic does not replace testing native selection,
clipboard paste, Esc cancellation, shortcut changes, and the global shortcut in the
installed app. Test additional monitors and keyboard hardware where available.

## How it works

- **AppKit + SwiftUI** — menu bar lifecycle and compact native settings.
- **Carbon `RegisterEventHotKey`** — a registered shortcut without global keyboard monitoring.
- **`/usr/sbin/screencapture -i -s -c -x`** — native selection directly into the clipboard.
- **UserDefaults + SMAppService** — local preferences and launch at login.

Normal capture creates no screenshot files or history. Concurrent captures are
blocked, and an unfinished selection times out after five minutes.
See [PRIVACY.md](PRIVACY.md) for the complete data flow.

## License

[MIT](LICENSE). Free to use, modify, and share.
