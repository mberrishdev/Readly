import AppKit
import SwiftUI

private final class ReadlySettingsWindow: NSWindow {
  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { true }

  override func cancelOperation(_ sender: Any?) {
    close()
  }
}

/// Owns Readly's one borderless Settings surface for the app's lifetime.
@MainActor
final class SettingsWindowController: NSWindowController {
  private static let windowSize = NSSize(width: 680, height: 460)
  private var hasPositionedWindow = false

  convenience init(settings: SettingsStore) {
    let window = ReadlySettingsWindow(
      contentRect: NSRect(origin: .zero, size: Self.windowSize),
      styleMask: [.borderless],
      backing: .buffered,
      defer: false
    )
    let hosting = NSHostingController(
      rootView: SettingsView(settings: settings, onClose: { [weak window] in window?.close() })
    )

    window.contentViewController = hosting
    window.title = "Readly Settings"
    window.level = .normal
    window.isOpaque = false
    window.backgroundColor = .clear
    window.hasShadow = true
    window.isMovable = true
    window.isMovableByWindowBackground = false
    window.isReleasedWhenClosed = false
    window.minSize = Self.windowSize
    window.maxSize = Self.windowSize
    window.setContentSize(Self.windowSize)
    self.init(window: window)
  }

  func show() {
    guard let window else { return }
    if !hasPositionedWindow {
      positionOnPointerDisplay(window)
      hasPositionedWindow = true
    }
    NSApp.activate(ignoringOtherApps: true)
    window.makeKeyAndOrderFront(nil)
  }

  private func positionOnPointerDisplay(_ window: NSWindow) {
    let pointer = NSEvent.mouseLocation
    let screen = NSScreen.screens.first { $0.frame.contains(pointer) } ?? NSScreen.main
    guard let visibleFrame = screen?.visibleFrame else {
      window.center()
      return
    }

    window.setFrameOrigin(
      NSPoint(
        x: visibleFrame.midX - window.frame.width / 2,
        y: visibleFrame.midY - window.frame.height / 2
      )
    )
  }
}
