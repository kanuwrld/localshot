import Foundation

public enum CaptureOutcome: Equatable, Sendable {
  case copied
  case cancelled
  case failed
  case timedOut

  public static func resolve(
    exitCode: Int32,
    clipboardChanged: Bool,
    clipboardHasImage: Bool,
    hasErrorOutput: Bool,
    timedOut: Bool
  ) -> Self {
    if timedOut { return .timedOut }
    if exitCode == 0 && clipboardChanged && clipboardHasImage { return .copied }
    // macOS may use exit 0 or 1 for an interactive Escape cancellation.
    if (exitCode == 0 || exitCode == 1) && !clipboardChanged && !hasErrorOutput {
      return .cancelled
    }
    return .failed
  }
}
