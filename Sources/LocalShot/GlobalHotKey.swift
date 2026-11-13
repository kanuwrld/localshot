import Carbon
import Foundation
import LocalShotCore

@MainActor
final class GlobalHotKey {
  private var hotKey: EventHotKeyRef?
  private var eventHandler: EventHandlerRef?
  var onPress: (() -> Void)?

  init() throws {
    // Trigger on release so holding the shortcut cannot start repeated captures.
    var type = EventTypeSpec(
      eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))
    let status = InstallEventHandler(
      GetApplicationEventTarget(),
      { _, event, context in
        guard let context, let event else { return OSStatus(eventNotHandledErr) }
        var identifier = EventHotKeyID()
        let result = GetEventParameter(
          event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
          nil, MemoryLayout<EventHotKeyID>.size, nil, &identifier
        )
        guard result == noErr, identifier.signature == 0x4C53_4854, identifier.id == 1 else {
          return OSStatus(eventNotHandledErr)
        }
        MainActor.assumeIsolated {
          Unmanaged<GlobalHotKey>.fromOpaque(context).takeUnretainedValue().onPress?()
        }
        return noErr
      },
      1, &type, Unmanaged.passUnretained(self).toOpaque(), &eventHandler
    )
    guard status == noErr else { throw HotKeyError.registration(status) }
  }

  func register(_ shortcut: Shortcut) throws {
    unregister()
    let identifier = EventHotKeyID(signature: 0x4C53_4854, id: 1)
    let status = RegisterEventHotKey(
      shortcut.keyCode, shortcut.modifiers, identifier, GetApplicationEventTarget(),
      OptionBits(kEventHotKeyExclusive), &hotKey
    )
    guard status == noErr else { throw HotKeyError.registration(status) }
  }

  func unregister() {
    if let hotKey { UnregisterEventHotKey(hotKey) }
    hotKey = nil
  }

  func stop() {
    unregister()
    if let eventHandler { RemoveEventHandler(eventHandler) }
    eventHandler = nil
  }

  enum HotKeyError: LocalizedError {
    case registration(OSStatus)

    var errorDescription: String? {
      "macOS could not register this shortcut. It may be used by the system or another app. Free it up or choose another."
    }
  }
}
