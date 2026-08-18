import CoreGraphics

/// The three coordinate spaces a drag rectangle passes through on its way
/// from the overlay window to a captured image, kept in one place because
/// nothing about this is obvious and every macOS screen-capture bug report
/// starts here:
///
/// 1. **Cocoa screen space** — what `NSScreen.frame` and mouse-drag tracking
///    produce. Origin at the bottom-left of the *primary* display, y
///    increasing upward. Multi-monitor setups can have negative x/y.
/// 2. **Core Graphics display space** — what `CGDisplayBounds`,
///    `SCContentFilter`, and every screen-capture API expect. Origin at the
///    top-left of the primary display, y increasing downward.
/// 3. **Pixel space** — display space scaled by `backingScaleFactor` (2x on
///    Retina), because a captured `CGImage`'s dimensions are pixels, not
///    points.
///
/// Every function here is pure geometry with no AppKit window or display
/// lookups, so `CoordinateMapperTests` can pin the arithmetic without a
/// screen attached.
enum CoordinateMapper {
  /// Converts a Cocoa screen-space rect into Core Graphics display space.
  ///
  /// - Parameter primaryDisplayHeight: The height, in points, of the
  ///   display whose bottom-left corner is the Cocoa coordinate origin —
  ///   `NSScreen.screens[0].frame.height`, not the target display's height.
  static func cocoaRectToDisplaySpace(
    _ rect: CGRect,
    primaryDisplayHeight: CGFloat
  ) -> CGRect {
    CGRect(
      x: rect.minX,
      y: primaryDisplayHeight - rect.maxY,
      width: rect.width,
      height: rect.height
    )
  }

  /// Re-origins a display-space rect to be relative to one display's own
  /// bounds, because a capture of a single `CGDirectDisplayID` returns an
  /// image whose (0, 0) is that display's top-left corner, not the global
  /// origin.
  static func rect(_ displaySpaceRect: CGRect, relativeTo displayBounds: CGRect) -> CGRect {
    CGRect(
      x: displaySpaceRect.minX - displayBounds.minX,
      y: displaySpaceRect.minY - displayBounds.minY,
      width: displaySpaceRect.width,
      height: displaySpaceRect.height
    )
  }

  /// Scales a points rect (already local to the target display) into pixels
  /// — unclamped, because the image it will crop does not exist yet at the
  /// point this usually runs.
  static func pixelRect(fromPoints rect: CGRect, scale: CGFloat) -> CGRect {
    CGRect(
      x: rect.minX * scale,
      y: rect.minY * scale,
      width: rect.width * scale,
      height: rect.height * scale
    )
  }

  /// Clamps a pixel rect to an actual image's bounds — a drag that ends a
  /// fraction of a point past the display edge, or a rounding error from the
  /// scale multiply, must not ask `CGImage.cropping` for pixels that do not
  /// exist.
  static func clamp(_ pixelRect: CGRect, to imagePixelSize: CGSize) -> CGRect {
    pixelRect.intersection(CGRect(origin: .zero, size: imagePixelSize))
  }

  /// The full pipeline: a Cocoa-space drag rectangle plus the display it was
  /// drawn on, resolved to the unclamped pixel rect to crop out of that
  /// display's captured image. `CaptureService` clamps this to the image it
  /// actually receives before cropping.
  static func pixelRect(
    forCocoaRect cocoaRect: CGRect,
    primaryDisplayHeight: CGFloat,
    displayBounds: CGRect,
    backingScaleFactor: CGFloat
  ) -> CGRect {
    let displaySpace = cocoaRectToDisplaySpace(cocoaRect, primaryDisplayHeight: primaryDisplayHeight)
    let localPoints = rect(displaySpace, relativeTo: displayBounds)
    return pixelRect(fromPoints: localPoints, scale: backingScaleFactor)
  }
}
