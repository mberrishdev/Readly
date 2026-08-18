import AppKit

/// Delivers a finished capture to the user, as a protocol so
/// `CaptureCoordinator` can be tested against a mock that records what it
/// was asked to present instead of touching the real pasteboard.
///
/// Every case is a distinct, user-visible outcome — including "no text
/// found" — on purpose: silently copying an empty string would overwrite
/// whatever the user had on their clipboard for no reason they could see.
@MainActor
protocol OutputServicing: AnyObject {
  func deliver(_ result: RecognitionResult)
  func presentNoTextFound()
  func present(_ failure: CaptureFailureReason)
}

@MainActor
final class OutputService: OutputServicing {
  private let hud = CaptureHUDController()
  private let pasteboard: NSPasteboard
  private let settings: SettingsStore

  init(settings: SettingsStore, pasteboard: NSPasteboard = .general) {
    self.settings = settings
    self.pasteboard = pasteboard
  }

  func deliver(_ result: RecognitionResult) {
    let text = result.text(keepLineBreaks: settings.keepLineBreaks)
    pasteboard.clearContents()
    pasteboard.setString(text, forType: .string)
    hud.show(
      symbolName: "checkmark.circle.fill",
      message: "\(result.characterCount) character\(result.characterCount == 1 ? "" : "s") copied"
    )
    playCaptureSoundIfEnabled()
  }

  /// A fresh `NSSound` instance every play, rather than one reused instance:
  /// a capture that lands mid-playback of the previous one needs its own
  /// sound to start from the top instead of being ignored or cut short.
  private func playCaptureSoundIfEnabled() {
    guard settings.playSoundOnCapture else { return }
    NSSound(named: settings.captureSound.rawValue)?.play()
  }

  func presentNoTextFound() {
    hud.show(symbolName: "text.viewfinder", message: "No text detected")
  }

  func present(_ failure: CaptureFailureReason) {
    hud.show(symbolName: "exclamationmark.triangle.fill", message: message(for: failure))
  }

  private func message(for failure: CaptureFailureReason) -> String {
    switch failure {
    case .permissionDenied:
      return "Screen Recording permission needed"
    case .captureUnavailable:
      return "Couldn't capture that region"
    case .recognitionUnavailable:
      return "Couldn't recognize text"
    }
  }
}
