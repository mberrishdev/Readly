import AppKit

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private var settings: SettingsStore?
  private var hotkeyManager: HotkeyManager?
  private var coordinator: CaptureCoordinator?
  private var statusMenuController: StatusMenuController?
  private var settingsWindowController: SettingsWindowController?
  private var onboardingWindowController: OnboardingWindowController?
  private let permissions: PermissionsManaging = PermissionsManager()

  static func main() {
    let application = NSApplication.shared
    let delegate = AppDelegate()
    application.delegate = delegate
    application.run()
  }

  /// True while this process hosts the test suite rather than a user.
  ///
  /// The live launch path registers a global hotkey and can show the
  /// onboarding window — neither of which should happen on a machine
  /// running the test suite. A test that means to exercise launch itself
  /// drives `AppDelegate` directly.
  private static var isHostingTests: Bool {
    let environment = ProcessInfo.processInfo.environment
    return environment["XCTestSessionIdentifier"] != nil
      || environment["XCTestConfigurationFilePath"] != nil
      || environment["XCTestBundlePath"] != nil
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    guard !Self.isHostingTests else { return }

    let settings = SettingsStore()
    self.settings = settings

    let hotkeyManager = HotkeyManager()
    self.hotkeyManager = hotkeyManager

    let outputService = OutputService(settings: settings)
    let coordinator = CaptureCoordinator(
      hotkey: hotkeyManager,
      outputService: outputService,
      permissions: permissions,
      settings: settings,
      onPermissionNeeded: { [weak self] in self?.showOnboarding() }
    )
    self.coordinator = coordinator
    coordinator.start()

    let statusMenuController = StatusMenuController(
      captureText: { hotkeyManager.onTrigger?() },
      openSettings: { [weak self] in self?.showSettings() },
      openOnboarding: { [weak self] in self?.showOnboarding() },
      hasScreenRecordingAccess: { [weak self] in self?.permissions.hasScreenRecordingAccess ?? false }
    )
    self.statusMenuController = statusMenuController

    // First launch (or any launch before access is granted) leads with the
    // onboarding window, rather than waiting for a hotkey press to surface
    // a cold system dialog.
    if !permissions.hasScreenRecordingAccess {
      showOnboarding()
    }
  }

  private func showSettings() {
    guard let settings else { return }
    if settingsWindowController == nil {
      settingsWindowController = SettingsWindowController(settings: settings)
    }
    settingsWindowController?.show()
  }

  private func showOnboarding() {
    if onboardingWindowController == nil {
      onboardingWindowController = OnboardingWindowController(permissions: permissions)
    }
    onboardingWindowController?.show()
  }
}
