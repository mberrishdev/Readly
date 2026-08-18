import CoreGraphics
import ScreenCaptureKit

enum CaptureError: Error {
  case permissionDenied
  case displayUnavailable
  case emptyRegion
  case captureFailed(Error)
}

/// Screen capture as a protocol so `CaptureCoordinator` can be tested
/// against a mock, and so the real implementation stays swappable if
/// ScreenCaptureKit's API shifts again.
protocol CaptureServicing: Sendable {
  /// - Parameters:
  ///   - pixelRect: The region to crop, in pixels local to `displayID` —
  ///     already resolved by `CoordinateMapper`. This service does no
  ///     coordinate math of its own.
  ///   - backingScaleFactor: The same scale `CoordinateMapper` used to
  ///     produce `pixelRect`, so the captured image's own pixel grid lines
  ///     up with it exactly.
  ///   - excludingWindowNumbers: Readly's own overlay window ids, so the
  ///     content filter never photographs the dimming layer itself.
  func captureImage(
    pixelRect: CGRect,
    displayID: CGDirectDisplayID,
    backingScaleFactor: CGFloat,
    excludingWindowNumbers: [CGWindowID]
  ) async throws -> CGImage

  /// Triggers ScreenCaptureKit's own one-time "bypass the picker" consent —
  /// distinct from the classic Screen Recording toggle — by making the same
  /// shareable-content and capture calls a real capture uses. Readly builds
  /// its own `SCContentFilter` instead of showing the system's content
  /// picker (the whole point of the custom selection overlay), and macOS
  /// warns the user about that the first time it happens. Called during
  /// onboarding so that dialog appears with context instead of cold on the
  /// user's first real capture.
  func primeScreenCaptureKitAccess() async
}

struct CaptureService: CaptureServicing {
  func primeScreenCaptureKitAccess() async {
    guard let content = try? await SCShareableContent.excludingDesktopWindows(
      false,
      onScreenWindowsOnly: true
    ), let display = content.displays.first else { return }

    let filter = SCContentFilter(display: display, excludingWindows: [])
    let configuration = SCStreamConfiguration()
    configuration.width = 2
    configuration.height = 2
    _ = try? await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
  }

  func captureImage(
    pixelRect: CGRect,
    displayID: CGDirectDisplayID,
    backingScaleFactor: CGFloat,
    excludingWindowNumbers: [CGWindowID]
  ) async throws -> CGImage {
    guard pixelRect.width > 0, pixelRect.height > 0 else {
      throw CaptureError.emptyRegion
    }

    let content: SCShareableContent
    do {
      content = try await SCShareableContent.excludingDesktopWindows(
        false,
        onScreenWindowsOnly: true
      )
    } catch {
      throw CaptureError.permissionDenied
    }

    guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
      throw CaptureError.displayUnavailable
    }

    let excludedWindows = content.windows.filter {
      excludingWindowNumbers.contains(CGWindowID($0.windowID))
    }
    let filter = SCContentFilter(display: display, excludingWindows: excludedWindows)

    let configuration = SCStreamConfiguration()
    configuration.width = Int(CGFloat(display.width) * backingScaleFactor)
    configuration.height = Int(CGFloat(display.height) * backingScaleFactor)
    configuration.scalesToFit = false
    configuration.showsCursor = false

    let fullImage: CGImage
    do {
      fullImage = try await SCScreenshotManager.captureImage(
        contentFilter: filter,
        configuration: configuration
      )
    } catch {
      throw CaptureError.captureFailed(error)
    }

    let clamped = CoordinateMapper.clamp(
      pixelRect,
      to: CGSize(width: fullImage.width, height: fullImage.height)
    )
    guard clamped.width > 0, clamped.height > 0,
      let cropped = fullImage.cropping(to: clamped) else {
      throw CaptureError.emptyRegion
    }
    return cropped
  }
}
