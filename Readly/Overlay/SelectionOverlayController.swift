import AppKit

/// A borderless window that forwards Escape to the controller instead of
/// closing itself — there is nothing to close, only a selection to cancel.
private final class SelectionOverlayWindow: NSWindow {
  var onCancel: (() -> Void)?

  override var canBecomeKey: Bool { true }

  override func cancelOperation(_ sender: Any?) {
    onCancel?()
  }
}

/// Puts one dimmed, crosshaired window over every connected screen and
/// resolves to whichever rect the user actually dragged, or `nil` on
/// Escape / a plain click with no drag.
///
/// Coordinates come back in Cocoa screen space (bottom-left origin of the
/// primary display, y-up) — `CoordinateMapper` is where that turns into
/// something `CaptureService` can crop out of a captured display image.
@MainActor
final class SelectionOverlayController {
  struct Selection: Equatable {
    let cocoaRect: CGRect
    let displayID: CGDirectDisplayID
    let backingScaleFactor: CGFloat
    /// Readly's own overlay window ids at the moment of selection, for
    /// `CaptureService` to exclude — captured here, before `dismiss()` runs,
    /// so there is no race between the windows disappearing and the
    /// exclusion list being read.
    let excludedWindowNumbers: [CGWindowID]
  }

  private var windows: [SelectionOverlayWindow] = []
  private var completion: ((Selection?) -> Void)?

  var isActive: Bool { completion != nil }

  func beginSelection(completion: @escaping (Selection?) -> Void) {
    guard !isActive else { return }
    self.completion = completion

    windows = NSScreen.screens.map(makeWindow)
    for (index, window) in windows.enumerated() {
      if index == 0 {
        window.makeKeyAndOrderFront(nil)
      } else {
        window.orderFrontRegardless()
      }
    }
  }

  /// Tears down every overlay window without reporting a selection — used
  /// when a second hotkey press interrupts an in-progress drag.
  func cancel() {
    finish(rect: nil, screen: nil)
  }

  private func makeWindow(for screen: NSScreen) -> SelectionOverlayWindow {
    let window = SelectionOverlayWindow(
      contentRect: screen.frame,
      styleMask: [.borderless],
      backing: .buffered,
      defer: false,
      screen: screen
    )
    window.isOpaque = false
    window.backgroundColor = .clear
    window.level = .screenSaver
    window.ignoresMouseEvents = false
    window.hasShadow = false
    window.isReleasedWhenClosed = false
    window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
    window.onCancel = { [weak self] in self?.finish(rect: nil, screen: nil) }

    let view = SelectionView(frame: NSRect(origin: .zero, size: screen.frame.size))
    view.onSelectionCompleted = { [weak self] rect in
      self?.finish(rect: rect, screen: screen)
    }
    window.contentView = view

    return window
  }

  /// `rect` is in the originating screen's own view space (bottom-left,
  /// y-up) — translated to global Cocoa screen space by adding that
  /// screen's own origin, which is exactly what `screen.frame` already is.
  private func finish(rect: CGRect?, screen: NSScreen?) {
    guard let completion else { return }
    self.completion = nil

    var selection: Selection?
    if let rect, let screen, rect.width > 2, rect.height > 2,
      let displayID = screen.cgDirectDisplayID {
      let globalRect = CGRect(
        x: screen.frame.minX + rect.minX,
        y: screen.frame.minY + rect.minY,
        width: rect.width,
        height: rect.height
      )
      selection = Selection(
        cocoaRect: globalRect,
        displayID: displayID,
        backingScaleFactor: screen.backingScaleFactor,
        excludedWindowNumbers: windows.map { CGWindowID($0.windowNumber) }
      )
    }

    dismiss()
    completion(selection)
  }

  private func dismiss() {
    windows.forEach { $0.orderOut(nil) }
    windows = []
  }
}
