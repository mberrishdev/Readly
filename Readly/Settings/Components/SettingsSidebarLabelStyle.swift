import SwiftUI

/// Lines the sidebar's titles up with each other.
///
/// `Label`'s default layout sizes the icon to its glyph, and SF Symbols are
/// not one width, so each row's title would start wherever its own icon
/// happened to end. A fixed column pins the text edge and lets the glyphs
/// vary inside it, the way every macOS sidebar reads.
struct SettingsSidebarLabelStyle: LabelStyle {
  private let iconColumn: CGFloat = 20

  func makeBody(configuration: Configuration) -> some View {
    HStack(spacing: 9) {
      configuration.icon
        .frame(width: iconColumn, alignment: .center)
      configuration.title
    }
  }
}
