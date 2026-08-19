import SwiftUI

struct GeneralSettingsView: View {
  @Bindable var settings: SettingsStore
  let updater: SparkleUpdaterService

  var body: some View {
    SettingsCard(title: "About") {
      SettingsRow(title: "Readly \(UpdatesSettingsView.version)") {
        Button("Check for Updates") {
          updater.checkForUpdates()
        }
        .buttonStyle(SettingsButtonStyle())
        .disabled(!updater.canCheckForUpdates)
      }
    }

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
