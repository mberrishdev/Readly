import Foundation

/// The short confirmation sound Readly can play after a successful capture.
/// Each case names one of macOS's own system sounds (`~/Library/Sounds` /
/// `/System/Library/Sounds`), played through `NSSound(named:)` — no bundled
/// audio assets needed.
enum CaptureSound: String, CaseIterable, Identifiable {
  case pop = "Pop"
  case tink = "Tink"
  case glass = "Glass"
  case ping = "Ping"
  case purr = "Purr"

  var id: Self { self }
  var displayName: String { rawValue }
}
