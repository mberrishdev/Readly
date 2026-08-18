import AppKit

extension NSScreen {
  /// The Core Graphics display this screen corresponds to. `CaptureService`
  /// and `CoordinateMapper` key everything off this id rather than the
  /// `NSScreen` instance itself, because it is what ScreenCaptureKit's
  /// `SCDisplay` and `CGDisplayBounds` both speak.
  var cgDirectDisplayID: CGDirectDisplayID? {
    deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
  }
}
