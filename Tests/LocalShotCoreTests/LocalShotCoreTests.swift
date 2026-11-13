import Foundation
import Testing

@testable import LocalShotCore

@Test func defaultShortcutIsValid() {
  #expect(Shortcut.standard.validationError == nil)
  #expect(Shortcut.standard.display == "⌃⌥S")
}

@Test func acceptsKeysWithoutCommandOrControl() {
  #expect(Shortcut(keyCode: 1, modifiers: 0).validationError == nil)
  #expect(Shortcut(keyCode: 1, modifiers: Shortcut.shift).validationError == nil)
  #expect(Shortcut(keyCode: 44, modifiers: Shortcut.option).validationError == nil)
  #expect(Shortcut(keyCode: 1, modifiers: Shortcut.function).validationError == nil)
  #expect(Shortcut(keyCode: 1, modifiers: Shortcut.function).display == "fn S")
  #expect(Shortcut(keyCode: 44, modifiers: Shortcut.shift | Shortcut.option).validationError == nil)
}

@Test func leavesSystemShortcutAvailabilityToMacOS() {
  #expect(Shortcut(keyCode: 12, modifiers: Shortcut.command).validationError == nil)
  #expect(
    Shortcut(keyCode: 21, modifiers: Shortcut.command | Shortcut.shift).validationError == nil)
  #expect(
    Shortcut(keyCode: 21, modifiers: Shortcut.command | Shortcut.shift | Shortcut.control)
      .validationError == nil)
}

@Test func acceptsNavigationEditingAndExtendedFunctionKeys() {
  for keyCode: UInt32 in [
    36, 48, 49, 51, 53, 64, 79, 80, 90, 105, 106, 107, 110, 113, 114, 115,
    116, 117, 119, 121, 123, 124, 125, 126,
  ] {
    #expect(Shortcut(keyCode: keyCode, modifiers: 0).validationError == nil)
    #expect(Shortcut(keyCode: keyCode, modifiers: Shortcut.option).validationError == nil)
  }
  #expect(Shortcut(keyCode: 53, modifiers: 0).display == "Esc")
  #expect(Shortcut(keyCode: 126, modifiers: Shortcut.option).display == "⌥↑")
}

@Test func distinguishesNumpadAndInternationalKeys() throws {
  for keyCode: UInt32 in [
    10, 65, 67, 69, 71, 75, 76, 78, 81, 82, 83, 84, 85, 86, 87, 88, 89,
    91, 92, 93, 94, 95, 102, 104,
  ] {
    let shortcut = Shortcut(keyCode: keyCode, modifiers: 0)
    #expect(shortcut.validationError == nil)
    #expect(
      try JSONDecoder().decode(Shortcut.self, from: JSONEncoder().encode(shortcut)) == shortcut)
  }
  #expect(
    Shortcut(keyCode: 76, modifiers: 0).display != Shortcut(keyCode: 36, modifiers: 0).display)
  #expect(
    Shortcut(keyCode: 83, modifiers: 0).display != Shortcut(keyCode: 18, modifiers: 0).display)
}

@Test func acceptsUnlistedVirtualKeyWithoutAnArtificialAllowlist() {
  let shortcut = Shortcut(keyCode: 52, modifiers: Shortcut.option)
  #expect(shortcut.validationError == nil)
  #expect(shortcut.display == "⌥Key 52")
}

@Test func rejectsCorruptPreferences() throws {
  #expect(Shortcut(keyCode: 500, modifiers: Shortcut.control).validationError != nil)
  #expect(Shortcut(keyCode: 1, modifiers: UInt32.max).validationError != nil)
  #expect(Shortcut(keyCode: 56, modifiers: 0).validationError != nil)
  let data = try JSONEncoder().encode(Shortcut.standard)
  #expect(try JSONDecoder().decode(Shortcut.self, from: data) == .standard)
  #expect((try? JSONDecoder().decode(Shortcut.self, from: Data("{}".utf8))) == nil)
}

@Test func acceptsCustomModifiedKey() {
  let shortcut = Shortcut(keyCode: 19, modifiers: Shortcut.command | Shortcut.shift)
  #expect(shortcut.validationError == nil)
  #expect(shortcut.display == "⇧⌘2")
}

@Test func successfulExitRequiresANewClipboardImage() {
  #expect(
    CaptureOutcome.resolve(
      exitCode: 0, clipboardChanged: true, clipboardHasImage: true, hasErrorOutput: false,
      timedOut: false) == .copied)
  #expect(
    CaptureOutcome.resolve(
      exitCode: 0, clipboardChanged: true, clipboardHasImage: false, hasErrorOutput: false,
      timedOut: false) == .failed)
}

@Test func escapeNeverClaimsAnOldImageAsSuccess() {
  for exitCode: Int32 in [0, 1] {
    #expect(
      CaptureOutcome.resolve(
        exitCode: exitCode, clipboardChanged: false, clipboardHasImage: true, hasErrorOutput: false,
        timedOut: false) == .cancelled)
  }
}

@Test func errorsAndTimeoutsDoNotLookLikeCancellation() {
  #expect(
    CaptureOutcome.resolve(
      exitCode: 1, clipboardChanged: false, clipboardHasImage: false, hasErrorOutput: true,
      timedOut: false) == .failed)
  #expect(
    CaptureOutcome.resolve(
      exitCode: 9, clipboardChanged: false, clipboardHasImage: false, hasErrorOutput: false,
      timedOut: false) == .failed)
  #expect(
    CaptureOutcome.resolve(
      exitCode: 0, clipboardChanged: false, clipboardHasImage: true, hasErrorOutput: false,
      timedOut: true) == .timedOut)
}
