import ApplicationServices
import Foundation

enum FieldUnavailableReason: String, Equatable {
    case notInspected
    case noFocusedElement
    case unsupportedRole
    case secureField
    case noSelectedRange
    case noCharacterCount
}

enum FieldReading: Equatable {
    case caret(FieldSnapshot)
    case selection
    case unavailable(FieldUnavailableReason)
}

/// Metadata for the diagnostic trace. Contains no document text.
struct FocusInspection {
    let changed: Bool
    let field: FieldReading
    var role: String? = nil
    var elementHash: UInt? = nil
}

/// Reads identity, selected range, and character count only, never document or typed text.
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

    func inspect(pid nextPID: pid_t, allowed: Bool) -> FocusInspection {
        guard allowed, nextPID > 0 else {
            let changed = element != nil
            stop()
            return FocusInspection(changed: changed, field: .unavailable(.notInspected))
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
                AXObserverAddNotification(created, application!, kAXFocusedWindowChangedNotification as CFString, pointer)
                CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(created), .commonModes)
            }
        }
        guard let application else { return FocusInspection(changed: false, field: .unavailable(.noFocusedElement)) }
        var raw: CFTypeRef?
        guard AXUIElementCopyAttributeValue(application, kAXFocusedUIElementAttribute as CFString, &raw) == .success,
              let raw, CFGetTypeID(raw) == AXUIElementGetTypeID() else {
            return FocusInspection(changed: true, field: .unavailable(.noFocusedElement))
        }
        let focused = raw as! AXUIElement
        let changed = element.map { !CFEqual($0, focused) } ?? true
        if changed {
            if let observer, let element {
                for name in Self.elementNotifications { AXObserverRemoveNotification(observer, element, name) }
            }
            element = focused
            AXUIElementSetMessagingTimeout(focused, 0.05)
            if let observer {
                // Value changes can be external edits that keep the same caret.
                for name in Self.elementNotifications {
                    AXObserverAddNotification(observer, focused, name, Unmanaged.passUnretained(self).toOpaque())
                }
            }
        }
        var role: CFTypeRef?
        var subrole: CFTypeRef?
        AXUIElementCopyAttributeValue(focused, kAXRoleAttribute as CFString, &role)
        AXUIElementCopyAttributeValue(focused, kAXSubroleAttribute as CFString, &subrole)
        let roleName = role as? String
        func result(_ field: FieldReading) -> FocusInspection {
            FocusInspection(changed: changed, field: field, role: roleName, elementHash: CFHash(focused))
        }
        guard let roleName, [kAXTextFieldRole, kAXTextAreaRole, kAXComboBoxRole].contains(roleName) else {
            return result(.unavailable(.unsupportedRole))
        }
        guard subrole as? String != kAXSecureTextFieldSubrole else { return result(.unavailable(.secureField)) }
        var rangeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(focused, kAXSelectedTextRangeAttribute as CFString, &rangeValue) == .success,
              let rangeValue, CFGetTypeID(rangeValue) == AXValueGetTypeID() else {
            return result(.unavailable(.noSelectedRange))
        }
        let value = rangeValue as! AXValue
        var range = CFRange()
        guard AXValueGetType(value) == .cfRange, AXValueGetValue(value, .cfRange, &range),
              range.location >= 0, range.length >= 0 else { return result(.unavailable(.noSelectedRange)) }
        guard range.length == 0 else { return result(.selection) }
        // A count, not content. Without it a same-caret external edit is unobservable.
        var count: CFTypeRef?
        guard AXUIElementCopyAttributeValue(focused, kAXNumberOfCharactersAttribute as CFString, &count) == .success,
              let length = count as? Int, length >= range.location else { return result(.unavailable(.noCharacterCount)) }
        return result(.caret(FieldSnapshot(caret: range.location, length: length)))
    }

    private static let elementNotifications = [kAXSelectedTextChangedNotification as CFString,
                                               kAXValueChangedNotification as CFString]
}
