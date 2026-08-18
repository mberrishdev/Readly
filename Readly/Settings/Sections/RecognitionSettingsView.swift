import SwiftUI

struct RecognitionSettingsView: View {
  @Bindable var settings: SettingsStore

  private static let languageOptions: [(tag: String, label: String)] = [
    ("", "Automatic"),
    ("en-US", "English"),
    ("es-ES", "Spanish"),
    ("fr-FR", "French"),
    ("de-DE", "German"),
    ("it-IT", "Italian"),
    ("pt-BR", "Portuguese"),
    ("zh-Hans", "Chinese (Simplified)"),
    ("ja-JP", "Japanese"),
  ]

  /// Vision takes an ordered list of preferred languages; the picker only
  /// ever offers one, so the array is either empty (automatic) or holds
  /// exactly that one tag.
  private var languageTag: Binding<String> {
    Binding(
      get: { settings.recognitionLanguages.first ?? "" },
      set: { settings.recognitionLanguages = $0.isEmpty ? [] : [$0] }
    )
  }

  var body: some View {
    SettingsCard(title: "Text") {
      SettingsRow(
        title: "Keep line breaks",
        description: "Preserve Vision's line detection instead of merging into one paragraph"
      ) {
        Toggle("Keep line breaks", isOn: $settings.keepLineBreaks)
          .labelsHidden()
          .toggleStyle(.switch)
      }

      SettingsPickerRow(
        title: "Language",
        description: "The language Vision expects to find in your selection",
        options: Self.languageOptions.map(\.tag),
        optionLabel: { tag in Self.languageOptions.first { $0.tag == tag }?.label ?? tag },
        selection: languageTag
      )
    }
  }
}
