import SwiftUI

struct GeneralSettingsView: View {
  @Bindable var settings: SettingsStore

  var body: some View {
    SettingsCard(title: "Startup") {
      SettingsRow(
        title: "Launch at login",
        description: "Open Readly automatically when you sign in"
      ) {
        Toggle("Launch at login", isOn: $settings.launchAtLogin)
          .labelsHidden()
          .toggleStyle(.switch)
      }
    }
  }
}
