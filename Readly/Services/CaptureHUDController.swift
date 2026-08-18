import AppKit
import SwiftUI

/// The confirmation toast: a small floating panel, centered near the bottom
/// of the active screen, that fades in and back out on its own. It never
/// takes key focus — `orderFrontRegardless()`, never `makeKey` — so it never
/// interrupts whatever the user pastes into next.
private struct HUDView: View {
  let symbolName: String
  let message: String

  var body: some View {
    Label {
      Text(message)
        .font(.system(size: 13, weight: .medium))
    } icon: {
      Image(systemName: symbolName)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 10)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    .fixedSize()
  }
}

@MainActor
final class CaptureHUDController {
  private static let visibleDuration: TimeInterval = 1.5
  private static let fadeDuration: TimeInterval = 0.2

  private var window: NSWindow?
  private var dismissWorkItem: DispatchWorkItem?

  func show(symbolName: String, message: String) {
    dismissWorkItem?.cancel()

    let hostingView = NSHostingView(rootView: HUDView(symbolName: symbolName, message: message))
    hostingView.layoutSubtreeIfNeeded()
    let size = hostingView.fittingSize

    let window = currentWindow()
    window.setContentSize(size)
    window.contentView = hostingView
    position(window, size: size)

    window.alphaValue = 0
    window.orderFrontRegardless()
    NSAnimationContext.runAnimationGroup { context in
      context.duration = Self.fadeDuration
      window.animator().alphaValue = 1
    }

    let workItem = DispatchWorkItem { [weak self] in self?.dismiss() }
    dismissWorkItem = workItem
    DispatchQueue.main.asyncAfter(deadline: .now() + Self.visibleDuration, execute: workItem)
  }

  private func dismiss() {
    guard let window else { return }
    NSAnimationContext.runAnimationGroup { context in
      context.duration = Self.fadeDuration
      window.animator().alphaValue = 0
    } completionHandler: { [weak window] in
      MainActor.assumeIsolated {
        window?.orderOut(nil)
      }
    }
  }

  private func currentWindow() -> NSWindow {
    if let window { return window }
    let newWindow = NSWindow(
      contentRect: .zero,
      styleMask: [.borderless],
      backing: .buffered,
      defer: false
    )
    newWindow.isOpaque = false
    newWindow.backgroundColor = .clear
    newWindow.hasShadow = true
    newWindow.level = .statusBar
    newWindow.ignoresMouseEvents = true
    newWindow.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
    newWindow.isReleasedWhenClosed = false
    window = newWindow
    return newWindow
  }

  private func position(_ window: NSWindow, size: NSSize) {
    let pointer = NSEvent.mouseLocation
    let screen = NSScreen.screens.first { $0.frame.contains(pointer) } ?? NSScreen.main
    guard let visibleFrame = screen?.visibleFrame else {
      window.setContentSize(size)
      window.center()
      return
    }
    window.setFrame(
      NSRect(
        x: visibleFrame.midX - size.width / 2,
        y: visibleFrame.minY + visibleFrame.height * 0.12,
        width: size.width,
        height: size.height
      ),
      display: false
    )
  }
}
