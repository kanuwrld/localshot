import AppKit

@MainActor
enum CaptureDiagnostic {
  struct Report: Encodable {
    var timestamp = Date()
    var version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    var screenAccess = CGPreflightScreenCaptureAccess()
    var captureExitCode: Int32?
    var imageWidth: Int?
    var imageHeight: Int?
    var error: String?
    var passed = false
  }

  // Run through LaunchServices with --diagnose-capture: a direct shell launch has
  // a different TCC responsible process and would test the terminal's permission.
  static func run() {
    var report = Report()
    let files = FileManager.default
    let temporary = files.temporaryDirectory.appendingPathComponent(
      "LocalShot-check-\(UUID().uuidString)")
    defer { try? files.removeItem(at: temporary) }
    do {
      try files.createDirectory(
        at: temporary, withIntermediateDirectories: false,
        attributes: [.posixPermissions: 0o700])
      let imageURL = temporary.appendingPathComponent("pixel.png")
      let task = Process()
      let errors = Pipe()
      task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
      task.arguments = ["-x", "-R0,0,1,1", "-t", "png", imageURL.path]
      task.standardOutput = FileHandle.nullDevice
      task.standardError = errors
      try task.run()
      task.waitUntilExit()
      report.captureExitCode = task.terminationStatus
      let errorData = errors.fileHandleForReading.readDataToEndOfFile()
      if !errorData.isEmpty {
        report.error = "The system screen capture command reported an error."
      }
      if let data = try? Data(contentsOf: imageURL), let image = NSBitmapImageRep(data: data) {
        report.imageWidth = image.pixelsWide
        report.imageHeight = image.pixelsHigh
        report.passed = task.terminationStatus == 0 && image.pixelsWide > 0 && image.pixelsHigh > 0
      }
    } catch {
      report.error = "Could not run the screen capture check."
    }
    let directory = files.homeDirectoryForCurrentUser.appendingPathComponent(
      "Library/Logs/LocalShot")
    do {
      try files.createDirectory(
        at: directory, withIntermediateDirectories: true,
        attributes: [.posixPermissions: 0o700])
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
      encoder.dateEncodingStrategy = .iso8601
      try encoder.encode(report).write(
        to: directory.appendingPathComponent("capture-check.json"), options: .atomic)
    } catch {
      NSLog("LocalShot could not save capture diagnostics.")
    }
  }
}
