import AppKit
import KeyboardShortcuts
import SwiftUI

/// Owns Readly's one onboarding window. `show()` requests Screen Recording
/// access automatically — Readly needs to appear under Privacy & Security →
/// Screen Recording on its own, not only once the user finds and clicks a
/// button — but only after the window itself is already on screen, so the
/// system dialog never appears with zero context.
@MainActor
final class OnboardingWindowController: NSWindowController, NSWindowDelegate {
  private let permissions: PermissionsManaging
  private let captureService: CaptureServicing
  private var hostingController: NSHostingController<OnboardingView>?

  init(permissions: PermissionsManaging, captureService: CaptureServicing = CaptureService()) {
    self.permissions = permissions
    self.captureService = captureService
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 440, height: 480),
      styleMask: [.titled, .closable],
      backing: .buffered,
      defer: false
    )
    window.title = "Readly"
    window.isReleasedWhenClosed = false
    super.init(window: window)
    window.delegate = self
    render()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  /// A no-op when access is already granted — this window has nothing left
  /// to say once Readly can already capture the screen.
  func show() {
    guard !permissions.hasScreenRecordingAccess else { return }

    render()
    NSApp.activate(ignoringOtherApps: true)
    window?.center()
    window?.makeKeyAndOrderFront(nil)
    requestAccess()
  }

  /// Fires both system prompts: the classic Screen Recording toggle, and
  /// ScreenCaptureKit's own "bypass the picker" consent — the second one
  /// only appears once something actually calls the capture APIs, so this
  /// makes the same throwaway call `CaptureService` primes with.
  private func requestAccess() {
    permissions.requestScreenRecordingAccess()
    Task { [weak self] in
      await self?.captureService.primeScreenCaptureKitAccess()
      self?.render()
    }
  }

  /// The user may have just come back from System Settings after granting
  /// (or denying) access — re-read the real status rather than trust
  /// whatever this window last showed.
  func windowDidBecomeKey(_ notification: Notification) {
    render()
  }

  private func render() {
    let status: OnboardingView.AccessStatus = permissions.hasScreenRecordingAccess
      ? .granted
      : .notGranted
    let view = OnboardingView(
      status: status,
      shortcutDescription: KeyboardShortcuts.getShortcut(for: .captureText)?.description ?? "your shortcut",
      onRequestAccess: { [weak self] in
        self?.requestAccess()
      },
      onOpenSystemSettings: {
        guard let url = URL(
          string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
        ) else { return }
        NSWorkspace.shared.open(url)
      },
      onContinue: { [weak self] in
        self?.window?.close()
      }
    )

    if let hostingController {
      hostingController.rootView = view
    } else {
      let hosting = NSHostingController(rootView: view)
      window?.contentViewController = hosting
      hostingController = hosting
    }
  }
}
