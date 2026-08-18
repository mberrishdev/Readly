import AppKit

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
  }

  override func mouseUp(with event: NSEvent) {
    dragOrigin = nil
    let result = currentRect
    currentRect = .zero
    needsDisplay = true
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

    NSColor.white.setStroke()
    let outline = NSBezierPath(rect: hole.insetBy(dx: 0.5, dy: 0.5))
    outline.lineWidth = 1
    outline.stroke()
  }
}
