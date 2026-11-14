import AppKit
import Carbon
import VietMacPlatform
import VietMacShell

/// Where the shell reads the status and sends mode changes. The M0 adapter is the live source;
/// Debug builds add a simulator that never calls `InputHost`.
@MainActor
protocol StatusSource: AnyObject {
    var status: RuntimeStatus { get }
    var onStatusChange: ((RuntimeStatus) -> Void)? { get set }
    func setMode(_ mode: InputMode, source: ModeSource)
    func resume()
}

extension M0StatusAdapter: StatusSource {}

/// Display names from the system, cached for the process lifetime.
@MainActor
enum SystemNames {
    private static var apps: [String: String] = [:]
    private static var sources: [String: String] = [:]

    static func resolver() -> NameResolver {
        NameResolver(appName: { id in MainActor.assumeIsolated { appName(id) } },
                     inputSourceName: { id in MainActor.assumeIsolated { inputSourceName(id) } })
    }

    static func appName(_ bundleID: String) -> String {
        if let cached = apps[bundleID] { return cached }
        // The five supported apps keep the short names of the design; others use the system name.
        let name = NameResolver.knownApps[bundleID]
            ?? NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first?.localizedName
            ?? NameResolver.fallback.appName(bundleID)
        apps[bundleID] = name
        return name
    }

    /// ABC or U.S. is among the enabled keyboard input sources.
    static func supportedSourceEnabled() -> Bool {
        guard let list = TISCreateInputSourceList(nil, false)?.takeRetainedValue() as? [TISInputSource] else {
            return true
        }
        return list.contains { source in
            guard let pointer = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else { return false }
            let id = Unmanaged<CFString>.fromOpaque(pointer).takeUnretainedValue() as String
            return RuntimeStatus.supportedInputSources.contains(id)
        }
    }

    static func inputSourceName(_ sourceID: String) -> String {
        if let cached = sources[sourceID] { return cached }
        var name = NameResolver.fallback.inputSourceName(sourceID)
        let filter = [kTISPropertyInputSourceID as String: sourceID] as CFDictionary
        if let list = TISCreateInputSourceList(filter, true)?.takeRetainedValue() as? [TISInputSource],
           let source = list.first, let pointer = TISGetInputSourceProperty(source, kTISPropertyLocalizedName) {
            name = Unmanaged<CFString>.fromOpaque(pointer).takeUnretainedValue() as String
        }
        sources[sourceID] = name
        return name
    }
}
