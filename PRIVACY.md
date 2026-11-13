# Privacy

LocalShot is an offline utility. The application has no networking code, analytics,
crash reporting service, accounts, license checks, or automatic updater. It has no
third-party package dependencies.

## Screenshots and clipboard

Normal capture invokes the built-in macOS screen capture tool with clipboard
output. LocalShot does not save screenshot files, maintain a history, or upload
images. Cancelling native selection leaves the previous clipboard content intact.
The app checks the clipboard change count and image types to confirm a new capture;
it does not record the clipboard's contents in logs.

The clipboard belongs to macOS. Other apps and macOS features such as Universal
Clipboard may use its contents according to your system settings.

## Keyboard

A Carbon hotkey registration handles the assigned shortcut. LocalShot does not
monitor global keyboard input. While you assign a shortcut in Settings, a local
event monitor reads keys in LocalShot only. That monitor is removed when recording
finishes, the window closes, or the app loses focus.

## Local storage

- UserDefaults stores the chosen shortcut, capture sound, and first-launch flag.
- macOS manages screen recording consent and launch-at-login registration.
- The build scripts keep a local signing key in the login Keychain, and a public
  certificate and fingerprint in the user's Application Support directory.
- The installer keeps previous app bundles in the ignored `output/backups/` folder.

No user preferences, signing identities, diagnostic logs, or build outputs are
part of the published source code.

## Optional diagnostic

The `--diagnose-capture` command is explicit, not a background task. It captures
one screen point into a temporary directory accessible only to the current user,
checks that the image can be decoded, then removes the directory. It does not
change the clipboard.

Its local JSON report contains the time, app version, permission result, exit code,
image dimensions, a fixed error description when needed, and pass/fail status.
It excludes image bytes, usernames, bundle paths, and raw command output. The app
never sends this report anywhere.

Before posting any bug report, review your attachments. Screenshots of other apps,
terminal output, and system logs can contain information unrelated to LocalShot.
