import AppKit
import SwiftUI

struct SoundsSettingsView: View {
  @Bindable var settings: SettingsStore

  var body: some View {
    SettingsCard(title: "Feedback") {
      SettingsRow(
        title: "Play sound on capture",
        description: "A short cue when text lands on the clipboard"
      ) {
        Toggle("Play sound on capture", isOn: $settings.playSoundOnCapture)
          .labelsHidden()
          .toggleStyle(.switch)
      }

      SettingsPickerRow(
        title: "Sound",
        description: "Which system sound plays",
        options: CaptureSound.allCases,
        optionLabel: \.displayName,
        selection: $settings.captureSound
      )
      .disabled(!settings.playSoundOnCapture)

      SettingsRow(
        title: "Preview",
        description: "Play the selected sound"
      ) {
        Button("Play") {
          NSSound(named: settings.captureSound.rawValue)?.play()
        }
        .buttonStyle(SettingsButtonStyle())
      }
      .disabled(!settings.playSoundOnCapture)
    }
  }
}
