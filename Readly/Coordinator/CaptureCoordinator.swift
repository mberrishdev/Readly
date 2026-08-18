import AppKit
import CoreGraphics

/// The brain: translates a hotkey press and overlay/service callbacks into
/// actions for `CaptureFlowMachine`, then executes the effects it returns
/// against the real services. Everything else in this pipeline is a dumb
/// service this coordinator calls in order — the machine is the only place
/// that decides what happens next.
@MainActor
final class CaptureCoordinator {
  private var machine = CaptureFlowMachine()

  private let hotkey: HotkeySourcing
  private let overlay: SelectionOverlayController
  private let captureService: CaptureServicing
  private let ocrService: OCRServicing
  private let outputService: OutputServicing
  private let permissions: PermissionsManaging
  private let settings: SettingsStore
  private let onPermissionNeeded: () -> Void

  /// Held between effects, out of the pure machine's state — exactly the
  /// way `DictationSessionMachine` keeps audio buffers out of band in
  /// Talkify. `pendingImage` clears once recognition starts; `pendingResult`
  /// clears once it's been handed to `OutputService`.
  private var pendingImage: CGImage?
  private var pendingResult: RecognitionResult?

  init(
    hotkey: HotkeySourcing,
    overlay: SelectionOverlayController = SelectionOverlayController(),
    captureService: CaptureServicing = CaptureService(),
    ocrService: OCRServicing = OCRService(),
    outputService: OutputServicing,
    permissions: PermissionsManaging = PermissionsManager(),
    settings: SettingsStore,
    onPermissionNeeded: @escaping () -> Void
  ) {
    self.hotkey = hotkey
    self.overlay = overlay
    self.captureService = captureService
    self.ocrService = ocrService
    self.outputService = outputService
    self.permissions = permissions
    self.settings = settings
    self.onPermissionNeeded = onPermissionNeeded
  }

  func start() {
    hotkey.onTrigger = { [weak self] in self?.handleHotkeyTrigger() }
  }

  /// Screen Recording access is checked here rather than folded into the
  /// machine: the check is synchronous (a cached TCC read), so there is no
  /// async gap for a second press to land in, and the machine never needs a
  /// "waiting on a guard" state that only this one action uses.
  ///
  /// This never calls `permissions.requestScreenRecordingAccess()` itself —
  /// that call pops the system TCC dialog, and doing it straight off a
  /// hotkey press the user hasn't been told about yet reads as broken, not
  /// as a permission request. `onPermissionNeeded` routes to the onboarding
  /// window instead, whose own "Grant Access" button is the one place that
  /// dialog is allowed to appear from.
  private func handleHotkeyTrigger() {
    if machine.state == .idle, !permissions.hasScreenRecordingAccess {
      onPermissionNeeded()
      return
    }
    perform(machine.reduce(.hotkeyPressed))
  }

  private func perform(_ effects: [CaptureFlowMachine.Effect]) {
    effects.forEach(perform)
  }

  private func perform(_ effect: CaptureFlowMachine.Effect) {
    switch effect {
    case .beginSelection:
      beginSelection()
    case .cancelSelection:
      overlay.cancel()
    case let .performCapture(rect, displayID, backingScaleFactor):
      performCapture(rect: rect, displayID: displayID, backingScaleFactor: backingScaleFactor)
    case .performRecognition:
      performRecognition()
    case let .presentResult(outcome):
      presentResult(outcome)
    }
  }

  private func beginSelection() {
    overlay.beginSelection { [weak self] selection in
      guard let self else { return }
      guard let selection else {
        self.perform(self.machine.reduce(.selectionCancelled))
        return
      }
      // Stashed for `performCapture` to read `excludedWindowNumbers` from —
      // the machine's own `.performCapture` effect intentionally omits it,
      // to keep every effect's payload the same small, testable shape.
      self.pendingSelection = selection
      self.perform(self.machine.reduce(
        .selectionCompleted(
          rect: selection.cocoaRect,
          displayID: selection.displayID,
          backingScaleFactor: selection.backingScaleFactor
        )
      ))
    }
  }

  private var pendingSelection: SelectionOverlayController.Selection?

  private func performCapture(
    rect: CGRect,
    displayID: CGDirectDisplayID,
    backingScaleFactor: CGFloat
  ) {
    let excludedWindowNumbers = pendingSelection?.excludedWindowNumbers ?? []
    pendingSelection = nil

    let primaryDisplayHeight = NSScreen.screens.first?.frame.height ?? 0
    let displayBounds = CGDisplayBounds(displayID)
    let pixelRect = CoordinateMapper.pixelRect(
      forCocoaRect: rect,
      primaryDisplayHeight: primaryDisplayHeight,
      displayBounds: displayBounds,
      backingScaleFactor: backingScaleFactor
    )

    Task { [weak self] in
      guard let self else { return }
      do {
        let image = try await self.captureService.captureImage(
          pixelRect: pixelRect,
          displayID: displayID,
          backingScaleFactor: backingScaleFactor,
          excludingWindowNumbers: excludedWindowNumbers
        )
        self.pendingImage = image
        self.perform(self.machine.reduce(.captureSucceeded))
      } catch CaptureError.permissionDenied {
        self.perform(self.machine.reduce(.captureFailed(.permissionDenied)))
      } catch {
        self.perform(self.machine.reduce(.captureFailed(.captureUnavailable)))
      }
    }
  }

  private func performRecognition() {
    guard let image = pendingImage else {
      perform(machine.reduce(.recognitionFailed(.recognitionUnavailable)))
      return
    }
    pendingImage = nil
    let languages = settings.recognitionLanguages

    Task { [weak self] in
      guard let self else { return }
      do {
        let result = try await self.ocrService.recognizeText(in: image, languages: languages)
        self.pendingResult = result
        self.perform(self.machine.reduce(.recognitionSucceeded(characterCount: result.characterCount)))
      } catch {
        self.perform(self.machine.reduce(.recognitionFailed(.recognitionUnavailable)))
      }
    }
  }

  private func presentResult(_ outcome: CaptureOutcome) {
    defer {
      pendingImage = nil
      pendingResult = nil
    }
    switch outcome {
    case .copied:
      if let pendingResult {
        outputService.deliver(pendingResult)
      }
    case .noTextFound:
      outputService.presentNoTextFound()
    case let .failed(reason):
      outputService.present(reason)
    }
  }
}
