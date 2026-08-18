import CoreGraphics

/// The reason a capture ended without landing text on the clipboard —
/// distinct from "no text found," which is not an error (`CaptureOutcome`).
enum CaptureFailureReason: Equatable {
  case permissionDenied
  case captureUnavailable
  case recognitionUnavailable
}

/// What `OutputService` should tell the user once a run through the
/// pipeline finishes.
enum CaptureOutcome: Equatable {
  case copied(characterCount: Int)
  case noTextFound
  case failed(CaptureFailureReason)
}

/// `CaptureCoordinator`'s pure reducer half: actions in, state transition
/// inside, effects out. No windows, no images, no Vision requests — which is
/// what makes the flow and re-entrancy rules (a second hotkey press while
/// selecting cancels instead of stacking a second overlay) unit-testable
/// (see the coordinator tests).
///
/// `CaptureCoordinator` owns the impure half: it turns hotkey presses and
/// overlay/service callbacks into actions, and executes the effects this
/// returns against the real services. Async completions come back in as new
/// actions, the same shape whether they succeeded or failed.
struct CaptureFlowMachine {
  enum State: Equatable {
    case idle
    case selecting
    case capturing
    case recognizing
  }

  enum Action: Equatable {
    case hotkeyPressed
    case selectionCompleted(rect: CGRect, displayID: CGDirectDisplayID, backingScaleFactor: CGFloat)
    case selectionCancelled
    case captureSucceeded
    case captureFailed(CaptureFailureReason)
    case recognitionSucceeded(characterCount: Int)
    case recognitionFailed(CaptureFailureReason)
  }

  enum Effect: Equatable {
    case beginSelection
    case cancelSelection
    case performCapture(rect: CGRect, displayID: CGDirectDisplayID, backingScaleFactor: CGFloat)
    case performRecognition
    case presentResult(CaptureOutcome)
  }

  private(set) var state = State.idle

  @discardableResult
  mutating func reduce(_ action: Action) -> [Effect] {
    switch (state, action) {
    case (.idle, .hotkeyPressed):
      state = .selecting
      return [.beginSelection]

    case (.selecting, .hotkeyPressed), (.selecting, .selectionCancelled):
      // A second press while the overlay is open cancels it rather than
      // stacking a second one behind it.
      state = .idle
      return [.cancelSelection]

    case let (.selecting, .selectionCompleted(rect, displayID, backingScaleFactor)):
      state = .capturing
      return [.performCapture(rect: rect, displayID: displayID, backingScaleFactor: backingScaleFactor)]

    case (.capturing, .captureSucceeded):
      state = .recognizing
      return [.performRecognition]

    case let (.capturing, .captureFailed(reason)):
      state = .idle
      return [.presentResult(.failed(reason))]

    case let (.recognizing, .recognitionSucceeded(characterCount)):
      state = .idle
      let outcome: CaptureOutcome = characterCount > 0
        ? .copied(characterCount: characterCount)
        : .noTextFound
      return [.presentResult(outcome)]

    case let (.recognizing, .recognitionFailed(reason)):
      state = .idle
      return [.presentResult(.failed(reason))]

    default:
      // Everything else — a stray callback landing after a cancel, a hotkey
      // press while capturing or recognizing — is a no-op by design: the
      // pipeline has exactly one run in flight at a time.
      return []
    }
  }
}
