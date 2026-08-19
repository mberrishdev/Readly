import AppKit
import SwiftUI

/// The dimmed, crosshaired drag surface for one screen. Reports back in its
/// own bounds space (bottom-left origin, y-up) — `SelectionOverlayController`
/// is the layer that knows how that relates to the other screens or to
/// `CGDirectDisplayID` space.
final class SelectionView: NSView {
  /// Fires once on mouse-up with the dragged rect, `.zero` for a plain click
  /// with no drag.
  var onSelectionCompleted: ((CGRect) -> Void)?

  private var dragOrigin: CGPoint?
  private var currentRect: CGRect = .zero
  private var glowHostingView: NSHostingView<SelectionGlowView>?

  override var acceptsFirstResponder: Bool { true }

  override func resetCursorRects() {
    addCursorRect(bounds, cursor: .crosshair)
  }

  override func mouseDown(with event: NSEvent) {
    let point = convert(event.locationInWindow, from: nil)
    dragOrigin = point
    currentRect = CGRect(origin: point, size: .zero)
    needsDisplay = true
  }

  override func mouseDragged(with event: NSEvent) {
    guard let dragOrigin else { return }
    let point = convert(event.locationInWindow, from: nil)
    currentRect = CGRect(
      x: min(dragOrigin.x, point.x),
      y: min(dragOrigin.y, point.y),
      width: abs(point.x - dragOrigin.x),
      height: abs(point.y - dragOrigin.y)
    )
    needsDisplay = true
    updateGlow(for: currentRect)
  }

  override func mouseUp(with event: NSEvent) {
    dragOrigin = nil
    let result = currentRect
    currentRect = .zero
    needsDisplay = true
    removeGlow()
    onSelectionCompleted?(result)
  }

  override func draw(_ dirtyRect: NSRect) {
    let dimColor = NSColor.black.withAlphaComponent(0.35)
    dimColor.setFill()

    guard currentRect.width > 0 || currentRect.height > 0 else {
      bounds.fill()
      return
    }

    // Four strips around the selection rather than a filled rect plus a
    // punched-out hole: compositing a true hole needs a non-default blend
    // mode, while four plain fills need nothing but arithmetic.
    let hole = currentRect
    NSRect(x: bounds.minX, y: hole.maxY, width: bounds.width, height: bounds.maxY - hole.maxY).fill()
    NSRect(x: bounds.minX, y: bounds.minY, width: bounds.width, height: hole.minY - bounds.minY).fill()
    NSRect(x: bounds.minX, y: hole.minY, width: hole.minX - bounds.minX, height: hole.height).fill()
    NSRect(x: hole.maxX, y: hole.minY, width: bounds.maxX - hole.maxX, height: hole.height).fill()

    // The border itself is drawn by `glowHostingView`'s Metal shader, not
    // here — a plain stroke would sit visually flat underneath its glow.
  }

  /// Creates the glow view on first use, sized with padding so the shader's
  /// outward samples (up to 9pt, see `SelectionGlow.metal`) have room to
  /// render without clipping at the hosting view's own edge.
  private func updateGlow(for rect: CGRect) {
    let padding: CGFloat = 14
    let frame = rect.insetBy(dx: -padding, dy: -padding)

    let hostingView: NSHostingView<SelectionGlowView>
    if let existing = glowHostingView {
      hostingView = existing
    } else {
      hostingView = NSHostingView(rootView: SelectionGlowView(padding: padding))
      hostingView.layer?.backgroundColor = .clear
      addSubview(hostingView)
      glowHostingView = hostingView
    }
    hostingView.frame = frame
  }

  private func removeGlow() {
    glowHostingView?.removeFromSuperview()
    glowHostingView = nil
  }
}
