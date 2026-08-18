import AppKit
import SwiftUI

/// The Settings surface's dark palette — the design tokens every Settings
/// component draws from. The accent is the same indigo as the app icon.
enum SettingsTheme {
  static let background = Color(red: 0.025, green: 0.027, blue: 0.035)
  static let sidebar = Color(red: 0.035, green: 0.038, blue: 0.049)
  static let card = Color(red: 0.065, green: 0.069, blue: 0.087)
  static let accent = Color(nsColor: accentColor)
  static let accentColor = NSColor(red: 0.44, green: 0.35, blue: 0.95, alpha: 1)
}
