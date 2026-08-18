import CoreGraphics
import Testing
@testable import Readly

/// Pins the geometry that turns a drag rectangle into the pixel rect
/// `CaptureService` crops out of a captured display image — the part of a
/// screen-capture tool that is impossible to eyeball right and easy to get
/// wrong on a second monitor or a non-Retina display.
struct CoordinateMapperTests {
  @Test func flipsCocoaSpaceToDisplaySpaceOnThePrimaryDisplay() {
    // A 1440-tall primary display; a 100x50 rect starting 200pt from the
    // bottom. Display space puts the same rect 190pt from the top.
    let cocoaRect = CGRect(x: 300, y: 200, width: 100, height: 50)
    let result = CoordinateMapper.cocoaRectToDisplaySpace(cocoaRect, primaryDisplayHeight: 1440)
    #expect(result == CGRect(x: 300, y: 1190, width: 100, height: 50))
  }

  @Test func rectRelativeToDisplayBoundsSubtractsTheDisplaysOwnOrigin() {
    // A secondary display sitting to the left of the primary, so its bounds
    // have a negative x origin in display space.
    let displaySpaceRect = CGRect(x: -1500, y: 100, width: 100, height: 50)
    let secondaryBounds = CGRect(x: -1920, y: 0, width: 1920, height: 1080)
    let result = CoordinateMapper.rect(displaySpaceRect, relativeTo: secondaryBounds)
    #expect(result == CGRect(x: 420, y: 100, width: 100, height: 50))
  }

  @Test func pixelRectScalesByTheBackingScaleFactor() {
    let points = CGRect(x: 10, y: 20, width: 100, height: 50)
    let result = CoordinateMapper.pixelRect(fromPoints: points, scale: 2)
    #expect(result == CGRect(x: 20, y: 40, width: 200, height: 100))
  }

  @Test func pixelRectAtScaleOneIsUnchanged() {
    let points = CGRect(x: 10, y: 20, width: 100, height: 50)
    let result = CoordinateMapper.pixelRect(fromPoints: points, scale: 1)
    #expect(result == points)
  }

  @Test func clampCutsARectDownToTheImagesOwnBounds() {
    // A drag that ended a few points past the display edge.
    let overshooting = CGRect(x: 1900, y: 1000, width: 100, height: 100)
    let imageSize = CGSize(width: 1920, height: 1080)
    let result = CoordinateMapper.clamp(overshooting, to: imageSize)
    #expect(result == CGRect(x: 1900, y: 1000, width: 20, height: 80))
  }

  @Test func clampLeavesAWhollyContainedRectUntouched() {
    let inside = CGRect(x: 100, y: 100, width: 200, height: 200)
    let imageSize = CGSize(width: 1920, height: 1080)
    #expect(CoordinateMapper.clamp(inside, to: imageSize) == inside)
  }

  @Test func fullPipelineOnThePrimaryRetinaDisplay() {
    // A 2x display whose bounds start at the display-space origin, which is
    // the common single-monitor Retina case.
    let cocoaRect = CGRect(x: 100, y: 700, width: 50, height: 30)
    let result = CoordinateMapper.pixelRect(
      forCocoaRect: cocoaRect,
      primaryDisplayHeight: 900,
      displayBounds: CGRect(x: 0, y: 0, width: 1440, height: 900),
      backingScaleFactor: 2
    )
    // Display space: y = 900 - (700 + 30) = 170; local == display space
    // since bounds start at zero; pixels double both axes.
    #expect(result == CGRect(x: 200, y: 340, width: 100, height: 60))
  }

  @Test func fullPipelineOnASecondaryDisplayToTheLeft() {
    // The primary is 1440 tall; the secondary sits to its left, so its
    // Cocoa-space origin (and hence its display-space origin) is negative x.
    let cocoaRect = CGRect(x: -1800, y: 940, width: 40, height: 40)
    let result = CoordinateMapper.pixelRect(
      forCocoaRect: cocoaRect,
      primaryDisplayHeight: 1440,
      displayBounds: CGRect(x: -1920, y: 0, width: 1920, height: 1080),
      backingScaleFactor: 1
    )
    // Display space y = 1440 - (940 + 40) = 460; local x = -1800 - (-1920) = 120.
    #expect(result == CGRect(x: 120, y: 460, width: 40, height: 40))
  }
}
