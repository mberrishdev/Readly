import AppKit

/// The menu bar shell: one `NSStatusItem` with a menu of three items, plus a
/// fourth that only appears while Screen Recording access is missing. Owns
/// no capture logic of its own — every action is a closure handed in by
/// whoever wires the app together.
@MainActor
final class StatusMenuController: NSObject, NSMenuDelegate {
  private let statusItem: NSStatusItem
  private let captureText: () -> Void
  private let openSettings: () -> Void
  private let openOnboarding: () -> Void
  private let checkForUpdates: () -> Void
  private let hasScreenRecordingAccess: () -> Bool

  private let accessItem: NSMenuItem
  private let accessSeparator = NSMenuItem.separator()

  init(
    captureText: @escaping () -> Void,
    openSettings: @escaping () -> Void,
    openOnboarding: @escaping () -> Void,
    checkForUpdates: @escaping () -> Void,
    hasScreenRecordingAccess: @escaping () -> Bool
  ) {
    self.captureText = captureText
    self.openSettings = openSettings
    self.openOnboarding = openOnboarding
    self.checkForUpdates = checkForUpdates
    self.hasScreenRecordingAccess = hasScreenRecordingAccess
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    accessItem = NSMenuItem(
      title: "Grant Screen Recording Access…",
      action: #selector(openOnboardingItem),
      keyEquivalent: ""
    )
    super.init()

    statusItem.button?.image = NSImage(
      systemSymbolName: "text.viewfinder",
      accessibilityDescription: "Readly"
    )

    let menu = NSMenu()
    menu.delegate = self

    accessItem.target = self
    menu.addItem(accessItem)
    menu.addItem(accessSeparator)

    let captureItem = NSMenuItem(
      title: "Capture Text",
      action: #selector(captureTextItem),
      keyEquivalent: ""
    )
    captureItem.target = self
    menu.addItem(captureItem)

    menu.addItem(.separator())

    let settingsItem = NSMenuItem(
      title: "Settings…",
      action: #selector(openSettingsItem),
      keyEquivalent: ","
    )
    settingsItem.target = self
    menu.addItem(settingsItem)

    let updatesItem = NSMenuItem(
      title: "Check for Updates…",
      action: #selector(checkForUpdatesItem),
      keyEquivalent: ""
    )
    updatesItem.target = self
    menu.addItem(updatesItem)

    menu.addItem(NSMenuItem(
      title: "Quit Readly",
      action: #selector(NSApplication.terminate(_:)),
      keyEquivalent: "q"
    ))

    statusItem.menu = menu
    refreshAccessItem()
  }

  /// Reads the real permission status fresh on every open, rather than
  /// polling — the user is far more likely to grant access from System
  /// Settings than from this menu, so the item has to stay honest without
  /// Readly ever being told about the change.
  func menuWillOpen(_ menu: NSMenu) {
    refreshAccessItem()
  }

  private func refreshAccessItem() {
    let granted = hasScreenRecordingAccess()
    accessItem.isHidden = granted
    accessSeparator.isHidden = granted
  }

  @objc private func captureTextItem() {
    captureText()
  }

  @objc private func openSettingsItem() {
    openSettings()
  }

  @objc private func openOnboardingItem() {
    openOnboarding()
  }

  @objc private func checkForUpdatesItem() {
    checkForUpdates()
  }
}
