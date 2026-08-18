import AppKit
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
  static let captureText = Self("captureText", default: .init(.two, modifiers: [.command, .shift]))
}

/// A source of hotkey triggers, as a protocol so `CaptureCoordinator` can be
/// driven by a fake trigger in tests instead of a real global shortcut.
@MainActor
protocol HotkeySourcing: AnyObject {
  var onTrigger: (() -> Void)? { get set }
}

/// Wraps the `KeyboardShortcuts` package (Sindre Sorhus). Its only job is to
/// fire a callback — it knows nothing about selection, capture, or OCR, so
/// rebinding the key in Settings never touches this class.
@MainActor
final class HotkeyManager: HotkeySourcing {
  var onTrigger: (() -> Void)?

  init() {
    KeyboardShortcuts.onKeyUp(for: .captureText) { [weak self] in
      self?.onTrigger?()
    }
  }
}
