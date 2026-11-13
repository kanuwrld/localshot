import AppKit

@main
struct LocalShotMain {
  @MainActor
  static func main() {
    let app = NSApplication.shared
    if CommandLine.arguments.contains("--diagnose-capture") {
      app.setActivationPolicy(.prohibited)
      CaptureDiagnostic.run()
      return
    }
    let delegate = AppDelegate()
    app.delegate = delegate
    withExtendedLifetime(delegate) { app.run() }
  }
}
