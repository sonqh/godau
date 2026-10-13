import ApplicationServices
import CoreGraphics
import VietMacCore

public struct PermissionSnapshot: Sendable {
    public let accessibility: Bool
    public let eventListening: Bool
    public let eventPosting: Bool

    /// Read-only capability checks. This function never requests permission.
    public static func current() -> PermissionSnapshot {
        PermissionSnapshot(
            accessibility: AXIsProcessTrusted(),
            eventListening: CGPreflightListenEventAccess(),
            eventPosting: CGPreflightPostEventAccess()
        )
    }
}

/// M0 will add the event tap and transport here. No interception exists yet.
public enum RuntimeStatus {
    public static let transportImplemented = false
}
