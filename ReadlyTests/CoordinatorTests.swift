import CoreGraphics
import Testing
@testable import Readly

/// Pins `CaptureFlowMachine`'s flow and re-entrancy rules — in particular
/// that a second hotkey press while the overlay is open cancels it instead
/// of stacking a second one behind it, and that "no text found" is a
/// distinct outcome from an error.
struct CoordinatorTests {
  private typealias Machine = CaptureFlowMachine

  private let rect = CGRect(x: 0, y: 0, width: 100, height: 100)
  private let displayID: CGDirectDisplayID = 1
  private let scale: CGFloat = 2

  @Test func hotkeyPressBeginsSelectionFromIdle() {
    var machine = Machine()
    let effects = machine.reduce(.hotkeyPressed)
    #expect(effects == [.beginSelection])
    #expect(machine.state == .selecting)
  }

  @Test func secondHotkeyPressWhileSelectingCancelsInsteadOfStacking() {
    var machine = Machine()
    _ = machine.reduce(.hotkeyPressed)
    let effects = machine.reduce(.hotkeyPressed)
    #expect(effects == [.cancelSelection])
    #expect(machine.state == .idle)
  }

  @Test func escapeWhileSelectingCancels() {
    var machine = Machine()
    _ = machine.reduce(.hotkeyPressed)
    let effects = machine.reduce(.selectionCancelled)
    #expect(effects == [.cancelSelection])
    #expect(machine.state == .idle)
  }

  @Test func completedSelectionMovesToCapturing() {
    var machine = Machine()
    _ = machine.reduce(.hotkeyPressed)
    let effects = machine.reduce(
      .selectionCompleted(rect: rect, displayID: displayID, backingScaleFactor: scale)
    )
    #expect(effects == [.performCapture(rect: rect, displayID: displayID, backingScaleFactor: scale)])
    #expect(machine.state == .capturing)
  }

  @Test func successfulCaptureMovesToRecognizing() {
    var machine = capturingMachine()
    let effects = machine.reduce(.captureSucceeded)
    #expect(effects == [.performRecognition])
    #expect(machine.state == .recognizing)
  }

  @Test func failedCapturePresentsTheFailureAndResets() {
    var machine = capturingMachine()
    let effects = machine.reduce(.captureFailed(.captureUnavailable))
    #expect(effects == [.presentResult(.failed(.captureUnavailable))])
    #expect(machine.state == .idle)
  }

  @Test func recognitionWithTextPresentsTheCopiedOutcome() {
    var machine = recognizingMachine()
    let effects = machine.reduce(.recognitionSucceeded(characterCount: 142))
    #expect(effects == [.presentResult(.copied(characterCount: 142))])
    #expect(machine.state == .idle)
  }

  @Test func recognitionWithNoTextPresentsNoTextFoundRatherThanCopyingNothing() {
    var machine = recognizingMachine()
    let effects = machine.reduce(.recognitionSucceeded(characterCount: 0))
    #expect(effects == [.presentResult(.noTextFound)])
    #expect(machine.state == .idle)
  }

  @Test func failedRecognitionPresentsTheFailureAndResets() {
    var machine = recognizingMachine()
    let effects = machine.reduce(.recognitionFailed(.recognitionUnavailable))
    #expect(effects == [.presentResult(.failed(.recognitionUnavailable))])
    #expect(machine.state == .idle)
  }

  @Test func hotkeyPressWhileCapturingOrRecognizingIsIgnored() {
    var capturing = capturingMachine()
    #expect(capturing.reduce(.hotkeyPressed).isEmpty)
    #expect(capturing.state == .capturing)

    var recognizing = recognizingMachine()
    #expect(recognizing.reduce(.hotkeyPressed).isEmpty)
    #expect(recognizing.state == .recognizing)
  }

  @Test func staleCallbacksAfterACancelAreNoOps() {
    var machine = Machine()
    _ = machine.reduce(.hotkeyPressed)
    _ = machine.reduce(.hotkeyPressed) // cancels back to idle
    #expect(machine.reduce(.captureSucceeded).isEmpty)
    #expect(machine.state == .idle)
  }

  private func capturingMachine() -> Machine {
    var machine = Machine()
    _ = machine.reduce(.hotkeyPressed)
    _ = machine.reduce(.selectionCompleted(rect: rect, displayID: displayID, backingScaleFactor: scale))
    return machine
  }

  private func recognizingMachine() -> Machine {
    var machine = capturingMachine()
    _ = machine.reduce(.captureSucceeded)
    return machine
  }
}
