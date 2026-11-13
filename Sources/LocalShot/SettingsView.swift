import SwiftUI

struct SettingsView: View {
  @ObservedObject var model: AppModel

  var body: some View {
    VStack(alignment: .leading, spacing: 24) {
      HStack(spacing: 14) {
        Image(systemName: "viewfinder")
          .font(.system(size: 30, weight: .medium))
          .frame(width: 42, height: 42)
          .accessibilityHidden(true)
        VStack(alignment: .leading, spacing: 5) {
          Text("LocalShot").font(.system(size: 24, weight: .semibold))
          Text("Select. Copy. Paste.").foregroundStyle(.secondary)
        }
      }

      VStack(alignment: .leading, spacing: 16) {
        HStack {
          VStack(alignment: .leading, spacing: 5) {
            Text("Capture area").fontWeight(.medium)
            Text("Works in any app.")
              .font(.caption).foregroundStyle(.secondary)
          }
          Spacer(minLength: 12)
          Text(model.isRecordingShortcut ? "Press keys…" : model.shortcut.display)
            .font(.system(size: 17, weight: .medium, design: .monospaced))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .layoutPriority(1)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 7))
            .accessibilityLabel(
              model.isRecordingShortcut ? "Press a shortcut" : "Shortcut: \(model.shortcut.display)"
            )
        }
        HStack {
          Button(model.isRecordingShortcut ? "Cancel" : "Change…") {
            if model.isRecordingShortcut {
              model.cancelRecordingShortcut()
            } else {
              model.beginRecordingShortcut()
            }
          }
          if model.shortcut != .standard && !model.isRecordingShortcut {
            Button("Reset") { model.resetShortcut() }
              .buttonStyle(.link)
          }
          Spacer()
          Text("Esc cancels capture").font(.caption).foregroundStyle(.secondary)
        }
        if let error = model.shortcutError {
          Text(error).font(.caption).foregroundStyle(.red).fixedSize(
            horizontal: false, vertical: true)
        } else if model.isRecordingShortcut {
          Text(
            "Press a key, with or without modifiers. Esc can be assigned too. Click Cancel to stop."
          )
          .font(.caption).foregroundStyle(.secondary)
        } else if model.shortcut.modifiers == 0 {
          Text("This key will capture instead of typing while LocalShot is running.")
            .font(.caption).foregroundStyle(.secondary)
        }
      }

      Divider()

      VStack(alignment: .leading, spacing: 16) {
        Toggle(
          "Launch at login",
          isOn: Binding(
            get: { model.launchAtLogin }, set: { model.setLaunchAtLogin($0) }
          ))
        Toggle("Play capture sound", isOn: $model.playSound)
        if model.loginNeedsApproval {
          Button("Allow launch at login…") { model.openLoginSettings() }
            .font(.caption)
        }
      }
      .toggleStyle(.checkbox)

      HStack(alignment: .top, spacing: 8) {
        Image(systemName: "lock").accessibilityHidden(true)
        Text("Straight to your clipboard. Nothing uploaded.")
          .fixedSize(horizontal: false, vertical: true)
      }
      .font(.caption).foregroundStyle(.secondary)

      if let message = model.message {
        Text(message).font(.caption).foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }

      HStack {
        Button("Screen access…") { model.openScreenPermissionSettings() }
          .buttonStyle(.link).font(.caption)
        Spacer()
        Button("Capture") { model.capture() }
          .buttonStyle(.borderedProminent)
          .disabled(model.isCapturing || model.isRecordingShortcut)
      }
    }
    .padding(28)
    .frame(width: 440, alignment: .leading)
    .fixedSize(horizontal: false, vertical: true)
    .onDisappear { model.cancelRecordingShortcut() }
  }
}
