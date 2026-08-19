import AppKit
import Observation
import Sparkle

/// Sparkle, wrapped so the rest of the app never imports it: Settings and
/// the status menu read this observable and call two methods. Updates are
/// signed with EdDSA and checked against `appcast.xml` in this repository —
/// Readly ships no server, so the feed is a static file (see CONTEXT.md and
/// `scripts/release.sh`).
@MainActor
@Observable
final class SparkleUpdaterService {
  /// False until Sparkle finishes starting, and while a check is in flight.
  /// The Updates section disables its button on this rather than guessing.
  private(set) var canCheckForUpdates = false
  /// The newest version Sparkle has seen, or nil when the app is current.
  private(set) var availableVersion: String?
  private(set) var lastCheckedAt: Date?

  @ObservationIgnored
  private var controller: SPUStandardUpdaterController?
  @ObservationIgnored
  private let updaterDelegate = UpdaterDelegate()
  @ObservationIgnored
  private let userDriverDelegate = UserDriverDelegate()
  @ObservationIgnored
  private var canCheckObservation: NSKeyValueObservation?

  var automaticallyChecksForUpdates: Bool {
    get { controller?.updater.automaticallyChecksForUpdates ?? true }
    set { controller?.updater.automaticallyChecksForUpdates = newValue }
  }

  var automaticallyDownloadsUpdates: Bool {
    get { controller?.updater.automaticallyDownloadsUpdates ?? false }
    set { controller?.updater.automaticallyDownloadsUpdates = newValue }
  }

  /// Starts Sparkle. Called once at launch. A no-op until
  /// `scripts/generate-sparkle-keys.sh` has been run and its public key
  /// pasted into `Readly/Info.plist` — starting with an empty
  /// `SUPublicEDKey` is how Sparkle fails loudly ("The updater failed to
  /// start"), which every debug build would otherwise hit before that
  /// one-time setup is done.
  func start() {
    guard controller == nil else { return }
    guard let key = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String,
      !key.isEmpty else { return }

    updaterDelegate.service = self
    userDriverDelegate.service = self
    controller = SPUStandardUpdaterController(
      startingUpdater: true,
      updaterDelegate: updaterDelegate,
      userDriverDelegate: userDriverDelegate
    )

    guard let updater = controller?.updater else { return }
    lastCheckedAt = updater.lastUpdateCheckDate
    canCheckForUpdates = updater.canCheckForUpdates
    canCheckObservation = updater.observe(\.canCheckForUpdates, options: [.new]) {
      [weak self] updater, _ in
      Task { @MainActor [weak self] in
        self?.canCheckForUpdates = updater.canCheckForUpdates
      }
    }
  }

  /// A user-initiated check. Sparkle shows its own window, including the
  /// "you're up to date" case, which is the feedback the user asked for by
  /// pressing the button.
  func checkForUpdates() {
    controller?.checkForUpdates(nil)
    lastCheckedAt = .now
  }

  fileprivate func foundUpdate(version: String?) {
    availableVersion = version
  }

  fileprivate func finishedCheck() {
    lastCheckedAt = controller?.updater.lastUpdateCheckDate ?? .now
  }
}

private final class UpdaterDelegate: NSObject, SPUUpdaterDelegate {
  weak var service: SparkleUpdaterService?

  func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
    Task { @MainActor [weak service] in
      service?.foundUpdate(version: item.displayVersionString)
    }
  }

  func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
    Task { @MainActor [weak service] in
      service?.foundUpdate(version: nil)
      service?.finishedCheck()
    }
  }

  func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: (any Error)?) {
    Task { @MainActor [weak service] in
      service?.finishedCheck()
    }
  }
}

/// Readly is `LSUIElement`: no dock icon, accessory activation policy.
/// Sparkle positions and focuses its windows like a regular app, so under
/// `.accessory` the update window can open unfocused or off-screen.
/// Becoming `.regular` while the update UI is up fixes both, and the policy
/// reverts when the session ends so the app stays out of the Dock.
private final class UserDriverDelegate: NSObject, SPUStandardUserDriverDelegate {
  weak var service: SparkleUpdaterService?

  var supportsGentleScheduledUpdateReminders: Bool { true }

  func standardUserDriverShouldHandleShowingScheduledUpdate(
    _ update: SUAppcastItem,
    andInImmediateFocus immediateFocus: Bool
  ) -> Bool {
    !immediateFocus
  }

  /// Only a check the user asked for gets the regular activation policy.
  /// Sparkle drives its user driver on the main thread but its protocol is
  /// not annotated for it, so the isolation is asserted rather than assumed
  /// silently.
  func standardUserDriverWillHandleShowingUpdate(
    _ handleShowingUpdate: Bool,
    forUpdate update: SUAppcastItem,
    state: SPUUserUpdateState
  ) {
    guard state.userInitiated else { return }
    MainActor.assumeIsolated {
      NSApp.setActivationPolicy(.regular)
      NSApp.activate(ignoringOtherApps: true)
    }
  }

  func standardUserDriverWillFinishUpdateSession() {
    MainActor.assumeIsolated {
      _ = NSApp.setActivationPolicy(.accessory)
    }
  }
}
