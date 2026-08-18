import KeyboardShortcuts
import SwiftUI

struct ShortcutSettingsView: View {
  var body: some View {
    SettingsCard(title: "Capture") {
      SettingsRow(
        title: "Capture Text",
        description: "Press to dim the screen and drag a selection"
      ) {
        KeyboardShortcuts.Recorder(for: .captureText)
      }
    }
  }
}
