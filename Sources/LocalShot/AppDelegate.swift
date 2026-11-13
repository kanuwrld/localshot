import AppKit
import LocalShotCore
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSWindowDelegate {
  private let model = AppModel()
  private var statusItem: NSStatusItem?
  private var captureMenuItem: NSMenuItem?
  private var settingsWindow: NSWindow?
  private var feedbackReset: DispatchWorkItem?

  func applicationDidFinishLaunching(_ notification: Notification) {
    guard !anotherInstanceIsRunning() else {
      NSApp.terminate(nil)
      return
    }
    NSApp.setActivationPolicy(.accessory)
    configureMainMenu()
    configureStatusItem()
    model.onCaptureStateChange = { [weak self] running, result in
      self?.updateStatus(running: running, outcome: result)
    }
    model.beforeCapture = { [weak self] in
      self?.statusItem?.menu?.cancelTracking()
      self?.settingsWindow?.orderOut(nil)
      NSApp.hide(nil)
    }
    model.onShortcutChange = { [weak self] in self?.updateMenu() }
    model.start()
    let firstLaunch = !UserDefaults.standard.bool(forKey: "hasLaunched")
    if firstLaunch {
      UserDefaults.standard.set(true, forKey: "hasLaunched")
      model.setLaunchAtLogin(true)
    }
    if firstLaunch || CommandLine.arguments.contains("--settings") || model.shortcutError != nil {
      showSettings()
    }
  }

  private func anotherInstanceIsRunning() -> Bool {
    guard let identifier = Bundle.main.bundleIdentifier else { return false }
    let others = NSRunningApplication.runningApplications(withBundleIdentifier: identifier)
      .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
    guard let existing = others.first else { return false }
    existing.activate(options: [.activateIgnoringOtherApps])
    return true
  }

  private func configureMainMenu() {
    let mainMenu = NSMenu()
    let appItem = NSMenuItem()
    let appMenu = NSMenu()
    let settings = NSMenuItem(
      title: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
    settings.target = self
    appMenu.addItem(settings)
    appMenu.addItem(.separator())
    appMenu.addItem(
      withTitle: "Quit LocalShot", action: #selector(NSApplication.terminate(_:)),
      keyEquivalent: "q")
    appItem.submenu = appMenu
    mainMenu.addItem(appItem)
    NSApp.mainMenu = mainMenu
  }

  private func configureStatusItem() {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    statusItem = item
    setIcon("viewfinder", label: "LocalShot — capture area")
    let menu = NSMenu()
    menu.delegate = self
    menu.autoenablesItems = false
    let title = NSMenuItem(title: "LocalShot", action: nil, keyEquivalent: "")
    title.isEnabled = false
    menu.addItem(title)
    let capture = NSMenuItem(title: "", action: #selector(takeScreenshot), keyEquivalent: "")
    capture.target = self
    menu.addItem(capture)
    captureMenuItem = capture
    menu.addItem(.separator())
    let settings = NSMenuItem(
      title: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
    settings.target = self
    menu.addItem(settings)
    menu.addItem(.separator())
    menu.addItem(
      withTitle: "Quit LocalShot", action: #selector(NSApplication.terminate(_:)),
      keyEquivalent: "q")
    item.menu = menu
    updateMenu()
  }

  private func setIcon(_ symbol: String, label: String) {
    let image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
    image?.isTemplate = true
    statusItem?.button?.image = image
    statusItem?.button?.toolTip = label
    statusItem?.button?.setAccessibilityLabel(label)
  }

  private func updateStatus(running: Bool, outcome: CaptureOutcome?) {
    feedbackReset?.cancel()
    if running {
      setIcon("crop", label: "LocalShot — select an area; Esc to cancel")
    } else if outcome == .copied {
      setIcon("checkmark", label: "LocalShot — copied to clipboard")
      let reset = DispatchWorkItem { [weak self] in
        self?.setIcon("viewfinder", label: "LocalShot — capture area")
      }
      feedbackReset = reset
      DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: reset)
    } else {
      setIcon("viewfinder", label: "LocalShot — capture area")
    }
    updateMenu()
  }

  private func updateMenu() {
    captureMenuItem?.title = "Capture area    \(model.shortcut.display)"
    captureMenuItem?.isEnabled = !model.isCapturing && !model.isRecordingShortcut
  }

  func menuWillOpen(_ menu: NSMenu) {
    model.refreshLoginStatus()
    updateMenu()
  }

  @objc private func takeScreenshot() { model.capture() }

  @objc private func showSettings() {
    if settingsWindow == nil {
      let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 440, height: 380),
        styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false
      )
      window.title = "LocalShot"
      window.contentViewController = NSHostingController(rootView: SettingsView(model: model))
      window.isReleasedWhenClosed = false
      window.delegate = self
      window.center()
      settingsWindow = window
    }
    model.refreshLoginStatus()
    NSApp.activate(ignoringOtherApps: true)
    settingsWindow?.makeKeyAndOrderFront(nil)
  }

  func windowWillClose(_ notification: Notification) { model.cancelRecordingShortcut() }

  func applicationDidResignActive(_ notification: Notification) { model.cancelRecordingShortcut() }

  func applicationDidBecomeActive(_ notification: Notification) { model.refreshLoginStatus() }

  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool
  {
    showSettings()
    return true
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

  func applicationWillTerminate(_ notification: Notification) {
    feedbackReset?.cancel()
    model.stop()
  }
}
