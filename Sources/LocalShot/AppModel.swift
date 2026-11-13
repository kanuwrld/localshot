import AppKit
import LocalShotCore
import ServiceManagement
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
  @Published private(set) var shortcut: Shortcut
  @Published private(set) var isRecordingShortcut = false
  @Published private(set) var isCapturing = false
  @Published private(set) var launchAtLogin = false
  @Published private(set) var loginNeedsApproval = false
  @Published var message: String?
  @Published var shortcutError: String?
  @Published var playSound: Bool {
    didSet { defaults.set(playSound, forKey: "playSound") }
  }

  var onCaptureStateChange: ((Bool, CaptureOutcome?) -> Void)?
  var beforeCapture: (() -> Void)?
  var onShortcutChange: (() -> Void)?
  private let defaults: UserDefaults
  private let captureController = CaptureController()
  private var hotKey: GlobalHotKey?
  private var keyMonitor: Any?
  private var pendingShortcut: Shortcut?
  private var functionModifierDown = false

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    if let data = defaults.data(forKey: "shortcut"),
      let saved = try? JSONDecoder().decode(Shortcut.self, from: data),
      saved.validationError == nil
    {
      shortcut = saved
    } else {
      shortcut = .standard
    }
    playSound = defaults.bool(forKey: "playSound")
  }

  func start() {
    do {
      hotKey = try GlobalHotKey()
      hotKey?.onPress = { [weak self] in self?.capture() }
      try hotKey?.register(shortcut)
    } catch {
      shortcutError = error.localizedDescription
    }
    captureController.onComplete = { [weak self] outcome in
      guard let self else { return }
      self.isCapturing = false
      self.registerCurrentShortcut()
      switch outcome {
      case .copied: self.message = "Copied. Paste with ⌘V."
      case .cancelled: self.message = nil
      case .failed:
        self.showCaptureError(
          "Could not copy the screenshot. Check screen recording access and try again.")
      case .timedOut:
        self.showCaptureError("Selection closed after 5 minutes. Start a new capture to try again.")
      }
      self.onCaptureStateChange?(false, outcome)
    }
    refreshLoginStatus()
  }

  func capture() {
    guard !isCapturing, !isRecordingShortcut else { return }
    guard CGPreflightScreenCaptureAccess() else {
      showCaptureError(
        "Allow LocalShot to record your screen in System Settings. Choose Screen access to open it."
      )
      return
    }
    isCapturing = true
    // A bare Esc/Space/arrow shortcut must not steal the selector's own controls.
    hotKey?.unregister()
    message = nil
    onCaptureStateChange?(true, nil)
    beforeCapture?()
    // Let the menu and settings window disappear before the system capture UI opens.
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
      guard let self, self.isCapturing else { return }
      do {
        try self.captureController.capture(playSound: self.playSound)
      } catch {
        self.isCapturing = false
        self.registerCurrentShortcut()
        self.onCaptureStateChange?(false, .failed)
        self.showCaptureError(
          "Could not start area selection. Try restarting LocalShot.")
      }
    }
  }

  func beginRecordingShortcut() {
    guard !isRecordingShortcut, !isCapturing else { return }
    shortcutError = nil
    isRecordingShortcut = true
    hotKey?.unregister()
    functionModifierDown = NSEvent.modifierFlags.contains(.function)
    keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) {
      [weak self] event in
      let keyCode = event.keyCode
      let flags = event.modifierFlags
      let eventType = event.type
      let consumed = MainActor.assumeIsolated {
        guard let self else { return false }
        if eventType == .flagsChanged {
          // Unlike a keyDown from F1/arrows, this flag describes the actual held Fn key.
          self.functionModifierDown = flags.contains(.function)
          return false
        }
        if eventType == .keyUp {
          if let pending = self.pendingShortcut, pending.keyCode == UInt32(keyCode) {
            // Register after release so assigning a shortcut cannot trigger a screenshot.
            self.applyShortcut(pending)
            return true
          }
          return false
        }
        guard self.pendingShortcut == nil else { return true }
        var modifiers: UInt32 = 0
        if flags.contains(.command) { modifiers |= Shortcut.command }
        if flags.contains(.control) { modifiers |= Shortcut.control }
        if flags.contains(.option) { modifiers |= Shortcut.option }
        if flags.contains(.shift) { modifiers |= Shortcut.shift }
        if self.functionModifierDown { modifiers |= Shortcut.function }
        let newShortcut = Shortcut(keyCode: UInt32(keyCode), modifiers: modifiers)
        if let error = newShortcut.validationError {
          self.shortcutError = error
        } else {
          self.shortcutError = nil
          self.pendingShortcut = newShortcut
        }
        return true
      }
      return consumed ? nil : event
    }
  }

  func cancelRecordingShortcut() {
    guard isRecordingShortcut else { return }
    finishRecording()
    registerCurrentShortcut()
  }

  func resetShortcut() { applyShortcut(.standard) }

  private func applyShortcut(_ newShortcut: Shortcut) {
    finishRecording()
    do {
      if hotKey == nil {
        hotKey = try GlobalHotKey()
        hotKey?.onPress = { [weak self] in self?.capture() }
      }
      try hotKey?.register(newShortcut)
      shortcut = newShortcut
      defaults.set(try JSONEncoder().encode(newShortcut), forKey: "shortcut")
      shortcutError = nil
      onShortcutChange?()
    } catch {
      shortcutError = error.localizedDescription
      // Failed registration must not silently remove the previously working shortcut.
      registerCurrentShortcut()
    }
  }

  private func registerCurrentShortcut() {
    do { try hotKey?.register(shortcut) } catch { shortcutError = error.localizedDescription }
  }

  private func finishRecording() {
    if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
    keyMonitor = nil
    pendingShortcut = nil
    functionModifierDown = false
    isRecordingShortcut = false
  }

  func setLaunchAtLogin(_ enabled: Bool) {
    do {
      if enabled {
        try SMAppService.mainApp.register()
      } else {
        try SMAppService.mainApp.unregister()
      }
      message = nil
    } catch {
      message =
        "Could not change launch at login. Check General → Login Items in System Settings."
    }
    refreshLoginStatus()
  }

  func refreshLoginStatus() {
    let status = SMAppService.mainApp.status
    launchAtLogin = status == .enabled || status == .requiresApproval
    loginNeedsApproval = status == .requiresApproval
  }

  func openLoginSettings() { SMAppService.openSystemSettingsLoginItems() }

  func openScreenPermissionSettings() {
    // Only ask for broad screen access when the user explicitly opens this action.
    _ = CGRequestScreenCaptureAccess()
    if let url = URL(
      string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
    {
      NSWorkspace.shared.open(url)
    }
  }

  private func showCaptureError(_ text: String) {
    message = text
    NSApp.activate(ignoringOtherApps: true)
    let alert = NSAlert()
    alert.messageText = "Could not capture"
    alert.informativeText = text
    alert.addButton(withTitle: "OK")
    alert.addButton(withTitle: "Screen access…")
    if alert.runModal() == .alertSecondButtonReturn { openScreenPermissionSettings() }
  }

  func stop() {
    finishRecording()
    isCapturing = false
    captureController.stop()
    hotKey?.stop()
  }
}
