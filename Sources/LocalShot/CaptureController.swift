import AppKit
import LocalShotCore

@MainActor
final class CaptureController {
  private var process: Process?
  private var timeout: DispatchWorkItem?
  private var didTimeOut = false
  var isRunning: Bool { process != nil }
  var onComplete: ((CaptureOutcome) -> Void)?

  func capture(playSound: Bool) throws {
    guard process == nil else { return }
    let initialChangeCount = NSPasteboard.general.changeCount
    let task = Process()
    let errors = Pipe()
    task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
    task.arguments = ["-i", "-s", "-c"] + (playSound ? [] : ["-x"])
    task.standardOutput = FileHandle.nullDevice
    task.standardError = errors
    didTimeOut = false
    task.terminationHandler = { [weak self] finished in
      let exitCode = finished.terminationStatus
      let hasErrors = !errors.fileHandleForReading.readDataToEndOfFile().isEmpty
      Task { @MainActor [weak self] in
        guard let self, self.process === finished else { return }
        self.timeout?.cancel()
        self.timeout = nil
        self.process = nil
        let pasteboard = NSPasteboard.general
        let outcome = CaptureOutcome.resolve(
          exitCode: exitCode,
          clipboardChanged: pasteboard.changeCount != initialChangeCount,
          clipboardHasImage: pasteboard.availableType(from: [.png, .tiff]) != nil,
          hasErrorOutput: hasErrors,
          timedOut: self.didTimeOut
        )
        self.onComplete?(outcome)
      }
    }
    process = task
    do {
      try task.run()
    } catch {
      process = nil
      throw error
    }
    let timeout = DispatchWorkItem { [weak self] in
      guard let self, let process = self.process, process.isRunning else { return }
      self.didTimeOut = true
      process.terminate()
    }
    self.timeout = timeout
    DispatchQueue.main.asyncAfter(deadline: .now() + 300, execute: timeout)
  }

  func stop() {
    timeout?.cancel()
    timeout = nil
    process?.terminationHandler = nil
    if let process, process.isRunning { process.terminate() }
    process = nil
  }
}
