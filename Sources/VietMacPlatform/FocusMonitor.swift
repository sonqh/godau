import ApplicationServices
import Foundation

/// Reads identity and selected range only, never document or typed text.
/// Called on the owning run loop outside the keyboard callback.
@MainActor
final class FocusMonitor {
    private(set) var element: AXUIElement?
    private var application: AXUIElement?
    private var observer: AXObserver?
    private var pid: pid_t = 0
    var onNotification: (() -> Void)?

    func stop() {
        if let observer {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        }
        observer = nil
        application = nil
        element = nil
        pid = 0
    }

    func inspect(pid nextPID: pid_t, allowed: Bool) -> (changed: Bool, selection: CFRange?) {
        guard allowed, nextPID > 0 else {
            let changed = element != nil
            stop()
            return (changed, nil)
        }
        if pid != nextPID {
            stop()
            pid = nextPID
            application = AXUIElementCreateApplication(pid)
            // Bound blocking AX calls outside the key path.
            AXUIElementSetMessagingTimeout(application!, 0.05)
            var created: AXObserver?
            let result = AXObserverCreate(pid, { _, _, _, pointer in
                guard let pointer else { return }
                MainActor.assumeIsolated {
                    Unmanaged<FocusMonitor>.fromOpaque(pointer).takeUnretainedValue().onNotification?()
                }
            }, &created)
            if result == .success, let created {
                observer = created
                let pointer = Unmanaged.passUnretained(self).toOpaque()
                AXObserverAddNotification(created, application!, kAXFocusedUIElementChangedNotification as CFString, pointer)
                CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(created), .commonModes)
            }
        }
        guard let application else { return (false, nil) }
        var raw: CFTypeRef?
        guard AXUIElementCopyAttributeValue(application, kAXFocusedUIElementAttribute as CFString, &raw) == .success,
              let raw, CFGetTypeID(raw) == AXUIElementGetTypeID() else { return (true, nil) }
        let focused = raw as! AXUIElement
        let changed = element.map { !CFEqual($0, focused) } ?? true
        if changed {
            if let observer, let element {
                AXObserverRemoveNotification(observer, element, kAXSelectedTextChangedNotification as CFString)
            }
            element = focused
            AXUIElementSetMessagingTimeout(focused, 0.05)
            if let observer {
                AXObserverAddNotification(observer, focused, kAXSelectedTextChangedNotification as CFString,
                                          Unmanaged.passUnretained(self).toOpaque())
            }
        }
        var role: CFTypeRef?
        var subrole: CFTypeRef?
        AXUIElementCopyAttributeValue(focused, kAXRoleAttribute as CFString, &role)
        AXUIElementCopyAttributeValue(focused, kAXSubroleAttribute as CFString, &subrole)
        guard let role = role as? String,
              [kAXTextFieldRole, kAXTextAreaRole, kAXComboBoxRole].contains(role),
              subrole as? String != kAXSecureTextFieldSubrole else { return (changed, nil) }
        var rangeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(focused, kAXSelectedTextRangeAttribute as CFString, &rangeValue) == .success,
              let rangeValue, CFGetTypeID(rangeValue) == AXValueGetTypeID() else { return (changed, nil) }
        let value = rangeValue as! AXValue
        var range = CFRange()
        guard AXValueGetType(value) == .cfRange, AXValueGetValue(value, .cfRange, &range),
              range.location >= 0, range.length >= 0 else { return (changed, nil) }
        return (changed, range)
    }
}
