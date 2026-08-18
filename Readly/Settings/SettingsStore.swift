import Foundation
import Observation
import ServiceManagement

/// Every user-facing preference in one observable, `UserDefaults`-backed
/// store. `SettingsView` binds to it, `OutputService` and
/// `CaptureCoordinator` read it, and nothing else touches `UserDefaults`
/// for these keys.
@MainActor
@Observable
final class SettingsStore {
  private enum Keys {
    static let recognitionLanguages = "recognitionLanguages"
    static let keepLineBreaks = "keepLineBreaks"
    static let playSoundOnCapture = "playSoundOnCapture"
    static let captureSound = "captureSound"
  }

  @ObservationIgnored
  private let defaults: UserDefaults

  /// BCP-47 language tags Vision should prefer, most-preferred first.
  /// Empty means "automatic" — Vision picks from the device's own
  /// language list.
  var recognitionLanguages: [String] {
    didSet { defaults.set(recognitionLanguages, forKey: Keys.recognitionLanguages) }
  }

  /// Whether a multi-line capture keeps its line breaks, or merges into one
  /// paragraph — useful when the source was a justified block of body text
  /// where Vision's per-line detection would otherwise scatter it.
  var keepLineBreaks: Bool {
    didSet { defaults.set(keepLineBreaks, forKey: Keys.keepLineBreaks) }
  }

  var playSoundOnCapture: Bool {
    didSet { defaults.set(playSoundOnCapture, forKey: Keys.playSoundOnCapture) }
  }

  /// Which system sound plays when `playSoundOnCapture` is on.
  var captureSound: CaptureSound {
    didSet { defaults.set(captureSound.rawValue, forKey: Keys.captureSound) }
  }

  /// Backed by `SMAppService` rather than `UserDefaults`: the source of
  /// truth is the login item registration itself, so this always reflects
  /// what macOS actually has scheduled rather than a stored guess.
  var launchAtLogin: Bool {
    get { SMAppService.mainApp.status == .enabled }
    set {
      do {
        if newValue {
          try SMAppService.mainApp.register()
        } else {
          try SMAppService.mainApp.unregister()
        }
      } catch {
        // Best-effort: a failed (un)registration just leaves the toggle
        // reading the previous, still-accurate state.
      }
    }
  }

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    recognitionLanguages = defaults.stringArray(forKey: Keys.recognitionLanguages) ?? []
    keepLineBreaks = defaults.object(forKey: Keys.keepLineBreaks) as? Bool ?? true
    playSoundOnCapture = defaults.object(forKey: Keys.playSoundOnCapture) as? Bool ?? true
    captureSound = defaults.string(forKey: Keys.captureSound).flatMap(CaptureSound.init(rawValue:)) ?? .pop
  }
}
