import Foundation

public struct Shortcut: Codable, Equatable, Sendable {
  public static let command: UInt32 = 1 << 8
  public static let shift: UInt32 = 1 << 9
  public static let option: UInt32 = 1 << 11
  public static let control: UInt32 = 1 << 12
  public static let function: UInt32 = 1 << 17
  public static let allowedModifiers = command | shift | option | control | function
  public static let standard = Shortcut(keyCode: 1, modifiers: control | option)

  public let keyCode: UInt32
  public let modifiers: UInt32

  public init(keyCode: UInt32, modifiers: UInt32) {
    self.keyCode = keyCode
    self.modifiers = modifiers
  }

  public var validationError: String? {
    guard keyCode <= 0x7F, !Self.modifierKeyCodes.contains(keyCode) else {
      return "Press a key or shortcut. Use ⌘, ⌃, ⌥, ⇧ and Fn together with another key."
    }
    guard modifiers & ~Self.allowedModifiers == 0 else {
      return "This shortcut is not supported."
    }
    return nil
  }

  public var display: String {
    let prefix = [
      (Self.function, "fn "), (Self.control, "⌃"), (Self.option, "⌥"), (Self.shift, "⇧"),
      (Self.command, "⌘"),
    ]
    .filter { modifiers & $0.0 != 0 }
    .map(\.1).joined()
    return prefix + (Self.keyNames[keyCode] ?? "Key \(keyCode)")
  }

  // These emit flagsChanged rather than keyDown, so Carbon cannot use them as a trigger.
  private static let modifierKeyCodes: Set<UInt32> = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63]

  // Physical ANSI key positions keep the shortcut stable across keyboard layouts.
  public static let keyNames: [UInt32: String] = [
    0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V", 10: "§",
    11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T",
    18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9", 26: "7",
    27: "−", 28: "8", 29: "0", 30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P",
    36: "Return", 37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/", 45: "N",
    46: "M", 47: ".", 48: "Tab", 49: "Space", 50: "`", 51: "Delete", 53: "Esc",
    64: "F17", 65: "Num .", 67: "Num ×", 69: "Num +", 71: "Clear",
    72: "Volume +", 73: "Volume −", 74: "Mute", 75: "Num /", 76: "Num Enter", 78: "Num −",
    79: "F18", 80: "F19", 81: "Num =", 82: "Num 0", 83: "Num 1", 84: "Num 2", 85: "Num 3",
    86: "Num 4", 87: "Num 5", 88: "Num 6", 89: "Num 7", 90: "F20", 91: "Num 8", 92: "Num 9",
    93: "¥", 94: "_", 95: "Num ,",
    96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8", 101: "F9", 102: "英数", 103: "F11",
    104: "かな", 105: "F13", 106: "F16", 107: "F14", 109: "F10", 110: "Menu", 111: "F12",
    113: "F15", 114: "Help", 115: "Home", 116: "Page Up", 117: "Forward Delete",
    118: "F4", 119: "End", 120: "F2", 121: "Page Down", 122: "F1",
    123: "←", 124: "→", 125: "↓", 126: "↑",
  ]
}
