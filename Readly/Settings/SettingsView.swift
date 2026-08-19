import SwiftUI

/// The fixed Settings surface: header, sidebar navigation, and the selected
/// section's scrolling pane — a borderless dark panel rather than a system
/// `Form` window.
struct SettingsView: View {
  @Bindable var settings: SettingsStore
  let updater: SparkleUpdaterService
  let onClose: () -> Void

  @Environment(\.colorSchemeContrast) private var contrast
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  @State private var selectedSection: SettingsSection = .general

  var body: some View {
    VStack(spacing: 0) {
      SettingsHeader(onClose: onClose)

      HStack(spacing: 0) {
        SettingsSidebar(selectedSection: $selectedSection)

        Rectangle()
          .fill(.white.opacity(contrast == .increased ? 0.18 : 0.08))
          .frame(width: 1)

        SettingsContent(section: selectedSection, settings: settings, updater: updater)
          .id(selectedSection)
          .transition(.opacity)
          .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: selectedSection)
      }
    }
    .frame(width: 680, height: 460)
    .background {
      ZStack {
        SettingsTheme.background
        LinearGradient(
          colors: [.white.opacity(0.035), .clear, .black.opacity(0.12)],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      }
    }
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .stroke(.white.opacity(contrast == .increased ? 0.24 : 0.1), lineWidth: 1)
    }
    .tint(SettingsTheme.accent)
    .preferredColorScheme(.dark)
    .onExitCommand(perform: onClose)
  }
}

private struct SettingsHeader: View {
  let onClose: () -> Void

  @Environment(\.colorSchemeContrast) private var contrast

  var body: some View {
    ZStack {
      // Close sits on the leading edge, where native macOS windows keep
      // their window controls.
      HStack {
        Button(action: onClose) {
          Image(systemName: "xmark")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white.opacity(contrast == .increased ? 0.92 : 0.7))
            .frame(width: 28, height: 28)
            .background(.white.opacity(0.07), in: Circle())
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        Spacer()
      }

      // Readly's identity, dead-center regardless of the close button.
      HStack(spacing: 9) {
        Image(systemName: "text.viewfinder")
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(.white.opacity(0.92))
          .frame(width: 26, height: 26)
          .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 7))

        Text("Readly")
          .font(.system(size: 15, weight: .semibold, design: .rounded))
      }
    }
    .padding(.horizontal, 16)
    .frame(height: 56)
    .background(SettingsWindowDragHandle())
    .overlay(alignment: .bottom) {
      Rectangle()
        .fill(.white.opacity(contrast == .increased ? 0.18 : 0.08))
        .frame(height: 1)
    }
  }
}

private struct SettingsSidebar: View {
  @Binding var selectedSection: SettingsSection

  @Environment(\.colorSchemeContrast) private var contrast
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("SETTINGS")
        .font(.system(size: 10, weight: .semibold))
        .tracking(0.8)
        .foregroundStyle(.white.opacity(contrast == .increased ? 0.62 : 0.35))
        .padding(.horizontal, 18)

      VStack(spacing: 2) {
        ForEach(SettingsSection.allCases) { section in
          Button {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.14)) {
              selectedSection = section
            }
          } label: {
            Label(section.title, systemImage: section.icon)
              .labelStyle(SettingsSidebarLabelStyle())
              .font(.system(size: 13, weight: .medium))
              .foregroundStyle(
                selectedSection == section
                  ? .white
                  : .white.opacity(contrast == .increased ? 0.82 : 0.62)
              )
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(.horizontal, 11)
              .padding(.vertical, 9)
              .background {
                if selectedSection == section {
                  RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(.white.opacity(contrast == .increased ? 0.15 : 0.09))
                    .overlay(alignment: .leading) {
                      Capsule()
                        .fill(SettingsTheme.accent)
                        .frame(width: 2)
                        .padding(.vertical, 7)
                    }
                }
              }
          }
          .buttonStyle(.plain)
        }
      }
      .padding(.horizontal, 10)

      Spacer()
    }
    .padding(.top, 20)
    .frame(width: 190)
    .frame(maxHeight: .infinity, alignment: .topLeading)
    .background(SettingsTheme.sidebar)
  }
}

private struct SettingsContent: View {
  let section: SettingsSection
  @Bindable var settings: SettingsStore
  let updater: SparkleUpdaterService

  @Environment(\.colorSchemeContrast) private var contrast

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        VStack(alignment: .leading, spacing: 6) {
          Text(section.title)
            .font(.system(size: 26, weight: .semibold, design: .rounded))
          Text(section.subtitle)
            .font(.subheadline)
            .foregroundStyle(.white.opacity(contrast == .increased ? 0.76 : 0.52))
        }

        switch section {
        case .general:
          GeneralSettingsView(settings: settings, updater: updater)
        case .shortcut:
          ShortcutSettingsView()
        case .recognition:
          RecognitionSettingsView(settings: settings)
        case .sounds:
          SoundsSettingsView(settings: settings)
        case .updates:
          UpdatesSettingsView(updater: updater)
        }
      }
      .frame(maxWidth: 440, alignment: .leading)
      .padding(.horizontal, 30)
      .padding(.vertical, 26)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }
}

#Preview {
  SettingsView(
    settings: SettingsStore(defaults: UserDefaults(suiteName: "preview")!),
    updater: SparkleUpdaterService(),
    onClose: {}
  )
}
