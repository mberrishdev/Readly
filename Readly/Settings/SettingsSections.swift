/// The Settings navigation model: one section per sidebar row, with a
/// stable typed id.
enum SettingsSection: String, CaseIterable, Identifiable {
  case general
  case shortcut
  case recognition
  case sounds
  case updates

  var id: Self { self }

  var title: String {
    switch self {
    case .general: "General"
    case .shortcut: "Shortcut"
    case .recognition: "Recognition"
    case .sounds: "Sounds"
    case .updates: "Updates"
    }
  }

  var subtitle: String {
    switch self {
    case .general: "Readly on startup"
    case .shortcut: "The key that opens the selection overlay"
    case .recognition: "How Vision reads the text you select"
    case .sounds: "Feedback when a capture finishes"
    case .updates: "Keep Readly current"
    }
  }

  var icon: String {
    switch self {
    case .general: "gearshape"
    case .shortcut: "keyboard"
    case .recognition: "text.viewfinder"
    case .sounds: "speaker.wave.2"
    case .updates: "arrow.down.circle"
    }
  }
}
