import CoreGraphics

/// Screen Recording access as a protocol so `CaptureCoordinator` can be
/// tested without touching TCC.
protocol PermissionsManaging: Sendable {
  var hasScreenRecordingAccess: Bool { get }
  /// Triggers the system prompt the first time it is called for this app;
  /// afterward macOS just returns the standing answer. Returns the access
  /// state at the moment of the call.
  @discardableResult
  func requestScreenRecordingAccess() -> Bool
}

struct PermissionsManager: PermissionsManaging {
  var hasScreenRecordingAccess: Bool {
    CGPreflightScreenCaptureAccess()
  }

  @discardableResult
  func requestScreenRecordingAccess() -> Bool {
    CGRequestScreenCaptureAccess()
  }
}
